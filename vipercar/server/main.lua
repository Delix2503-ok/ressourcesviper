local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Table SQL ────────────────────────────────────────────────────────────────
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `vipercar_npcs` (
            `id`              INT NOT NULL AUTO_INCREMENT,
            `name`            VARCHAR(64) NOT NULL DEFAULT 'Vendeur',
            `x`               FLOAT NOT NULL DEFAULT 0,
            `y`               FLOAT NOT NULL DEFAULT 0,
            `z`               FLOAT NOT NULL DEFAULT 0,
            `heading`         FLOAT NOT NULL DEFAULT 0,
            `spawn_x1`        FLOAT NOT NULL DEFAULT 0,
            `spawn_y1`        FLOAT NOT NULL DEFAULT 0,
            `spawn_z1`        FLOAT NOT NULL DEFAULT 0,
            `spawn_heading1`  FLOAT NOT NULL DEFAULT 0,
            `spawn_x2`        FLOAT NOT NULL DEFAULT 0,
            `spawn_y2`        FLOAT NOT NULL DEFAULT 0,
            `spawn_z2`        FLOAT NOT NULL DEFAULT 0,
            `spawn_heading2`  FLOAT NOT NULL DEFAULT 0,
            `spawn_x3`        FLOAT NOT NULL DEFAULT 0,
            `spawn_y3`        FLOAT NOT NULL DEFAULT 0,
            `spawn_z3`        FLOAT NOT NULL DEFAULT 0,
            `spawn_heading3`  FLOAT NOT NULL DEFAULT 0,
            `spawn_x4`        FLOAT NOT NULL DEFAULT 0,
            `spawn_y4`        FLOAT NOT NULL DEFAULT 0,
            `spawn_z4`        FLOAT NOT NULL DEFAULT 0,
            `spawn_heading4`  FLOAT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Migration : donne un DEFAULT aux anciennes colonnes (évite l'erreur "doesn't have a default value")
    MySQL.query([[
        ALTER TABLE `vipercar_npcs`
            MODIFY COLUMN IF EXISTS `spawn_x`       FLOAT NOT NULL DEFAULT 0,
            MODIFY COLUMN IF EXISTS `spawn_y`       FLOAT NOT NULL DEFAULT 0,
            MODIFY COLUMN IF EXISTS `spawn_z`       FLOAT NOT NULL DEFAULT 0,
            MODIFY COLUMN IF EXISTS `spawn_heading` FLOAT NOT NULL DEFAULT 0
    ]])

    -- Migration : ajoute les nouvelles colonnes si la table existait déjà avec l'ancien schéma
    MySQL.query([[
        ALTER TABLE `vipercar_npcs`
            ADD COLUMN IF NOT EXISTS `spawn_x1`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_y1`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_z1`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_heading1` FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_x2`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_y2`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_z2`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_heading2` FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_x3`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_y3`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_z3`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_heading3` FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_x4`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_y4`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_z4`       FLOAT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `spawn_heading4` FLOAT NOT NULL DEFAULT 0
    ]])

    -- Migration : colonne name
    MySQL.query([[
        ALTER TABLE `vipercar_npcs`
            ADD COLUMN IF NOT EXISTS `name` VARCHAR(64) NOT NULL DEFAULT 'Vendeur'
    ]])
end)

-- ─── Vérification admin par licence ──────────────────────────────────────────
local function getPlayerLicense(src)
    local ids = GetPlayerIdentifiers(src)
    for _, v in ipairs(ids) do
        if string.find(v, 'license:') then return v end
    end
    return nil
end

local function isAdmin(src)
    local license = getPlayerLicense(src)
    if not license then return false end
    for _, l in ipairs(Config.AdminLicences) do
        if l == license then return true end
    end
    return false
end

local function loadNPCs(cb)
    MySQL.query('SELECT * FROM vipercar_npcs', {}, function(rows)
        cb(rows or {})
    end)
end

-- ─── Événements ───────────────────────────────────────────────────────────────

RegisterNetEvent('vipercar:server:GetNPCs', function()
    local src = source
    loadNPCs(function(npcs)
        TriggerClientEvent('vipercar:client:LoadNPCs', src, npcs)
    end)
end)

RegisterNetEvent('vipercar:server:CheckAdmin', function()
    local src = source
    if not isAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, 'Accès refusé — vous n\'êtes pas administrateur.', 'error', 4000)
        return
    end
    loadNPCs(function(npcs)
        TriggerClientEvent('vipercar:client:OpenAdmin', src, npcs)
    end)
end)

RegisterNetEvent('vipercar:server:AddNPC', function(data)
    local src = source
    if not isAdmin(src) then return end

    MySQL.insert(
        [[INSERT INTO vipercar_npcs
            (name, x, y, z, heading,
             spawn_x1, spawn_y1, spawn_z1, spawn_heading1,
             spawn_x2, spawn_y2, spawn_z2, spawn_heading2,
             spawn_x3, spawn_y3, spawn_z3, spawn_heading3,
             spawn_x4, spawn_y4, spawn_z4, spawn_heading4)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            data.name or 'Vendeur',
            data.x, data.y, data.z, data.heading,
            data.spawn_x1, data.spawn_y1, data.spawn_z1, data.spawn_heading1,
            data.spawn_x2, data.spawn_y2, data.spawn_z2, data.spawn_heading2,
            data.spawn_x3, data.spawn_y3, data.spawn_z3, data.spawn_heading3,
            data.spawn_x4, data.spawn_y4, data.spawn_z4, data.spawn_heading4,
        },
        function(id)
            data.id = id
            TriggerClientEvent('vipercar:client:SpawnNPC', -1, data)
            TriggerClientEvent('vipercar:client:AdminNPCCreated', src, data)
        end
    )
end)

RegisterNetEvent('vipercar:server:DeleteNPC', function(id)
    local src = source
    if not isAdmin(src) then return end

    MySQL.query('DELETE FROM vipercar_npcs WHERE id = ?', { id }, function()
        TriggerClientEvent('vipercar:client:RemoveNPC', -1, id)
    end)
end)

-- Whitelist des modèles autorisés (anti spawn de véhicule arbitraire)
local AllowedModels = {}
for _, v in ipairs(Config.Vehicles or {}) do
    if v.model then AllowedModels[string.lower(v.model)] = true end
end

RegisterNetEvent('vipercar:server:SpawnVehicle', function(model, spawnData)
    local src = source
    if not model or not AllowedModels[string.lower(tostring(model))] then return end
    TriggerClientEvent('vipercar:client:DoSpawnVehicle', src, model, spawnData)
end)
