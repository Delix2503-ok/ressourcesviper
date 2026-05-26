local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  Self-service F4/F3 — met a jour les metadatas QBCore
-- ============================================================
RegisterNetEvent('viper-hud:server:selfArmor', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print('[viper-hud] selfArmor: joueur introuvable src=' .. src)
        return
    end
    -- Tente les deux clés possibles selon version QBCore
    Player.Functions.SetMetaData('armor',  Config.MaxArmorValue)
    Player.Functions.SetMetaData('armour', Config.MaxArmorValue)
    -- Sauvegarde immédiate en BDD pour que le reset de qb-smallresources lise 100
    Player.Functions.Save()
    TriggerClientEvent('viper-hud:client:setArmor', src, Config.MaxArmorValue)
    print('[viper-hud] selfArmor OK pour src=' .. src)
end)

RegisterNetEvent('viper-hud:server:selfHealth', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('viper-hud:client:setHealth', src, 100)
end)

-- Etat serveur persistant (survivre aux reouvertures du panel admin)
local serverState = {
    weather    = true,
    traffic    = true,
    hunger     = true,
    blips      = true,
    safeCoords = { x = Config.SafeZone.x, y = Config.SafeZone.y,
                   z = Config.SafeZone.z, h = Config.SafeZone.h }
}

local function isAdmin(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        for _, license in ipairs(Config.AdminLicenses) do
            if id == license then return true end
        end
    end
    return false
end

local function getPlayerList()
    local list = {}
    local players = QBCore.Functions.GetPlayers()
    for _, id in ipairs(players) do
        local P = QBCore.Functions.GetPlayer(id)
        if P then
            list[#list + 1] = {
                id    = id,
                name  = P.PlayerData.charinfo and
                        (P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname)
                        or GetPlayerName(id),
                group = P.PlayerData.permission or 'user',
                ping  = GetPlayerPing(id)
            }
        end
    end
    return list
end

-- ============================================================
--  Faim / Soif freeze
-- ============================================================
RegisterNetEvent('viper-hud:server:setHungerThirst', function(hunger, thirst)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.SetMetaData('hunger', hunger)
    Player.Functions.SetMetaData('thirst', thirst)
end)

-- ============================================================
--  /safe  (accessible a tous)
-- ============================================================
QBCore.Commands.Add('safe', 'Teleportation zone de securite', {}, false, function(src, args)
    local ok, inZone = pcall(function()
        return exports['gfx-redzone']:IsPlayerInActiveRedzone(src)
    end)
    if ok and inZone then
        TriggerClientEvent('QBCore:Notify', src, "Impossible d'utiliser /safe dans une RedZone active.", 'error', 3000)
        return
    end
    TriggerClientEvent('viper-hud:client:startSafe', src, serverState.safeCoords)
end)

-- ============================================================
--  /viperadmin
-- ============================================================
QBCore.Commands.Add('viperadmin', 'Panel Admin ViperPVP', {}, false, function(src, args)
    if not isAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, 'Accès refusé.', 'error', 3000)
        return
    end
    TriggerClientEvent('viper-hud:client:openAdmin', src, getPlayerList(), serverState)
end)

-- ============================================================
--  Rafraichissement liste joueurs
-- ============================================================
RegisterNetEvent('viper-hud:server:getPlayers', function()
    local src = source
    if not isAdmin(src) then return end
    TriggerClientEvent('viper-hud:client:updatePlayerList', src, getPlayerList())
end)

-- ============================================================
--  Actions admin
-- ============================================================
RegisterNetEvent('viper-hud:server:adminAction', function(data)
    local src = source
    if not isAdmin(src) then return end

    local action = data.action
    local target = tonumber(data.target)

    if action == 'healHealth' and target then
        TriggerClientEvent('viper-hud:client:setHealth', target, 100)
        TriggerClientEvent('QBCore:Notify', src, 'Joueur soigné.', 'success', 2000)

    elseif action == 'healArmor' and target then
        TriggerClientEvent('viper-hud:client:setArmor', target, Config.MaxArmorValue)
        TriggerClientEvent('QBCore:Notify', src, 'Armure donnée.', 'success', 2000)

    elseif action == 'healAll' and target then
        TriggerClientEvent('viper-hud:client:setHealth', target, 100)
        TriggerClientEvent('viper-hud:client:setArmor', target, Config.MaxArmorValue)
        TriggerClientEvent('QBCore:Notify', src, 'Joueur soigné + armure.', 'success', 2000)

    elseif action == 'healAllPlayers' then
        for _, id in ipairs(QBCore.Functions.GetPlayers()) do
            TriggerClientEvent('viper-hud:client:setHealth', id, 100)
            TriggerClientEvent('viper-hud:client:setArmor', id, Config.MaxArmorValue)
        end
        TriggerClientEvent('QBCore:Notify', src, 'Tous les joueurs soignés !', 'success', 3000)

    elseif action == 'fullArmorAll' then
        for _, id in ipairs(QBCore.Functions.GetPlayers()) do
            TriggerClientEvent('viper-hud:client:setArmor', id, Config.MaxArmorValue)
        end
        TriggerClientEvent('QBCore:Notify', src, 'Armure max donnée à tous !', 'success', 3000)

    elseif action == 'kick' and target then
        DropPlayer(target, data.reason or 'Expulsé par un admin')
        TriggerClientEvent('QBCore:Notify', src, 'Joueur expulsé.', 'success', 2000)

    -- Toggles : on met a jour serverState ET on applique au client admin
    elseif action == 'toggleWeather' then
        serverState.weather = data.value
        TriggerClientEvent('viper-hud:client:updateConfig', src, 'weather', data.value)

    elseif action == 'toggleTraffic' then
        serverState.traffic = data.value
        TriggerClientEvent('viper-hud:client:updateConfig', src, 'traffic', data.value)

    elseif action == 'toggleHunger' then
        serverState.hunger = data.value
        TriggerClientEvent('viper-hud:client:updateConfig', src, 'hunger', data.value)

    elseif action == 'toggleBlips' then
        serverState.blips = data.value
        if data.value then
            TriggerClientEvent('viper-hud:client:hideBlips', src)
        else
            TriggerClientEvent('viper-hud:client:showBlips', src)
        end

    -- Mise a jour coords SafeZone depuis panel admin
    elseif action == 'updateSafeCoords' then
        local raw = tostring(data.coords or '')
        -- Accepte format: vector4(x, y, z, h)  ou  x, y, z, h
        local x, y, z, h = raw:match('vector4%(([%d%-%./]+),%s*([%d%-%./]+),%s*([%d%-%./]+),%s*([%d%-%./]+)%)')
        if not x then
            x, y, z, h = raw:match('([%d%-%./]+),%s*([%d%-%./]+),%s*([%d%-%./]+),%s*([%d%-%./]+)')
        end
        if x and y and z and h then
            serverState.safeCoords = {
                x = tonumber(x), y = tonumber(y),
                z = tonumber(z), h = tonumber(h)
            }
            TriggerClientEvent('QBCore:Notify', src, 'Coords SafeZone mises à jour !', 'success', 2500)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Format invalide. Ex: vector4(x, y, z, h)', 'error', 3000)
        end
    end
end)
