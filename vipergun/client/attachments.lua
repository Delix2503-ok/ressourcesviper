local menuOpen           = false
local WEAPON_UNARMED     = GetHashKey('weapon_unarmed')
local currentAttachments = {}
local currentWeaponName  = nil
local currentWeaponHash  = 0
-- [weaponName] = { [compName] = true/false } — état sauvegardé par l'user pour la session
local SavedComponents    = {}

-- ----------------------------------------------------------------
-- Construit la liste des accessoires pour l'arme courante
-- ----------------------------------------------------------------
local function buildAttachmentList(weaponName, weaponHash)
    local components = Config.WeaponAttachments[weaponName]
    if not components then return nil end

    local ped  = PlayerPedId()
    local list = {}

    for _, compName in ipairs(components) do
        local label = Config.ComponentLabels[compName]
        if label then
            local compHash    = GetHashKey(compName)
            local wasEquipped = HasPedGotWeaponComponent(ped, weaponHash, compHash)
            local compatible  = false

            if wasEquipped then
                -- Teste si ce composant est réellement retirable (les composants par défaut non-retirables doivent être ignorés)
                RemoveWeaponComponentFromPed(ped, weaponHash, compHash)
                local stillEquipped = HasPedGotWeaponComponent(ped, weaponHash, compHash)
                if not stillEquipped then
                    -- Retiré avec succès → restorè + affiche comme équipé et retiirable
                    GiveWeaponComponentToPed(ped, weaponHash, compHash)
                    compatible = true
                end
                -- Si stillEquipped = true : composant par défaut non-retirable → on ne l'affiche pas
            elseif label.forceCompat then
                -- HasPedGotWeaponComponent peu fiable pour certains chargeurs → on suppose compatible
                compatible = true
            else
                -- Test de compatibilité : tente l'équipement
                GiveWeaponComponentToPed(ped, weaponHash, compHash)
                compatible = HasPedGotWeaponComponent(ped, weaponHash, compHash)
                if compatible then
                    RemoveWeaponComponentFromPed(ped, weaponHash, compHash)
                end
            end

            -- N'affiche que les accessoires réellement compatibles et retirables
            if compatible then
                table.insert(list, {
                    name     = compName,
                    label    = label.label,
                    category = label.category,
                    icon     = label.icon,
                    equipped = wasEquipped,
                })
            end
        end
    end

    return #list > 0 and list or nil
end

-- ----------------------------------------------------------------
-- Fermeture du menu
-- ----------------------------------------------------------------
local function closeMenu()
    menuOpen            = false
    currentAttachments  = {}
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeAttachments' })
end

-- ----------------------------------------------------------------
-- Ouverture du menu
-- ----------------------------------------------------------------
local function openMenu()
    local ped        = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(ped)

    if weaponHash == WEAPON_UNARMED or weaponHash == 0 then
        lib.notify({ title = 'Accessoires', description = 'Équipez une arme d\'abord', type = 'error', duration = 2000 })
        return
    end

    local weaponName = nil
    for name in pairs(Config.WeaponAttachments) do
        if GetHashKey(name) == weaponHash then
            weaponName = name
            break
        end
    end

    if not weaponName then
        lib.notify({ title = 'Accessoires', description = 'Aucun accessoire configuré pour cette arme', type = 'warning', duration = 2000 })
        return
    end

    local attachments = buildAttachmentList(weaponName, weaponHash)
    if not attachments then
        lib.notify({ title = 'Accessoires', description = 'Aucun accessoire disponible', type = 'warning', duration = 2000 })
        return
    end

    currentAttachments = attachments
    currentWeaponName  = weaponName
    currentWeaponHash  = weaponHash
    menuOpen           = true

    -- Focus NUI complet : le JS gère le clavier (flèches, Enter, Escape)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action      = 'openAttachments',
        weaponName  = weaponName,
        attachments = attachments,
    })
end

-- ----------------------------------------------------------------
-- Touche F6
-- ----------------------------------------------------------------
RegisterKeyMapping('vipergun_attachments', 'Menu Accessoires Arme', 'keyboard', 'F6')
RegisterCommand('vipergun_attachments', function()
    if menuOpen then closeMenu() else openMenu() end
end, false)

-- ----------------------------------------------------------------
-- Callback NUI : toggle via clic souris
-- ----------------------------------------------------------------
RegisterNUICallback('toggleAttachment', function(data, cb)
    local ped        = PlayerPedId()
    local wHash      = GetHashKey(data.weaponName)
    local compHash   = GetHashKey(data.componentName)
    local targetState

    if data.equipped then
        RemoveWeaponComponentFromPed(ped, wHash, compHash)
        targetState = false
    else
        GiveWeaponComponentToPed(ped, wHash, compHash)
        targetState = true
    end

    for i, att in ipairs(currentAttachments) do
        if att.name == data.componentName then
            currentAttachments[i].equipped = targetState
            break
        end
    end

    -- Sauvegarder le choix de l'user pour ce composant
    if not SavedComponents[data.weaponName] then SavedComponents[data.weaponName] = {} end
    SavedComponents[data.weaponName][data.componentName] = targetState

    cb({ equipped = targetState })
end)

-- ----------------------------------------------------------------
-- Callback NUI : fermeture via la croix ou Escape
-- ----------------------------------------------------------------
RegisterNUICallback('closeAttachments', function(_, cb)
    menuOpen           = false
    currentAttachments = {}
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ----------------------------------------------------------------
-- Scopes par défaut des snipers
-- ----------------------------------------------------------------
local SNIPER_DEFAULT_SCOPES = {
    ['weapon_sniperrifle']       = 'COMPONENT_AT_SCOPE_LARGE',
    ['weapon_heavysniper']       = 'COMPONENT_AT_SCOPE_MAX',
    ['weapon_heavysniper_mk2']   = 'COMPONENT_AT_SCOPE_MAX',
    ['weapon_marksmanrifle']     = 'COMPONENT_AT_SCOPE_LARGE',
    ['weapon_marksmanrifle_mk2'] = 'COMPONENT_AT_SCOPE_LARGE',
}

local function getWeaponName(wHash)
    for name in pairs(Config.WeaponAttachments) do
        if GetHashKey(name) == wHash then return name end
    end
    -- Chercher aussi dans les scopes sniper
    for name in pairs(SNIPER_DEFAULT_SCOPES) do
        if GetHashKey(name) == wHash then return name end
    end
    return nil
end

-- ----------------------------------------------------------------
-- Restaure les composants sauvegardés + scope par défaut
-- Appelé à chaque fois que l'arme change
-- ----------------------------------------------------------------
local function restoreComponents(ped, wHash, wName)
    -- 1. Composants sauvegardés par l'user
    if wName and SavedComponents[wName] then
        for compName, equipped in pairs(SavedComponents[wName]) do
            local compHash = GetHashKey(compName)
            if equipped then
                GiveWeaponComponentToPed(ped, wHash, compHash)
            else
                RemoveWeaponComponentFromPed(ped, wHash, compHash)
            end
        end
    end
    -- 2. Scope par défaut des snipers (sauf si l'user l'a explicitement enlevé)
    local defaultScope = wName and SNIPER_DEFAULT_SCOPES[wName]
    if defaultScope then
        local userRemoved = wName and SavedComponents[wName] and SavedComponents[wName][defaultScope] == false
        if not userRemoved then
            local compHash = GetHashKey(defaultScope)
            if not HasPedGotWeaponComponent(ped, wHash, compHash) then
                GiveWeaponComponentToPed(ped, wHash, compHash)
            end
        end
    end
end

-- ----------------------------------------------------------------
-- Normalisation hash signé → non-signé (FiveM int64 vs GTA uint32)
-- ----------------------------------------------------------------
local function toUnsigned(h)
    if h < 0 then return h + 4294967296 end
    return h
end

-- ----------------------------------------------------------------
-- Hook ox_inventory : scope overlay ne s'active que si le composant
-- est présent AU MOMENT où SetCurrentPedWeapon est appelé.
-- ox_inventory équipe l'arme SANS scope → on le donne dans la foulée
-- puis on force un cycle arme pour réinitialiser le rendu du scope.
-- ----------------------------------------------------------------
AddEventHandler('ox_inventory:currentWeapon', function(item)
    if not item or not item.hash then return end
    local wHash = item.hash

    local scopeComp = nil
    for wName, compName in pairs(SNIPER_DEFAULT_SCOPES) do
        if toUnsigned(GetHashKey(wName)) == toUnsigned(wHash) then
            scopeComp = compName
            break
        end
    end
    if not scopeComp then return end

    CreateThread(function()
        local ped = PlayerPedId()
        GiveWeaponComponentToPed(ped, wHash, GetHashKey(scopeComp))
        Wait(0)
        if GetSelectedPedWeapon(ped) == wHash then
            SetCurrentPedWeapon(ped, WEAPON_UNARMED, true)
            Wait(0)
            SetCurrentPedWeapon(ped, wHash, true)
        end
    end)
end)

-- ----------------------------------------------------------------
-- Thread principal : détecte changement d'arme + refresh live NUI
-- ----------------------------------------------------------------
CreateThread(function()
    local lastHash = 0
    while true do
        Wait(300)
        local ped   = PlayerPedId()
        local wHash = GetSelectedPedWeapon(ped)

        -- Changement d'arme → restaurer composants
        if wHash ~= lastHash then
            lastHash = wHash
            if wHash ~= 0 and wHash ~= WEAPON_UNARMED then
                local wName = getWeaponName(wHash)
                restoreComponents(ped, wHash, wName)
            end
            -- Fermer le menu si arme changée pendant qu'il était ouvert
            if menuOpen then closeMenu() end
        end

        -- Refresh live NUI si menu ouvert
        if menuOpen and currentWeaponName and currentWeaponHash ~= 0 then
            local changed = false
            for i, att in ipairs(currentAttachments) do
                local now = HasPedGotWeaponComponent(ped, currentWeaponHash, GetHashKey(att.name))
                if now ~= att.equipped then
                    currentAttachments[i].equipped = now
                    changed = true
                end
            end
            if changed then
                SendNUIMessage({
                    action      = 'openAttachments',
                    weaponName  = currentWeaponName,
                    attachments = currentAttachments,
                })
            end
        end
    end
end)
