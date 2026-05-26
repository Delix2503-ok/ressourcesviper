local mySquadHash = nil

function SetRelationDamage(id)
    if id and (mySquadHash == nil or not DoesRelationshipGroupExist(mySquadHash)) then
        local retval, hash = AddRelationshipGroup(("squad_%s"):format(id))
        SetPedRelationshipGroupHash(PlayerPedId(), hash)
        SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), false,  hash)
        mySquadHash = hash
    else
        SetPedRelationshipGroupHash(PlayerPedId(), mySquadHash)
        SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), false,  mySquadHash)
    end
    return mySquadHash
end

function StartRelationLoop(id)
    Citizen.CreateThread(function()
        local hash = SetRelationDamage(id)
        while mySquadHash ~= nil do
            Citizen.Wait(2000)
            SetRelationDamage()
        end
        if DoesRelationshipGroupExist(mySquadHash) then
            SetPedRelationshipGroupHash(PlayerPedId(), 0x6F0783F5)
            SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), true,  mySquadHash)
            RemoveRelationshipGroup(mySquadHash)
            mySquadHash = nil
        end
    end)
end

RegisterNetEvent("gfx-squad:AddRelationShip")
AddEventHandler("gfx-squad:AddRelationShip", function(id)
    if Config.FriendlyFire then return end
    StartRelationLoop(id)
end)

RegisterNetEvent("gfx-squad:RemoveRelationShip")
AddEventHandler("gfx-squad:RemoveRelationShip", function()
    if Config.FriendlyFire then return end
    if DoesRelationshipGroupExist(mySquadHash) then
        SetPedRelationshipGroupHash(PlayerPedId(), 0x6F0783F5)
        SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), true,  mySquadHash)
        RemoveRelationshipGroup(mySquadHash)
        mySquadHash = nil
    end
    RemoveGamerTags()
end)

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then
        RemoveGamerTags()

        if DoesRelationshipGroupExist(mySquadHash) then
            SetPedRelationshipGroupHash(PlayerPedId(), 0x6F0783F5)
            SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), true,  mySquadHash)
            RemoveRelationshipGroup(mySquadHash)
            mySquadHash = nil
        end
    end
end)