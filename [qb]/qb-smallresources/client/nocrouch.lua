local INPUT_DUCK  = 36
local INPUT_COVER = 44

CreateThread(function()
    while true do
        Wait(0)

        DisableControlAction(0, INPUT_DUCK,  true)
        DisableControlAction(1, INPUT_DUCK,  true)
        DisableControlAction(2, INPUT_DUCK,  true)
        DisableControlAction(0, INPUT_COVER, true)
        DisableControlAction(1, INPUT_COVER, true)
        DisableControlAction(2, INPUT_COVER, true)

        local ped = PlayerPedId()

        if IsPedDucking(ped) then
            ClearPedTasksImmediately(ped)
        end

        if GetPedStealthMovement(ped) then
            SetPedStealthMovement(ped, false, 0)
        end
    end
end)
