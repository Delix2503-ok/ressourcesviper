-- ----------------------------------------------------------------
-- Formatage d'un nombre en string avec espaces (1 000 000)
-- ----------------------------------------------------------------
local function formatMoney(amount)
    local s = tostring(math.floor(amount))
    return s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
end

-- ----------------------------------------------------------------
-- Affichage du menu de sélection de coffre
-- ----------------------------------------------------------------
local function showCoffreMenu(data)
    local options = {}

    for i = 1, Config.Coffres.maxChests do
        if i <= data.count then
            options[#options + 1] = {
                title       = 'Coffre #' .. i,
                description = 'Ouvrir le coffre ' .. i,
                icon        = 'box-open',
                iconColor   = '#39ff14',
                onSelect    = function()
                    TriggerServerEvent('vipergun:openCoffre', i)
                end,
            }
        else
            local price = Config.Coffres.chestPrices[i]
            options[#options + 1] = {
                title       = 'Coffre #' .. i .. '  [VERROUILLÉ]',
                description = 'Débloquer pour ' .. formatMoney(price) .. ' $',
                icon        = 'lock',
                iconColor   = '#ff4444',
                onSelect    = function()
                    TriggerServerEvent('vipergun:buyCoffre', i)
                end,
            }
        end
    end

    lib.registerContext({
        id      = 'vipergun_coffres',
        title   = 'Mes Coffres',
        options = options,
    })
    lib.showContext('vipergun_coffres')
end

-- ----------------------------------------------------------------
-- Déclenchement depuis le PNJ (ped.lua)
-- ----------------------------------------------------------------
AddEventHandler('vipergun:openCoffresMenu', function()
    TriggerServerEvent('vipergun:getCoffreData')
end)

-- ----------------------------------------------------------------
-- Réponses serveur
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:receiveCoffreData', function(data)
    showCoffreMenu(data)
end)

RegisterNetEvent('vipergun:openStash', function(stashId)
    exports.ox_inventory:openInventory('stash', stashId)
end)

RegisterNetEvent('vipergun:coffrePurchased', function(slot)
    lib.notify({
        title       = 'Coffre déverrouillé',
        description = 'Coffre #' .. slot .. ' est maintenant disponible !',
        type        = 'success',
        duration    = 4000,
    })
    -- Rafraîchit le menu avec les nouvelles données
    TriggerServerEvent('vipergun:getCoffreData')
end)

RegisterNetEvent('vipergun:coffreError', function(msg)
    lib.notify({
        title       = 'Erreur',
        description = msg,
        type        = 'error',
        duration    = 3000,
    })
end)
