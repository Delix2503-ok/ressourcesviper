local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function IsAdmin(src)
    local license = GetPlayerIdentifierByType(src, 'license')
    for _, l in ipairs(Config.AdminLicenses) do
        if l == license then return true end
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local group = Player.PlayerData.group
        for _, g in ipairs(Config.AdminGroups) do
            if g == group then return true end
        end
    end
    return false
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('QBCore:Notify', src, msg, ntype or 'primary', 4000)
end

local function GetCoins(citizenid)
    local result = MySQL.scalar.await('SELECT coins FROM boutique_coins WHERE citizenid = ?', { citizenid })
    return result or 0
end

local function SetCoins(citizenid, license, amount)
    MySQL.query.await(
        'INSERT INTO boutique_coins (citizenid, license, coins) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE coins = ?, license = ?',
        { citizenid, license, amount, amount, license }
    )
end

-- ─── ACE Groups ───────────────────────────────────────────────────────────────
-- Ajoute un groupe grade sans toucher aux autres (accumulation)
local function AddGroup(license, newGroup)
    if newGroup and newGroup ~= '' then
        ExecuteCommand('add_principal identifier.' .. license .. ' ' .. newGroup)
    end
end

-- Sauvegarde un grade (INSERT IGNORE — ne remplace pas les grades existants)
local function SaveGroup(citizenid, license, groupName)
    MySQL.query.await(
        'INSERT IGNORE INTO boutique_grades (citizenid, license, grp) VALUES (?, ?, ?)',
        { citizenid, license, groupName }
    )
end

-- Retourne TOUS les grades d'un joueur
local function GetStoredGroups(license)
    local rows = MySQL.query.await('SELECT grp FROM boutique_grades WHERE license = ?', { license })
    local groups = {}
    for _, row in ipairs(rows or {}) do groups[#groups+1] = row.grp end
    return groups
end

-- ─── Init DB ──────────────────────────────────────────────────────────────────
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_coins` (
            `citizenid` varchar(50)  NOT NULL,
            `license`   varchar(100) NOT NULL,
            `coins`     int(11)      NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_grades` (
            `citizenid` varchar(50)  NOT NULL,
            `license`   varchar(100) NOT NULL,
            `grp`       varchar(50)  NOT NULL,
            PRIMARY KEY (`citizenid`, `grp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    -- Migration : si l'ancienne PK était juste citizenid, on la remplace
    pcall(function()
        MySQL.query.await('ALTER TABLE `boutique_grades` DROP PRIMARY KEY')
        MySQL.query.await('ALTER TABLE `boutique_grades` ADD PRIMARY KEY (`citizenid`, `grp`)')
    end)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_items` (
            `id`          int(11)      NOT NULL AUTO_INCREMENT,
            `category`    varchar(32)  NOT NULL DEFAULT 'autres',
            `label`       varchar(128) NOT NULL,
            `item_name`   varchar(64)  DEFAULT NULL,
            `price`       int(11)      NOT NULL DEFAULT 0,
            `description` varchar(255) DEFAULT NULL,
            `max_qty`     int(11)      NOT NULL DEFAULT 1,
            `set_group`   varchar(50)  DEFAULT NULL,
            `image_url`   varchar(255) DEFAULT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_garage_npcs` (
            `id`             int(11)      NOT NULL AUTO_INCREMENT,
            `name`           varchar(128) DEFAULT NULL,
            `x`              float        NOT NULL,
            `y`              float        NOT NULL,
            `z`              float        NOT NULL,
            `heading`        float        NOT NULL DEFAULT 0,
            `spawn_x`        float        DEFAULT NULL,
            `spawn_y`        float        DEFAULT NULL,
            `spawn_z`        float        DEFAULT NULL,
            `spawn_heading`  float        DEFAULT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_vehicles` (
            `id`            int(11)      NOT NULL AUTO_INCREMENT,
            `citizenid`     varchar(50)  NOT NULL,
            `license`       varchar(100) NOT NULL,
            `vehicle_model` varchar(64)  NOT NULL,
            `vehicle_label` varchar(128) NOT NULL,
            `purchased_at`  timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid_model` (`citizenid`, `vehicle_model`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    -- Migration si tables existantes
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_unique_purchases` (
            `citizenid` varchar(50) NOT NULL,
            `item_id`   int(11)     NOT NULL,
            PRIMARY KEY (`citizenid`, `item_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await('ALTER TABLE `boutique_items` ADD COLUMN IF NOT EXISTS `set_group`   varchar(50)  DEFAULT NULL')
    MySQL.query.await('ALTER TABLE `boutique_items` ADD COLUMN IF NOT EXISTS `image_url`   varchar(255) DEFAULT NULL')
    MySQL.query.await('ALTER TABLE `boutique_items` ADD COLUMN IF NOT EXISTS `set_vehicle` varchar(64)  DEFAULT NULL')
    MySQL.query.await('ALTER TABLE `boutique_items` ADD COLUMN IF NOT EXISTS `unique_buy`  tinyint(1)   NOT NULL DEFAULT 0')
    MySQL.query.await('ALTER TABLE `boutique_garage_npcs` ADD COLUMN IF NOT EXISTS `name` varchar(128) DEFAULT NULL')
    -- Autoriser NULL sur item_name (peut être vide pour grades/véhicules)
    MySQL.query.await('ALTER TABLE `boutique_items` MODIFY COLUMN `item_name` varchar(64) DEFAULT NULL')
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_vehicle_mods` (
            `citizenid`       varchar(50) NOT NULL,
            `vehicle_model`   varchar(64) NOT NULL,
            `primary_color`   smallint    DEFAULT NULL,
            `secondary_color` smallint    DEFAULT NULL,
            `pearl_color`     smallint    DEFAULT NULL,
            `wheel_color`     smallint    DEFAULT NULL,
            `wheel_type`      tinyint     DEFAULT NULL,
            `wheel_mod`       smallint    DEFAULT NULL,
            `window_tint`     tinyint     DEFAULT NULL,
            `xenon_enabled`   tinyint(1)  NOT NULL DEFAULT 0,
            `xenon_color`     smallint    DEFAULT 255,
            `neon_left`       tinyint(1)  NOT NULL DEFAULT 0,
            `neon_right`      tinyint(1)  NOT NULL DEFAULT 0,
            `neon_front`      tinyint(1)  NOT NULL DEFAULT 0,
            `neon_back`       tinyint(1)  NOT NULL DEFAULT 0,
            `neon_r`          tinyint unsigned NOT NULL DEFAULT 0,
            `neon_g`          tinyint unsigned NOT NULL DEFAULT 255,
            `neon_b`          tinyint unsigned NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`, `vehicle_model`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_custom_npcs` (
            `id`      int(11)      NOT NULL AUTO_INCREMENT,
            `name`    varchar(128) DEFAULT NULL,
            `x`       float        NOT NULL,
            `y`       float        NOT NULL,
            `z`       float        NOT NULL,
            `heading` float        NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boutique_givecoins_logs` (
            `id`          int(11)      NOT NULL AUTO_INCREMENT,
            `citizenid`   varchar(50)  NOT NULL,
            `player_name` varchar(64)  NOT NULL,
            `license`     varchar(100) NOT NULL DEFAULT '',
            `amount`      int(11)      NOT NULL,
            `given_at`    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    -- Migration : colonne body_mods pour mods esthétiques
    MySQL.query.await([[
        ALTER TABLE boutique_vehicle_mods
        ADD COLUMN IF NOT EXISTS body_mods TEXT DEFAULT NULL
    ]])
    -- Migration : importer les grades existants dans boutique_unique_purchases
    MySQL.query.await([[
        INSERT IGNORE INTO boutique_unique_purchases (citizenid, item_id)
        SELECT bg.citizenid, bi.id
        FROM boutique_grades bg
        JOIN boutique_items bi ON bi.set_group = bg.grp
    ]])
    print('^2[viper-boutique]^7 Tables DB prêtes.')
end)

-- ─── Réappliquer le grade ACE au login ───────────────────────────────────────
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src     = Player.PlayerData.source
    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then return end

    local groups = GetStoredGroups(license)
    for _, grp in ipairs(groups) do
        AddGroup(license, grp)
    end
    if #groups > 0 then
        print('^2[viper-boutique]^7 Grades réappliqués à ' .. GetPlayerName(src) .. ' : ' .. table.concat(groups, ', '))
    end
end)

-- ─── /givecoins [sid] [montant] ──────────────────────────────────────────────
-- Usage Tebex : givecoins {sid} 1000
-- Usage console : givecoins <serverPlayerId> <montant>
RegisterCommand('givecoins', function(source, args)
    if source ~= 0 and not IsAdmin(source) then return end

    local targetSrc = tonumber(args[1])
    local amount    = tonumber(args[2])

    if not targetSrc or not amount or amount <= 0 then
        print('[viper-boutique] Usage : givecoins <serverPlayerId> <montant>')
        return
    end

    local Player = QBCore.Functions.GetPlayer(targetSrc)
    if not Player then
        print('[viper-boutique] ERREUR : joueur ID ' .. targetSrc .. ' introuvable (hors ligne ?)')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local license   = GetPlayerIdentifierByType(targetSrc, 'license')
    local current   = GetCoins(citizenid)
    local newTotal  = current + amount

    SetCoins(citizenid, license, newTotal)
    TriggerClientEvent('boutique:updateCoins', targetSrc, newTotal)
    Notify(targetSrc, '+' .. amount .. ' ViperCoins crédités !', 'success')
    MySQL.query('INSERT INTO boutique_givecoins_logs (citizenid, player_name, license, amount) VALUES (?, ?, ?, ?)',
        { citizenid, GetPlayerName(targetSrc), license or '', amount })
    print('[viper-boutique] ' .. amount .. ' VC → ' .. GetPlayerName(targetSrc) .. ' (ID ' .. targetSrc .. ')')
end, true)

-- ─── Admin : logs givecoins + soldes coins ────────────────────────────────────
RegisterNetEvent('boutique:adminGetLogs', function()
    local src = source
    if not IsAdmin(src) then return end
    local logs = MySQL.query.await(
        'SELECT * FROM boutique_givecoins_logs ORDER BY given_at DESC LIMIT 500', {}
    )
    local coins = MySQL.query.await([[
        SELECT bc.citizenid, bc.coins,
               COALESCE(CONCAT(
                   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
               ), bc.citizenid) AS player_name
        FROM boutique_coins bc
        LEFT JOIN players p ON p.citizenid = bc.citizenid
        ORDER BY bc.coins DESC
        LIMIT 300
    ]], {})
    TriggerClientEvent('boutique:adminLogsData', src, logs, coins)
end)

-- ─── Sync coins au login ──────────────────────────────────────────────────────
AddEventHandler('playerConnecting', function()
    local src = source
    SetTimeout(5000, function()
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local coins = GetCoins(Player.PlayerData.citizenid)
        TriggerClientEvent('boutique:updateCoins', src, coins)
    end)
end)

-- ─── Ouvrir boutique joueur ───────────────────────────────────────────────────
RegisterNetEvent('boutique:requestOpen', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local coins  = GetCoins(citizenid)
    local items  = MySQL.query.await('SELECT * FROM boutique_items ORDER BY category, id', {})
    local owned  = MySQL.query.await('SELECT item_id FROM boutique_unique_purchases WHERE citizenid = ?', { citizenid })
    local ownedIds = {}
    for _, row in ipairs(owned or {}) do ownedIds[#ownedIds+1] = row.item_id end
    TriggerClientEvent('boutique:open', src, items, coins, ownedIds)
end)

-- ─── Ouvrir boutique admin ────────────────────────────────────────────────────
RegisterNetEvent('boutique:requestAdminOpen', function()
    local src = source
    if not IsAdmin(src) then Notify(src, 'Accès refusé.', 'error'); return end

    local items = MySQL.query.await('SELECT * FROM boutique_items ORDER BY category, id', {})
    TriggerClientEvent('boutique:adminOpen', src, items)
end)

-- ─── Admin : sauvegarder article ─────────────────────────────────────────────
RegisterNetEvent('boutique:adminSave', function(data)
    local src = source
    if not IsAdmin(src) then return end

    local id          = tonumber(data.id)
    local category    = tostring(data.category    or 'autres')
    local label       = tostring(data.label       or ''):sub(1, 128)
    local item_name   = (data.item_name  and data.item_name  ~= '') and tostring(data.item_name):sub(1, 64)  or nil
    local price       = math.max(0, tonumber(data.price)   or 0)
    local description = tostring(data.description or ''):sub(1, 255)
    local max_qty     = math.max(1, tonumber(data.max_qty) or 1)
    local set_group   = (data.set_group   and data.set_group   ~= '') and tostring(data.set_group):sub(1, 50)   or nil
    local image_url   = (data.image_url   and data.image_url   ~= '') and tostring(data.image_url):sub(1, 255)  or nil
    local set_vehicle = (data.set_vehicle and data.set_vehicle ~= '') and tostring(data.set_vehicle):sub(1, 64) or nil
    local unique_buy  = data.unique_buy and 1 or 0

    if label == '' then
        Notify(src, 'Le label est requis.', 'error'); return
    end

    if id and id > 0 then
        MySQL.query.await(
            'UPDATE boutique_items SET category=?, label=?, item_name=?, price=?, description=?, max_qty=?, set_group=?, image_url=?, set_vehicle=?, unique_buy=? WHERE id=?',
            { category, label, item_name, price, description, max_qty, set_group, image_url, set_vehicle, unique_buy, id }
        )
    else
        MySQL.query.await(
            'INSERT INTO boutique_items (category, label, item_name, price, description, max_qty, set_group, image_url, set_vehicle, unique_buy) VALUES (?,?,?,?,?,?,?,?,?,?)',
            { category, label, item_name, price, description, max_qty, set_group, image_url, set_vehicle, unique_buy }
        )
    end

    local items = MySQL.query.await('SELECT * FROM boutique_items ORDER BY category, id', {})
    TriggerClientEvent('boutique:adminSync', src, items)
    Notify(src, 'Article sauvegardé.', 'success')
end)

-- ─── Admin : supprimer article ────────────────────────────────────────────────
RegisterNetEvent('boutique:adminDelete', function(id)
    local src = source
    if not IsAdmin(src) then return end

    MySQL.query.await('DELETE FROM boutique_items WHERE id = ?', { tonumber(id) })
    local items = MySQL.query.await('SELECT * FROM boutique_items ORDER BY category, id', {})
    TriggerClientEvent('boutique:adminSync', src, items)
    Notify(src, 'Article supprimé.', 'success')
end)

-- ─── Achat ────────────────────────────────────────────────────────────────────
RegisterNetEvent('boutique:buy', function(itemId, qty)
    local src     = source
    local Player  = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    qty = math.max(1, math.min(9999, tonumber(qty) or 1))

    local item = MySQL.single.await('SELECT * FROM boutique_items WHERE id = ?', { tonumber(itemId) })
    if not item then Notify(src, 'Article introuvable.', 'error'); return end

    local isGrade   = item.set_group   and item.set_group   ~= ''
    local isVehicle = item.set_vehicle and item.set_vehicle ~= ''

    -- Grades et véhicules = toujours quantité 1
    if isGrade or isVehicle then qty = 1 end
    qty = math.min(qty, item.max_qty)

    local total     = item.price * qty
    local citizenid = Player.PlayerData.citizenid
    local license   = GetPlayerIdentifierByType(src, 'license')

    -- Grades : toujours bloqué si déjà possédé (indépendant du flag unique_buy)
    if isGrade then
        local alreadyGrade = MySQL.scalar.await(
            'SELECT COUNT(*) FROM boutique_grades WHERE citizenid = ? AND grp = ?',
            { citizenid, item.set_group }
        )
        if alreadyGrade and alreadyGrade > 0 then
            Notify(src, 'Vous possédez déjà ce grade !', 'error'); return
        end
    end

    -- Achat unique (autres items) : vérifier boutique_unique_purchases
    if item.unique_buy == 1 and not isGrade then
        local already = MySQL.scalar.await(
            'SELECT COUNT(*) FROM boutique_unique_purchases WHERE citizenid = ? AND item_id = ?',
            { citizenid, item.id }
        )
        if already and already > 0 then
            Notify(src, 'Vous avez déjà acheté cet article.', 'error'); return
        end
    end

    local coins = GetCoins(citizenid)

    if coins < total then
        Notify(src, 'Pas assez de ViperCoins. (manque ' .. (total - coins) .. ' VC)', 'error'); return
    end

    -- Bloquer l'achat d'un véhicule déjà possédé
    if isVehicle then
        local already = MySQL.scalar.await(
            'SELECT COUNT(*) FROM boutique_vehicles WHERE citizenid = ? AND vehicle_model = ?',
            { citizenid, item.set_vehicle }
        )
        if already and already > 0 then
            Notify(src, 'Vous possédez déjà ce véhicule !', 'error'); return
        end
    end

    -- Vérifier inventaire uniquement pour les items physiques
    if not isGrade and not isVehicle and item.item_name and item.item_name ~= '' then
        if not exports.ox_inventory:CanCarryItem(src, item.item_name, qty) then
            Notify(src, 'Inventaire plein.', 'error'); return
        end
    end

    -- Débiter les coins
    SetCoins(citizenid, license, coins - total)
    TriggerClientEvent('boutique:updateCoins', src, coins - total)

    -- Enregistrer achat unique (grades toujours inclus)
    if item.unique_buy == 1 or isGrade then
        MySQL.query.await(
            'INSERT IGNORE INTO boutique_unique_purchases (citizenid, item_id) VALUES (?, ?)',
            { citizenid, item.id }
        )
    end

    -- Attribuer le grade ACE (accumulation : n'écrase pas les grades existants)
    if isGrade then
        AddGroup(license, item.set_group)
        SaveGroup(citizenid, license, item.set_group)
        Notify(src, 'Grade [' .. item.label .. '] attribué !', 'success')
        print('[viper-boutique] ' .. GetPlayerName(src) .. ' → grade ' .. item.set_group)
    end

    -- Ajouter le véhicule au garage
    if isVehicle then
        MySQL.query.await(
            'INSERT INTO boutique_vehicles (citizenid, license, vehicle_model, vehicle_label) VALUES (?, ?, ?, ?)',
            { citizenid, license, item.set_vehicle, item.label }
        )
        Notify(src, 'Véhicule [' .. item.label .. '] ajouté au garage ! Tape /garage pour le sortir.', 'success')
        print('[viper-boutique] ' .. GetPlayerName(src) .. ' → véhicule ' .. item.set_vehicle)
    end

    -- Donner l'item physique (armes, munitions, autres)
    if not isGrade and not isVehicle and item.item_name and item.item_name ~= '' then
        exports.ox_inventory:AddItem(src, item.item_name, qty)
        local msg = qty > 1 and (item.label .. ' x' .. qty .. ' acheté !') or (item.label .. ' acheté !')
        Notify(src, msg, 'success')
    end
end)

-- ─── Garage NPC : sync vers clients ─────────────────────────────────────────────
local function BroadcastGarageNpcs()
    local npcs = MySQL.query.await('SELECT * FROM boutique_garage_npcs', {})
    TriggerClientEvent('boutique:syncGarageNpcs', -1, npcs)
end

RegisterNetEvent('boutique:requestGarageNpcs', function()
    local src  = source
    local npcs = MySQL.query.await('SELECT * FROM boutique_garage_npcs', {})
    TriggerClientEvent('boutique:syncGarageNpcs', src, npcs)
end)

-- ─── Garage NPC : placer un NPC ici ──────────────────────────────────────────────
RegisterNetEvent('boutique:placeGarageNpc', function(coords, heading, name)
    local src = source
    if not IsAdmin(src) then return end

    MySQL.query.await(
        'INSERT INTO boutique_garage_npcs (name, x, y, z, heading) VALUES (?, ?, ?, ?, ?)',
        { name or 'Garage', coords.x, coords.y, coords.z, heading }
    )
    local npcs = MySQL.query.await('SELECT * FROM boutique_garage_npcs', {})
    TriggerClientEvent('boutique:syncGarageNpcs', -1, npcs)
    TriggerClientEvent('boutique:adminGarageNpcSync', src, npcs)
    Notify(src, 'NPC garage "' .. (name or 'Garage') .. '" placé !', 'success')
end)

-- ─── Garage NPC : définir point de spawn véhicule ────────────────────────────────
RegisterNetEvent('boutique:setGarageNpcSpawn', function(npcId, coords, heading)
    local src = source
    if not IsAdmin(src) then return end

    MySQL.query.await(
        'UPDATE boutique_garage_npcs SET spawn_x=?, spawn_y=?, spawn_z=?, spawn_heading=? WHERE id=?',
        { coords.x, coords.y, coords.z, heading, tonumber(npcId) }
    )
    local npcs = MySQL.query.await('SELECT * FROM boutique_garage_npcs', {})
    TriggerClientEvent('boutique:syncGarageNpcs', -1, npcs)
    TriggerClientEvent('boutique:adminGarageNpcSync', src, npcs)
    Notify(src, 'Point de spawn défini !', 'success')
end)

-- ─── Garage NPC : supprimer ───────────────────────────────────────────────────────
RegisterNetEvent('boutique:deleteGarageNpc', function(npcId)
    local src = source
    if not IsAdmin(src) then return end

    MySQL.query.await('DELETE FROM boutique_garage_npcs WHERE id = ?', { tonumber(npcId) })
    local npcs = MySQL.query.await('SELECT * FROM boutique_garage_npcs', {})
    TriggerClientEvent('boutique:syncGarageNpcs', -1, npcs)
    TriggerClientEvent('boutique:adminGarageNpcSync', src, npcs)
    Notify(src, 'NPC garage supprimé.', 'success')
end)

-- ─── Garage : liste des véhicules du joueur ────────────────────────────────────
RegisterNetEvent('boutique:requestGarage', function(npcId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local vehicles = MySQL.query.await(
        'SELECT vehicle_model, vehicle_label FROM boutique_vehicles WHERE citizenid = ? ORDER BY purchased_at DESC',
        { Player.PlayerData.citizenid }
    )
    TriggerClientEvent('boutique:openGarage', src, vehicles, npcId)
end)

-- ─── Custom NPC : sync ───────────────────────────────────────────────────────
local function BroadcastCustomNpcs()
    local npcs = MySQL.query.await('SELECT * FROM boutique_custom_npcs', {})
    TriggerClientEvent('boutique:syncCustomNpcs', -1, npcs)
end

RegisterNetEvent('boutique:requestCustomNpcs', function()
    local src  = source
    local npcs = MySQL.query.await('SELECT * FROM boutique_custom_npcs', {})
    TriggerClientEvent('boutique:syncCustomNpcs', src, npcs)
end)

RegisterNetEvent('boutique:placeCustomNpc', function(coords, heading, name)
    local src = source
    if not IsAdmin(src) then return end
    MySQL.query.await(
        'INSERT INTO boutique_custom_npcs (name, x, y, z, heading) VALUES (?, ?, ?, ?, ?)',
        { name or 'Atelier', coords.x, coords.y, coords.z, heading }
    )
    local npcs = MySQL.query.await('SELECT * FROM boutique_custom_npcs', {})
    TriggerClientEvent('boutique:syncCustomNpcs', -1, npcs)
    TriggerClientEvent('boutique:adminCustomNpcSync', src, npcs)
    Notify(src, 'NPC atelier "' .. (name or 'Atelier') .. '" placé !', 'success')
end)

RegisterNetEvent('boutique:deleteCustomNpc', function(npcId)
    local src = source
    if not IsAdmin(src) then return end
    MySQL.query.await('DELETE FROM boutique_custom_npcs WHERE id = ?', { tonumber(npcId) })
    local npcs = MySQL.query.await('SELECT * FROM boutique_custom_npcs', {})
    TriggerClientEvent('boutique:syncCustomNpcs', -1, npcs)
    TriggerClientEvent('boutique:adminCustomNpcSync', src, npcs)
    Notify(src, 'NPC atelier supprimé.', 'success')
end)

RegisterNetEvent('boutique:requestCustomShop', function()
    local src = source
    TriggerClientEvent('boutique:openCustomShop', src)
end)

-- ─── Sauvegarde des mods véhicule ─────────────────────────────────────────────
RegisterNetEvent('boutique:saveVehicleMods', function(vehicleModel, mods)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local bodyModsJson = nil
    if mods.body_mods then
        if type(mods.body_mods) == 'table' then
            bodyModsJson = json.encode(mods.body_mods)
        else
            bodyModsJson = mods.body_mods
        end
    end
    MySQL.query(
        [[INSERT INTO boutique_vehicle_mods
            (citizenid, vehicle_model, primary_color, secondary_color, pearl_color, wheel_color,
             wheel_type, wheel_mod, window_tint, xenon_enabled, xenon_color,
             neon_left, neon_right, neon_front, neon_back, neon_r, neon_g, neon_b, body_mods)
          VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
          ON DUPLICATE KEY UPDATE
            primary_color=VALUES(primary_color), secondary_color=VALUES(secondary_color),
            pearl_color=VALUES(pearl_color), wheel_color=VALUES(wheel_color),
            wheel_type=VALUES(wheel_type), wheel_mod=VALUES(wheel_mod),
            window_tint=VALUES(window_tint), xenon_enabled=VALUES(xenon_enabled),
            xenon_color=VALUES(xenon_color), neon_left=VALUES(neon_left),
            neon_right=VALUES(neon_right), neon_front=VALUES(neon_front),
            neon_back=VALUES(neon_back), neon_r=VALUES(neon_r),
            neon_g=VALUES(neon_g), neon_b=VALUES(neon_b),
            body_mods=VALUES(body_mods)]],
        { citizenid, vehicleModel,
          mods.primary_color, mods.secondary_color, mods.pearl_color, mods.wheel_color,
          mods.wheel_type, mods.wheel_mod, mods.window_tint,
          mods.xenon_enabled and 1 or 0, mods.xenon_color,
          mods.neon_left and 1 or 0, mods.neon_right and 1 or 0,
          mods.neon_front and 1 or 0, mods.neon_back and 1 or 0,
          mods.neon_r or 0, mods.neon_g or 255, mods.neon_b or 0,
          bodyModsJson }
    )
end)

-- Génère une plaque fixe et unique par (citizenid, modèle)
-- Utilisée comme clé dans player_vehicles pour que ox_inventory sauvegarde la boîte à gants
local function MakeBoutiquePlate(citizenid, model)
    local prefix = string.upper(string.sub(model, 1, 3))
    local suffix = string.upper(string.sub(citizenid, -5))
    return string.sub(prefix .. suffix, 1, 8)
end

-- ─── Garage : spawner un véhicule (validation serveur) ────────────────────────
RegisterNetEvent('boutique:spawnVehicle', function(model, npcId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    local owns = MySQL.scalar.await(
        'SELECT COUNT(*) FROM boutique_vehicles WHERE citizenid = ? AND vehicle_model = ?',
        { citizenid, tostring(model) }
    )
    if not owns or owns == 0 then
        Notify(src, 'Véhicule introuvable dans votre garage.', 'error'); return
    end

    -- Générer/garantir la plaque fixe dans player_vehicles (pour boîte à gants ox_inventory)
    local plate   = MakeBoutiquePlate(citizenid, model)
    local license = GetPlayerIdentifierByType(src, 'license') or 'license:boutique'
    MySQL.query([[
        INSERT IGNORE INTO player_vehicles
            (citizenid, license, plate, vehicle, mods, garage, fuel, engine, body, state)
        VALUES (?,?,?,?,?,'boutique',100,1000.0,1000.0,0)
    ]], { citizenid, license, plate, json.encode({ model = model }), '{}' })

    -- Récupérer le point de spawn du NPC
    local spawnData = nil
    if npcId then
        local npc = MySQL.single.await(
            'SELECT spawn_x, spawn_y, spawn_z, spawn_heading FROM boutique_garage_npcs WHERE id = ? AND spawn_x IS NOT NULL',
            { tonumber(npcId) }
        )
        if npc then
            spawnData = { x = npc.spawn_x, y = npc.spawn_y, z = npc.spawn_z, heading = npc.spawn_heading }
        end
    end

    local mods = MySQL.single.await(
        'SELECT * FROM boutique_vehicle_mods WHERE citizenid = ? AND vehicle_model = ?',
        { citizenid, tostring(model) }
    )
    TriggerClientEvent('boutique:doSpawnVehicle', src, model, spawnData, mods, plate)
end)
