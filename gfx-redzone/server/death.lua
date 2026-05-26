local QBCore = exports['qb-core']:GetCoreObject()

local DeadPlayers = {}
local Carriers    = {}

-- ─── Mort / Coma ──────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:death:register', function(killerId, zoneId)
    local victimId    = source
    local victimIdent = GetIdent(victimId)
    DeadPlayers[victimId] = GetGameTimer()

    if not killerId or not zoneId then return end
    killerId = tonumber(killerId)
    if not killerId or killerId == victimId then return end

    local killerIdent = GetIdent(killerId)
    if not Zones[zoneId] then return end

    -- Mort de la victime dans la zone
    if Zones[zoneId].players[victimIdent] then
        Zones[zoneId].players[victimIdent].d = (Zones[zoneId].players[victimIdent].d or 0) + 1
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "players", nil, victimIdent, nil, "d", Zones[zoneId].players[victimIdent].d)
    end

    -- Kill du killer (doit être dans la zone et actif)
    if killerIdent and Zones[zoneId].players[killerIdent] and Zones[zoneId].players[killerIdent].i then
        Zones[zoneId].players[killerIdent].k = Zones[zoneId].players[killerIdent].k + 1
        Zones[zoneId].totalKills             = Zones[zoneId].totalKills + 1
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "players", nil, killerIdent, nil, "k", Zones[zoneId].players[killerIdent].k)
        TriggerClientEvent("gfx-redzone:UpdateZones", -1, nil, zoneId, "totalKills", Zones[zoneId].totalKills)
        local pName = Zones[zoneId].players[killerIdent].n or 'Inconnu'
        exports['oxmysql']:update(
            'INSERT INTO gfx_redzone_leaderboard (citizenid, player_name, kills) VALUES (?, ?, 1) ' ..
            'ON DUPLICATE KEY UPDATE kills = kills + 1, player_name = VALUES(player_name)',
            { killerIdent, pName }
        )
        -- Récompense 1500 black_money par kill en redzone
        exports.ox_inventory:AddItem(killerId, 'black_money', 1500)
        TriggerClientEvent('QBCore:Notify', killerId, "+1500 Argent Sale", 'success', 4000)
    end
end)

RegisterNetEvent('gfx-redzone:death:clear', function()
    DeadPlayers[source] = nil
end)

-- ─── Revive ───────────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:revive:attempt', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or not DeadPlayers[targetId] then return end

    local rCoords = GetEntityCoords(GetPlayerPed(src))
    local tCoords = GetEntityCoords(GetPlayerPed(targetId))
    if #(rCoords - tCoords) > 5.0 then return end

    DeadPlayers[targetId] = nil

    -- Arrêter le portage si la cible était portée
    for carrierId, cTarget in pairs(Carriers) do
        if cTarget == targetId then
            Carriers[carrierId] = nil
            local ped = GetPlayerPed(targetId)
            if ped and ped ~= 0 then
                local netId = NetworkGetNetworkIdFromEntity(ped)
                if netId then TriggerClientEvent('gfx-redzone:carry:detach', -1, netId) end
            end
            TriggerClientEvent('gfx-redzone:carry:stopped', carrierId)
            break
        end
    end

    TriggerClientEvent('gfx-redzone:revived', targetId)
end)

-- ─── Porter ───────────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:carry:start', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end
    if Carriers[src] then return end

    local rPos      = GetEntityCoords(GetPlayerPed(src))
    local targetPed = GetPlayerPed(targetId)
    local tPos      = GetEntityCoords(targetPed)

    if #(rPos - tPos) > 4.0 then
        TriggerClientEvent('QBCore:Notify', src, "Joueur trop loin.", 'error')
        return
    end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 or GetVehiclePedIsIn(targetPed, false) ~= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Impossible de porter dans un véhicule.", 'error')
        return
    end

    Carriers[src] = targetId
    local carrierNet = NetworkGetNetworkIdFromEntity(GetPlayerPed(src))
    local targetNet  = NetworkGetNetworkIdFromEntity(GetPlayerPed(targetId))
    TriggerClientEvent('gfx-redzone:carry:doCarry',    src,      targetNet)
    TriggerClientEvent('gfx-redzone:carry:attachSelf', targetId, carrierNet, src)
end)

RegisterNetEvent('gfx-redzone:carry:stop', function()
    local src      = source
    local targetId = Carriers[src]
    if not targetId then return end
    Carriers[src] = nil
    local ped = GetPlayerPed(targetId)
    if ped and ped ~= 0 then
        local netId = NetworkGetNetworkIdFromEntity(ped)
        if netId then TriggerClientEvent('gfx-redzone:carry:detach', -1, netId) end
    end
    TriggerClientEvent('gfx-redzone:carry:released', targetId)
end)

RegisterNetEvent('gfx-redzone:carry:escape', function()
    local src = source
    for carrierId, targetId in pairs(Carriers) do
        if targetId == src then
            Carriers[carrierId] = nil
            TriggerClientEvent('gfx-redzone:carry:stopped', carrierId)
            break
        end
    end
end)

-- ─── Loot ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:loot:request', function(targetId)
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
    TriggerClientEvent('gfx-redzone:loot:allowSteal', targetId, true)
    SetTimeout(600, function()
        TriggerClientEvent('gfx-redzone:loot:open', src, targetId)
        SetTimeout(15000, function()
            TriggerClientEvent('gfx-redzone:loot:allowSteal', targetId, false)
        end)
    end)
end)

-- ─── Déconnexion ──────────────────────────────────────────────────────────────

-- ─── Commandes admin ──────────────────────────────────────────────────────────

RegisterCommand('autorevive', function(source)
    if source == 0 then return end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local perm = Player.PlayerData.permission or Player.PlayerData.group or 'user'
    local hasAccess = (perm == 'admin' or perm == 'god')
        or QBCore.Functions.HasPermission(source, 'admin')
        or IsPlayerAceAllowed(source, 'command.god')
    if not hasAccess then
        TriggerClientEvent('QBCore:Notify', source, "Permission refusée.", 'error', 3000)
        return
    end
    TriggerClientEvent('gfx-redzone:autorevive', source)
end, false)

AddEventHandler('playerDropped', function()
    local src = source

    -- Vider l'inventaire si mort pendant le deathscreen
    if DeadPlayers[src] then
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            local citizenid = player.PlayerData.citizenid
            SetTimeout(500, function()
                exports['oxmysql']:update('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', citizenid })
            end)
        end
    end
    DeadPlayers[src] = nil

    -- Libérer la cible si ce joueur portait quelqu'un
    local targetId = Carriers[src]
    if targetId then
        Carriers[src] = nil
        TriggerClientEvent('gfx-redzone:carry:released', targetId)
        local ped = GetPlayerPed(targetId)
        if ped and ped ~= 0 then
            local netId = NetworkGetNetworkIdFromEntity(ped)
            if netId then TriggerClientEvent('gfx-redzone:carry:detach', -1, netId) end
        end
    end
    -- Libérer le porteur si ce joueur était porté
    for cId, tId in pairs(Carriers) do
        if tId == src then Carriers[cId] = nil; break end
    end
end)
