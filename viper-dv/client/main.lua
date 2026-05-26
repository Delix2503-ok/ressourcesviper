local parkingZones  = {}
local zoneGroundZ   = {}   -- Z sol mis en cache par zone id
local panelOpen     = false

-- ─── Chargement initial ───────────────────────────────────────────────────────

local function RequestZones()
    TriggerServerEvent('viperdv:requestZones')
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then Wait(2000); RequestZones() end
end)
AddEventHandler('QBCore:Client:OnPlayerLoaded', function() Wait(1000); RequestZones() end)

-- ─── Auto-DV sweep ───────────────────────────────────────────────────────────

local function IsVehicleInactive(veh)
    return GetEntitySpeed(veh) < Config.MinSpeed
end

RegisterNetEvent('viperdv:warning')
AddEventHandler('viperdv:warning', function(remaining)
    lib.notify({
        title       = 'Nettoyage véhicules',
        description = 'Suppression des véhicules à l\'arrêt dans ' .. remaining .. 's',
        type        = 'warning',
        position    = 'top-right',
        duration    = 4500,
    })
end)

RegisterNetEvent('viperdv:sweep')
AddEventHandler('viperdv:sweep', function()
    local myId = PlayerId()
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if NetworkGetEntityOwner(veh) == myId and IsVehicleInactive(veh) then
            DeleteEntity(veh)
        end
    end
end)

-- ─── DV par coords ───────────────────────────────────────────────────────────

RegisterNetEvent('viperdv:dvRequest')
AddEventHandler('viperdv:dvRequest', function(radius)
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('viperdv:dvCoords', c.x, c.y, c.z, radius)
end)

RegisterNetEvent('viperdv:dvExecute')
AddEventHandler('viperdv:dvExecute', function(x, y, z, radius, adminSrc)
    local myId   = PlayerId()
    local origin = vector3(x, y, z)
    local count  = 0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if NetworkGetEntityOwner(veh) == myId then
            if #(GetEntityCoords(veh) - origin) <= radius then
                DeleteEntity(veh)
                count = count + 1
            end
        end
    end
    if GetPlayerServerId(myId) == adminSrc then
        lib.notify({
            title       = 'DV',
            description = count .. ' véhicule(s) supprimé(s) dans ' .. radius .. 'm',
            type        = 'success',
            position    = 'top-right',
        })
    end
end)

-- ─── Synchro zones parking ────────────────────────────────────────────────────

RegisterNetEvent('viperdv:syncZones')
AddEventHandler('viperdv:syncZones', function(zones)
    parkingZones = zones or {}
    zoneGroundZ  = {}
    -- Snap Z au sol pour chaque zone (une seule fois à la réception)
    CreateThread(function()
        for _, z in ipairs(parkingZones) do
            local found, gz = GetGroundZFor_3dCoord(z.x, z.y, z.z + 2.0, false)
            zoneGroundZ[z.id] = (found and gz) or z.z
            Wait(0)
        end
    end)
    if panelOpen then
        SendNUIMessage({ action = 'updateZones', zones = parkingZones })
    end
end)

-- ─── Dessin zones parking + interaction E ─────────────────────────────────────

local function DrawText3D(x, y, z, text)
    local cam  = GetGameplayCamCoords()
    local dist = #(cam - vector3(x, y, z))
    local fov  = (1 / GetGameplayCamFov()) * 100
    local size = math.min((1 / math.max(dist, 1)) * 2.5 * fov, 0.6)

    SetTextScale(size, size)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(57, 255, 20, 230)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local sleep = 500

        if #parkingZones > 0 then
            local ped      = PlayerPedId()
            local myCoords = GetEntityCoords(ped)
            local myVeh    = GetVehiclePedIsIn(ped, false)
            local t        = GetGameTimer()

            for _, zone in ipairs(parkingZones) do
                local zPos = vector3(zone.x, zone.y, zone.z)
                local dist = #(myCoords - zPos)

                if dist < 40.0 then
                    sleep = 0
                    local baseSize = (Config.ParkingRadius * 2) / 3.0
                    local pulse    = math.abs(math.sin(t / 600.0)) * 0.3 + baseSize

                    local gz = zoneGroundZ[zone.id] or zone.z
                    -- Cercle au sol (3x plus petit, snappé au sol)
                    DrawMarker(28, zone.x, zone.y, gz, 0,0,0, 0,0,0, pulse, pulse, 0.5, 0,200,50,80, false, true, 2, false, nil, nil, false)

                    -- Texte : instruction uniquement
                    DrawText3D(zone.x, zone.y, gz + 1.7, 'Range ton véhicule  [E]')

                    -- Interaction E si en véhicule dans le rayon
                    if dist < Config.ParkingRadius and myVeh ~= 0 then
                        if IsControlJustPressed(0, 38) then
                            DeleteEntity(myVeh)
                            lib.notify({
                                title       = 'Parking',
                                description = 'Véhicule rangé. Les objets dans la boîte à gants sont conservés.',
                                type        = 'success',
                                duration    = 4000,
                            })
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ─── Panel admin (/dvadmin) ───────────────────────────────────────────────────

RegisterCommand('dvadmin', function()
    TriggerServerEvent('viperdv:openAdmin')
end, false)

RegisterNetEvent('viperdv:openPanel')
AddEventHandler('viperdv:openPanel', function(zones)
    parkingZones = zones or {}
    panelOpen    = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openPanel', zones = parkingZones })
end)

-- ─── Callbacks NUI ────────────────────────────────────────────────────────────

RegisterNUICallback('closePanel', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('dvRadius', function(data, cb)
    TriggerServerEvent('viperdv:adminDvRadius', tonumber(data.radius) or 30)
    cb('ok')
end)

RegisterNUICallback('addZone', function(data, cb)
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('viperdv:addZone', data.name or '', c.x, c.y, c.z)
    cb('ok')
end)

RegisterNUICallback('removeZone', function(data, cb)
    TriggerServerEvent('viperdv:removeZone', tonumber(data.id))
    cb('ok')
end)

RegisterNUICallback('tpZone', function(data, cb)
    for _, z in ipairs(parkingZones) do
        if z.id == tonumber(data.id) then
            SetEntityCoords(PlayerPedId(), z.x, z.y, z.z + 0.5, false, false, false, false)
            break
        end
    end
    cb('ok')
end)
