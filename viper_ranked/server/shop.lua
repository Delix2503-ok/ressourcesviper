local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Rotation ────────────────────────────────────────────────────────────────
local function GetRotationInfo()
    local id    = tonumber(MySQL.scalar.await("SELECT setting_value FROM ranked_settings WHERE setting_key='shop_rotation_id'",    {})) or 1
    local start = tonumber(MySQL.scalar.await("SELECT setting_value FROM ranked_settings WHERE setting_key='shop_rotation_start'", {})) or os.time()
    return id, start
end

local function CheckAutoRotation()
    local rotId, rotStart = GetRotationInfo()
    if (os.time() - rotStart) >= (Config.ShopRotationDays * 86400) then
        local newId = rotId + 1
        MySQL.query.await("UPDATE ranked_settings SET setting_value=? WHERE setting_key='shop_rotation_id'",    { tostring(newId) })
        MySQL.query.await("UPDATE ranked_settings SET setting_value=? WHERE setting_key='shop_rotation_start'", { tostring(os.time()) })
        print('^3[viper_ranked] ^7Boutique auto-actualisée (rotation #'..newId..')')
    end
end

AddEventHandler('onResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    SetTimeout(3000, CheckAutoRotation)
end)

-- ─── Fonction interne : panel boutique admin ─────────────────────────────────
-- (déclarée en premier car utilisée par plusieurs events)
local function SendShopPanel(src)
    local rotId, rotStart = GetRotationInfo()
    local secLeft  = math.max(0, (rotStart + Config.ShopRotationDays * 86400) - os.time())
    local daysLeft = math.floor(secLeft / 86400)
    local hrsLeft  = math.floor((secLeft % 86400) / 3600)

    local items = MySQL.query.await('SELECT * FROM ranked_shop WHERE rotation_id=? ORDER BY price ASC', { rotId }) or {}

    local totalBuys = 0
    for _, item in ipairs(items) do
        local n = MySQL.scalar.await('SELECT COUNT(*) FROM ranked_purchases WHERE shop_item_id=?', { item.id }) or 0
        item.buy_count = n
        totalBuys = totalBuys + n
    end

    TriggerClientEvent('viper_ranked:adminReceiveShopPanel', src, {
        rotId     = rotId,
        daysLeft  = daysLeft,
        hrsLeft   = hrsLeft,
        totalBuys = totalBuys,
        items     = items,
    })
end

-- ─── Boutique côté joueur ────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:getShop', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid            = Player.PlayerData.citizenid
    local rotId, rotStart = GetRotationInfo()

    local items = MySQL.query.await('SELECT * FROM ranked_shop WHERE rotation_id=? ORDER BY price ASC', { rotId }) or {}

    -- Achats de la rotation courante uniquement (peut racheter la rotation suivante)
    local rows  = MySQL.query.await('SELECT shop_item_id FROM ranked_purchases WHERE citizenid=?', { cid }) or {}
    local bought = {}
    for _, r in ipairs(rows) do bought[tostring(r.shop_item_id)] = true end

    local coins = MySQL.scalar.await('SELECT ranked_coins FROM ranked_stats WHERE citizenid=?', { cid }) or 0

    TriggerClientEvent('viper_ranked:receiveShop', src, {
        items         = items,
        bought        = bought,
        coins         = coins,
        rotationStart = rotStart,
        rotationDays  = Config.ShopRotationDays,
    })
end)

-- ─── Acheter un article ───────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:buyItem', function(itemId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid    = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM ranked_shop WHERE id=?', { itemId })
    local item   = result and result[1]

    if not item then
        TriggerClientEvent('ox_lib:notify', src, { title='Boutique', description='Article introuvable!', type='error' })
        return
    end
    if MySQL.scalar.await('SELECT id FROM ranked_purchases WHERE citizenid=? AND shop_item_id=?', { cid, itemId }) then
        TriggerClientEvent('ox_lib:notify', src, { title='Boutique', description='Article déjà acheté cette rotation!', type='error' })
        return
    end

    local coins = MySQL.scalar.await('SELECT ranked_coins FROM ranked_stats WHERE citizenid=?', { cid }) or 0
    if coins < item.price then
        TriggerClientEvent('ox_lib:notify', src, {
            title='Boutique', description='Pas assez de RC ! ('..coins..'/'..item.price..')', type='error',
        })
        return
    end

    MySQL.query.await('UPDATE ranked_stats SET ranked_coins=ranked_coins-? WHERE citizenid=?', { item.price, cid })
    MySQL.insert.await('INSERT INTO ranked_purchases (citizenid, shop_item_id) VALUES (?,?)', { cid, itemId })
    exports.ox_inventory:AddItem(src, item.item_name, 1)

    TriggerClientEvent('viper_ranked:shopBought', src, {
        label    = item.item_label,
        itemId   = itemId,
        newCoins = coins - item.price,
    })
end)

-- ─── Refresh boutique (onglet NUI déjà ouvert) ───────────────────────────────
RegisterNetEvent('viper_ranked:refreshShop', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid             = Player.PlayerData.citizenid
    local rotId, rotStart = GetRotationInfo()
    local items  = MySQL.query.await('SELECT * FROM ranked_shop WHERE rotation_id=? ORDER BY price ASC', { rotId }) or {}
    local rows   = MySQL.query.await('SELECT shop_item_id FROM ranked_purchases WHERE citizenid=?', { cid }) or {}
    local bought = {}
    for _, r in ipairs(rows) do bought[tostring(r.shop_item_id)] = true end
    local coins  = MySQL.scalar.await('SELECT ranked_coins FROM ranked_stats WHERE citizenid=?', { cid }) or 0

    TriggerClientEvent('viper_ranked:updateShop', src, {
        items         = items,
        bought        = bought,
        coins         = coins,
        rotationStart = rotStart,
        rotationDays  = Config.ShopRotationDays,
    })
end)

-- ─── Admin : panel boutique (données live) ────────────────────────────────────
RegisterNetEvent('viper_ranked:adminGetShopPanel', function()
    local src = source
    if not IsAdmin(src) then return end
    SendShopPanel(src)
end)

-- ─── Admin : ajouter un article ──────────────────────────────────────────────
RegisterNetEvent('viper_ranked:adminAddShopItem', function(itemData)
    local src = source
    if not IsAdmin(src) then return end

    local rotId = GetRotationInfo()
    MySQL.insert.await(
        'INSERT INTO ranked_shop (item_name, item_label, item_type, price, rotation_id) VALUES (?,?,?,?,?)',
        { itemData.name, itemData.label, itemData.itype, itemData.price, rotId }
    )
    TriggerClientEvent('ox_lib:notify', src, { title='Boutique', description=itemData.label..' ajouté!', type='success' })
    SendShopPanel(src)   -- rafraîchit le menu automatiquement
end)

-- ─── Admin : supprimer un article ────────────────────────────────────────────
RegisterNetEvent('viper_ranked:adminDeleteShopItem', function(itemId)
    local src = source
    if not IsAdmin(src) then return end
    MySQL.query.await('DELETE FROM ranked_shop WHERE id=?', { itemId })
    MySQL.query.await('DELETE FROM ranked_purchases WHERE shop_item_id=?', { itemId })
    TriggerClientEvent('ox_lib:notify', src, { title='Boutique', description='Article supprimé.', type='info' })
    SendShopPanel(src)
end)

-- ─── Admin : modifier le prix d'un article ───────────────────────────────────
RegisterNetEvent('viper_ranked:adminEditShopItem', function(itemId, newPrice)
    local src = source
    if not IsAdmin(src) then return end
    MySQL.query.await('UPDATE ranked_shop SET price=? WHERE id=?', { newPrice, itemId })
    TriggerClientEvent('ox_lib:notify', src, { title='Boutique', description='Prix mis à jour : '..newPrice..' RC', type='success' })
    SendShopPanel(src)
end)

-- ─── Admin : réinitialiser la rotation (reset timer) ────────────────────────
RegisterNetEvent('viper_ranked:adminRefreshShop', function()
    local src = source
    if not IsAdmin(src) then return end

    local rotId = GetRotationInfo()
    local newId = rotId + 1
    MySQL.query.await("UPDATE ranked_settings SET setting_value=? WHERE setting_key='shop_rotation_id'",    { tostring(newId) })
    MySQL.query.await("UPDATE ranked_settings SET setting_value=? WHERE setting_key='shop_rotation_start'", { tostring(os.time()) })

    TriggerClientEvent('ox_lib:notify', src, { title='Boutique Admin', description='Rotation #'..newId..' démarrée!', type='success' })
    TriggerClientEvent('ox_lib:notify', -1,  { title='Boutique Ranked', description='La boutique a été actualisée!', type='info' })
    SendShopPanel(src)   -- rouvre le panel avec les nouvelles données
end)
