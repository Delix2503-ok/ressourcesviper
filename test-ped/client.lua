local spawnedPed = nil

RegisterCommand('spawntest', function()
    if spawnedPed and DoesEntityExist(spawnedPed) then
        DeleteEntity(spawnedPed)
    end

    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    local heading = GetEntityHeading(player)

    local offset = GetOffsetFromEntityInWorldCoords(player, 0.0, 3.0, 0.0)

    RequestModel(GetHashKey("a_m_m_tourist_01"))
    while not HasModelLoaded(GetHashKey("a_m_m_tourist_01")) do Wait(10) end

    spawnedPed = CreatePed(4, GetHashKey("a_m_m_tourist_01"), offset.x, offset.y, offset.z, heading + 180.0, false, true)

    SetEntityInvincible(spawnedPed, false)
    SetPedCanRagdoll(spawnedPed, true)
    SetPedFleeAttributes(spawnedPed, 0, false)
    SetPedCombatAttributes(spawnedPed, 46, true)
    SetBlockingOfNonTemporaryEvents(spawnedPed, true)
    FreezeEntityPosition(spawnedPed, true)

    SetModelAsNoLongerNeeded(GetHashKey("a_m_m_tourist_01"))

    TriggerEvent('chat:addMessage', { args = { "^2[TEST]", "Ped spawné — HP: " .. GetEntityHealth(spawnedPed) } })
end, false)

RegisterCommand('hptest', function()
    if spawnedPed and DoesEntityExist(spawnedPed) then
        local hp = GetEntityHealth(spawnedPed)
        TriggerEvent('chat:addMessage', { args = { "^3[TEST]", "HP du ped : " .. hp .. " / 200" } })
    else
        TriggerEvent('chat:addMessage', { args = { "^1[TEST]", "Aucun ped spawné. Fais /spawntest d'abord." } })
    end
end, false)

RegisterCommand('deletetest', function()
    if spawnedPed and DoesEntityExist(spawnedPed) then
        DeleteEntity(spawnedPed)
        spawnedPed = nil
        TriggerEvent('chat:addMessage', { args = { "^1[TEST]", "Ped supprimé." } })
    end
end, false)
