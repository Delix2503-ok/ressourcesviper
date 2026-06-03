local QBCore        = exports['qb-core']:GetCoreObject()
local safeInProgress = false
local InRedzone      = false

AddEventHandler('viperpvp_redzone:zoneChanged', function(inZone)
    InRedzone = inZone
end)
AddEventHandler('gfx-redzone:zoneChanged', function(inZone)
    InRedzone = inZone
end)

-- ============================================================
--  HUD: sante / armure → NUI
-- ============================================================
CreateThread(function()
    while true do
        Wait(333)
        local ped   = PlayerPedId()
        local hp    = math.max(0, math.floor(((GetEntityHealth(ped) - 100) / 100) * 100))
        local armor = math.floor(GetPedArmour(ped))
        SendNUIMessage({ action = 'updateHUD', health = hp, armor = armor })
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SendNUIMessage({ action = 'showHUD', playerId = GetPlayerServerId(PlayerId()) })
end)
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    SendNUIMessage({ action = 'hideHUD' })
end)
CreateThread(function()
    Wait(2000)
    SendNUIMessage({ action = 'showHUD', playerId = GetPlayerServerId(PlayerId()) })
end)

-- ============================================================
--  HUD: arme & munitions → NUI
-- ============================================================

-- Table de correspondance hash → spawn name pour les armes ggcweapons (non dans QBCore.Shared.Weapons)
local GGCWeaponsByHash = {}
do
    local ggcNames = {
        'weapon_katana','weapon_shiv','weapon_sledgehammer','weapon_karambit','weapon_keyboard',
        'weapon_beanbag','weapon_glock17','weapon_glock18c','weapon_glock19gen4','weapon_glock20',
        'weapon_glock22','weapon_deagle','weapon_fnx45','weapon_m1911','weapon_browning',
        'weapon_pmxfm','weapon_mac10','weapon_mk47fm','weapon_m6ic','weapon_scarsc',
        'weapon_m4','weapon_ak47','weapon_ak74','weapon_aks74','weapon_groza',
    }
    for _, name in ipairs(ggcNames) do
        local h = GetHashKey(name)
        if h < 0 then h = h + 4294967296 end
        GGCWeaponsByHash[h] = name
    end
end

CreateThread(function()
    local unarmedHash = GetHashKey('WEAPON_UNARMED')
    while true do
        Wait(333)
        local ok, err = pcall(function()
            local ped        = PlayerPedId()
            local weaponHash = GetSelectedPedWeapon(ped)

            if weaponHash ~= unarmedHash then
                local _, ammoClip = GetAmmoInClip(ped, weaponHash)
                local ammoTotal   = GetAmmoInPedWeapon(ped, weaponHash)

                -- Normaliser en unsigned pour la lookup GGC (GetSelectedPedWeapon retourne signé)
                local weaponHashU = weaponHash < 0 and weaponHash + 4294967296 or weaponHash
                -- QBCore natif en priorité, fallback ggcweapons
                local weaponData = QBCore.Shared.Weapons[weaponHash] or QBCore.Shared.Weapons[weaponHashU]
                local spawnName  = (weaponData and weaponData.name) or GGCWeaponsByHash[weaponHashU] or GGCWeaponsByHash[weaponHash] or nil

                SendNUIMessage({
                    action      = 'updateWeapon',
                    weaponSpawn = spawnName,
                    ammoClip    = ammoClip  or 0,
                    ammoTotal   = ammoTotal or 0
                })
            else
                SendNUIMessage({ action = 'updateWeapon', ammoClip = 0, ammoTotal = 0 })
            end
        end)
        if not ok then
            print('[viper-hud] weapon thread error: ' .. tostring(err))
        end
    end
end)

-- ============================================================
--  Cache le HUD natif GTA (barres HP/armure sous la minimap)
-- ============================================================
DisplayHud(true)  -- réactive le HUD (DisplayHud est persistant — doit être reset explicitement)

CreateThread(function()
    while true do
        Wait(0)
        DisplayRadar(true)
        -- Force la suppression des indicateurs vie/armure natifs GTA
        HideHudComponentThisFrame(1)   -- wanted stars
        HideHudComponentThisFrame(2)   -- weapon icon
        HideHudComponentThisFrame(6)   -- vehicle name
        HideHudComponentThisFrame(7)   -- area name
        HideHudComponentThisFrame(8)   -- vehicle class
        HideHudComponentThisFrame(9)   -- street name
        HideHudComponentThisFrame(20)  -- health/armor (MP_GAME_INFO)
        HideHudComponentThisFrame(21)  -- speedometer
        HideHudComponentThisFrame(22)  -- speedometer 2
    end
end)

-- ============================================================
--  METEO FORCEE
-- ============================================================
CreateThread(function()
    while true do
        Wait(5000)
        if Config.Weather.locked then
            SetWeatherTypePersist(Config.Weather.type)
            SetWeatherTypeNowPersist(Config.Weather.type)
            SetWeatherTypeNow(Config.Weather.type)
            SetRainFxIntensity(0.0)
            SetWind(0.0)
            SetWindSpeed(0.0)
            SetWindDirection(0.0)
            NetworkOverrideClockTime(Config.Weather.hour, Config.Weather.minute, 0)
        end
    end
end)

-- ============================================================
--  TRAFIC & PNJ → 0
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if Config.World.noTraffic then
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
        end
        if Config.World.noPeds then
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        end
    end
end)

-- ============================================================
--  FAIM & SOIF desactivees
-- ============================================================
CreateThread(function()
    if not Config.Hunger.disabled then return end
    while true do
        Wait(3000)
        local Player = QBCore.Functions.GetPlayerData()
        if Player and Player.metadata then
            local hunger = Player.metadata['hunger']
            local thirst = Player.metadata['thirst']
            if hunger and hunger < 95 then
                TriggerServerEvent('viper-hud:server:setHungerThirst', 100, thirst or 100)
            end
            if thirst and thirst < 95 then
                TriggerServerEvent('viper-hud:server:setHungerThirst', hunger or 100, 100)
            end
        end
    end
end)

-- ============================================================
--  F4 → barre verte 3s → armure pour soi (sans limite de pression)
-- ============================================================
local armorTick = 0

RegisterKeyMapping('viper_fullarmor', 'Viper - Armure max (soi-meme)', 'keyboard', 'F4')
RegisterCommand('viper_fullarmor', function()
    armorTick = armorTick + 1
    local myTick = armorTick
    SendNUIMessage({ action = 'startArmorProgress' })
    CreateThread(function()
        Wait(3250)
        if myTick ~= armorTick then return end
        TriggerServerEvent('viper-hud:server:selfArmor')
        -- SetPlayerMaxArmour (comme ox_inventory) + SetPedArmour
        local endTime = GetGameTimer() + 800
        while GetGameTimer() < endTime do
            if myTick ~= armorTick then break end
            SetPlayerMaxArmour(PlayerId(), Config.MaxArmorValue)
            SetPedArmour(PlayerPedId(), Config.MaxArmorValue)
            Wait(0)
        end
    end)
end, false)

-- Reception armure depuis serveur (panel admin / F4)
RegisterNetEvent('viper-hud:client:setArmor', function(value)
    CreateThread(function()
        local endTime = GetGameTimer() + 800
        while GetGameTimer() < endTime do
            SetPlayerMaxArmour(PlayerId(), value)
            SetPedArmour(PlayerPedId(), value)
            Wait(0)
        end
    end)
end)

-- Reception sante depuis serveur (panel admin / F3)
RegisterNetEvent('viper-hud:client:setHealth', function(value)
    CreateThread(function()
        local endTime = GetGameTimer() + 800
        while GetGameTimer() < endTime do
            local ped = PlayerPedId()
            SetEntityHealth(ped, 100 + math.floor(value))
            Wait(0)
        end
    end)
end)

-- ============================================================
--  F3 → barre rouge 5s → soin complet pour soi (sans limite)
-- ============================================================
local healthTick = 0

RegisterKeyMapping('viper_fullheal', 'Viper - Soin complet (soi-meme)', 'keyboard', 'F3')
RegisterCommand('viper_fullheal', function()
    healthTick = healthTick + 1
    local myTick = healthTick
    SendNUIMessage({ action = 'startHealthProgress' })
    CreateThread(function()
        Wait(5250)
        if myTick ~= healthTick then return end
        TriggerServerEvent('viper-hud:server:selfHealth')
        local endTime = GetGameTimer() + 800
        while GetGameTimer() < endTime do
            if myTick ~= healthTick then break end
            local ped = PlayerPedId()
            SetEntityHealth(ped, 200)
            Wait(0)
        end
    end)
end, false)

-- ============================================================
--  /safe → barre bleue 20s → teleport (annule si bouge)
-- ============================================================
local safeCoords = nil
RegisterNetEvent('viper-hud:client:startSafe', function(coords)
    if safeInProgress then return end
    safeInProgress = true
    safeCoords = coords

    local startPos = GetEntityCoords(PlayerPedId())
    SendNUIMessage({ action = 'startSafeProgress' })

    -- Detection du mouvement et de l'entree en redzone pendant 20s
    CreateThread(function()
        for i = 1, 400 do  -- 400 * 50ms = 20s
            Wait(50)
            if not safeInProgress then break end
            if InRedzone then
                safeInProgress = false
                SendNUIMessage({ action = 'cancelProgress' })
                QBCore.Functions.Notify("Impossible d'utiliser /safe dans une RedZone active.", 'error', 3000)
                break
            end
            local cur = GetEntityCoords(PlayerPedId())
            if #(cur - startPos) > 1.5 then
                safeInProgress = false
                SendNUIMessage({ action = 'cancelProgress' })
                QBCore.Functions.Notify('Téléportation annulée — vous avez bougé !', 'error', 3000)
                break
            end
        end
        safeInProgress = false
    end)

end)

-- Callback NUI quand la barre est terminee — enregistre une seule fois au scope fichier
RegisterNUICallback('safeDone', function(d, cb)
    if safeInProgress and safeCoords then
        local ped = PlayerPedId()
        SetEntityCoords(ped, safeCoords.x, safeCoords.y, safeCoords.z, false, false, false, false)
        SetEntityHeading(ped, safeCoords.h)
    end
    safeInProgress = false
    cb('ok')
end)

-- ============================================================
--  Mise a jour config depuis admin panel
-- ============================================================
RegisterNetEvent('viper-hud:client:updateConfig', function(key, value)
    if key == 'weather' then
        Config.Weather.locked = value
    elseif key == 'traffic' then
        Config.World.noTraffic = value
        Config.World.noPeds    = value
    elseif key == 'hunger' then
        Config.Hunger.disabled = value
    elseif key == 'ambient' then
        Config.World.muteAmbient = value
        if not value then
            SetAudioFlag('WantedMusicDisabled', false)
            SetAudioFlag('PoliceScannerDisabled', false)
        end
    end
end)

-- ============================================================
--  SONS PNJ : coupe sirenes, klaxons, moteurs, musique ambiante
--  Actif par defaut (Config.World.muteAmbient = true)
--  Vehicules joueurs non affectes (check hasPlayer)
-- ============================================================

-- Zones ambiantes GTA V productrices de sons/musique de quartier.
-- GTA ignore silencieusement les noms invalides → liste large = safe.
local AMBIENT_ZONES = {
    'HILLS_AMBIENT_01','HILLS_AMBIENT_02',
    'VINEWOOD_HILLS_01_AMBIENT','VINEWOOD_HILLS_02_AMBIENT',
    'RICHMAN_01_AMBIENT','RICHMAN_02_AMBIENT',
    'ROCKFORD_01_AMBIENT','ROCKFORD_02_AMBIENT',
    'CITY_01_AMBIENT','CITY_02_AMBIENT',
    'DOWNTOWN_01_AMBIENT','DOWNTOWN_02_AMBIENT',
    'SANDY_SHORE_01_AMBIENT','PALETO_01_AMBIENT',
    'BEACH_01_AMBIENT','BEACH_02_AMBIENT',
    'PORT_01_AMBIENT',
    'SUBURB_01_AMBIENT','SUBURB_02_AMBIENT',
    'GROVE_01_AMBIENT',
    'BAR_01_AMBIENT','BAR_02_AMBIENT',
    'NIGHTCLUB_01_AMBIENT','STRIPCLUB_01_AMBIENT',
    'VANILLA_UNICORN_01','LOST_MC_01_AMBIENT',
    'BENNY_01_AMBIENT',
    'AZ_HILLS_AMBIENT','AZ_VINEWOOD_AMBIENT',
    'AZ_CITY_AMBIENT','AZ_BEACH_AMBIENT',
}

CreateThread(function()
    if not Config.World.muteAmbient then return end
    -- Application initiale persistante (survit aux frames, pas besoin de boucle)
    for _, zone in ipairs(AMBIENT_ZONES) do
        SetAmbientZoneStatePersistent(zone, false, true)
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if Config.World.muteAmbient then
            SetAudioFlag('WantedMusicDisabled', true)
            SetAudioFlag('PoliceScannerDisabled', true)
            SetAudioFlag('DisableFlightMusic', true)
            -- Couper moteurs des vehicules sans joueur encore presents
            local myVeh = GetVehiclePedIsIn(PlayerPedId(), false)
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(veh) and veh ~= myVeh then
                    local hasPlayer = false
                    for _, pid in ipairs(GetActivePlayers()) do
                        if GetVehiclePedIsIn(GetPlayerPed(pid), false) == veh then
                            hasPlayer = true
                            break
                        end
                    end
                    if not hasPlayer then
                        SetVehicleEngineOn(veh, false, true, false)
                    end
                end
            end
        end
    end
end)
