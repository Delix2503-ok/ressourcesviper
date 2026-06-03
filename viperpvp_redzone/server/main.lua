local QBCore      = exports['qb-core']:GetCoreObject()
local Zones       = {}   -- [id] = zone table
local ActiveZoneId = nil
local SafeZones   = {}   -- [id] = safezone table
local ZoneKills   = {}   -- [serverId] = kills dans la zone active (reset à chaque changement)
local TpNpcs      = {}   -- [id] = NPC TP data

local VoteActive  = false
local VoteOptions = {}
local VoteCount   = {}
local VoteVoters  = {}
local EndVote     -- forward declaration (utilisé dans StartVote avant sa définition)

-- ─────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────

local function IsAdmin(src)
    -- Whitelist directe par licence (prioritaire)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        for _, adminId in ipairs(Config.AdminLicenses) do
            if id == adminId then return true end
        end
    end
    -- Groupes QBCore / ACE
    for _, group in ipairs(Config.AdminGroups) do
        if QBCore.Functions.HasPermission(src, group) then return true end
        if IsPlayerAceAllowed(src, group) then return true end
    end
    return false
end

local function Snapshot()
    local t = {}
    for _, z in pairs(Zones) do
        t[#t + 1] = {
            id            = z.id,
            name          = z.name,
            x             = z.x,
            y             = z.y,
            z             = z.z,
            radius        = z.radius,
            active        = z.active,
            killCount     = z.killCount,
            killThreshold = z.killThreshold,
            moneyReward   = z.moneyReward,
            winReward     = z.winReward,
        }
    end
    return t
end

local function SyncAll()
    TriggerClientEvent('redzone:sync', -1, Snapshot())
end

local function SafezoneSnap()
    local t = {}
    for _, z in pairs(SafeZones) do
        t[#t + 1] = { id = z.id, name = z.name, x = z.x, y = z.y, z = z.z, radius = z.radius, active = z.active }
    end
    return t
end

local function SyncSafezones()
    TriggerClientEvent('redzone:syncSafezones', -1, SafezoneSnap())
end

local function TpNpcSnap()
    local t = {}
    for _, n in pairs(TpNpcs) do
        t[#t + 1] = { id = n.id, name = n.name or '', x = n.x, y = n.y, z = n.z, heading = n.heading }
    end
    return t
end

local function SyncTpNpcs()
    TriggerClientEvent('redzone:syncTpNpcs', -1, TpNpcSnap())
end

exports('IsPlayerInActiveRedzone', function(src)
    if not ActiveZoneId then return false end
    local zone = Zones[ActiveZoneId]
    if not zone or not zone.active then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local dx = pos.x - zone.x
    local dy = pos.y - zone.y
    local dz = pos.z - zone.z
    return (dx*dx + dy*dy + dz*dz) <= (zone.radius * zone.radius)
end)

-- ─────────────────────────────────────────────────
--  ROTATION DE ZONES
-- ─────────────────────────────────────────────────

local function Activate(zoneId)
    -- ── Récompenser le gagnant de la zone qui se termine ──────────────────
    if ActiveZoneId and next(ZoneKills) then
        local winnerId, maxKills = nil, 0
        for sid, k in pairs(ZoneKills) do
            if k > maxKills then maxKills = k; winnerId = sid end
        end
        if winnerId then
            local winnerPlayer = QBCore.Functions.GetPlayer(winnerId)
            local prevZone     = Zones[ActiveZoneId]
            if winnerPlayer and prevZone then
                local reward     = prevZone.winReward or Config.ZoneWinReward
                local winnerName = winnerPlayer.PlayerData.charinfo.firstname
                                .. ' ' .. winnerPlayer.PlayerData.charinfo.lastname
                exports['ox_inventory']:AddItem(winnerId, 'black_money', reward)
                TriggerClientEvent('QBCore:Notify', winnerId,
                    ('🏆 Vous avez gagné la RedZone avec %d kills ! +%d$ argent sale'):format(maxKills, reward),
                    'success', 8000)
                TriggerClientEvent('redzone:zoneWinner', -1, winnerName, maxKills, reward)
                print(('[RedZone] Gagnant : %s (%d kills, +%d$)'):format(winnerName, maxKills, reward))
            end
        end
    end
    ZoneKills = {}

    -- ── Rotation de zone ───────────────────────────────────────────────────
    for _, z in pairs(Zones) do
        z.active    = false
        z.killCount = 0
    end
    MySQL.update('UPDATE redzone_zones SET active = 0, kill_count = 0', {})

    Zones[zoneId].active    = true
    Zones[zoneId].killCount = 0
    ActiveZoneId = zoneId
    MySQL.update('UPDATE redzone_zones SET active = 1 WHERE id = ?', { zoneId })

    TriggerClientEvent('redzone:zoneChanged', -1, Snapshot(), Zones[zoneId].name)
    print(('[RedZone] Zone active : %s'):format(Zones[zoneId].name))
end

local function NextZone()
    local ids = {}
    for id in pairs(Zones) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids == 0 then return end

    -- Trouver la prochaine zone (rotation circulaire)
    local nextId = ids[1]
    if ActiveZoneId then
        for i, id in ipairs(ids) do
            if id == ActiveZoneId then
                nextId = ids[(i % #ids) + 1]
                break
            end
        end
    end
    Activate(nextId)
end

-- ─────────────────────────────────────────────────
--  SYSTÈME DE VOTE
-- ─────────────────────────────────────────────────

local function StartVote()
    if VoteActive then return end

    -- Construire la liste des zones candidates (toutes sauf l'active)
    local candidates = {}
    for id, z in pairs(Zones) do
        if id ~= ActiveZoneId then
            candidates[#candidates + 1] = { id = z.id, name = z.name, x = z.x, y = z.y, z = z.z, radius = z.radius }
        end
    end

    if #candidates == 0 then NextZone(); return end

    -- Mélange Fisher-Yates pour sélection aléatoire
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    local options = {}
    for i = 1, math.min(3, #candidates) do options[i] = candidates[i] end

    -- Moins de 2 candidats : activation directe sans vote
    if #options == 1 then Activate(options[1].id); SyncAll(); return end

    VoteActive  = true
    VoteOptions = options
    VoteCount   = {}
    VoteVoters  = {}
    for _, z in ipairs(options) do VoteCount[z.id] = 0 end

    TriggerClientEvent('redzone:vote:start', -1, options, 30)

    SetTimeout(30000, function()
        if VoteActive then EndVote() end
    end)
end

EndVote = function()
    if not VoteActive then return end
    VoteActive = false

    -- Trouver la zone gagnante
    local winnerId = nil
    local maxVotes = -1
    for id, count in pairs(VoteCount) do
        if count > maxVotes then maxVotes = count; winnerId = id end
    end

    -- Égalité ou aucun vote → choix aléatoire parmi les options
    if not winnerId then
        winnerId = VoteOptions[math.random(1, #VoteOptions)].id
    end

    local winnerName = Zones[winnerId] and Zones[winnerId].name or '?'
    TriggerClientEvent('redzone:vote:end', -1, winnerId, winnerName)

    SetTimeout(3000, function()
        if Zones[winnerId] then Activate(winnerId); SyncAll() end
        VoteOptions = {}; VoteCount = {}; VoteVoters = {}
    end)
end

-- ─────────────────────────────────────────────────
--  CHARGEMENT DEPUIS LA BASE DE DONNÉES
-- ─────────────────────────────────────────────────

local function LoadZones()
    -- Ajouter la colonne win_reward si elle n'existe pas (migration silencieuse)
    pcall(function()
        MySQL.update.await('ALTER TABLE redzone_zones ADD COLUMN win_reward INT NOT NULL DEFAULT 15000')
    end)

    local rows = MySQL.query.await('SELECT * FROM redzone_zones ORDER BY id ASC')
    Zones       = {}
    ActiveZoneId = nil

    if rows and #rows > 0 then
        for _, r in ipairs(rows) do
            Zones[r.id] = {
                id            = r.id,
                name          = r.name,
                x             = r.x,
                y             = r.y,
                z             = r.z,
                radius        = r.radius,
                active        = r.active == 1,
                killCount     = r.kill_count,
                killThreshold = r.kill_threshold,
                moneyReward   = r.money_reward,
                winReward     = r.win_reward or Config.ZoneWinReward,
            }
            if r.active == 1 then ActiveZoneId = r.id end
        end
        if not ActiveZoneId then NextZone() end
    else
        for _, d in ipairs(Config.DefaultZones) do
            local id = MySQL.insert.await(
                'INSERT INTO redzone_zones (name, x, y, z, radius, kill_threshold, money_reward, win_reward) VALUES (?,?,?,?,?,?,?,?)',
                { d.name, d.x, d.y, d.z, d.radius, Config.KillThreshold, Config.MoneyReward, Config.ZoneWinReward }
            )
            Zones[id] = {
                id            = id,
                name          = d.name,
                x             = d.x,
                y             = d.y,
                z             = d.z,
                radius        = d.radius,
                active        = false,
                killCount     = 0,
                killThreshold = Config.KillThreshold,
                moneyReward   = Config.MoneyReward,
                winReward     = Config.ZoneWinReward,
            }
        end
        NextZone()
    end

    print(('[RedZone] %d zone(s) chargée(s).'):format(#(rows or {})))
    SyncAll()
end

local function LoadSafezones()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS redzone_safezones (
            id     INT AUTO_INCREMENT PRIMARY KEY,
            name   VARCHAR(80) NOT NULL,
            x      FLOAT NOT NULL DEFAULT 0,
            y      FLOAT NOT NULL DEFAULT 0,
            z      FLOAT NOT NULL DEFAULT 0,
            radius INT   NOT NULL DEFAULT 100,
            active TINYINT(1) NOT NULL DEFAULT 1
        )
    ]])
    -- Forcer toutes les safezones à active = 1 (elles doivent toujours bloquer les tirs)
    MySQL.update.await('UPDATE redzone_safezones SET active = 1', {})
    local rows = MySQL.query.await('SELECT * FROM redzone_safezones ORDER BY id ASC')
    SafeZones = {}
    if rows then
        for _, r in ipairs(rows) do
            SafeZones[r.id] = { id = r.id, name = r.name, x = r.x, y = r.y, z = r.z, radius = r.radius, active = true }
        end
    end
    print(('[RedZone] %d safezone(s) chargée(s).'):format(rows and #rows or 0))
    SyncSafezones()
end

local function LoadTpNpcs()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS redzone_tp_npcs (
            id      INT AUTO_INCREMENT PRIMARY KEY,
            name    VARCHAR(64) NOT NULL DEFAULT '',
            x       FLOAT NOT NULL DEFAULT 0,
            y       FLOAT NOT NULL DEFAULT 0,
            z       FLOAT NOT NULL DEFAULT 0,
            heading FLOAT NOT NULL DEFAULT 0
        )
    ]])
    -- Ajouter la colonne name si elle n'existe pas (migration)
    pcall(function()
        MySQL.query.await("ALTER TABLE redzone_tp_npcs ADD COLUMN name VARCHAR(64) NOT NULL DEFAULT ''")
    end)
    local rows = MySQL.query.await('SELECT * FROM redzone_tp_npcs ORDER BY id ASC')
    TpNpcs = {}
    if rows then
        for _, r in ipairs(rows) do
            TpNpcs[r.id] = { id = r.id, name = r.name or '', x = r.x, y = r.y, z = r.z, heading = r.heading }
        end
    end
    print(('[RedZone] %d NPC(s) TP chargé(s).'):format(rows and #rows or 0))
    SyncTpNpcs()
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(500)
    LoadZones()
    LoadSafezones()
    LoadTpNpcs()
end)

-- Sync au joueur qui rejoint (sans TpNpcs : déjà envoyé par requestSync au démarrage client)
AddEventHandler('playerJoining', function()
    TriggerClientEvent('redzone:sync', source, Snapshot())
    TriggerClientEvent('redzone:syncSafezones', source, SafezoneSnap())
end)

-- Sync à la demande (resource restart côté client)
RegisterNetEvent('redzone:requestSync', function()
    local src = source
    TriggerClientEvent('redzone:sync', src, Snapshot())
    TriggerClientEvent('redzone:syncSafezones', src, SafezoneSnap())
    TriggerClientEvent('redzone:syncTpNpcs', src, TpNpcSnap())
end)

-- ─────────────────────────────────────────────────
--  STATISTIQUES LEADERBOARD
-- ─────────────────────────────────────────────────

local function RecordKillStats(killerSrc, victimSrc)
    local killer = QBCore.Functions.GetPlayer(killerSrc)
    local victim = QBCore.Functions.GetPlayer(victimSrc)
    if not killer or not victim then return end

    local kId   = killer.PlayerData.citizenid
    local kName = killer.PlayerData.charinfo.firstname .. ' ' .. killer.PlayerData.charinfo.lastname
    local vId   = victim.PlayerData.citizenid
    local vName = victim.PlayerData.charinfo.firstname .. ' ' .. victim.PlayerData.charinfo.lastname

    MySQL.update(
        'INSERT INTO redzone_stats (citizenid, player_name, kills_total, kills_month) VALUES (?, ?, 1, 1) ON DUPLICATE KEY UPDATE player_name = VALUES(player_name), kills_total = kills_total + 1, kills_month = kills_month + 1',
        { kId, kName }
    )
    MySQL.update(
        'INSERT INTO redzone_stats (citizenid, player_name, deaths_total) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE player_name = VALUES(player_name), deaths_total = deaths_total + 1',
        { vId, vName }
    )
end

-- (redzone:kill supprimé — la gestion des kills est maintenant dans redzone:death:register)

-- ─────────────────────────────────────────────────
--  PANEL ADMIN — DONNÉES
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:admin:get', function()
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, Config.Locale.not_admin, 'error')
        TriggerClientEvent('redzone:admin:permDenied', src)
        return
    end
    TriggerClientEvent('redzone:admin:data', src, Snapshot())
end)

-- Créer une zone
RegisterNetEvent('redzone:admin:create', function(data)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, Config.Locale.not_admin, 'error')
        return
    end

    local id = MySQL.insert.await(
        'INSERT INTO redzone_zones (name, x, y, z, radius, kill_threshold, money_reward, win_reward) VALUES (?,?,?,?,?,?,?,?)',
        { data.name, data.x, data.y, data.z, data.radius, data.killThreshold, data.moneyReward, data.winReward or Config.ZoneWinReward }
    )

    Zones[id] = {
        id            = id,
        name          = data.name,
        x             = data.x,
        y             = data.y,
        z             = data.z,
        radius        = data.radius,
        active        = false,
        killCount     = 0,
        killThreshold = data.killThreshold,
        moneyReward   = data.moneyReward,
        winReward     = data.winReward or Config.ZoneWinReward,
    }

    SyncAll()
    TriggerClientEvent('redzone:admin:data', src, Snapshot())
    TriggerClientEvent('QBCore:Notify', src, Config.Locale.zone_created:format(data.name), 'success')
end)

-- Modifier une zone
RegisterNetEvent('redzone:admin:update', function(data)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, Config.Locale.not_admin, 'error')
        return
    end

    data.id = tonumber(data.id)
    if not Zones[data.id] then return end

    MySQL.update(
        'UPDATE redzone_zones SET name=?, x=?, y=?, z=?, radius=?, kill_threshold=?, money_reward=?, win_reward=? WHERE id=?',
        { data.name, data.x, data.y, data.z, data.radius, data.killThreshold, data.moneyReward, data.winReward, data.id }
    )

    local z = Zones[data.id]
    z.name          = data.name
    z.x             = data.x
    z.y             = data.y
    z.z             = data.z
    z.radius        = data.radius
    z.killThreshold = data.killThreshold
    z.moneyReward   = data.moneyReward
    z.winReward     = data.winReward

    SyncAll()
    TriggerClientEvent('redzone:admin:data', src, Snapshot())
    TriggerClientEvent('QBCore:Notify', src, Config.Locale.zone_updated:format(data.name), 'success')
end)

-- Supprimer une zone
RegisterNetEvent('redzone:admin:delete', function(zoneId)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, Config.Locale.not_admin, 'error')
        return
    end

    zoneId = tonumber(zoneId)
    if not Zones[zoneId] then return end
    local name      = Zones[zoneId].name
    local wasActive = Zones[zoneId].active

    MySQL.update('DELETE FROM redzone_zones WHERE id = ?', { zoneId })
    Zones[zoneId] = nil

    if wasActive then
        ActiveZoneId = nil
        NextZone()
    end

    SyncAll()
    TriggerClientEvent('redzone:admin:data', src, Snapshot())
    TriggerClientEvent('QBCore:Notify', src, Config.Locale.zone_deleted:format(name), 'success')
end)

-- Forcer l'activation d'une zone
RegisterNetEvent('redzone:admin:activate', function(zoneId)
    local src = source
    if not IsAdmin(src) then return end
    zoneId = tonumber(zoneId)
    if not Zones[zoneId] then return end
    Activate(zoneId)
    SyncAll()
    TriggerClientEvent('redzone:admin:data', src, Snapshot())
end)

-- Forcer un vote (bouton admin)
RegisterNetEvent('redzone:admin:forceVote', function()
    local src = source
    if not IsAdmin(src) then return end
    if VoteActive then
        TriggerClientEvent('QBCore:Notify', src, 'Un vote est déjà en cours.', 'error')
        return
    end
    StartVote()
end)

-- ─────────────────────────────────────────────────
--  LEADERBOARD
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:vote:submit', function(zoneId)
    local src = source
    if not VoteActive then return end
    if VoteVoters[src] then return end
    zoneId = tonumber(zoneId)
    if not VoteCount[zoneId] then return end
    VoteVoters[src] = zoneId
    VoteCount[zoneId] = VoteCount[zoneId] + 1
    TriggerClientEvent('redzone:vote:update', -1, VoteCount)
end)

RegisterNetEvent('redzone:leaderboard:get', function()
    local src  = source
    local rows = MySQL.query.await(
        'SELECT citizenid, player_name, kills_total, deaths_total, kills_month FROM redzone_stats ORDER BY kills_month DESC, kills_total DESC LIMIT 50'
    )
    -- Récupérer les stats personnelles du joueur avec son rang mensuel
    local myStats = nil
    local player  = QBCore.Functions.GetPlayer(src)
    if player then
        local cid  = player.PlayerData.citizenid
        local mine = MySQL.query.await(
            'SELECT citizenid, player_name, kills_total, deaths_total, kills_month FROM redzone_stats WHERE citizenid = ?',
            { cid }
        )
        if mine and #mine > 0 then
            myStats = mine[1]
            myStats.rank = 1
            for _, r in ipairs(rows or {}) do
                if r.citizenid == cid then break end
                myStats.rank = myStats.rank + 1
            end
        end
    end
    TriggerClientEvent('redzone:leaderboard:data', src, rows or {}, IsAdmin(src), myStats)
end)

RegisterNetEvent('redzone:leaderboard:reset', function()
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, Config.Locale.not_admin, 'error')
        return
    end
    MySQL.update.await('UPDATE redzone_stats SET kills_month = 0, kills_total = 0, deaths_total = 0', {})
    TriggerClientEvent('QBCore:Notify', src, 'Leaderboard réinitialisé.', 'success')

    -- Rafraîchir uniquement l'onglet admin, sans ouvrir le leaderboard public
    local rows = MySQL.query.await(
        'SELECT citizenid, player_name, kills_total, kills_month, deaths_total FROM redzone_stats ORDER BY kills_month DESC, kills_total DESC'
    )
    TriggerClientEvent('redzone:admin:lbData', src, rows or {})
end)

-- /autorevive : se relève instantanément (modo, modo_test, admin, god)
RegisterCommand('autorevive', function(src)
    if src == 0 then return end
    if not IsPlayerAceAllowed(src, 'viper.modo') then
        TriggerClientEvent('QBCore:Notify', src, 'Accès refusé.', 'error')
        return
    end
    TriggerClientEvent('redzone:autorevive', src)
end, false)

-- Commande console/admin pour reset le leaderboard mensuel : /rzresetlb
RegisterCommand('rzresetlb', function(src)
    if src ~= 0 and not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, Config.Locale.not_admin, 'error')
        return
    end
    MySQL.update('UPDATE redzone_stats SET kills_month = 0, kills_total = 0, deaths_total = 0', {})
    print('[RedZone] Leaderboard mensuel réinitialisé.')
    if src ~= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Leaderboard mensuel réinitialisé.', 'success')
    end
end, true)

-- ─────────────────────────────────────────────────
--  PANEL ADMIN — GESTION LEADERBOARD
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:admin:lb:get', function()
    local src = source
    if not IsAdmin(src) then return end
    local rows = MySQL.query.await(
        'SELECT citizenid, player_name, kills_total, kills_month, deaths_total FROM redzone_stats ORDER BY kills_month DESC, kills_total DESC'
    )
    TriggerClientEvent('redzone:admin:lbData', src, rows or {})
end)

RegisterNetEvent('redzone:admin:lb:delete', function(citizenids)
    local src = source
    if not IsAdmin(src) then return end
    if type(citizenids) ~= 'table' or #citizenids == 0 then return end

    local placeholders = {}
    for i = 1, #citizenids do placeholders[i] = '?' end
    MySQL.update(
        'DELETE FROM redzone_stats WHERE citizenid IN (' .. table.concat(placeholders, ',') .. ')',
        citizenids
    )

    TriggerClientEvent('QBCore:Notify', src, #citizenids .. ' joueur(s) supprimé(s) du leaderboard.', 'success')

    local rows = MySQL.query.await(
        'SELECT citizenid, player_name, kills_total, kills_month, deaths_total FROM redzone_stats ORDER BY kills_month DESC, kills_total DESC'
    )
    TriggerClientEvent('redzone:admin:lbData', src, rows or {})
end)

-- ─────────────────────────────────────────────────
--  PANEL ADMIN — SAFEZONES
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:admin:sz:get', function()
    local src = source
    if not IsAdmin(src) then TriggerClientEvent('redzone:admin:permDenied', src); return end
    TriggerClientEvent('redzone:admin:szData', src, SafezoneSnap())
end)

RegisterNetEvent('redzone:admin:sz:create', function(data)
    local src = source
    if not IsAdmin(src) then return end
    local id = MySQL.insert.await(
        'INSERT INTO redzone_safezones (name, x, y, z, radius, active) VALUES (?,?,?,?,?,1)',
        { data.name, data.x, data.y, data.z, data.radius }
    )
    SafeZones[id] = { id = id, name = data.name, x = data.x, y = data.y, z = data.z, radius = data.radius, active = true }
    SyncSafezones()
    TriggerClientEvent('redzone:admin:szData', src, SafezoneSnap())
end)

RegisterNetEvent('redzone:admin:sz:update', function(data)
    local src = source
    if not IsAdmin(src) then return end
    data.id = tonumber(data.id)
    if not SafeZones[data.id] then return end
    MySQL.update(
        'UPDATE redzone_safezones SET name=?, x=?, y=?, z=?, radius=? WHERE id=?',
        { data.name, data.x, data.y, data.z, data.radius, data.id }
    )
    local z = SafeZones[data.id]
    z.name = data.name; z.x = data.x; z.y = data.y; z.z = data.z; z.radius = data.radius
    SyncSafezones()
    TriggerClientEvent('redzone:admin:szData', src, SafezoneSnap())
end)

RegisterNetEvent('redzone:admin:sz:delete', function(szId)
    local src = source
    if not IsAdmin(src) then return end
    szId = tonumber(szId)
    if not SafeZones[szId] then return end
    MySQL.update('DELETE FROM redzone_safezones WHERE id = ?', { szId })
    SafeZones[szId] = nil
    SyncSafezones()
    TriggerClientEvent('redzone:admin:szData', src, SafezoneSnap())
end)

RegisterNetEvent('redzone:admin:sz:toggle', function(szId)
    local src = source
    if not IsAdmin(src) then return end
    szId = tonumber(szId)
    if not SafeZones[szId] then return end
    SafeZones[szId].active = not SafeZones[szId].active
    MySQL.update('UPDATE redzone_safezones SET active = ? WHERE id = ?', { SafeZones[szId].active and 1 or 0, szId })
    SyncSafezones()
    TriggerClientEvent('redzone:admin:szData', src, SafezoneSnap())
end)

-- ─────────────────────────────────────────────────
--  PANEL ADMIN — NPC TP
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:admin:tpnpc:list', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('redzone:admin:tpNpcData', src, TpNpcSnap())
end)

RegisterNetEvent('redzone:admin:tpnpc:create', function(npcName)
    local src = source
    if not IsAdmin(src) then return end
    local ped     = GetPlayerPed(src)
    local pos     = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local name    = tostring(npcName or ''):sub(1, 64)
    local id = MySQL.insert.await(
        'INSERT INTO redzone_tp_npcs (name, x, y, z, heading) VALUES (?,?,?,?,?)',
        { name, pos.x, pos.y, pos.z, heading }
    )
    TpNpcs[id] = { id = id, name = name, x = pos.x, y = pos.y, z = pos.z, heading = heading }
    SyncTpNpcs()
    TriggerClientEvent('redzone:admin:tpNpcData', src, TpNpcSnap())
    TriggerClientEvent('QBCore:Notify', src, ('NPC TP "%s" spawné.'):format(name ~= '' and name or ('#'..id)), 'success')
end)

RegisterNetEvent('redzone:admin:tpnpc:delete', function(npcId)
    local src = source
    if not IsAdmin(src) then return end
    npcId = tonumber(npcId)
    if not TpNpcs[npcId] then return end
    MySQL.update('DELETE FROM redzone_tp_npcs WHERE id = ?', { npcId })
    TpNpcs[npcId] = nil
    SyncTpNpcs()
    TriggerClientEvent('redzone:admin:tpNpcData', src, TpNpcSnap())
    TriggerClientEvent('QBCore:Notify', src, 'NPC TP supprimé.', 'success')
end)

-- ─────────────────────────────────────────────────
--  SYSTÈME DE MORT / COMA
-- ─────────────────────────────────────────────────

local DeadPlayers = {}  -- [serverId] = timestamp (GetGameTimer) de la mort

-- Exports état de mort validé serveur-side (utilisés par vipertpramp pour le self-revive)
exports('IsPlayerDead', function(src)
    return DeadPlayers[tonumber(src)] ~= nil
end)
exports('ClearPlayerDeath', function(src)
    DeadPlayers[tonumber(src)] = nil
end)

RegisterNetEvent('redzone:death:register', function(killerId, zoneId)
    local victimId = source
    -- Anti-spam / anti double-crédit : ignorer si la victime est déjà comptée morte
    if DeadPlayers[victimId] then return end
    DeadPlayers[victimId] = GetGameTimer()

    -- Émettre l'événement de log (même sans kill en zone)
    TriggerEvent('viperlogs:death', victimId, killerId and tonumber(killerId))

    -- Créditer le kill au dernier attaquant si la victime était en zone
    if not killerId or not zoneId then return end
    killerId = tonumber(killerId)
    if not killerId or killerId == victimId then return end
    -- Un joueur mort ne peut pas créditer un kill (empêche le farm via alt à terre)
    if DeadPlayers[killerId] then return end

    local zone = Zones[zoneId]
    if not zone or not zone.active then return end

    local killer = QBCore.Functions.GetPlayer(killerId)
    local victim = QBCore.Functions.GetPlayer(victimId)
    if not killer or not victim then return end

    -- Valider que le killer est encore dans la zone (tolérance 25m)
    local kcoords = GetEntityCoords(GetPlayerPed(killerId))
    local dx = kcoords.x - zone.x
    local dy = kcoords.y - zone.y
    if (dx * dx + dy * dy) > ((zone.radius + 25) * (zone.radius + 25)) then return end

    -- Valider que la victime était elle aussi en zone (tolérance 25m)
    local vcoords = GetEntityCoords(GetPlayerPed(victimId))
    local vdx = vcoords.x - zone.x
    local vdy = vcoords.y - zone.y
    if (vdx * vdx + vdy * vdy) > ((zone.radius + 25) * (zone.radius + 25)) then return end

    exports['ox_inventory']:AddItem(killerId, 'black_money', zone.moneyReward)
    TriggerClientEvent('redzone:notifyKill', killerId, zone.moneyReward)
    RecordKillStats(killerId, victimId)

    ZoneKills[killerId] = (ZoneKills[killerId] or 0) + 1

    -- Trouver le leader actuel (joueur avec le plus de kills dans la zone)
    local leaderName, leaderKills = nil, 0
    for sid, k in pairs(ZoneKills) do
        if k > leaderKills then
            leaderKills = k
            local lp = QBCore.Functions.GetPlayer(tonumber(sid))
            if lp then
                leaderName = lp.PlayerData.charinfo.firstname .. ' ' .. lp.PlayerData.charinfo.lastname
            end
        end
    end

    zone.killCount = zone.killCount + 1
    MySQL.update('UPDATE redzone_zones SET kill_count = ? WHERE id = ?', { zone.killCount, zoneId })
    TriggerClientEvent('redzone:updateKills', -1, zoneId, zone.killCount, leaderName, leaderKills)

    if zone.killCount >= zone.killThreshold then
        zone.active = false
        MySQL.update('UPDATE redzone_zones SET active = 0 WHERE id = ?', { zoneId })
        SyncAll()
        -- Délai de grâce : 10s sans zone active → les joueurs peuvent utiliser /safe librement
        SetTimeout(10000, function()
            StartVote()
        end)
    end
end)

RegisterNetEvent('redzone:death:clear', function()
    DeadPlayers[source] = nil
end)

RegisterNetEvent('redzone:revive:attempt', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not DeadPlayers[targetId] then return end

    local rCoords = GetEntityCoords(GetPlayerPed(src))
    local tCoords = GetEntityCoords(GetPlayerPed(targetId))
    local dx = rCoords.x - tCoords.x
    local dy = rCoords.y - tCoords.y
    local dz = rCoords.z - tCoords.z
    if (dx*dx + dy*dy + dz*dz) > 25.0 then return end  -- 5m max

    DeadPlayers[targetId] = nil

    -- Si la cible était portée, stopper le portage proprement
    for carrierId, cTarget in pairs(Carriers or {}) do
        if cTarget == targetId then
            Carriers[carrierId] = nil
            local ok, ped = pcall(GetPlayerPed, targetId)
            if ok and ped and ped ~= 0 then
                local ok2, netId = pcall(NetworkGetNetworkIdFromEntity, ped)
                if ok2 and netId then
                    TriggerClientEvent('redzone:carry:detach', -1, netId)
                end
            end
            TriggerClientEvent('redzone:carry:stopped', carrierId)
            break
        end
    end

    TriggerClientEvent('redzone:revived', targetId)
end)

local Carriers = {}  -- [carrierId] = targetId

AddEventHandler('playerDropped', function()
    local src = source

    -- Déco pendant le death screen → vider l'inventaire en DB
    -- ox_inventory sauvegarde en async (MySQL.prepare non-bloquant) dans son propre playerDropped.
    -- On attend 500ms pour être sûr que son save est terminé, puis on écrase avec un inventaire vide.
    if DeadPlayers[src] then
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            player.Functions.SetMetaData('isdead', false)
            player.Functions.SetMetaData('inLastStand', false)
            local citizenid = player.PlayerData.citizenid
            SetTimeout(500, function()
                MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', citizenid })
            end)
        end
    end
    DeadPlayers[src] = nil

    -- Si ce joueur portait quelqu'un → libérer
    local targetId = Carriers[src]
    if targetId then
        Carriers[src] = nil
        TriggerClientEvent('redzone:carry:released', targetId)
        local ok, ped = pcall(GetPlayerPed, targetId)
        if ok and ped and ped ~= 0 then
            local ok2, netId = pcall(NetworkGetNetworkIdFromEntity, ped)
            if ok2 and netId then
                TriggerClientEvent('redzone:carry:detach', -1, netId)
            end
        end
    end
    -- Si ce joueur était porté → libérer le porteur
    for cId, tId in pairs(Carriers) do
        if tId == src then
            Carriers[cId] = nil
            break
        end
    end
end)

-- ─────────────────────────────────────────────────
--  PORTER
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:carry:start', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end
    if Carriers[src] then return end
    local ok, inMatch = pcall(function() return exports['viper_ranked']:IsPlayerInMatch(src) end)
    if ok and inMatch then return end

    local rPos = GetEntityCoords(GetPlayerPed(src))

    -- Bloquer le portage si le porteur est dans une safezone
    for _, z in pairs(SafeZones) do
        if z.active then
            local dx = rPos.x - z.x
            local dy = rPos.y - z.y
            if (dx*dx + dy*dy) <= (z.radius * z.radius) then
                TriggerClientEvent('QBCore:Notify', src, "Impossible de porter dans une safezone.", 'error')
                return
            end
        end
    end

    local targetPed = GetPlayerPed(targetId)
    local tPos = GetEntityCoords(targetPed)
    if #(rPos - tPos) > 4.0 then
        TriggerClientEvent('QBCore:Notify', src, "Joueur trop loin.", 'error')
        return
    end

    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 or GetVehiclePedIsIn(targetPed, false) ~= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Impossible de porter quelqu'un dans un véhicule.", 'error')
        return
    end

    Carriers[src] = targetId
    local carrierNet = NetworkGetNetworkIdFromEntity(GetPlayerPed(src))
    local targetNet  = NetworkGetNetworkIdFromEntity(GetPlayerPed(targetId))
    TriggerClientEvent('redzone:carry:doCarry',    src,      targetNet)
    -- La CIBLE reçoit le netId ET le server ID du porteur
    TriggerClientEvent('redzone:carry:attachSelf', targetId, carrierNet, src)
end)

RegisterNetEvent('redzone:carry:stop', function()
    local src      = source
    local targetId = Carriers[src]
    if not targetId then return end
    Carriers[src] = nil
    local ok, ped = pcall(GetPlayerPed, targetId)
    if ok and ped and ped ~= 0 then
        local ok2, netId = pcall(NetworkGetNetworkIdFromEntity, ped)
        if ok2 and netId then
            TriggerClientEvent('redzone:carry:detach', -1, netId)
        end
    end
    TriggerClientEvent('redzone:carry:released', targetId)
end)

-- Cible vivante qui se libère elle-même du porteur
RegisterNetEvent('redzone:carry:escape', function()
    local src = source
    -- Trouver qui porte cette cible
    for carrierId, targetId in pairs(Carriers) do
        if targetId == src then
            Carriers[carrierId] = nil
            -- Stopper l'état porteur côté carrier
            TriggerClientEvent('redzone:carry:stopped', carrierId)
            break
        end
    end
end)

-- ─────────────────────────────────────────────────
--  LOOT
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:admin:toggleAmbientSounds', function(muted)
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('viper-hud:client:updateConfig', -1, 'ambient', muted)
end)

RegisterNetEvent('redzone:loot:request', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end
    if not DeadPlayers[targetId] then
        TriggerClientEvent('QBCore:Notify', src, "Ce joueur n'est pas à terre.", 'error')
        return
    end
    local rPos = GetEntityCoords(GetPlayerPed(src))
    local tPos = GetEntityCoords(GetPlayerPed(targetId))
    if #(rPos - tPos) > 4.0 then
        TriggerClientEvent('QBCore:Notify', src, "Trop loin pour fouiller.", 'error')
        return
    end
    -- Autoriser canSteal sur la cible le temps de l'ouverture (ox_inventory vérifie ce state bag)
    TriggerClientEvent('redzone:loot:allowSteal', targetId, true)
    -- 600ms : laisse le state bag canSteal se propager jusqu'au client looter avant d'ouvrir l'inventaire
    SetTimeout(600, function()
        TriggerClientEvent('redzone:loot:open', src, targetId)
        -- Révoquer l'autorisation après 15s (temps de fermeture naturelle de l'inventaire)
        SetTimeout(15000, function()
            TriggerClientEvent('redzone:loot:allowSteal', targetId, false)
        end)
    end)
end)
