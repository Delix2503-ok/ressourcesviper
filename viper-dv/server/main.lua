local parkingZones   = {}
local zoneIdCounter  = 0
local playerCooldowns = {}

-- ─── Utilitaires ─────────────────────────────────────────────────────────────

local function IsAdmin(src)
    if src == 0 then return true end
    local license = GetPlayerIdentifierByType(src, 'license')
    if license then
        for _, l in ipairs(Config.AdminLicenses) do
            if l == license then return true end
        end
    end
    for _, g in ipairs(Config.AdminGroups) do
        if IsPlayerAceAllowed(src, 'group.' .. g) then return true end
    end
    return false
end

local function LoadZones()
    local saved = GetResourceKvpString('viperdv_parking_zones')
    if saved then
        local data = json.decode(saved)
        if data then
            parkingZones  = data.zones   or {}
            zoneIdCounter = data.counter or #parkingZones
        end
    end
end

local function SaveZones()
    SetResourceKvp('viperdv_parking_zones', json.encode({ zones = parkingZones, counter = zoneIdCounter }))
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        LoadZones()
        print(('[^2Viper-DV^7] %d zone(s) parking chargée(s).'):format(#parkingZones))
    end
end)

-- ─── Boucle auto-DV (120s) ───────────────────────────────────────────────────

CreateThread(function()
    Wait(5000)
    while true do
        Wait(60000)
        TriggerClientEvent('viperdv:warning', -1, 30)
        Wait(20000)
        TriggerClientEvent('viperdv:warning', -1, 10)
        Wait(5000)
        TriggerClientEvent('viperdv:warning', -1, 5)
        Wait(5000)
        TriggerClientEvent('viperdv:sweep', -1)
    end
end)

-- ─── /dv [radius] ────────────────────────────────────────────────────────────

RegisterCommand('dv', function(src, args)
    if src == 0 then return end
    if not IsAdmin(src) then return end
    local radius = tonumber(args[1]) or 30
    TriggerClientEvent('viperdv:dvRequest', src, radius)
end, false)

-- ─── Synchro zones ───────────────────────────────────────────────────────────

RegisterNetEvent('viperdv:requestZones')
AddEventHandler('viperdv:requestZones', function()
    TriggerClientEvent('viperdv:syncZones', source, parkingZones)
end)

-- ─── Panel admin ─────────────────────────────────────────────────────────────

RegisterNetEvent('viperdv:openAdmin')
AddEventHandler('viperdv:openAdmin', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('viperdv:openPanel', src, parkingZones)
end)

-- DV rayon depuis le panel
RegisterNetEvent('viperdv:adminDvRadius')
AddEventHandler('viperdv:adminDvRadius', function(radius)
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('viperdv:dvRequest', src, tonumber(radius) or 30)
end)

-- Ajouter une zone parking
RegisterNetEvent('viperdv:addZone')
AddEventHandler('viperdv:addZone', function(name, x, y, z)
    local src = source
    if not IsAdmin(src) then return end
    zoneIdCounter = zoneIdCounter + 1
    local zone = { id = zoneIdCounter, name = name ~= '' and name or ('Zone #' .. zoneIdCounter), x = x, y = y, z = z }
    table.insert(parkingZones, zone)
    SaveZones()
    TriggerClientEvent('viperdv:syncZones', -1, parkingZones)
    print(('[^2Viper-DV^7] Zone "%s" ajoutée par %s (%.1f, %.1f, %.1f)'):format(zone.name, GetPlayerName(src), x, y, z))
end)

-- Supprimer une zone parking
RegisterNetEvent('viperdv:removeZone')
AddEventHandler('viperdv:removeZone', function(zoneId)
    local src = source
    if not IsAdmin(src) then return end
    for i, z in ipairs(parkingZones) do
        if z.id == zoneId then
            print(('[^2Viper-DV^7] Zone "%s" supprimée par %s'):format(z.name, GetPlayerName(src)))
            table.remove(parkingZones, i)
            break
        end
    end
    SaveZones()
    TriggerClientEvent('viperdv:syncZones', -1, parkingZones)
end)

-- ─── /dv admin depuis coords ──────────────────────────────────────────────────

RegisterNetEvent('viperdv:dvCoords')
AddEventHandler('viperdv:dvCoords', function(x, y, z, radius)
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('viperdv:dvExecute', -1, x, y, z, radius, src)
end)
