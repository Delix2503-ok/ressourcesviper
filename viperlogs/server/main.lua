print('^2[viperlogs]^7 Chargement du script serveur...')

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function GetLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function GetPName(src)
    local qbp = QBCore.Functions.GetPlayer(src)
    if qbp then
        local ci = qbp.PlayerData.charinfo
        if ci and ci.firstname then
            return ci.firstname .. ' ' .. (ci.lastname or '')
        end
    end
    return tostring(GetPlayerName(src) or 'Inconnu')
end

local function IsAllowed(src)
    -- Check via les ACE Viper définies dans server.cfg
    local aces = { 'viper.fondateur', 'viper.responsable', 'viper.admin', 'viper.modo', 'viper.modo_test', 'viper.helper' }
    for _, ace in ipairs(aces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    -- Check licences hardcodées en fallback
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
        title = 'ViperLogs', description = msg, type = ntype, duration = 4000
    })
end

-- ─── DB setup ────────────────────────────────────────────────────────────────
MySQL.ready(function()
    print('^2[viperlogs]^7 MySQL ready, création des tables...')
    -- Migration : ajout colonne from_player_name si absente
    MySQL.query("ALTER TABLE viperlogs_loot ADD COLUMN IF NOT EXISTS from_player_name VARCHAR(64)")
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `viperlogs_kills` (
            `id`             INT AUTO_INCREMENT PRIMARY KEY,
            `victim_license` VARCHAR(64) NOT NULL,
            `victim_name`    VARCHAR(64) NOT NULL,
            `killer_license` VARCHAR(64),
            `killer_name`    VARCHAR(64),
            `weapon`         VARCHAR(64) DEFAULT 'unknown',
            `created_at`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_victim (`victim_license`),
            INDEX idx_killer (`killer_license`),
            INDEX idx_date   (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `viperlogs_drops` (
            `id`             INT AUTO_INCREMENT PRIMARY KEY,
            `player_license` VARCHAR(64) NOT NULL,
            `player_name`    VARCHAR(64) NOT NULL,
            `item_name`      VARCHAR(64) NOT NULL,
            `item_label`     VARCHAR(128),
            `quantity`       INT NOT NULL DEFAULT 1,
            `created_at`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_license (`player_license`),
            INDEX idx_date    (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `viperlogs_loot` (
            `id`             INT AUTO_INCREMENT PRIMARY KEY,
            `player_license` VARCHAR(64) NOT NULL,
            `player_name`    VARCHAR(64) NOT NULL,
            `item_name`      VARCHAR(64) NOT NULL,
            `item_label`     VARCHAR(128),
            `quantity`       INT NOT NULL DEFAULT 1,
            `from_type`      VARCHAR(32) DEFAULT 'unknown',
            `created_at`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_license (`player_license`),
            INDEX idx_date    (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    print('^2[viperlogs]^7 Tables créées.')
end)

-- ─── Kill logging (via viperpvp_redzone) ─────────────────────────────────────
AddEventHandler('viperlogs:death', function(victimId, killerId)
    local vLicense = GetLicense(victimId)
    local vName    = GetPName(victimId)
    if not vLicense then return end

    local kLicense, kName = nil, nil
    if killerId and killerId ~= victimId then
        kLicense = GetLicense(killerId)
        kName    = GetPName(killerId)
    end

    MySQL.insert(
        'INSERT INTO viperlogs_kills (victim_license, victim_name, killer_license, killer_name) VALUES (?, ?, ?, ?)',
        { vLicense, vName, kLicense, kName }
    )
end)

-- ─── ox_inventory hook (registerHook, r minuscule) ───────────────────────────
exports.ox_inventory:registerHook('swapItems', function(payload)
    local src      = payload.source
    local fromType = payload.fromType
    local toType   = payload.toType
    local item     = payload.fromSlot
    local qty      = math.abs(tonumber(payload.count) or (item and item.count) or 1)

    if not src or not item or not item.name then return end

    -- Drop : joueur pose un item par terre
    if fromType == 'player' and toType == 'drop' then
        local license = GetLicense(src)
        local name    = GetPName(src)
        if license then
            MySQL.insert(
                'INSERT INTO viperlogs_drops (player_license, player_name, item_name, item_label, quantity) VALUES (?, ?, ?, ?, ?)',
                { license, name, item.name, item.label or item.name, qty }
            )
        end
    end

    -- Loot : joueur ramasse depuis le sol, un coffre, ou l'inventaire d'un autre joueur
    if toType == 'player' and (fromType == 'drop' or fromType == 'stash') then
        local license = GetLicense(src)
        local name    = GetPName(src)
        if license then
            MySQL.insert(
                'INSERT INTO viperlogs_loot (player_license, player_name, item_name, item_label, quantity, from_type) VALUES (?, ?, ?, ?, ?, ?)',
                { license, name, item.name, item.label or item.name, qty, fromType }
            )
        end
    end

    -- Loot joueur→joueur : log sous la licence de la VICTIME (celle qui se fait loot)
    if fromType == 'player' and toType == 'player' and payload.fromInventory ~= src then
        local victimSrc = tonumber(payload.fromInventory)
        if victimSrc and victimSrc ~= src then
            local victimLicense = GetLicense(victimSrc)
            local victimName    = GetPName(victimSrc)
            local looterName    = GetPName(src)
            if victimLicense then
                MySQL.insert(
                    'INSERT INTO viperlogs_loot (player_license, player_name, item_name, item_label, quantity, from_type, from_player_name) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    { victimLicense, victimName, item.name, item.label or item.name, qty, 'player', looterName }
                )
            end
        end
    end
end)

-- ─── Requêtes panel ──────────────────────────────────────────────────────────
local days = math.max(1, math.floor(tonumber(Config.LogDays) or 7))  -- entier clampé : sûr pour la concat SQL

RegisterNetEvent('viperlogs:getKills')
AddEventHandler('viperlogs:getKills', function(license)
    local src = source
    if not IsAllowed(src) then
        Notify(src, 'Permission refusée.', 'error')
        TriggerClientEvent('viperlogs:receiveKills', src, {})
        return
    end
    if not license or license == '' then
        TriggerClientEvent('viperlogs:receiveKills', src, {})
        return
    end
    local rows = MySQL.query.await(
        'SELECT * FROM viperlogs_kills WHERE (victim_license = ? OR killer_license = ?) AND created_at >= DATE_SUB(NOW(), INTERVAL ' .. days .. ' DAY) ORDER BY created_at DESC LIMIT 200',
        { license, license }
    )
    TriggerClientEvent('viperlogs:receiveKills', src, rows or {})
end)

RegisterNetEvent('viperlogs:getLoot')
AddEventHandler('viperlogs:getLoot', function(license)
    local src = source
    if not IsAllowed(src) then
        Notify(src, 'Permission refusée.', 'error')
        TriggerClientEvent('viperlogs:receiveLoot', src, {})
        return
    end
    if not license or license == '' then
        TriggerClientEvent('viperlogs:receiveLoot', src, {})
        return
    end
    local rows = MySQL.query.await(
        'SELECT * FROM viperlogs_loot WHERE player_license = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ' .. days .. ' DAY) ORDER BY created_at DESC LIMIT 200',
        { license }
    )
    TriggerClientEvent('viperlogs:receiveLoot', src, rows or {})
end)

print('^2[viperlogs]^7 Script serveur chargé.')
