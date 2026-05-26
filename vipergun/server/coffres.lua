local QBCore = exports['qb-core']:GetCoreObject()

-- ----------------------------------------------------------------
-- Création des tables EN SÉQUENCE (await = attend la fin avant de passer)
-- puis signale que la BDD est prête pour weapons.lua
-- ----------------------------------------------------------------
CreateThread(function()
    Wait(800)

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vipergun_coffres` (
            `citizenid`    VARCHAR(50) NOT NULL,
            `coffre_count` INT         NOT NULL DEFAULT 4,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vipergun_weapon_overrides` (
            `weapon_name` VARCHAR(100) NOT NULL,
            `body_damage` INT          NOT NULL,
            `head_damage` INT          NOT NULL,
            `range_val`   FLOAT        NOT NULL,
            `enabled`     TINYINT(1)   NOT NULL DEFAULT 1,
            PRIMARY KEY (`weapon_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vipergun_ped_config` (
            `id`      INT          NOT NULL DEFAULT 1,
            `model`   VARCHAR(100) NOT NULL DEFAULT 's_m_y_dealer_01',
            `x`       FLOAT        NOT NULL DEFAULT 0.0,
            `y`       FLOAT        NOT NULL DEFAULT 0.0,
            `z`       FLOAT        NOT NULL DEFAULT 0.0,
            `heading` FLOAT        NOT NULL DEFAULT 0.0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Table multi-PNJ (remplace l'ancienne vipergun_ped_config à terme)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vipergun_peds` (
            `id`      INT          NOT NULL AUTO_INCREMENT,
            `model`   VARCHAR(100) NOT NULL DEFAULT 's_m_y_dealer_01',
            `x`       FLOAT        NOT NULL DEFAULT 0.0,
            `y`       FLOAT        NOT NULL DEFAULT 0.0,
            `z`       FLOAT        NOT NULL DEFAULT 0.0,
            `heading` FLOAT        NOT NULL DEFAULT 0.0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Signale à weapons.lua que les tables sont prêtes
    TriggerEvent('vipergun:dbReady')
end)

-- ----------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------
local function getPedConfig(cb)
    MySQL.query('SELECT * FROM vipergun_ped_config WHERE id = 1', {}, function(rows)
        if rows and rows[1] then
            cb(rows[1])
        else
            cb(Config.Coffres.pedLocation)
        end
    end)
end

local function getPlayerCoffreCount(citizenid, cb)
    MySQL.query(
        'SELECT coffre_count FROM vipergun_coffres WHERE citizenid = ?',
        { citizenid },
        function(rows)
            if rows and rows[1] then
                cb(rows[1].coffre_count)
            else
                MySQL.query(
                    'INSERT INTO vipergun_coffres (citizenid, coffre_count) VALUES (?, ?)',
                    { citizenid, Config.Coffres.baseChests }
                )
                cb(Config.Coffres.baseChests)
            end
        end
    )
end

local function registerStashes(citizenid, count)
    for i = 1, count do
        local ok, err = pcall(function()
            exports.ox_inventory:RegisterStash(
                'vipergun_coffre_' .. citizenid .. '_' .. i,
                'Coffre #' .. i,
                Config.Coffres.slotsPerChest,
                Config.Coffres.weightPerChest,
                citizenid
            )
        end)
        if not ok then
            print('[vipergun] Erreur RegisterStash coffre ' .. i .. ' : ' .. tostring(err))
        end
    end
end

-- ----------------------------------------------------------------
-- Enregistrement des stashes au chargement du joueur
-- ----------------------------------------------------------------
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local citizenid = Player.PlayerData.citizenid
    if not citizenid then return end
    getPlayerCoffreCount(citizenid, function(count)
        registerStashes(citizenid, count)
    end)
end)

-- ----------------------------------------------------------------
-- Sync de tous les PNJ au joueur qui rejoint
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:requestPedSpawn', function()
    local src = source
    MySQL.query('SELECT * FROM vipergun_peds', {}, function(rows)
        TriggerClientEvent('vipergun:syncPeds', src, rows or {})
    end)
end)

-- ----------------------------------------------------------------
-- Récupère les données coffres du joueur
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:getCoffreData', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    getPlayerCoffreCount(Player.PlayerData.citizenid, function(count)
        TriggerClientEvent('vipergun:receiveCoffreData', src, {
            count    = count,
            maxCount = Config.Coffres.maxChests,
            prices   = Config.Coffres.chestPrices,
        })
    end)
end)

-- ----------------------------------------------------------------
-- Ouvre un coffre spécifique
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:openCoffre', function(slot)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    getPlayerCoffreCount(citizenid, function(count)
        if slot < 1 or slot > count then
            TriggerClientEvent('vipergun:coffreError', src, 'Coffre non déverrouillé')
            return
        end
        local stashId = 'vipergun_coffre_' .. citizenid .. '_' .. slot
        TriggerClientEvent('vipergun:openStash', src, stashId)
    end)
end)

-- ----------------------------------------------------------------
-- Achète un coffre supplémentaire
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:buyCoffre', function(slot)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    getPlayerCoffreCount(citizenid, function(currentCount)
        if slot ~= currentCount + 1 then
            TriggerClientEvent('vipergun:coffreError', src, 'Achetez les coffres dans l\'ordre')
            return
        end
        if slot > Config.Coffres.maxChests then
            TriggerClientEvent('vipergun:coffreError', src, 'Vous avez le maximum de coffres')
            return
        end

        local price = Config.Coffres.chestPrices[slot]
        if not price then
            TriggerClientEvent('vipergun:coffreError', src, 'Prix introuvable')
            return
        end

        local moneyCount = exports.ox_inventory:Search(src, 'count', 'money') or 0
        if moneyCount < price then
            TriggerClientEvent('vipergun:coffreError', src,
                'Fonds insuffisants. Il vous faut ' .. price .. ' $ en cash sur vous')
            return
        end

        exports.ox_inventory:RemoveItem(src, 'money', price)

        local newCount = currentCount + 1
        MySQL.query('UPDATE vipergun_coffres SET coffre_count = ? WHERE citizenid = ?',
            { newCount, citizenid })

        pcall(function()
            exports.ox_inventory:RegisterStash(
                'vipergun_coffre_' .. citizenid .. '_' .. newCount,
                'Coffre #' .. newCount,
                Config.Coffres.slotsPerChest,
                Config.Coffres.weightPerChest,
                citizenid
            )
        end)

        TriggerClientEvent('vipergun:coffrePurchased', src, slot)
    end)
end)
