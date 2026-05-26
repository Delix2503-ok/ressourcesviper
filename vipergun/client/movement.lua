local INPUT_DUCK  = 36   -- C  (accroupissement)
local INPUT_COVER = 44   -- Q  (mise à couvert)

CreateThread(function()
    while true do
        Wait(0)

        -- Désactive l'input sur tous les groupes de contrôle
        DisableControlAction(0, INPUT_DUCK,  true)
        DisableControlAction(1, INPUT_DUCK,  true)
        DisableControlAction(2, INPUT_DUCK,  true)
        DisableControlAction(0, INPUT_COVER, true)
        DisableControlAction(1, INPUT_COVER, true)
        DisableControlAction(2, INPUT_COVER, true)

        local ped = PlayerPedId()

        -- Si l'état duck est quand même appliqué → annule immédiatement
        if IsPedDucking(ped) then
            ClearPedTasksImmediately(ped)
        end

        -- Annule le mode furtif/sneak
        if GetPedStealthMovement(ped) then
            SetPedStealthMovement(ped, false, 0)
        end
    end
end)
