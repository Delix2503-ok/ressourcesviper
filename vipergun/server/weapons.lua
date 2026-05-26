local QBCore = exports['qb-core']:GetCoreObject()

-- Config runtime (defaults config.lua fusionnés avec overrides BDD)
local activeWeapons = {}
local configLoaded  = false

-- ----------------------------------------------------------------
-- Charge les overrides BDD et les fusionne avec Config.Weapons
-- N'est appelé QUE après que les tables soient créées (vipergun:dbReady)
-- ----------------------------------------------------------------
local function loadWeaponConfig()
    activeWeapons = {}
    for name, data in pairs(Config.Weapons) do
        activeWeapons[name] = {
            damage     = data.damage,
            headDamage = data.headDamage,
            range      = data.range,
            enabled    = data.enabled,
        }
    end

    MySQL.query('SELECT * FROM vipergun_weapon_overrides', {}, function(rows)
        if not rows then return end
        for _, row in ipairs(rows) do
            if activeWeapons[row.weapon_name] then
                activeWeapons[row.weapon_name].damage     = row.body_damage
                activeWeapons[row.weapon_name].headDamage = row.head_damage
                activeWeapons[row.weapon_name].range      = row.range_val
                activeWeapons[row.weapon_name].enabled    = row.enabled == 1
            end
        end
        configLoaded = true
        -- Re-broadcast la config définitive (BDD) à tous les clients connectés
        TriggerClientEvent('vipergun:receiveWeaponConfig', -1, activeWeapons)
    end)
end

-- Expose pour server/admin.lua
function GetActiveWeapons() return activeWeapons end
function SetActiveWeapons(w) activeWeapons = w end

-- ----------------------------------------------------------------
-- Tables prêtes → on charge la config armes
-- (signal envoyé par server/coffres.lua après les CREATE TABLE)
-- ----------------------------------------------------------------
AddEventHandler('vipergun:dbReady', function()
    loadWeaponConfig()
end)

-- ----------------------------------------------------------------
-- Envoie la config à un client qui la demande
-- Si la config n'est pas encore chargée, envoie les defaults
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:requestWeaponConfig', function()
    TriggerClientEvent('vipergun:receiveWeaponConfig', source, activeWeapons)
end)

-- ----------------------------------------------------------------
-- Relay hitmarker : victime → serveur → attaquant
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:hitRegistered', function(data)
    local attackerSrc = tonumber(data.attackerServerId)
    if attackerSrc and GetPlayerPed(attackerSrc) ~= 0 then
        TriggerClientEvent('vipergun:showHitmarker', attackerSrc, {
            damage     = data.damage,
            isHeadshot = data.isHeadshot,
            victimX    = data.victimX,
            victimY    = data.victimY,
            victimZ    = data.victimZ,
        })
    end
end)

-- ----------------------------------------------------------------
-- Charge les defaults immédiatement (sans BDD) pour que les
-- premiers clients aient au moins la config par défaut
-- ----------------------------------------------------------------
for name, data in pairs(Config.Weapons) do
    activeWeapons[name] = {
        damage     = data.damage,
        headDamage = data.headDamage,
        range      = data.range,
        enabled    = data.enabled,
    }
end
