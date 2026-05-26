-- ─── Copie d'images via xcopy ─────────────────────────────────────────────────
local function CopyAllImages()
    local myPath = GetResourcePath(GetCurrentResourceName()):gsub('/', '\\')
    local dstDir = myPath .. '\\html\\images\\'

    os.execute('if not exist "' .. dstDir .. '" mkdir "' .. dstDir .. '"')

    local sources = {
        GetResourcePath('ox_inventory'):gsub('/', '\\') .. '\\web\\images\\*.png',
        GetResourcePath('ggcweapons'):gsub('/', '\\')   .. '\\images\\*.png',
        GetResourcePath('vipergun'):gsub('/', '\\')     .. '\\html\\images\\*.png',
    }

    for _, src in ipairs(sources) do
        os.execute('xcopy /Y /Q "' .. src .. '" "' .. dstDir .. '" >nul 2>nul')
    end

    print('^2[viper-shop]^7 Images copiées dans html/images/')
end

local function CopyItemImage(itemName)
    local myPath = GetResourcePath(GetCurrentResourceName()):gsub('/', '\\')
    local dstDir = myPath .. '\\html\\images\\'
    local sources = {
        GetResourcePath('ox_inventory'):gsub('/', '\\') .. '\\web\\images\\' .. itemName .. '.png',
        GetResourcePath('ggcweapons'):gsub('/', '\\')   .. '\\images\\'       .. itemName .. '.png',
        GetResourcePath('vipergun'):gsub('/', '\\')     .. '\\html\\images\\' .. itemName .. '.png',
    }
    for _, src in ipairs(sources) do
        local result = os.execute('if exist "' .. src .. '" xcopy /Y /Q "' .. src .. '" "' .. dstDir .. '" >nul 2>nul')
        if result == 0 then return true end
    end
    return false
end

-- ─── Positions persistantes ───────────────────────────────────────────────────
local Positions = {}
local posRaw = LoadResourceFile(GetCurrentResourceName(), 'positions.json')
if posRaw then Positions = json.decode(posRaw) or {} end

print('^2[viper-shop]^7 Positions chargées : ' .. json.encode(Positions))

local function SavePositions()
    local encoded = json.encode(Positions)
    local ok = SaveResourceFile(GetCurrentResourceName(), 'positions.json', encoded, -1)
    print('^2[viper-shop]^7 SavePositions -> ' .. encoded .. ' (ok=' .. tostring(ok) .. ')')
end

-- ─── DB ───────────────────────────────────────────────────────────────────────
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `viper_shop_items` (
            `id`        INT AUTO_INCREMENT PRIMARY KEY,
            `shop_type` VARCHAR(16)  NOT NULL,
            `item_name` VARCHAR(64)  NOT NULL,
            `label`     VARCHAR(128) NOT NULL,
            `price`     INT          NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    CopyAllImages()
end)

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function IsAdmin(src)
    local ids = GetPlayerIdentifiers(src)
    for _, id in ipairs(ids) do
        for _, allowed in ipairs(Config.AdminLicenses) do
            if id == allowed then return true end
        end
    end
    return false
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Viper Shop', description = msg, type = ntype, duration = 4000
    })
end

local function GetAllItems()
    return MySQL.query.await('SELECT * FROM viper_shop_items ORDER BY shop_type, id ASC') or {}
end

-- Push automatique à tous les joueurs connectés au démarrage de la ressource
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(2000, function()
        for _, src in ipairs(GetPlayers()) do
            TriggerClientEvent('viper_shop:syncPositions', tonumber(src), Positions)
        end
        print('^2[viper-shop]^7 Push démarrage -> ' .. json.encode(Positions) .. ' (' .. #GetPlayers() .. ' joueurs)')
    end)
end)

-- ─── Positions NPC ────────────────────────────────────────────────────────────
RegisterNetEvent('viper_shop:requestPositions', function()
    local src = source
    -- Relire le fichier pour garantir les données les plus récentes
    local raw = LoadResourceFile(GetCurrentResourceName(), 'positions.json')
    if raw then
        local decoded = json.decode(raw)
        if decoded and next(decoded) then Positions = decoded end
    end
    print('^2[viper-shop]^7 requestPositions src=' .. src .. ' -> ' .. json.encode(Positions))
    TriggerClientEvent('viper_shop:syncPositions', src, Positions)
end)

RegisterNetEvent('viper_shop:saveNpcPos', function(shopType, x, y, z, w)
    local src = source
    print('^2[viper-shop]^7 saveNpcPos src=' .. src .. ' type=' .. tostring(shopType) .. ' admin=' .. tostring(IsAdmin(src)))
    if not IsAdmin(src) then return end
    if shopType ~= 'weapons' and shopType ~= 'ammo' and shopType ~= 'illegal' then return end
    Positions[shopType] = { x = x, y = y, z = z, w = w }
    SavePositions()
    TriggerClientEvent('viper_shop:syncNpcPos', -1, shopType, Positions[shopType])
end)

-- Envoi positions aux nouveaux joueurs qui rejoignent
AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(5000, function()
        if GetPlayerName(src) ~= nil then
            TriggerClientEvent('viper_shop:syncPositions', src, Positions)
        end
    end)
end)

-- ─── Admin ────────────────────────────────────────────────────────────────────
RegisterNetEvent('viper_shop:adminOpen', function()
    local src = source
    if not IsAdmin(src) then Notify(src, 'Permission refusée.', 'error'); return end
    TriggerClientEvent('viper_shop:adminReceiveItems', src, GetAllItems())
end)

RegisterNetEvent('viper_shop:adminCreate', function(data)
    local src = source
    if not IsAdmin(src) then return end
    if not data.label or data.label == '' then return end
    if not data.item_name or data.item_name == '' then return end
    local validTypes = { weapons = true, ammo = true, illegal = true }
    local shopType = validTypes[data.shop_type] and data.shop_type or 'weapons'
    MySQL.insert.await('INSERT INTO viper_shop_items (shop_type, item_name, label, price) VALUES (?, ?, ?, ?)', {
        shopType, data.item_name, data.label, tonumber(data.price) or 0,
    })
    CopyItemImage(data.item_name)
    Notify(src, '**' .. data.label .. '** ajouté.', 'success')
    TriggerClientEvent('viper_shop:adminReceiveItems', src, GetAllItems())
end)

RegisterNetEvent('viper_shop:adminEdit', function(data)
    local src = source
    if not IsAdmin(src) then return end
    if not data.id then return end
    MySQL.query.await('UPDATE viper_shop_items SET item_name=?, label=?, price=? WHERE id=?', {
        data.item_name, data.label, tonumber(data.price) or 0, data.id,
    })
    CopyItemImage(data.item_name)
    Notify(src, 'Article modifié.', 'success')
    TriggerClientEvent('viper_shop:adminReceiveItems', src, GetAllItems())
end)

RegisterNetEvent('viper_shop:adminDelete', function(id)
    local src = source
    if not IsAdmin(src) then return end
    MySQL.query.await('DELETE FROM viper_shop_items WHERE id=?', { id })
    Notify(src, 'Article supprimé.', 'success')
    TriggerClientEvent('viper_shop:adminReceiveItems', src, GetAllItems())
end)

-- ─── Joueur : ouvrir shop ─────────────────────────────────────────────────────
RegisterNetEvent('viper_shop:openShop', function(shopType)
    local src = source
    if shopType ~= 'weapons' and shopType ~= 'ammo' and shopType ~= 'illegal' then return end
    local rows = MySQL.query.await('SELECT * FROM viper_shop_items WHERE shop_type=? ORDER BY id ASC', { shopType })
    rows = rows or {}

    -- Construire la liste de revente (weapons uniquement)
    local sellItems = {}
    if shopType == 'weapons' then
        local ok, err = pcall(function()
            for _, item in ipairs(rows) do
                local count = exports.ox_inventory:GetItemCount(src, item.item_name)
                if count and count > 0 then
                    sellItems[#sellItems + 1] = {
                        name       = item.item_name,
                        label      = item.label,
                        sell_price = math.floor((tonumber(item.price) or 0) * 0.45),
                        owned      = count,
                    }
                end
            end
        end)
        if not ok then
            print('^1[viper-shop] Erreur build sellItems: ' .. tostring(err) .. '^0')
            sellItems = {}
        end
    end

    TriggerClientEvent('viper_shop:receiveShop', src, shopType, rows, sellItems)
end)

-- ─── Joueur : vendre ──────────────────────────────────────────────────────────
RegisterNetEvent('viper_shop:sell', function(itemName, qty)
    local src = source
    qty = math.max(1, math.min(10000, tonumber(qty) or 1))

    local rows = MySQL.query.await('SELECT * FROM viper_shop_items WHERE shop_type=? AND item_name=?', { 'weapons', itemName })
    if not rows or not rows[1] then return end
    local item = rows[1]

    local owned = exports.ox_inventory:GetItemCount(src, itemName) or 0
    if owned < qty then
        Notify(src, 'Vous n\'avez pas ' .. qty .. 'x **' .. item.label .. '**.', 'error')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, itemName, qty)
    if not removed then
        Notify(src, 'Erreur lors de la vente.', 'error')
        return
    end

    local earned = math.floor((tonumber(item.price) or 0) * 0.45) * qty
    exports.ox_inventory:AddItem(src, 'black_money', earned)
    Notify(src, qty .. 'x **' .. item.label .. '** vendu(s) — **$' .. earned .. '** argent sale.', 'success')
end)

-- ─── Joueur : acheter ─────────────────────────────────────────────────────────
RegisterNetEvent('viper_shop:buy', function(itemId, qty)
    local src = source
    qty = math.max(1, math.min(10000, tonumber(qty) or 1))

    local rows = MySQL.query.await('SELECT * FROM viper_shop_items WHERE id=?', { itemId })
    if not rows or not rows[1] then return end
    local item  = rows[1]
    local total = (tonumber(item.price) or 0) * qty

    if not exports.ox_inventory:CanCarryItem(src, item.item_name, qty) then
        Notify(src, 'Inventaire plein — impossible de porter ' .. qty .. 'x **' .. item.label .. '**.', 'error')
        return
    end

    if total > 0 then
        local removed = exports.ox_inventory:RemoveItem(src, 'money', total)
        if not removed then
            Notify(src, 'Pas assez d\'argent. Prix : **$' .. total .. '**.', 'error')
            return
        end
    end

    exports.ox_inventory:AddItem(src, item.item_name, qty)
    Notify(src, qty .. 'x **' .. item.label .. '** acheté pour **$' .. total .. '**.', 'success')
end)
