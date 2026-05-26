-- ─── Véhicules blindés : protection invincibilité ────────────────────────────

local BLINDES = {
    [GetHashKey('m3g80')]           = true,
    [GetHashKey('DBMG63PxxBK')]     = true,
    [GetHashKey('DBsou_chargerpd')] = true,
}
local InBlinde = false

CreateThread(function()
    while true do
        Wait(0)
        local ped    = PlayerPedId()
        local veh    = GetVehiclePedIsIn(ped, false)
        local dedans = veh ~= 0 and BLINDES[GetEntityModel(veh)] == true

        if dedans then
            InBlinde = true
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)
            SetPlayerInvincible(PlayerId(), true)
            SetPedSuffersCriticalHits(ped, false)
            SetEntityInvincible(veh, true)
            SetEntityCanBeDamaged(veh, false)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 5000.0)
            SetVehiclePetrolTankHealth(veh, 1000.0)
        elseif InBlinde then
            InBlinde = false
            SetEntityInvincible(ped, false)
            SetEntityCanBeDamaged(ped, true)
            SetPlayerInvincible(PlayerId(), false)
            SetPedSuffersCriticalHits(ped, true)
        end
    end
end)
