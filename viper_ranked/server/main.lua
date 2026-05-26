local QBCore = exports['qb-core']:GetCoreObject()

-- ─── État global partagé ────────────────────────────────────────────────────
Positions = {
    npc     = nil,
    ['1v1'] = { arenas = {} },
    ['2v2'] = { arenas = {} },
    ['3v3'] = { arenas = {} },
}

PlayerInMatch  = {}
Matches        = {}
PendingRematch = {}

exports('IsPlayerInMatch', function(src) return PlayerInMatch[tonumber(src)] ~= nil end)  -- [matchId] = { players={[src]=true}, t1={}, t2={}, mode='' }

RegisterNetEvent('viper_ranked:cancelRematch', function()
    local src = source
    for matchId, pending in pairs(PendingRematch) do
        local team = nil
        for _, s in ipairs(pending.t1) do if s == src then team = 't1'; break end end
        if not team then
            for _, s in ipairs(pending.t2) do if s == src then team = 't2'; break end end
        end
        if team then
            for _, s in ipairs(pending[team]) do
                pending.players[s] = nil
                TriggerClientEvent('viper_ranked:rematchCancelled', s)
            end
            break
        end
    end
end)

-- ─── Positions (fichier JSON) ────────────────────────────────────────────────
local function LoadPositions()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'positions.json')
    if raw and raw ~= '' then
        local decoded = json.decode(raw)
        if decoded then
            -- Migrate old flat format {team1={}, team2={}} → {arenas=[{team1,team2}]}
            for _, mode in ipairs({ '1v1', '2v2', '3v3' }) do
                local m = decoded[mode] or {}
                if (m.team1 or m.team2) and not m.arenas then
                    local arena = { team1 = m.team1 or {}, team2 = m.team2 or {} }
                    decoded[mode] = { arenas = (next(arena.team1) or next(arena.team2)) and { arena } or {} }
                else
                    decoded[mode] = { arenas = m.arenas or {} }
                end
            end
            Positions = decoded
        end
    end
end

function SavePositions()
    SaveResourceFile(GetCurrentResourceName(), 'positions.json', json.encode(Positions), -1)
end

function GetPositions() return Positions end

-- ─── Base de données — création automatique ──────────────────────────────────
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ranked_stats` (
            `citizenid`     VARCHAR(50)  NOT NULL,
            `name`          VARCHAR(100) DEFAULT NULL,
            `wins`          INT(11)      DEFAULT 0,
            `losses`        INT(11)      DEFAULT 0,
            `elo`           INT(11)      DEFAULT 200,
            `matches`       INT(11)      DEFAULT 0,
            `ranked_coins`  INT(11)      DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        ALTER TABLE `ranked_stats`
        ADD COLUMN IF NOT EXISTS `ranked_coins` INT(11) DEFAULT 0;
    ]])

    MySQL.query([[
        ALTER TABLE `ranked_stats` ALTER COLUMN `elo` SET DEFAULT 200;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ranked_settings` (
            `setting_key`   VARCHAR(50) NOT NULL,
            `setting_value` TEXT        DEFAULT NULL,
            PRIMARY KEY (`setting_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ranked_shop` (
            `id`             INT(11)      NOT NULL AUTO_INCREMENT,
            `item_name`      VARCHAR(100) NOT NULL,
            `item_label`     VARCHAR(100) NOT NULL,
            `item_type`      ENUM('item','weapon') DEFAULT 'weapon',
            `price`          INT(11)      NOT NULL DEFAULT 100,
            `rotation_id`    INT(11)      NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ranked_purchases` (
            `id`          INT(11)     NOT NULL AUTO_INCREMENT,
            `citizenid`   VARCHAR(50) NOT NULL,
            `shop_item_id` INT(11)   NOT NULL,
            `purchased_at` TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_purchase` (`citizenid`, `shop_item_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        INSERT IGNORE INTO `ranked_settings` (`setting_key`, `setting_value`)
        VALUES ('shop_rotation_id', '1'), ('shop_rotation_start', UNIX_TIMESTAMP());
    ]])

    print('^2[viper_ranked] ^7Base de données initialisée.')
end)

-- ─── Démarrage ───────────────────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    LoadPositions()
    print('^2[viper_ranked] ^7Positions chargées.')
    SetTimeout(5000, function()
        ScheduleHoloBroadcast()
    end)
end)

-- ─── Stats joueur ────────────────────────────────────────────────────────────
function EnsurePlayer(cid, name)
    local exists = MySQL.scalar.await('SELECT citizenid FROM ranked_stats WHERE citizenid = ?', { cid })
    if not exists then
        MySQL.insert.await(
            'INSERT INTO ranked_stats (citizenid, name) VALUES (?, ?)',
            { cid, name }
        )
    end
end

function UpdatePlayerStats(src, win, cache)
    local cid, name
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        cid  = Player.PlayerData.citizenid
        name = Player.PlayerData.charinfo.firstname
    elseif cache and cache[src] then
        cid  = cache[src].cid
        name = cache[src].name
    else
        return
    end

    EnsurePlayer(cid, name)

    if win then
        MySQL.query.await(
            'UPDATE ranked_stats SET wins=wins+1, elo=elo+?, matches=matches+1, ranked_coins=ranked_coins+?, name=? WHERE citizenid=?',
            { Config.EloGain, Config.CoinsPerWin, name, cid }
        )
    else
        MySQL.query.await(
            'UPDATE ranked_stats SET losses=losses+1, elo=GREATEST(0,elo-?), matches=matches+1, name=? WHERE citizenid=?',
            { Config.EloLoss, name, cid }
        )
    end
end

function GetPlayerCoins(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 0 end
    local cid = Player.PlayerData.citizenid
    return MySQL.scalar.await('SELECT ranked_coins FROM ranked_stats WHERE citizenid=?', { cid }) or 0
end

-- ─── Leaderboard ─────────────────────────────────────────────────────────────
local function FetchLeaderboard()
    return MySQL.query.await('SELECT name, wins, losses, elo, matches FROM ranked_stats ORDER BY elo DESC LIMIT 50', {}) or {}
end

local function FetchHoloTop3()
    return MySQL.query.await('SELECT name, elo FROM ranked_stats ORDER BY elo DESC LIMIT 3', {}) or {}
end

RegisterNetEvent('viper_ranked:getLeaderboard', function()
    TriggerClientEvent('viper_ranked:receiveLeaderboard', source, FetchLeaderboard())
end)

RegisterNetEvent('viper_ranked:refreshLeaderboard', function()
    TriggerClientEvent('viper_ranked:updateLeaderboard', source, FetchLeaderboard())
end)

-- ─── Hologramme Top 3 ────────────────────────────────────────────────────────
function BroadcastHoloData()
    local pos  = Positions.holo
    local top3 = pos and FetchHoloTop3() or {}
    TriggerClientEvent('viper_ranked:syncHoloData', -1, pos, top3)
end

function ScheduleHoloBroadcast()
    SetTimeout(60000, function()
        BroadcastHoloData()
        ScheduleHoloBroadcast()
    end)
end

RegisterNetEvent('viper_ranked:requestHoloData', function()
    local src  = source
    local pos  = Positions.holo
    local top3 = pos and FetchHoloTop3() or {}
    TriggerClientEvent('viper_ranked:syncHoloData', src, pos, top3)
end)

RegisterNetEvent('viper_ranked:adminSetHoloPos', function(coords)
    local src = source
    if not IsAdmin(src) then return end
    Positions.holo = coords
    SavePositions()
    BroadcastHoloData()
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '📺 Hologramme',
        description = 'Position définie — x=' .. math.floor(coords.x) .. '  y=' .. math.floor(coords.y),
        type        = 'success',
    })
end)

RegisterNetEvent('viper_ranked:adminDeleteHoloPos', function()
    local src = source
    if not IsAdmin(src) then return end
    Positions.holo = nil
    SavePositions()
    BroadcastHoloData()
    TriggerClientEvent('ox_lib:notify', src, { title='📺 Hologramme', description='Hologramme supprimé.', type='warning' })
end)

-- ─── NPC coords ──────────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:requestNPCCoords', function()
    TriggerClientEvent('viper_ranked:syncNPCCoords', source, Positions.npc)
end)

-- ─── Admin ───────────────────────────────────────────────────────────────────
function IsAdmin(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        for _, license in ipairs(Config.AdminLicenses) do
            if id == license then return true end
        end
    end
    return false
end

RegisterNetEvent('viper_ranked:checkAdmin', function()
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('ox_lib:notify', src, { title='Admin', description='Accès refusé!', type='error' })
        return
    end
    TriggerClientEvent('viper_ranked:openAdminMenu', src)
end)

-- ─── Admin : positions / arènes ──────────────────────────────────────────────
local function SendPositionsData(src)
    local data = {}
    for _, mode in ipairs({'1v1', '2v2', '3v3'}) do
        data[mode] = Positions[mode] and Positions[mode].arenas or {}
    end
    TriggerClientEvent('viper_ranked:adminReceivePositionsData', src, data, Positions.npc)
end

RegisterNetEvent('viper_ranked:adminGetPositionsData', function()
    local src = source
    if not IsAdmin(src) then return end
    SendPositionsData(src)
end)

RegisterNetEvent('viper_ranked:adminSetNpcPos', function(coords)
    local src = source
    if not IsAdmin(src) then return end
    Positions.npc = coords
    SavePositions()
    TriggerClientEvent('viper_ranked:syncNPCCoords', -1, coords)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '✅ Position PNJ',
        description = 'Sauvegardée — x=' .. math.floor(coords.x) .. ' y=' .. math.floor(coords.y),
        type        = 'success',
    })
end)

RegisterNetEvent('viper_ranked:adminAddArena', function(mode)
    local src = source
    if not IsAdmin(src) then return end
    if not Positions[mode] then return end
    table.insert(Positions[mode].arenas, { team1 = {}, team2 = {} })
    local idx = #Positions[mode].arenas
    SavePositions()
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '✅ Arène créée',
        description = mode:upper() .. ' · Arène #' .. idx .. ' — configure maintenant les spawns.',
        type        = 'success',
    })
    SendPositionsData(src)
end)

RegisterNetEvent('viper_ranked:adminSetArenaSpawn', function(mode, arenaIdx, side, playerIdx, coords)
    local src = source
    if not IsAdmin(src) then return end
    local arena = Positions[mode] and Positions[mode].arenas[arenaIdx]
    if not arena then return end
    arena[side] = arena[side] or {}
    arena[side][playerIdx] = coords
    SavePositions()
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '✅ Spawn sauvegardé',
        description = mode:upper() .. ' · Arène #' .. arenaIdx .. ' · ' .. side .. ' J' .. playerIdx,
        type        = 'success',
    })
end)

RegisterNetEvent('viper_ranked:adminDeleteArena', function(mode, arenaIdx)
    local src = source
    if not IsAdmin(src) then return end
    if not Positions[mode] or not Positions[mode].arenas[arenaIdx] then return end
    table.remove(Positions[mode].arenas, arenaIdx)
    SavePositions()
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '🗑️ Arène supprimée',
        description = mode:upper() .. ' · Arène #' .. arenaIdx .. ' supprimée.',
        type        = 'warning',
    })
    SendPositionsData(src)
end)

RegisterNetEvent('viper_ranked:adminSetArenaBoundary', function(mode, arenaIdx, boundary)
    local src = source
    if not IsAdmin(src) then return end
    local arena = Positions[mode] and Positions[mode].arenas[arenaIdx]
    if not arena then return end
    arena.boundary = boundary
    SavePositions()
    if boundary then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = '✅ Périmètre sauvegardé',
            description = mode:upper() .. ' · Arène #' .. arenaIdx .. ' · Rayon : ' .. math.floor(boundary.radius) .. ' m',
            type        = 'success',
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title       = '🗑️ Périmètre supprimé',
            description = mode:upper() .. ' · Arène #' .. arenaIdx,
            type        = 'warning',
        })
    end
    SendPositionsData(src)
end)

RegisterNetEvent('viper_ranked:adminResetLeaderboard', function()
    local src = source
    if not IsAdmin(src) then return end
    MySQL.query.await('UPDATE ranked_stats SET wins=0, losses=0, elo=200, matches=0', {})
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '🏆 Classement réinitialisé',
        description = 'Tous les joueurs ont été remis à 200 ELO.',
        type        = 'success',
    })
    print('^2[viper_ranked] ^7Classement réinitialisé par ' .. GetPlayerName(src))
end)

RegisterNetEvent('viper_ranked:refreshNPC', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('viper_ranked:syncNPCCoords', -1, Positions.npc)
    TriggerClientEvent('ox_lib:notify', src, { title='Admin', description='PNJ rafraîchi!', type='success' })
end)

-- ─── Admin : liste des joueurs en ligne ─────────────────────────────────────
RegisterNetEvent('viper_ranked:adminGetOnlinePlayers', function()
    local src = source
    if not IsAdmin(src) then return end

    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(tonumber(id))
        if Player then
            local cid   = Player.PlayerData.citizenid
            local info  = Player.PlayerData.charinfo
            local name  = info.firstname .. ' ' .. info.lastname
            local coins = MySQL.scalar.await('SELECT ranked_coins FROM ranked_stats WHERE citizenid=?', { cid }) or 0
            table.insert(list, { src = tonumber(id), name = name, citizenid = cid, coins = coins })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    TriggerClientEvent('viper_ranked:adminReceiveOnlinePlayers', src, list)
end)

-- ─── Admin : donner des RC à un joueur ───────────────────────────────────────
RegisterNetEvent('viper_ranked:adminGiveCoins', function(targetSrc, amount)
    local src = source
    if not IsAdmin(src) then return end

    local Player = QBCore.Functions.GetPlayer(targetSrc)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, { title='Admin', description='Joueur introuvable!', type='error' })
        return
    end

    local cid  = Player.PlayerData.citizenid
    local info = Player.PlayerData.charinfo
    local name = info.firstname

    EnsurePlayer(cid, name)
    MySQL.query.await('UPDATE ranked_stats SET ranked_coins = ranked_coins + ? WHERE citizenid = ?', { amount, cid })
    local newTotal = MySQL.scalar.await('SELECT ranked_coins FROM ranked_stats WHERE citizenid = ?', { cid }) or 0

    TriggerClientEvent('ox_lib:notify', src, {
        title       = '🪙  RC donnés',
        description = '**+' .. amount .. ' RC** à **' .. name .. '**\nIl a maintenant **' .. newTotal .. ' RC**.',
        type        = 'success',
        duration    = 5000,
    })
    TriggerClientEvent('ox_lib:notify', targetSrc, {
        title       = '🪙  RankedCoins reçus',
        description = 'Un admin t\'a crédité **+' .. amount .. ' RC**.\nTon solde : **' .. newTotal .. ' RC**.',
        type        = 'success',
        duration    = 6000,
    })
end)

-- ─── Déconnexion ─────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    if PlayerInMatch[src] then
        local data  = PlayerInMatch[src]
        local match = Matches[data.matchId]
        if match and match.state ~= 'ended' then
            local winner = data.team == 'team1' and 'team2' or 'team1'
            EndMatch(data.matchId, winner)
        end
        PlayerInMatch[src] = nil
    end
    RemovePlayerFromQueue(src)
end)
