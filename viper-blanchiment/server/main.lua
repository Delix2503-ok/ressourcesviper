local QBCore = exports['qb-core']:GetCoreObject()

local spots = {}
local playerCooldowns = {}

-- ─── Persistance via KVP ──────────────────────────────────────────────────────

local function LoadSpots()
    local saved = GetResourceKvpString('viper_laundry_spots')
    if saved then
        spots = json.decode(saved) or {}
    end
end

local function SaveSpots()
    SetResourceKvp('viper_laundry_spots', json.encode(spots))
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        LoadSpots()
        print(('[^2Viper-Blanchiment^7] %d spot(s) chargé(s).'):format(#spots))
    end
end)

-- ─── Utilitaires ──────────────────────────────────────────────────────────────

local function IsAdmin(source)
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license then return false end
    for _, v in ipairs(Config.AdminLicenses) do
        if v == license then return true end
    end
    return false
end

local function IsVip(src)
    return IsPlayerAceAllowed(src, 'group.vip')
end

local function GetRate(src)
    return IsVip(src) and Config.LaundryRateVip or Config.LaundryRate
end

local function Notify(src, type, msg)
    TriggerClientEvent('viper-blanchiment:client:notify', src, type, msg)
end

-- ─── Events réseau ────────────────────────────────────────────────────────────

RegisterNetEvent('viper-blanchiment:server:getSpots', function()
    TriggerClientEvent('viper-blanchiment:client:receiveSpots', source, spots)
end)

RegisterNetEvent('viper-blanchiment:server:checkAdmin', function()
    TriggerClientEvent('viper-blanchiment:client:adminStatus', source, IsAdmin(source))
end)

-- Admin : ajouter un spot
RegisterNetEvent('viper-blanchiment:server:addSpot', function(data)
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'error', 'Accès refusé.')
        return
    end

    local newId = #spots + 1
    local spot = {
        id       = newId,
        name     = data.name ~= '' and data.name or ('Spot #' .. newId),
        x        = math.floor(data.x * 100) / 100,
        y        = math.floor(data.y * 100) / 100,
        z        = math.floor(data.z * 100) / 100,
        heading  = math.floor(data.heading * 100) / 100,
        pedModel = data.pedModel or Config.PedModel,
    }

    table.insert(spots, spot)
    SaveSpots()

    TriggerClientEvent('viper-blanchiment:client:receiveSpots', -1, spots)
    Notify(src, 'success', 'Spot "' .. spot.name .. '" ajouté avec succès!')
    print(('[^2Viper-Blanchiment^7] Spot ajouté par %s : %s (%.1f, %.1f, %.1f)'):format(
        GetPlayerName(src), spot.name, spot.x, spot.y, spot.z))
end)

-- Admin : supprimer un spot
RegisterNetEvent('viper-blanchiment:server:removeSpot', function(spotId)
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'error', 'Accès refusé.')
        return
    end

    local removed = false
    for i, s in ipairs(spots) do
        if s.id == spotId then
            print(('[^2Viper-Blanchiment^7] Spot "%s" supprimé par %s'):format(s.name, GetPlayerName(src)))
            table.remove(spots, i)
            removed = true
            break
        end
    end

    if not removed then
        Notify(src, 'error', 'Spot introuvable.')
        return
    end

    -- Réassigner les IDs
    for i, s in ipairs(spots) do
        s.id = i
    end

    SaveSpots()
    TriggerClientEvent('viper-blanchiment:client:receiveSpots', -1, spots)
    Notify(src, 'success', 'Spot supprimé.')
end)

-- Blanchiment d'argent
RegisterNetEvent('viper-blanchiment:server:launderMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.floor(tonumber(amount) or 0)

    -- Vérifications montant
    if amount < Config.MinAmount then
        Notify(src, 'error', 'Montant minimum : $' .. Config.MinAmount)
        return
    end
    if amount > Config.MaxAmount then
        Notify(src, 'error', 'Montant maximum : $' .. Config.MaxAmount)
        return
    end

    -- Cooldown
    if Config.Cooldown > 0 then
        local now = os.time()
        if playerCooldowns[src] and (now - playerCooldowns[src]) < Config.Cooldown then
            local remaining = Config.Cooldown - (now - playerCooldowns[src])
            Notify(src, 'error', ('Cooldown : encore %ds avant de pouvoir blanchir.'):format(remaining))
            return
        end
    end

    -- Vérification argent sale
    local blackItem = Player.Functions.GetItemByName('black_money')
    if not blackItem or blackItem.amount < amount then
        Notify(src, 'error', 'Argent sale insuffisant !')
        return
    end

    local cleanAmount = math.floor(amount * GetRate(src))

    -- N'ajouter l'argent propre que si le retrait a réellement réussi (anti-dupe)
    if not Player.Functions.RemoveItem('black_money', amount) then
        Notify(src, 'error', 'Erreur lors du retrait de l\'argent sale.')
        return
    end
    Player.Functions.AddMoney('cash', cleanAmount)

    if Config.Cooldown > 0 then
        playerCooldowns[src] = os.time()
    end

    TriggerClientEvent('viper-blanchiment:client:launderSuccess', src, cleanAmount, amount - cleanAmount)

    print(('[^2Viper-Blanchiment^7] %s a blanchi $%d → $%d nets (frais: $%d)'):format(
        GetPlayerName(src), amount, cleanAmount, amount - cleanAmount))
end)

-- Callback : quantité de black_money côté serveur (fiable, pas de cache client)
QBCore.Functions.CreateCallback('viper-blanchiment:server:getBlackMoney', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({ blackMoney = 0, rate = Config.LaundryRate, isVip = false }); return end
    local item = Player.Functions.GetItemByName('black_money')
    local vip  = IsVip(source)
    cb({
        blackMoney = item and item.amount or 0,
        rate       = vip and Config.LaundryRateVip or Config.LaundryRate,
        isVip      = vip,
    })
end)

-- Nettoyage cooldowns à la déconnexion
AddEventHandler('playerDropped', function()
    playerCooldowns[source] = nil
end)
