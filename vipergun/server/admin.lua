local QBCore = exports['qb-core']:GetCoreObject()

-- ----------------------------------------------------------------
-- Vérification de la licence admin
-- ----------------------------------------------------------------
local function isAdmin(src)
    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then return false end
    for _, adminLicense in ipairs(Config.AdminLicenses) do
        if license == adminLicense then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------
-- Ouvre le panel admin (envoie toutes les données)
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:admin:getFullData', function()
    local src = source
    if not isAdmin(src) then
        TriggerClientEvent('vipergun:admin:notify', src, 'Accès refusé.', 'error')
        return
    end

    MySQL.query([[
        SELECT vc.citizenid, vc.coffre_count, p.name AS player_name
        FROM vipergun_coffres vc
        LEFT JOIN players p ON p.citizenid = vc.citizenid
    ]], {}, function(coffres)
        MySQL.query('SELECT * FROM vipergun_peds', {}, function(peds)
            TriggerClientEvent('vipergun:admin:openPanel', src, {
                coffres = coffres or {},
                peds    = peds or {},
            })
        end)
    end)
end)

-- ----------------------------------------------------------------
-- Ajoute un PNJ (INSERT BDD + sync tous les clients)
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:admin:addPed', function(data)
    local src = source
    if not isAdmin(src) then return end

    local model   = tostring(data.model or 's_m_y_dealer_01')
    local x       = tonumber(data.x)       or 0.0
    local y       = tonumber(data.y)       or 0.0
    local z       = tonumber(data.z)       or 0.0
    local heading = tonumber(data.heading) or 0.0

    MySQL.insert(
        'INSERT INTO vipergun_peds (model, x, y, z, heading) VALUES (?, ?, ?, ?, ?)',
        { model, x, y, z, heading },
        function(newId)
            if not newId then
                TriggerClientEvent('vipergun:admin:notify', src, 'Erreur BDD lors de l\'ajout.', 'error')
                return
            end
            MySQL.query('SELECT * FROM vipergun_peds', {}, function(rows)
                local allPeds = rows or {}
                TriggerClientEvent('vipergun:syncPeds', -1, allPeds)
                TriggerClientEvent('vipergun:admin:updatePeds', src, allPeds)
            end)
            TriggerClientEvent('vipergun:admin:notify', src, 'PNJ ajouté (ID ' .. newId .. ').', 'success')
        end
    )
end)

-- ----------------------------------------------------------------
-- Supprime un PNJ par son ID
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:admin:removePed', function(data)
    local src   = source
    if not isAdmin(src) then return end

    local pedId = tonumber(data and data.id)
    if not pedId then return end

    MySQL.query('DELETE FROM vipergun_peds WHERE id = ?', { pedId }, function()
        TriggerClientEvent('vipergun:removePedById', -1, pedId)
        MySQL.query('SELECT * FROM vipergun_peds', {}, function(rows)
            TriggerClientEvent('vipergun:admin:updatePeds', src, rows or {})
        end)
        TriggerClientEvent('vipergun:admin:notify', src, 'PNJ supprimé.', 'success')
    end)
end)

-- ----------------------------------------------------------------
-- Modifie le nombre de coffres d'un joueur (admin)
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:admin:updatePlayerCoffres', function(data)
    local src = source
    if not isAdmin(src) then return end

    local citizenid = data.citizenid
    local newCount  = math.max(Config.Coffres.baseChests,
                       math.min(Config.Coffres.maxChests, tonumber(data.count) or Config.Coffres.baseChests))

    MySQL.query('UPDATE vipergun_coffres SET coffre_count = ? WHERE citizenid = ?',
        { newCount, citizenid })

    -- Enregistre les stashes additionnels si besoin
    for i = 1, newCount do
        exports.ox_inventory:RegisterStash(
            'vipergun_coffre_' .. citizenid .. '_' .. i,
            'Coffre #' .. i,
            Config.Coffres.slotsPerChest,
            Config.Coffres.weightPerChest,
            citizenid
        )
    end

    TriggerClientEvent('vipergun:admin:notify', src,
        'Coffres mis à jour : ' .. newCount .. ' coffres.', 'success')
end)
