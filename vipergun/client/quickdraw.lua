-- Supprime l'animation de dégainage (sortie du dos).
-- Dès que l'arme sélectionnée change, on force la mise en main immédiate
-- via SetCurrentPedWeapon(..., true) — le flag bForceInHand bypasse l'anim.

local UNARMED = GetHashKey('weapon_unarmed')
local lastHash = 0

CreateThread(function()
    while true do
        local ped  = PlayerPedId()
        local hash = GetSelectedPedWeapon(ped)

        if hash ~= lastHash then
            lastHash = hash
            if hash ~= UNARMED and hash ~= 0 then
                SetCurrentPedWeapon(ped, hash, true)
            end
            Wait(0)   -- reste frame par frame pendant le changement
        else
            Wait(50)  -- ralentit quand rien ne change (perf)
        end
    end
end)
