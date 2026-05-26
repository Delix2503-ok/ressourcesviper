local QBCore = exports['qb-core']:GetCoreObject()

local QBCore = exports['qb-core']:GetCoreObject()

Zones = {}
local zoneBlips, killeaderBlips = {}, {}
isPlayerInZone, zoneIndex = false, false   -- globaux : accessibles depuis death.lua
local identifier, thread

Citizen.CreateThread(function()
    TriggerServerEvent("gfx-redzone:server:Identifier")
end)

RegisterNetEvent("gfx-redzone:Identifier", function(i)
    identifier = i
end)

RegisterNetEvent("gfx-redzone:UpdateZones", function(value, index, key, keyValue, keyIndex, keyIndexValue, keyIndexKey, keyIndexKeyValue)
    if index then
        if key then
            if keyIndex then
                if keyIndexKey then
                    Zones[index][key][keyIndex][keyIndexKey] = keyIndexKeyValue
                else
                    Zones[index][key][keyIndex] = keyIndexValue
                end
            else
                Zones[index][key] = keyValue
            end
        else
            Zones[index] = value
        end
    else
        Zones = value
        if Zones and next(Zones) ~= nil then
            CreateZoneBlips()
        end
    end
    if Zones == nil or next(Zones) == nil then
        isPlayerInZone, zoneIndex = false, false
    end
    UpdateZoneUI()
end)

local zoneBlipsNeedRefresh = false

RegisterNetEvent("gfx-redzone:CreateZone", function()
    zoneBlipsNeedRefresh = true
end)

RegisterNetEvent("gfx-redzone:RemoveZone", function()
    zoneBlipsNeedRefresh = true
end)

function CreateZoneBlips()
    zoneBlipsNeedRefresh = true
end

function DeleteBlips()
    for i = 1, #zoneBlips do
        if DoesBlipExist(zoneBlips[i]) then RemoveBlip(zoneBlips[i]) end
    end
    zoneBlips = {}
end

Citizen.CreateThread(function()
    while true do
        if zoneBlipsNeedRefresh then
            zoneBlipsNeedRefresh = false
            -- Désenregistrer les anciens blips de la protection viper-hud
            if #zoneBlips > 0 then
                pcall(function() exports['viper-hud']:UnregisterProtectedBlips(zoneBlips) end)
            end
            DeleteBlips()
            for i = 1, #Zones do
                if Zones[i] and Zones[i].id then
                    local v = Config.ZoneLocations[Zones[i].id]
                    if v then
                        -- Minimap : cercle semi-transparent display 2
                        local bMini = AddBlipForRadius(v.coords.x, v.coords.y, v.coords.z, v.radius)
                        SetBlipHighDetail(bMini, true)
                        SetBlipColour(bMini, 1)
                        SetBlipAlpha(bMini, 160)
                        SetBlipDisplay(bMini, 2)
                        table.insert(zoneBlips, bMini)

                        -- Grande carte (F) : cercle semi-transparent display 4
                        local bMap = AddBlipForRadius(v.coords.x, v.coords.y, v.coords.z, v.radius)
                        SetBlipHighDetail(bMap, true)
                        SetBlipColour(bMap, 1)
                        SetBlipAlpha(bMap, 160)
                        SetBlipDisplay(bMap, 4)
                        table.insert(zoneBlips, bMap)
                    end
                end
            end
            -- Enregistrer les nouveaux blips comme protégés dans viper-hud
            if #zoneBlips > 0 then
                pcall(function() exports['viper-hud']:RegisterProtectedBlips(zoneBlips) end)
            end
        end
        Citizen.Wait(500)
    end
end)

-- ─── Blips safezones (vert) — depuis Config.SafeZoneLocations ───────────────

local szBlips = {}

local function BuildSzBlips()
    -- Nettoyage
    if #szBlips > 0 then
        pcall(function() exports['viper-hud']:UnregisterProtectedBlips(szBlips) end)
    end
    for _, b in ipairs(szBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    szBlips = {}

    if not Config.SafeZoneLocations then return end

    for _, v in ipairs(Config.SafeZoneLocations) do
        -- Minimap
        local bMini = AddBlipForRadius(v.coords.x, v.coords.y, v.coords.z, v.radius)
        SetBlipHighDetail(bMini, true)
        SetBlipColour(bMini, 2)
        SetBlipAlpha(bMini, 160)
        SetBlipDisplay(bMini, 2)
        table.insert(szBlips, bMini)

        -- Grande carte (F)
        local bMap = AddBlipForRadius(v.coords.x, v.coords.y, v.coords.z, v.radius)
        SetBlipHighDetail(bMap, true)
        SetBlipColour(bMap, 2)
        SetBlipAlpha(bMap, 160)
        SetBlipDisplay(bMap, 4)
        table.insert(szBlips, bMap)
    end

    if #szBlips > 0 then
        pcall(function() exports['viper-hud']:RegisterProtectedBlips(szBlips) end)
    end
end

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(2000)
    BuildSzBlips()
end)

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then
        DeleteBlips()
        if #szBlips > 0 then
            pcall(function() exports['viper-hud']:UnregisterProtectedBlips(szBlips) end)
        end
        for _, b in ipairs(szBlips) do
            if DoesBlipExist(b) then RemoveBlip(b) end
        end
        szBlips = {}
    end
end)

function ComputeLeader(zoneId)
    local leaderIdentifier = GetKillLeader(Zones[zoneId].players)
    if leaderIdentifier then
        Zones[zoneId].leader = Zones[zoneId].players[leaderIdentifier]
    else
        Zones[zoneId].leader = { n = "—", k = 0 }
    end
end

function enteredZone(zoneId)
    isPlayerInZone = true
    zoneIndex = zoneId
    ComputeLeader(zoneId)
    SendNUIMessage({
        type = "display",
        bool = true,
        zone = Zones[zoneId],
        identifier = identifier,
        myRank = GetMyRank(Zones[zoneId].players)
    })
    TriggerEvent('gfx-redzone:zoneChanged', true)
end

function exitedZone(zoneId)
    isPlayerInZone = false
    zoneIndex = false
    SendNUIMessage({
        type = "display",
        bool = false
    })
    TriggerEvent('gfx-redzone:zoneChanged', false)
end

function UpdateZoneUI()
    if isPlayerInZone and zoneIndex then
        ComputeLeader(zoneIndex)
        SendNUIMessage({
            type = "update",
            zone = Zones[zoneIndex],
            identifier = identifier,
            myRank = GetMyRank(Zones[zoneIndex].players)
        })
    end
end

Citizen.CreateThread(function()
    local enteredEventSend, exitedEventSend, zoneId = false, true, 1
    while true do
        local sleep, inZone = 750, false
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        for i = 1, #Zones do
            local zoneData = Config.ZoneLocations[Zones[i].id]
            local distance = #(zoneData.coords - coords)
            if distance <= zoneData.radius then
                inZone = true
                zoneId = i
            end
        end
        if inZone and not enteredEventSend then
            enteredEventSend = true
            exitedEventSend = false
            enteredZone(zoneId)
            TriggerServerEvent("gfx-redzone:enteredZone", zoneId)
        elseif not inZone and not exitedEventSend then
            enteredEventSend = false
            exitedEventSend = true
            exitedZone(zoneId)
            TriggerServerEvent("gfx-redzone:exitedZone", zoneId)
        end
        Citizen.Wait(sleep)
    end
end)

function IsAnyPlayerInVehicle(vehicle)
    for i = 1, 10 do
        if GetPedInVehicleSeat(vehicle, i) ~= 0 then
            return true
        end
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(math.random(5, 15)*1000)
        RemoveKilleaderBlips()
        for i = 1, #Zones do
            ComputeLeader(i)
            local leaderIdentifier = GetKillLeader(Zones[i].players)
            local leader = Zones[i].players[leaderIdentifier]
            if leader then
                local playerIdx = GetPlayerFromServerId(leader.s)
                if playerIdx ~= - 1 then
                    local ped = GetPlayerPed(playerIdx)
                    if ped ~= -1 then
                        local blip = AddKillerLeaderBlips(GetEntityCoords(ped))
                        SetBlipInfo(leader, blip, Zones[i].totalKills)
                    end
                end
            end
        end
    end
end)

function SetBlipInfo(leader, blip, total)
    SetBlipInfoTitle(blip, "Redzone Kill Leader", false)
    AddBlipInfoText(blip, "Leader", leader.n)
    AddBlipInfoText(blip, "Killed Player By Leader", tostring(leader.k))
    AddBlipInfoText(blip, "Total Kills", tostring(total))
    AddBlipInfoHeader(blip, "")
    AddBlipInfoText(blip, "This Blip Show The Kill Leader Of The Redzone")
end

function AddKillerLeaderBlips(coords)
    local blip = AddBlipForCoord(coords.x,coords.y,coords.z)
    SetBlipSprite(blip, 310)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip,true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Kill Leader")
    EndTextCommandSetBlipName(blip)
    table.insert(killeaderBlips, blip)
    return blip
end

function RemoveKilleaderBlips()
    for i = 1, #killeaderBlips do
        RemoveBlip(killeaderBlips[i])
    end
    killeaderBlips = {}
end

function GetKillLeader(t)
    local sortedTable = {}
    for k, v in spairs(t, function(t,a,b) return t[b].k < t[a].k end) do
        if v.s ~= nil then
            if v.i and v.k > 0 then
                table.insert(sortedTable, k)
            end
        end
    end
    return sortedTable[1] ~= nil and sortedTable[1] or false
end

function GetMyRank(t)
    local sortedTable = {}
    for k, v in spairs(t, function(t,a,b) return t[b].k < t[a].k end) do
        if v.s ~= nil then
            if v.i and v.k > 0 then
                table.insert(sortedTable, k)
            end
        end
    end
    local myRank = "None"
    for i = 1, #sortedTable do
        if sortedTable[i] == identifier then
            myRank = i
            break
        end
    end
    return myRank
end

-- ─── Timer ───────────────────────────────────────────────────────────────────

local timerReceivedAt = 0
local timerDuration   = 0

RegisterNetEvent("gfx-redzone:TimerUpdate", function(seconds)
    timerReceivedAt = GetGameTimer()
    timerDuration   = seconds
    SendNUIMessage({ type = "timerUpdate", seconds = math.floor(seconds) })
end)

-- Resync NUI toutes les 10s au cas où le premier message serait raté
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        if timerDuration > 0 then
            local elapsed   = (GetGameTimer() - timerReceivedAt) / 1000
            local remaining = math.max(0, timerDuration - elapsed)
            SendNUIMessage({ type = "timerUpdate", seconds = math.floor(remaining) })
        end
    end
end)

-- ─── Vote zone ───────────────────────────────────────────────────────────────

local VoteOpen     = false
local VoteOptions  = {}
local VoteSelected = 1
local VoteHasVoted = false

RegisterNetEvent("gfx-redzone:vote:start", function(options, duration)
    VoteOpen     = true
    VoteOptions  = options
    VoteSelected = 1
    VoteHasVoted = false
    SendNUIMessage({ type = "voteStart", options = options, duration = duration })
end)

RegisterNetEvent("gfx-redzone:vote:end", function(winnerId, winnerName)
    VoteOpen = false
    SendNUIMessage({ type = "voteEnd", winnerId = winnerId, winnerName = winnerName })
    SetTimeout(4000, function()
        SendNUIMessage({ type = "voteHide" })
    end)
end)

RegisterNetEvent("gfx-redzone:vote:update", function(counts)
    SendNUIMessage({ type = "voteUpdate", counts = counts })
end)

Citizen.CreateThread(function()
    while true do
        if VoteOpen and not VoteHasVoted then
            Citizen.Wait(0)
            if IsControlJustPressed(0, 174) then  -- flèche gauche
                VoteSelected = math.max(1, VoteSelected - 1)
                SendNUIMessage({ type = "voteSelect", index = VoteSelected - 1 })
            elseif IsControlJustPressed(0, 175) then  -- flèche droite
                VoteSelected = math.min(#VoteOptions, VoteSelected + 1)
                SendNUIMessage({ type = "voteSelect", index = VoteSelected - 1 })
            elseif IsControlJustPressed(0, 201) then  -- Entrée
                if VoteOptions[VoteSelected] then
                    VoteHasVoted = true
                    TriggerServerEvent("gfx-redzone:vote:submit", VoteOptions[VoteSelected].id)
                    SendNUIMessage({ type = "voteVoted", index = VoteSelected - 1 })
                end
            end
        else
            Citizen.Wait(200)
        end
    end
end)

RegisterNUICallback('voteSubmit', function(data, cb)
    if VoteOpen and not VoteHasVoted and data.id then
        for idx, opt in ipairs(VoteOptions) do
            if opt.id == data.id then
                VoteHasVoted = true
                TriggerServerEvent("gfx-redzone:vote:submit", opt.id)
                SendNUIMessage({ type = "voteVoted", index = idx - 1 })
                break
            end
        end
    end
    cb('ok')
end)

-- ─── Leaderboard NUI ─────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:openLeaderboard', function()
    TriggerServerEvent('gfx-redzone:requestLeaderboard')
end)

RegisterNetEvent('gfx-redzone:showLeaderboard', function(data)
    SendNUIMessage({ type = 'leaderboard', rows = data })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('leaderboardClose', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterCommand('leaderboard', function()
    TriggerServerEvent('gfx-redzone:requestLeaderboard')
end, false)

-- ─── Zone Picker admin ───────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:openZonePicker', function()
    local zones = {}
    for i, v in ipairs(Config.ZoneLocations) do
        zones[#zones + 1] = { index = i, name = v.name }
    end
    SendNUIMessage({ type = 'zonePicker', zones = zones })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('zonePickerClose', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('zonePickerSelect', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('gfx-redzone:forceZone', data.index)
    cb('ok')
end)

-- ─── Destruction véhicules en redzone active (40s sans joueur) ───────────────
-- Le serveur gère la suppression → fonctionne pour tous les clients, pas seulement le propriétaire réseau.
-- Sortir de la zone reset le compteur ; rentrer redémarre le timer.

-- Thread 1 : suppression globale des véhicules inactifs toutes les 60s
CreateThread(function()
    while true do
        Wait(60000)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if not DoesEntityExist(veh) then goto cont60 end
            if NetworkGetEntityOwner(veh) ~= PlayerId() then goto cont60 end
            local hasPlayer = false
            for _, pid in ipairs(GetActivePlayers()) do
                if GetVehiclePedIsIn(GetPlayerPed(pid), false) == veh then hasPlayer = true; break end
            end
            if not hasPlayer then DeleteVehicle(veh) end
            ::cont60::
        end
    end
end)

-- Thread 2 : suppression des véhicules en redzone après 40s
local VehZoneEntry = {}
CreateThread(function()
    while true do
        Wait(1000)
        local now      = GetGameTimer()
        local myPed    = PlayerPedId()
        local myVeh    = GetVehiclePedIsIn(myPed, false)
        local toDelete = {}

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if not DoesEntityExist(veh) then goto contz end
            local netId = NetworkGetNetworkIdFromEntity(veh)
            if not netId or netId == 0 then goto contz end

            local vehPos = GetEntityCoords(veh)
            local inZone = false
            for _, zone in ipairs(Zones) do
                if zone and zone.id then
                    local loc = Config.ZoneLocations[zone.id]
                    if loc and #(vehPos - loc.coords) <= loc.radius then inZone = true; break end
                end
            end

            if inZone then
                if not VehZoneEntry[netId] then
                    VehZoneEntry[netId] = now
                    if myVeh == veh then
                        QBCore.Functions.Notify("⚠ Sortez du véhicule ! Il sera supprimé dans 40 secondes.", 'error', 6000)
                    end
                else
                    local elapsed = now - VehZoneEntry[netId]
                    if myVeh == veh then
                        if elapsed >= 20000 and elapsed < 21000 then
                            QBCore.Functions.Notify("⏱ Véhicule en RedZone — 20 secondes avant suppression !", 'error', 4000)
                        elseif elapsed >= 30000 and elapsed < 31000 then
                            QBCore.Functions.Notify("⏱ Véhicule en RedZone — 10 secondes avant suppression !", 'error', 4000)
                        elseif elapsed >= 35000 and elapsed < 36000 then
                            QBCore.Functions.Notify("🚨 Véhicule en RedZone — 5 secondes avant suppression !", 'error', 5000)
                        end
                    end
                    if elapsed >= 40000 then
                        toDelete[#toDelete + 1] = { veh = veh, netId = netId }
                    end
                end
            else
                VehZoneEntry[netId] = nil
            end
            ::contz::
        end

        for _, item in ipairs(toDelete) do
            if DoesEntityExist(item.veh) and NetworkGetEntityOwner(item.veh) == PlayerId() then
                if GetVehiclePedIsIn(myPed, false) == item.veh then
                    TaskLeaveVehicle(myPed, item.veh, 0)
                    Wait(500)
                end
                DeleteVehicle(item.veh)
            end
            VehZoneEntry[item.netId] = nil
        end

        for netId in pairs(VehZoneEntry) do
            local e = NetworkGetEntityFromNetworkId(netId)
            if not e or not DoesEntityExist(e) then VehZoneEntry[netId] = nil end
        end
    end
end)