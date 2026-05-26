local QBCore = exports['qb-core']:GetCoreObject()

-- Config runtime reçue depuis le serveur (fusionnée defaults + overrides BDD)
local activeWeapons = {}
-- Table hash → config pour recherche rapide
local weaponByHash  = {}

local prevHealth = 200
local prevArmor  = 100

-- ----------------------------------------------------------------
-- Construction de la table de lookup par hash
-- ----------------------------------------------------------------
local function buildLookup(weapons)
    weaponByHash = {}
    for name, data in pairs(weapons) do
        if data.enabled then
            weaponByHash[GetHashKey(name)] = { name = name, cfg = data }
        end
    end
    activeWeapons = weapons
end

-- ----------------------------------------------------------------
-- Suivi HP/Armor frame par frame
-- Doit tourner AVANT que gameEventTriggered ne fire dans la même frame
-- ----------------------------------------------------------------
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if not IsPedDeadOrDying(ped, true) then
            prevHealth = GetEntityHealth(ped)
            prevArmor  = GetPedArmour(ped)
        end
        Wait(0)
    end
end)

-- ----------------------------------------------------------------
-- Application des dégâts corps (armure absorbe en premier)
-- ----------------------------------------------------------------
local function applyBodyDamage(ped, damage)
    SetEntityHealth(ped, prevHealth)
    SetPedArmour(ped, prevArmor)

    local remaining = damage
    local newArmor  = prevArmor
    local newHealth = prevHealth

    if newArmor > 0 then
        local absorbed = math.min(newArmor, remaining)
        newArmor  = newArmor  - absorbed
        remaining = remaining - absorbed
    end

    if remaining > 0 then
        newHealth = newHealth - remaining
    end

    if newHealth <= 100 then
        SetEntityHealth(ped, 0)
    else
        SetEntityHealth(ped, newHealth)
        SetPedArmour(ped, newArmor)
    end
end

-- ----------------------------------------------------------------
-- Application des dégâts tête (bypasse l'armure)
-- ----------------------------------------------------------------
local function applyHeadDamage(ped, damage)
    SetEntityHealth(ped, prevHealth)
    SetPedArmour(ped, prevArmor)

    local newHealth = prevHealth - damage

    if newHealth <= 100 then
        SetEntityHealth(ped, 0)
    else
        SetEntityHealth(ped, newHealth)
        -- L'armure n'est pas touchée par une balle en tête
    end
end

-- ----------------------------------------------------------------
-- Interception des dégâts
-- ----------------------------------------------------------------
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim     = args[1]
    local attacker   = args[2]
    local weaponHash = args[4]

    -- On ne gère que les dégâts reçus par le joueur local
    if victim ~= PlayerPedId() then return end
    if IsPedDeadOrDying(victim, true) then return end

    local info = weaponByHash[weaponHash]
    if not info then return end

    local cfg = info.cfg

    -- Vérification de la portée
    local victimPos   = GetEntityCoords(victim)
    local attackerPos = GetEntityCoords(attacker)
    local dist        = #(victimPos - attackerPos)

    if dist > cfg.range then
        -- Hors portée : annule les dégâts
        SetEntityHealth(victim, prevHealth)
        SetPedArmour(victim, prevArmor)
        return
    end

    -- Détection headshot via l'os touché (31086 = SKEL_Head)
    local _, boneIndex = GetPedLastDamageBone(victim)
    local isHeadshot   = (boneIndex == 31086)

    if isHeadshot then
        applyHeadDamage(victim, cfg.headDamage)
    else
        applyBodyDamage(victim, cfg.damage)
    end

    -- Notifie l'attaquant pour l'hitmarker
    local attackerNetId = NetworkGetPlayerIndexFromPed(attacker)
    if attackerNetId ~= -1 then
        TriggerServerEvent('vipergun:hitRegistered', {
            attackerServerId = GetPlayerServerId(attackerNetId),
            damage           = isHeadshot and cfg.headDamage or cfg.damage,
            isHeadshot       = isHeadshot,
            victimX          = victimPos.x,
            victimY          = victimPos.y,
            victimZ          = victimPos.z,
        })
    end
end)

-- ----------------------------------------------------------------
-- Réception de la config serveur (startup + mises à jour admin)
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:receiveWeaponConfig', function(weapons)
    buildLookup(weapons)
end)

RegisterNetEvent('vipergun:requestWeaponConfig', function()
    TriggerServerEvent('vipergun:requestWeaponConfig')
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('vipergun:requestWeaponConfig')
end)

-- Demande initiale au chargement de la ressource
TriggerServerEvent('vipergun:requestWeaponConfig')

-- ----------------------------------------------------------------
-- Garde-fou scope snipers : redonne le composant toutes les 500ms
-- au cas où quelque chose le retire entre deux équipements.
-- Le rendu de l'overlay est géré par attachments.lua (event handler).
-- ----------------------------------------------------------------
local SNIPER_DEFAULT_SCOPES = {
    ['weapon_sniperrifle']       = 'COMPONENT_AT_SCOPE_LARGE',
    ['weapon_heavysniper']       = 'COMPONENT_AT_SCOPE_MAX',
    ['weapon_heavysniper_mk2']   = 'COMPONENT_AT_SCOPE_MAX',
    ['weapon_marksmanrifle']     = 'COMPONENT_AT_SCOPE_LARGE',
    ['weapon_marksmanrifle_mk2'] = 'COMPONENT_AT_SCOPE_LARGE',
}

local function toUnsignedW(h)
    if h < 0 then return h + 4294967296 end
    return h
end

CreateThread(function()
    while true do
        Wait(500)
        local ped   = PlayerPedId()
        local wHash = GetSelectedPedWeapon(ped)
        if wHash ~= 0 then
            local wHashU = toUnsignedW(wHash)
            for wName, compName in pairs(SNIPER_DEFAULT_SCOPES) do
                if toUnsignedW(GetHashKey(wName)) == wHashU then
                    GiveWeaponComponentToPed(ped, wHash, GetHashKey(compName))
                    break
                end
            end
        end
    end
end)
