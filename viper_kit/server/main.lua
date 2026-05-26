local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function IsKitAdmin(src)
    local ids = GetPlayerIdentifiers(src)
    for _, id in ipairs(ids) do
        for _, allowed in ipairs(Config.AdminLicenses) do
            if id == allowed then return true end
        end
    end
    return false
end

local function GetCitizenId(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid or nil
end

local function GetAllKits()
    local rows = MySQL.query.await('SELECT * FROM viper_kits ORDER BY id ASC')
    for _, kit in ipairs(rows) do
        kit.items    = json.decode(kit.items or '[]')
        kit.one_time = kit.one_time == 1 or kit.one_time == true
    end
    return rows
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Viper Kit', description = msg, type = ntype, duration = 4000
    })
end

-- ─── Positions persistantes (positions.json) ─────────────────────────────────
local Positions = {}
local posRaw = LoadResourceFile(GetCurrentResourceName(), 'positions.json')
if posRaw then Positions = json.decode(posRaw) or {} end

local function SavePositions()
    SaveResourceFile(GetCurrentResourceName(), 'positions.json', json.encode(Positions), -1)
end

-- Client qui rejoint → lui envoyer les coords du PNJ si sauvegardées
RegisterNetEvent('viper_kit:requestNpcPos', function()
    local src = source
    if Positions.npc then
        TriggerClientEvent('viper_kit:syncNpcPos', src, Positions.npc)
    end
end)

-- Admin : sauvegarder position PNJ
RegisterNetEvent('viper_kit:saveNpcPos', function(x, y, z, w)
    local src = source
    if not IsKitAdmin(src) then return end
    Positions.npc = { x = x, y = y, z = z, w = w }
    SavePositions()
    TriggerClientEvent('viper_kit:syncNpcPos', -1, Positions.npc)
end)

-- ─── DB auto-create ──────────────────────────────────────────────────────────
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `viper_kits` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `name`       VARCHAR(64)  NOT NULL,
            `permission` VARCHAR(64)  DEFAULT NULL,
            `one_time`   TINYINT(1)   NOT NULL DEFAULT 0,
            `items`      TEXT         NOT NULL DEFAULT '[]'
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `viper_kit_used` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid`  VARCHAR(64)  NOT NULL,
            `kit_id`     INT          NOT NULL,
            UNIQUE KEY `unique_use` (`citizenid`, `kit_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `viper_kit_cooldowns` (
            `citizenid`    VARCHAR(64) NOT NULL,
            `kit_id`       INT         NOT NULL,
            `last_claimed` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_cd` (`citizenid`, `kit_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        ALTER TABLE `viper_kits`
        ADD COLUMN IF NOT EXISTS `one_time` TINYINT(1) NOT NULL DEFAULT 0;
    ]])
    MySQL.query([[
        ALTER TABLE `viper_kits`
        ADD COLUMN IF NOT EXISTS `cooldown_minutes` INT NOT NULL DEFAULT 0;
    ]])
end)

-- ─── Admin : ouvrir panel ────────────────────────────────────────────────────
RegisterNetEvent('viper_kit:adminOpen', function()
    local src = source
    if not IsKitAdmin(src) then Notify(src, 'Permission refusée.', 'error'); return end
    TriggerClientEvent('viper_kit:adminReceiveKits', src, GetAllKits())
end)

-- ─── Admin : créer ───────────────────────────────────────────────────────────
RegisterNetEvent('viper_kit:adminCreate', function(data)
    local src = source
    if not IsKitAdmin(src) then return end
    if not data.name or data.name == '' then return end
    MySQL.insert.await('INSERT INTO viper_kits (name, permission, one_time, cooldown_minutes, items) VALUES (?, ?, ?, ?, ?)', {
        data.name,
        (data.permission ~= nil and data.permission ~= '') and data.permission or nil,
        data.one_time and 1 or 0,
        tonumber(data.cooldown_minutes) or 0,
        json.encode(data.items or {}),
    })
    Notify(src, 'Kit **' .. data.name .. '** créé !', 'success')
    TriggerClientEvent('viper_kit:adminReceiveKits', src, GetAllKits())
end)

-- ─── Admin : modifier ────────────────────────────────────────────────────────
RegisterNetEvent('viper_kit:adminEdit', function(data)
    local src = source
    if not IsKitAdmin(src) then return end
    MySQL.query.await('UPDATE viper_kits SET name=?, permission=?, one_time=?, cooldown_minutes=?, items=? WHERE id=?', {
        data.name,
        (data.permission ~= nil and data.permission ~= '') and data.permission or nil,
        data.one_time and 1 or 0,
        tonumber(data.cooldown_minutes) or 0,
        json.encode(data.items or {}),
        data.id,
    })
    Notify(src, 'Kit modifié.', 'success')
    TriggerClientEvent('viper_kit:adminReceiveKits', src, GetAllKits())
end)

-- ─── Admin : supprimer ───────────────────────────────────────────────────────
RegisterNetEvent('viper_kit:adminDelete', function(id)
    local src = source
    if not IsKitAdmin(src) then return end
    MySQL.query.await('DELETE FROM viper_kits WHERE id=?', { id })
    MySQL.query.await('DELETE FROM viper_kit_used WHERE kit_id=?', { id })
    MySQL.query.await('DELETE FROM viper_kit_cooldowns WHERE kit_id=?', { id })
    Notify(src, 'Kit supprimé.', 'success')
    TriggerClientEvent('viper_kit:adminReceiveKits', src, GetAllKits())
end)

-- ─── Joueur : récupérer ses kits accessibles ─────────────────────────────────
RegisterNetEvent('viper_kit:getMyKits', function()
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then return end

    local all = GetAllKits()

    -- Kits déjà utilisés par ce joueur
    local usedRows = MySQL.query.await('SELECT kit_id FROM viper_kit_used WHERE citizenid=?', { citizenid })
    local used = {}
    for _, r in ipairs(usedRows) do used[r.kit_id] = true end

    local mine = {}
    for _, kit in ipairs(all) do
        local perm = kit.permission
        if not perm or perm == '' or IsPlayerAceAllowed(src, perm) then
            kit.already_used = used[kit.id] == true
            -- Cooldown restant
            local cdMins = tonumber(kit.cooldown_minutes) or 0
            if cdMins > 0 and not kit.one_time then
                local cdRow = MySQL.query.await(
                    'SELECT TIMESTAMPDIFF(SECOND, last_claimed, NOW()) AS elapsed FROM viper_kit_cooldowns WHERE citizenid=? AND kit_id=?',
                    { citizenid, kit.id }
                )
                if cdRow and cdRow[1] then
                    local elapsed = tonumber(cdRow[1].elapsed) or 0
                    local cdSecs  = cdMins * 60
                    if elapsed < cdSecs then
                        kit.cooldown_remaining = math.ceil((cdSecs - elapsed) / 60)
                    end
                end
            end
            table.insert(mine, kit)
        end
    end
    TriggerClientEvent('viper_kit:receiveMyKits', src, mine)
end)

-- ─── Joueur : réclamer un kit ────────────────────────────────────────────────
RegisterNetEvent('viper_kit:claim', function(kitId)
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then return end

    local rows = MySQL.query.await('SELECT * FROM viper_kits WHERE id=?', { kitId })
    if not rows or not rows[1] then return end
    local kit = rows[1]

    local perm = kit.permission
    if perm and perm ~= '' and not IsPlayerAceAllowed(src, perm) then
        Notify(src, 'Permission refusée.', 'error'); return
    end

    -- Vérification one-time
    if kit.one_time == 1 or kit.one_time == true then
        local check = MySQL.query.await('SELECT id FROM viper_kit_used WHERE citizenid=? AND kit_id=?', { citizenid, kitId })
        if check and check[1] then
            Notify(src, 'Tu as déjà utilisé ce kit.', 'error'); return
        end
        MySQL.insert('INSERT IGNORE INTO viper_kit_used (citizenid, kit_id) VALUES (?, ?)', { citizenid, kitId })
    else
        -- Vérification cooldown
        local cdMins = tonumber(kit.cooldown_minutes) or 0
        if cdMins > 0 then
            local cdRow = MySQL.query.await(
                'SELECT TIMESTAMPDIFF(SECOND, last_claimed, NOW()) AS elapsed FROM viper_kit_cooldowns WHERE citizenid=? AND kit_id=?',
                { citizenid, kitId }
            )
            if cdRow and cdRow[1] then
                local elapsed = tonumber(cdRow[1].elapsed) or 0
                local cdSecs  = cdMins * 60
                if elapsed < cdSecs then
                    local remaining = math.ceil((cdSecs - elapsed) / 60)
                    Notify(src, 'Kit disponible dans **' .. remaining .. ' min**.', 'error'); return
                end
            end
            MySQL.query.await(
                'INSERT INTO viper_kit_cooldowns (citizenid, kit_id, last_claimed) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE last_claimed=NOW()',
                { citizenid, kitId }
            )
        end
    end

    local items = json.decode(kit.items or '[]')
    for _, item in ipairs(items) do
        exports.ox_inventory:AddItem(src, item.item, tonumber(item.amount) or 1)
    end
    Notify(src, 'Kit **' .. kit.name .. '** reçu !', 'success')
end)
