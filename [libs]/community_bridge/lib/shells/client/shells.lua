local Target = Require('modules/target/_default/init.lua')
local ClientEntity = Require("lib/entities/client/client_entity.lua")


Shells = Shells or Require("lib/shells/client/config.lua")
Shells.All = Shells.All or {}
local insideShell = false
Shells.Events = {
    OnSpawn = {},
    OnRemove = {},
}

--Set Target lang or additionals
-- Shells.Target.Set('entrance', {
--     enter = {
--         label = 'yerp',
--         icon = 'fa-solid fa-door-open',
--     },
-- })

-- Shells.Target.Set('exit', {
--     leave = {
--         label = 'leerp',
--         icon = 'fa-solid fa-door-closed',
--     },
-- })

Shells.Event = {
    Add = function(eventName, callback)
        if Shells.Events[eventName] then
            table.insert(Shells.Events[eventName], callback)
        else
            print(string.format("Shells.Event.Add: Invalid event name '%s'", eventName))
        end
    end,
    Trigger = function(eventName, ...)
        if Shells.Events[eventName] then
            for _, callback in ipairs(Shells.Events[eventName]) do
                callback(...)
            end
        else
            print(string.format("Shells.Event.Trigger: Invalid event name '%s'", eventName))
        end
    end,
}

-- Shells.Event.Add('OnSpawn', function(pointData, entity)
--     print(string.format("Exterior point created with ID: %s, Type: %s, Entity: %s", pointData.id, pointData.type, entity))
-- end)
-- Shells.Event.Add('OnRemove', function(pointData)
--     print(string.format("Interior point created with ID: %s, Type: %s", pointData.id, pointData.type))
-- end)

function Shells.AddInteriorObject(shell, objectData)
     objectData.OnSpawn = function(pointData)
        Shells.Event.Trigger('OnSpawn', objectData, pointData.spawned)
        local targetOptions = Shells.Target.Get(objectData.type, shell.id, objectData.id)
        if targetOptions then
            local size = vector3(objectData.distance / 2, objectData.distance / 2, objectData.distance / 2) -- this might need to be size
            Target.AddBoxZone(objectData.id, objectData.coords, size, objectData.rotation.z, targetOptions, true)
        end
    end
    objectData.OnRemove = function(pointData)
        Shells.Event.Trigger('OnRemove', objectData, pointData.spawned)
        Target.RemoveZone(objectData.id)
    end
    return ClientEntity.Register(objectData)
end

function Shells.SetupInterior(shell)
    if not shell or not shell.interior then return end
    for _, v in pairs(shell.interior) do
        local pointData = Shells.AddInteriorObject(shell, v)
        shell.interiorSpawned[pointData.id] = pointData
    end
end

function Shells.SetupExterior(shell)
    if not shell or not shell.exterior then return end
    for k, v in pairs(shell.exterior) do
        local pointData = Shells.AddInteriorObject(shell, v)
        shell.exteriorSpawned[pointData.id] = pointData
    end
end

function Shells.ClearInterior(shell)
    if not shell or not shell.interiorSpawned then return end
    for _, v in pairs(shell.interiorSpawned) do
        ClientEntity.Unregister(v.id)
        Target.RemoveZone(v.id)
    end
    shell.interiorSpawned = {}
end

function Shells.ClearExterior(shell)
    if not shell or not shell.exteriorSpawned then return end
    for _, v in pairs(shell.exteriorSpawned) do
        ClientEntity.Unregister(v.id)
        Target.RemoveZone(v.id)
    end
    shell.exteriorSpawned = {}
end


function Shells.New(data)
    assert(data.id, "Shells.Create: 'id' is required")
    assert(data.model, "Shells.Create: 'shellModel' is required")
    assert(data.coords, "Shells.Create: 'coords' is required")
    local exterior = data.exterior or {}
    local exteriorSpawned = {}
    for k, v in pairs(exterior or {}) do
        v.OnSpawn = function(pointData)
            Shells.Event.Trigger('OnSpawn', v, pointData.spawned)
            local targetOptions = Shells.Target.Get(v.type, data.id, v.id)
            if targetOptions then
                local size = vector3(v.distance / 2, v.distance / 2, v.distance / 2)
                Target.AddBoxZone(v.id, v.coords, size, v.rotation.z, targetOptions, true)
            end
        end
        v.OnRemove = function(pointData)
            Shells.Event.Trigger('OnRemove', v, pointData.spawned)
            Target.RemoveZone(v.id)
        end
        local pointData = ClientEntity.Register(v)
        exteriorSpawned[pointData.id] = pointData
    end
    data.interiorSpawned = {}
    data.exteriorSpawned = exteriorSpawned
    Shells.All[data.id] = data
    return data
end

local returnPoint = nil
function Shells.Enter(id, entranceId)
    local shell = Shells.All[id]
    if not shell then
        print(string.format("Shells.Spawn: Shell with ID '%s' not found", id))
        return
    end
    local entrance = shell.interior[entranceId]
    if not entrance then
        print(string.format("Shells.Enter: Entrance with ID '%s' not found in shell '%s'", entranceId, id))
        return
    end
    local ped = PlayerPedId()
    returnPoint = GetEntityCoords(ped)
    DoScreenFadeOut(1000)
    Wait(1000)
    local entranceCoords = entrance.coords
    SetEntityCoords(ped, entranceCoords.x, entranceCoords.y, entranceCoords.z, false, false, false, true)
    FreezeEntityPosition(ped, true)
    local oldShell = insideShell and Shells.All[insideShell]
    if oldShell?.id ~= id then
        Shells.ClearExterior(oldShell)
        Shells.ClearInterior(oldShell)
    end
    Shells.ClearExterior(shell)
    Shells.SetupInterior(shell)
    ClientEntity.Register(shell)
    Wait(1000) -- Wait for the fade out to complete
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(1000)
    insideShell = shell.id
end

function Shells.Exit(id, exitId)
    local shell = Shells.All[id]
    if not shell then
        print(string.format("Shells.Exit: Shell with ID '%s' not found", id))
        return
    end
    local oldCoords = GetEntityCoords(PlayerPedId())
    local oldPoint = shell.exterior[exitId]
    if not oldPoint then
        print(string.format("Shells.Exit: Old point with ID '%s' not found in shell '%s'", exitId, id))
        return
    end
    DoScreenFadeOut(1000)
    Wait(1000)
    SetEntityCoords(PlayerPedId(), oldPoint.coords.x, oldPoint.coords.y, oldPoint.coords.z, false, false, false, true)
    FreezeEntityPosition(PlayerPedId(), true)
    Shells.ClearInterior(shell)
    ClientEntity.Unregister(shell.id)
    Shells.SetupExterior(shell)
    shell.interiorSpawned = {}
    FreezeEntityPosition(PlayerPedId(), false)
    DoScreenFadeIn(1000)
    insideShell = false
end

function Shells.Inside()
    return insideShell
end

RegisterNetEvent('community_bridge:client:CreateShell', function(shell)
    Shells.New(shell)
end)

RegisterNetEvent('community_bridge:client:EnterShell', function(shellId, entranceId, oldId)
    local shell = Shells.All[shellId]
    if not shell then
        print(string.format("Shells.EnterShell: Shell with ID '%s' not found", shellId))
        return
    end

    Shells.Enter(shellId, entranceId, oldId)
end)

RegisterNetEvent('community_bridge:client:ExitShell', function(shellId, oldId)
    local shell = Shells.All[shellId]
    print(string.format("Shells.ExitShell: Exiting shell '%s'", shellId))
    if not shell then
        print(string.format("Shells.ExitShell: Shell with ID '%s' not found", shellId))
        return
    end
    Shells.Exit(shellId, oldId)

end)

RegisterNetEvent('community_bridge:client:AddObjectsToShell', function (shellId, interiorObjects, exteriorObjects)
    local shell = Shells.All[shellId]
    print(string.format("Shells.AddObjectsToShell: Adding objects to shell '%s'", shellId),
    json.encode({interiorObjects = interiorObjects, exteriorObjects = exteriorObjects}, { indent = true }))
    if not shell then
        print(string.format("Shells.AddObjectsToShell: Shell with ID '%s' not found", shellId))
        return
    end
        local insideShell = Shells.Inside()
    if interiorObjects then
        for _, obj in pairs(interiorObjects) do
            if not shell.interior[obj.id] then
                shell.interior[obj.id] = obj
                if insideShell and insideShell == shellId then
                    local pointData = Shells.AddInteriorObject(shell, obj)
                    shell.interiorSpawned[pointData.id] = pointData
                end
            end
        end
    end
    if exteriorObjects then
        for _, obj in pairs(exteriorObjects) do
            if not shell.exterior[obj.id] then
                shell.exterior[obj.id] = obj
                if not insideShell then
                    local pointData = Shells.AddInteriorObject(shell, obj)
                    shell.exteriorSpawned[pointData.id] = pointData
                end
            end
        end
    end
end)

RegisterNetEvent('community_bridge:client:CreateShells', function(shells)
    print("Shells.CreateShells: Creating shells")
    for _, shell in pairs(shells) do
        Shells.New(shell)
    end
end)
-- TriggerClientEvent('community_bridge:client:CreateShells', -1, toClient)
-- TriggerClientEvent('community_bridge:client:ExitShell', src, oldId)


AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        DoScreenFadeIn(1000) -- Fade in when resource stops
        if not returnPoint then return end
        SetEntityCoords(PlayerPedId(), returnPoint.x, returnPoint.y, returnPoint.z, false, false, false, true)
    end
end)