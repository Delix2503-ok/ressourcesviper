-- =============================================
--   Speedboost - Two Hand Hold
--   Framework : QBCore
-- =============================================

local HOLD_DURATION  = 4000
local INPUT_AIM      = 25
local WEAPON_UNARMED = GetHashKey("WEAPON_UNARMED")

local function toUnsigned(h)
    if h < 0 then return h + 4294967296 end
    return h
end

local oneHandedWeapons = {
    [toUnsigned(GetHashKey("WEAPON_PISTOL"))]              = true,
    [toUnsigned(GetHashKey("WEAPON_PISTOL_MK2"))]          = true,
    [toUnsigned(GetHashKey("WEAPON_COMBATPISTOL"))]        = true,
    [toUnsigned(GetHashKey("WEAPON_APPISTOL"))]            = true,
    [toUnsigned(GetHashKey("WEAPON_STUNGUN"))]             = true,
    [toUnsigned(GetHashKey("WEAPON_PISTOL50"))]            = true,
    [toUnsigned(GetHashKey("WEAPON_SNSPISTOL"))]           = true,
    [toUnsigned(GetHashKey("WEAPON_SNSPISTOL_MK2"))]       = true,
    [toUnsigned(GetHashKey("WEAPON_HEAVYPISTOL"))]         = true,
    [toUnsigned(GetHashKey("WEAPON_VINTAGEPISTOL"))]       = true,
    [toUnsigned(GetHashKey("WEAPON_FLAREGUN"))]            = true,
    [toUnsigned(GetHashKey("WEAPON_MARKSMANPISTOL"))]      = true,
    [toUnsigned(GetHashKey("WEAPON_REVOLVER"))]            = true,
    [toUnsigned(GetHashKey("WEAPON_REVOLVER_MK2"))]        = true,
    [toUnsigned(GetHashKey("WEAPON_DOUBLEACTION"))]        = true,
    [toUnsigned(GetHashKey("WEAPON_RAYPISTOL"))]           = true,
    [toUnsigned(GetHashKey("WEAPON_CERAMICPISTOL"))]       = true,
    [toUnsigned(GetHashKey("WEAPON_NAVYREVOLVER"))]        = true,
    [toUnsigned(GetHashKey("WEAPON_GADGETPISTOL"))]        = true,
    [toUnsigned(GetHashKey("WEAPON_STUNGUN_MP"))]          = true,
}

local wasAiming  = false
local holdUntil  = 0
local holdActive = false

CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        local now = GetGameTimer()

        if holdActive then
            if now < holdUntil then
                -- Arme en main, posture de visée injectée (arme visible, combat ready)
                SetControlNormal(0, INPUT_AIM, 1.0)
            else
                holdActive = false
                wasAiming  = false
            end
        else
            local rawWeapon   = GetSelectedPedWeapon(ped)
            local isOneHanded = oneHandedWeapons[toUnsigned(rawWeapon)] ~= nil
            local isAiming    = IsDisabledControlPressed(0, INPUT_AIM)

            if wasAiming and not isAiming and isOneHanded then
                holdUntil  = now + HOLD_DURATION
                holdActive = true
            end

            wasAiming = isAiming
        end
    end
end)
