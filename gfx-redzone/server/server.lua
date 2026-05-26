Zones = {}
local ZoneCreatedAt = 0

-- ─── Vote state ───────────────────────────────────────────────────────────────
local VoteActive  = false
local VoteCounts  = {}
local VoteOptions = {}
local VoteVoters  = {}

local VOTE_DURATION = 30 -- secondes

local function PickVoteCandidates(count)
    local locationKeys = {}
    for k in pairs(Config.ZoneLocations) do locationKeys[#locationKeys + 1] = k end
    -- Exclure zones actives
    local activeIds = {}
    for _, z in ipairs(Zones) do activeIds[z.id] = true end
    local available = {}
    for _, k in ipairs(locationKeys) do
        if not activeIds[k] then available[#available + 1] = k end
    end
    -- Fisher-Yates shuffle
    for i = #available, 2, -1 do
        local j = math.random(i)
        available[i], available[j] = available[j], available[i]
    end
    local candidates = {}
    for i = 1, math.min(count, #available) do
        local id  = available[i]
        local v   = Config.ZoneLocations[id]
        candidates[#candidates + 1] = { id = id, name = v.name or ('Zone ' .. id) }
    end
    -- Fallback : compléter avec des zones actives si pas assez
    if #candidates < count then
        for _, k in ipairs(locationKeys) do
            local already = false
            for _, c in ipairs(candidates) do if c.id == k then already = true; break end end
            if not already then
                local v = Config.ZoneLocations[k]
                candidates[#candidates + 1] = { id = k, name = v.name or ('Zone ' .. k) }
                if #candidates >= count then break end
            end
        end
    end
    return candidates
end

local function PickVoteWinner()
    local best, bestCount = nil, -1
    local tied = {}
    for _, opt in ipairs(VoteOptions) do
        local c = VoteCounts[opt.id] or 0
        if c > bestCount then
            bestCount = c; best = opt; tied = { opt }
        elseif c == bestCount then
            tied[#tied + 1] = opt
        end
    end
    local winner = (#tied > 1) and tied[math.random(#tied)] or best
    if not winner and #VoteOptions > 0 then winner = VoteOptions[math.random(#VoteOptions)] end
    return winner and winner.id or nil, winner and winner.name or nil
end

RegisterNetEvent('gfx-redzone:vote:submit', function(zoneId)
    if not VoteActive then return end
    local src = source
    if VoteVoters[src] then return end
    VoteVoters[src] = true
    VoteCounts[zoneId] = (VoteCounts[zoneId] or 0) + 1
    TriggerClientEvent('gfx-redzone:vote:update', -1, VoteCounts)
end)

function GetKillLeader(players)
    local maxKills, leader = 0, false
    for identifier, player in pairs(players) do
        if player.i and player.k > maxKills then
            maxKills = player.k
            leader   = identifier
        end
    end
    return maxKills > 0 and leader or false
end

function CreateZones()
    local pickCount     = Config.ZoneCount
    local pickedIndexes = {}
    local locationKeys  = {}
    for k in pairs(Config.ZoneLocations) do locationKeys[#locationKeys + 1] = k end
    for i = 1, pickCount do
        local id = locationKeys[math.random(#locationKeys)]
        while pickedIndexes[id] do
            id = locationKeys[math.random(#locationKeys)]
        end
        pickedIndexes[id] = true
        table.insert(Zones, { id = id, totalKills = 0, players = {} })
    end
    ZoneCreatedAt = os.time()
    TriggerClientEvent("gfx-redzone:UpdateZones",  -1, Zones)
    TriggerClientEvent("gfx-redzone:CreateZone",   -1)
    TriggerClientEvent("gfx-redzone:TimerUpdate",  -1, Config.ChangeZonesInterval * 60)
end

function DeleteZones()
    if #Zones == 0 then return end

    for i = 1, #Zones do
        -- Chercher le gagnant parmi tous les participants (i=false inclus — joueur peut avoir quitté la zone)
        local leader, maxK = false, 0
        for ident, player in pairs(Zones[i].players) do
            if player.k > maxK then maxK = player.k; leader = ident end
        end

        if leader and maxK > 0 then
            if Config.RewardOnFinish.money ~= 0 then
                AddMoney(Zones[i].players[leader].s, Config.RewardOnFinish.money)
            end
            if Config.RewardOnFinish.giveAllItems then
                for _, item in ipairs(Config.RewardOnFinish.items) do
                    AddItem(Zones[i].players[leader].s, item.name, item.count, item.label)
                end
            elseif #Config.RewardOnFinish.items > 0 then
                local item = Config.RewardOnFinish.items[math.random(#Config.RewardOnFinish.items)]
                AddItem(Zones[i].players[leader].s, item.name, item.count, item.label)
            end
        end
    end

    Zones = {}
    TriggerClientEvent("gfx-redzone:UpdateZones", -1, Zones)
    TriggerClientEvent("gfx-redzone:RemoveZone",  -1)
end

function RelocateZones()
    DeleteZones()
    CreateZones()
    Notify(-1, Locales["zones_changed"])
end

-- ─── Entrée / sortie de zone ──────────────────────────────────────────────────

RegisterServerEvent("gfx-redzone:enteredZone", function(zoneId)
    local identifier = GetIdent(source)
    if not Zones[zoneId] then return end
    if Zones[zoneId].players[identifier] == nil then
        Zones[zoneId].players[identifier] = { k = 0, d = 0, i = true, n = GetName(source), s = source }
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "players", nil, identifier, Zones[zoneId].players[identifier])
    else
        Zones[zoneId].players[identifier].i = true
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "players", nil, identifier, nil, "i", true)
    end
end)

RegisterServerEvent("gfx-redzone:exitedZone", function(zoneId)
    local identifier = GetIdent(source)
    if Zones[zoneId] and Zones[zoneId].players[identifier] then
        Zones[zoneId].players[identifier].i = false
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "players", nil, identifier, nil, "i", false)
    end
end)

-- ─── Kill (via baseevents:onPlayerDied côté victime) ──────────────────────────

RegisterServerEvent("gfx-redzone:playerKilled", function(zoneId, killerServerId)
    local victimSrc   = source
    local victimIdent = GetIdent(victimSrc)
    local killerIdent = killerServerId and GetIdent(killerServerId) or nil

    if not Zones[zoneId] then return end

    if Zones[zoneId].players[victimIdent] and Zones[zoneId].players[victimIdent].i then
        Zones[zoneId].players[victimIdent].d = Zones[zoneId].players[victimIdent].d + 1
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "players", nil, victimIdent, nil, "d", Zones[zoneId].players[victimIdent].d)
    end

    if killerIdent and Zones[zoneId].players[killerIdent] and Zones[zoneId].players[killerIdent].i then
        Zones[zoneId].players[killerIdent].k = Zones[zoneId].players[killerIdent].k + 1
        Zones[zoneId].totalKills             = Zones[zoneId].totalKills + 1
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "players", nil, killerIdent, nil, "k", Zones[zoneId].players[killerIdent].k)
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "totalKills", Zones[zoneId].totalKills)
    end
end)

-- ─── Connexion joueur ─────────────────────────────────────────────────────────

RegisterServerEvent("gfx-redzone:server:Identifier", function()
    local id        = GetIdent(source)  -- utilise Config.IdentifierType = "license"
    local remaining = math.max(0, (Config.ChangeZonesInterval * 60) - (os.time() - ZoneCreatedAt))
    TriggerClientEvent("gfx-redzone:UpdateZones",  source, Zones)
    TriggerClientEvent("gfx-redzone:CreateZone",   source)
    TriggerClientEvent("gfx-redzone:Identifier",   source, id)
    TriggerClientEvent("gfx-redzone:TimerUpdate",  source, remaining)
end)

-- ─── Helpers ──────────────────────────────────────────────────────────────────

function GetIdent(source, idType)
    if source ~= 0 then
        idType = idType ~= nil and idType or Config.IdentifierType
        local identifiers = GetPlayerIdentifiers(source)
        for i = 1, #identifiers do
            if identifiers[i]:match(idType) then return identifiers[i] end
        end
    else
        return 0
    end
end

function IsPlayerInZone(source)
    -- Vérification par coordonnées réelles — fiable même si le joueur a quitté l'event enteredZone sans que exitedZone soit reçu
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local ok, pos = pcall(GetEntityCoords, ped)
    if not ok then return false end
    for i = 1, #Zones do
        local loc = Config.ZoneLocations[Zones[i].id]
        if loc then
            local dx = pos.x - loc.coords.x
            local dy = pos.y - loc.coords.y
            if (dx*dx + dy*dy) <= (loc.radius * loc.radius) then
                return true
            end
        end
    end
    return false
end

exports("IsPlayerInRedZone",         IsPlayerInZone)
exports("IsPlayerInActiveRedzone",   IsPlayerInZone)

-- ─── Démarrage ────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Les zones doivent se créer immédiatement, sans dépendance DB
    CreateZones()

    Citizen.CreateThread(function()
        while true do
            -- Attendre la durée complète de la zone (timer → 0)
            Wait(math.max(1000, Config.ChangeZonesInterval * 60 * 1000))

            -- Lancer le vote quand le timer atteint 0
            local candidates = PickVoteCandidates(3)
            VoteOptions = candidates
            VoteCounts  = {}
            VoteVoters  = {}
            VoteActive  = true
            TriggerClientEvent('gfx-redzone:vote:start', -1, candidates, VOTE_DURATION)

            -- Attendre la fin du vote
            Wait(VOTE_DURATION * 1000)

            -- Résultat
            local winnerId, winnerName = PickVoteWinner()
            VoteActive = false
            TriggerClientEvent('gfx-redzone:vote:end', -1, winnerId, winnerName)

            -- Changer les zones avec le gagnant
            DeleteZones()
            if winnerId then
                local locationKeys = {}
                for k in pairs(Config.ZoneLocations) do locationKeys[#locationKeys + 1] = k end
                local picked = { [winnerId] = true }
                Zones = { { id = winnerId, totalKills = 0, players = {} } }
                for i = 2, Config.ZoneCount do
                    local id
                    repeat id = locationKeys[math.random(#locationKeys)] until not picked[id]
                    picked[id] = true
                    Zones[#Zones + 1] = { id = id, totalKills = 0, players = {} }
                end
            else
                -- Aucun vote → aléatoire
                local locationKeys = {}
                for k in pairs(Config.ZoneLocations) do locationKeys[#locationKeys + 1] = k end
                local picked = {}
                for i = 1, Config.ZoneCount do
                    local id
                    repeat id = locationKeys[math.random(#locationKeys)] until not picked[id]
                    picked[id] = true
                    Zones[#Zones + 1] = { id = id, totalKills = 0, players = {} }
                end
            end
            ZoneCreatedAt = os.time()
            TriggerClientEvent('gfx-redzone:UpdateZones',  -1, Zones)
            TriggerClientEvent('gfx-redzone:CreateZone',   -1)
            TriggerClientEvent('gfx-redzone:TimerUpdate',  -1, Config.ChangeZonesInterval * 60)
            Notify(-1, Locales["zones_changed"])
        end
    end)

    -- Création de la table leaderboard (non-bloquant, délai pour laisser oxmysql démarrer)
    Citizen.CreateThread(function()
        Wait(3000)
        exports['oxmysql']:update([[
            CREATE TABLE IF NOT EXISTS gfx_redzone_leaderboard (
                citizenid   VARCHAR(60)  NOT NULL,
                player_name VARCHAR(100) NOT NULL DEFAULT 'Inconnu',
                kills       INT          NOT NULL DEFAULT 0,
                PRIMARY KEY (citizenid)
            )
        ]], {})
    end)
end)

-- ─── Commandes leaderboard ────────────────────────────────────────────────────

-- ─── Suppression véhicule redzone ────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:deleteVehicle', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
end)

RegisterNetEvent('gfx-redzone:requestLeaderboard', function()
    local src = source
    exports['oxmysql']:query(
        'SELECT citizenid, player_name, kills FROM gfx_redzone_leaderboard ORDER BY kills DESC LIMIT 20',
        {},
        function(results)
            TriggerClientEvent('gfx-redzone:showLeaderboard', src, results or {})
        end
    )
end)

RegisterCommand("leaderboard", function(source)
    if source == 0 then
        exports['oxmysql']:query(
            'SELECT player_name, kills FROM gfx_redzone_leaderboard ORDER BY kills DESC LIMIT 20',
            {}, function(results)
                if not results then return end
                print("[GFX-REDZONE] TOP 20 :")
                for i, row in ipairs(results) do
                    print(string.format("  #%d %s — %d kills", i, row.player_name, row.kills))
                end
            end
        )
    else
        TriggerClientEvent('gfx-redzone:openLeaderboard', source)
    end
end, false)

RegisterCommand("resetleaderboard", function(source, args)
    if source > 0 and not IsPlayerAceAllowed(tostring(source), 'command') then
        Notify(source, "Permission refusée.")
        return
    end
    exports['oxmysql']:update('TRUNCATE TABLE gfx_redzone_leaderboard', {}, function()
        Notify(-1, "Leaderboard Redzone réinitialisé !")
    end)
end, false)

-- ─── /rzzone — Forcer une redzone (admin/god) ─────────────────────────────────

local function isAdminOrGod(src)
    if src == 0 then return true end
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        for _, license in ipairs(Config.AdminLicenses) do
            if id == license then return true end
        end
    end
    return false
end

local function DoForceZone(zoneIdx, adminName)
    if not zoneIdx or not Config.ZoneLocations[zoneIdx] then return false end
    local zoneName = Config.ZoneLocations[zoneIdx].name

    if VoteActive then
        VoteActive = false
        TriggerClientEvent('gfx-redzone:vote:end', -1, nil, "Changement forcé")
    end

    DeleteZones()

    local picked = { [zoneIdx] = true }
    Zones = { { id = zoneIdx, totalKills = 0, players = {} } }
    local locationKeys = {}
    for k in pairs(Config.ZoneLocations) do locationKeys[#locationKeys + 1] = k end
    for i = 2, Config.ZoneCount do
        local id
        repeat id = locationKeys[math.random(#locationKeys)] until not picked[id]
        picked[id] = true
        Zones[#Zones + 1] = { id = id, totalKills = 0, players = {} }
    end
    ZoneCreatedAt = os.time()

    TriggerClientEvent('gfx-redzone:UpdateZones', -1, Zones)
    TriggerClientEvent('gfx-redzone:CreateZone',  -1)
    TriggerClientEvent('gfx-redzone:TimerUpdate', -1, Config.ChangeZonesInterval * 60)
    Notify(-1, "Redzone forcée sur : " .. zoneName)
    print(string.format("^3[GFX-REDZONE] %s a forcé la zone → %s^0", adminName, zoneName))
    return true
end

-- Event déclenché depuis le Zone Picker NUI
RegisterNetEvent('gfx-redzone:forceZone', function(zoneIdx)
    local src = source
    if not isAdminOrGod(src) then return end
    local adminName = GetPlayerName(src) or "Admin"
    if not DoForceZone(zoneIdx, adminName) then
        Notify(src, "Zone introuvable.")
    end
end)

RegisterCommand("rzzone", function(source, args)
    local src = source
    if not isAdminOrGod(src) then
        if src ~= 0 then Notify(src, "Permission refusée.") end
        return
    end

    -- Pas d'argument + joueur en jeu → ouvrir le picker NUI
    if not args or not args[1] then
        if src ~= 0 then
            TriggerClientEvent('gfx-redzone:openZonePicker', src)
        else
            -- Console → afficher la liste
            local lines = { "^3[GFX-REDZONE] Zones disponibles (/rzzone [numéro]) :^0" }
            for i, v in ipairs(Config.ZoneLocations) do
                lines[#lines + 1] = string.format("  ^5%2d^0 — %s", i, v.name)
            end
            print(table.concat(lines, "\n"))
        end
        return
    end

    -- Recherche par numéro ou par nom
    local zoneIdx = tonumber(args[1])
    if not zoneIdx or not Config.ZoneLocations[zoneIdx] then
        local search = table.concat(args, " "):upper()
        for i, v in ipairs(Config.ZoneLocations) do
            if v.name:upper():find(search, 1, true) then
                zoneIdx = i; break
            end
        end
    end

    local adminName = src ~= 0 and GetPlayerName(src) or "Console"
    if not DoForceZone(zoneIdx, adminName) then
        local err = "Zone introuvable. /rzzone sans argument pour le sélecteur."
        if src ~= 0 then Notify(src, err) end
        print("^1[GFX-REDZONE] " .. err .. "^0")
    end
end, false)
