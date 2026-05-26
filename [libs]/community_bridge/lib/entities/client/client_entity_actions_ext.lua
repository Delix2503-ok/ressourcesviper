DefaultActions = {}
ClientEntityActions = ClientEntityActions or Require("lib/entities/client/client_entity_actions.lua")
LA = LA or Require("lib/utility/shared/la.lua")

--- Internal implementation for walking. Registered via RegisterAction.
function DefaultActions.WalkTo(entityData, coords, speed, timeout)
    local entity = entityData.spawned
    local entityId = entityData.id -- Store ID locally for safety in thread

    if not entity or not DoesEntityExist(entity) or not IsEntityAPed(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end

    -- Clear previous tasks just in case
    ClearPedTasks(entity)

    local thread = CreateThread(function()
        TaskGoToCoordAnyMeans(entity, coords.x, coords.y, coords.z, speed or 1.0, 0, false, 786603, timeout or -1)
        -- Wait until task is completed/interrupted or entity is despawned/changed
        local entityCoords = GetEntityCoords(entity)
        while ClientEntityActions.IsActionRunning[entityId] and entityData.spawned == entity and DoesEntityExist(entity) and #(entityCoords - coords) > 2.0 do
            entityCoords = GetEntityCoords(entity)
            Wait(0) -- Yield to avoid freezing the game
        end
        ClientEntityActions.ActionThreads[entityId] = nil -- Clear thread reference
        -- Only process next action if this thread was the one running the action
        if ClientEntityActions.IsActionRunning[entityId] then
            ClientEntityActions.IsActionRunning[entityId] = false
            ClientEntityActions.ProcessNextAction(entityId)
        end
    end)
    ClientEntityActions.ActionThreads[entityId] = thread
end
--- Internal implementation for playing an animation. Registered via RegisterAction.
--- @param entityData table
--- @param animDict string
--- @param animName string
--- @param blendIn number (Optional, default 8.0)
--- @param blendOut number (Optional, default -8.0)
--- @param duration number (Optional, default -1 for loop/until stopped)
--- @param flag number (Optional, default 0)
--- @param playbackRate number (Optional, default 0.0)
function DefaultActions.PlayAnim(entityData, animDict, animName, blendIn, blendOut, duration, flag, playbackRate)
    local entity = entityData.spawned
    local entityId = entityData.id

    if not entity or not DoesEntityExist(entity) or not IsEntityAPed(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId)
        return
    end

    blendIn = blendIn or 8.0
    blendOut = blendOut or -8.0
    duration = duration or -1
    flag = flag or 0
    playbackRate = playbackRate or 0.0

    local thread = CreateThread(function()
        if not HasAnimDictLoaded(animDict) then
            RequestAnimDict(animDict)
            local timeout = 100
            while not HasAnimDictLoaded(animDict) and timeout > 0 do
                Wait(10)
                timeout = timeout - 1
            end
        end

        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(entity, animDict, animName, blendIn, blendOut, duration, flag, playbackRate, false, false, false)

            -- Wait for completion or interruption
            local startTime = GetGameTimer()
            local animTime = duration > 0 and (startTime + duration) or -1

            while ClientEntityActions.IsActionRunning[entityId] and entityData.spawned == entity and DoesEntityExist(entity) do
                local isPlaying = IsEntityPlayingAnim(entity, animDict, animName, 3)

                -- Break conditions:
                -- 1. Action was stopped/skipped externally
                -- 2. Entity changed/despawned
                -- 3. Animation finished naturally (if not looping based on flags/duration)
                -- 4. Duration expired (if duration > 0)
                if not ClientEntityActions.IsActionRunning[entityId] or entityData.spawned ~= entity or not DoesEntityExist(entity) then break end
                if duration == -1 and not isPlaying and GetEntityAnimCurrentTime(entity, animDict, animName) > 0.1 then break end -- Check if non-looping anim finished
                if animTime ~= -1 and GetGameTimer() >= animTime then break end

                Wait(100) -- Check periodically
            end
            -- Don't remove dict here if other actions might use it immediately after
            -- Consider a separate cleanup mechanism if needed
        else
            print(string.format("[ClientEntityActions] Failed to load anim dict '%s' for entity %s", animDict, entityId))
        end

        -- Crucial: Mark as finished and process next
        if ClientEntityActions.IsActionRunning[entityId] then
            ClientEntityActions.IsActionRunning[entityId] = false
            ClientEntityActions.ProcessNextAction(entityId)
        end
    end)
    ClientEntityActions.ActionThreads[entityId] = thread
end
--- Internal implementation for lerping. Registered via RegisterAction.
function DefaultActions.LerpTo(entityData, targetCoords, duration, easingType, easingDirection)
    local entity = entityData.spawned
    local entityId = entityData.id -- Store ID locally

    if not entity or not DoesEntityExist(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end

    local startCoords = GetEntityCoords(entity)
    local startTime = GetGameTimer()
    easingType = easingType or "linear"
    easingDirection = easingDirection or "inout"

    local thread = CreateThread(function()
        while GetGameTimer() < startTime + duration do
            -- Check if action should continue
            if not ClientEntityActions.IsActionRunning[entityId] or not entityData.spawned or entityData.spawned ~= entity or not DoesEntityExist(entity) then
                break -- Stop if entity despawned, changed, or action was stopped/skipped
            end

            local elapsed = GetGameTimer() - startTime
            local t = LA.Clamp(elapsed / duration, 0.0, 1.0)
            local easedT = LA.EaseInOut(t, easingType) -- Default

            if easingDirection == "in" then
                easedT = LA.EaseIn(t, easingType)
            elseif easingDirection == "out" then
                easedT = LA.EaseOut(t, easingType)
            end

            local currentPos = LA.LerpVector(startCoords, targetCoords, easedT)
            SetEntityCoordsNoOffset(entity, currentPos.x, currentPos.y, currentPos.z, false, false, false)
            Wait(0)
        end

        -- Ensure final position if completed fully and action wasn't stopped/skipped
        if ClientEntityActions.IsActionRunning[entityId] and entityData.spawned == entity and DoesEntityExist(entity) then
             SetEntityCoordsNoOffset(entity, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
        end

        ClientEntityActions.ActionThreads[entityId] = nil -- Clear thread reference
        -- Only process next action if this thread was the one running the action
        if ClientEntityActions.IsActionRunning[entityId] then
            ClientEntityActions.IsActionRunning[entityId] = false
            ClientEntityActions.ProcessNextAction(entityId)
        end
    end)
    ClientEntityActions.ActionThreads[entityId] = thread
end
--- Internal implementation for attaching a prop. Registered via RegisterAction.
--- This action completes immediately after attaching. Use DetachProp to remove.
--- @param entityData table
--- @param propModel string|number
--- @param boneIndex number (Optional, default -1 for root)
--- @param offsetPos vector3 (Optional, default vector3(0,0,0))
--- @param offsetRot vector3 (Optional, default vector3(0,0,0))
--- @param useSoftPinning boolean (Optional, default false)
--- @param collision boolean (Optional, default false)
--- @param isPed boolean (Optional, default false) - Seems unused in native?
--- @param vertexIndex number (Optional, default 2) - Seems unused in native?
--- @param fixedRot boolean (Optional, default true)
function DefaultActions.AttachProp(entityData, propModel, boneName, offsetPos, offsetRot, useSoftPinning, collision, isPed, vertexIndex, fixedRot)
    local entity = entityData.spawned
    local entityId = entityData.id

    if not entity or not DoesEntityExist(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId)
        return
    end

    local modelHash = Utility.GetEntityHashFromModel(propModel)
    if not Utility.LoadModel(modelHash) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId)
        return
    end

    local boneIndex = GetEntityBoneIndexByName(entity, boneName)
    local coords = GetEntityCoords(entity)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    boneIndex = boneIndex or GetPedBoneIndex(entity, 60309) -- SKEL_R_Hand if not specified and is ped
    if boneIndex == -1 then boneIndex = 0 end -- Default to root if bone not found or not ped
    offsetPos = offsetPos or vector3(0.0, 0.0, 0.0)
    offsetRot = offsetRot or vector3(0.0, 0.0, 0.0)
    AttachEntityToEntity(prop, entity, boneIndex, offsetPos.x, offsetPos.y, offsetPos.z, offsetRot.x, offsetRot.y, offsetRot.z, false, useSoftPinning or false, collision or false, isPed or false, vertexIndex or 2, fixedRot == nil and true or fixedRot)
    entityData.props = entityData.props or {} -- Ensure props table exists
    table.insert(entityData.props, prop) -- Store the prop handle in the entity data
    -- Store the attached prop handle for later removal
    if not entityData.attachedProps then entityData.attachedProps = {} end
    entityData.attachedProps[propModel] = prop -- Store by model name/hash for easy lookup

    -- This action finishes immediately
    ClientEntityActions.IsActionRunning[entityId] = false
    ClientEntityActions.ProcessNextAction(entityId)
end
--- Internal implementation for detaching a prop. Registered via RegisterAction.
--- @param entityData table
--- @param propModel string|number The model name/hash of the prop to detach.
function DefaultActions.DetachProp(entityData, propModel)
    local entityId = entityData.id

    if entityData.attachedProps and propModel then
        local propHandle = entityData.attachedProps[propModel]
        if propHandle and DoesEntityExist(propHandle) then
            DetachEntity(propHandle, true, true) -- Detach
            DeleteEntity(propHandle) -- Delete
            entityData.attachedProps[propModel] = nil -- Remove from tracking
            -- print(string.format("[ClientEntityActions] Detached prop '%s' from entity %s", propModel, entityId))
        else
            -- print(string.format("[ClientEntityActions] Prop '%s' not found attached to entity %s for detachment.", propModel, entityId))
        end
    else
       -- print(string.format("[ClientEntityActions] No props tracked or propModel not specified for detachment on entity %s.", entityId))
    end

    -- This action finishes immediately
    -- ClientEntityActions.IsActionRunning[entityId] = false
    -- ClientEntityActions.ProcessNextAction(entityId)
end

function DefaultActions.GetInCar(entityData, vehicleData, seatIndex, timeout)
    local entity = entityData.spawned
    local vehicle = vehicleData.spawned
    local entityId = entityData.id

    if not entity or not DoesEntityExist(entity) or not IsEntityAPed(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end

    if not vehicle or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end

    -- Clear previous tasks just in case
    ClearPedTasks(entity)

    local thread = CreateThread(function()
        TaskEnterVehicle(entity, vehicle, timeout or 1000, seatIndex or -1, 1.0, 1, 0) -- Enter vehicle
        Wait(timeout or 1000) -- Wait for a bit to ensure the task is completed

        ClientEntityActions.ActionThreads[entityId] = nil -- Clear thread reference
        -- Only process next action if this thread was the one running the action
        if ClientEntityActions.IsActionRunning[entityId] then
            ClientEntityActions.IsActionRunning[entityId] = false
            ClientEntityActions.ProcessNextAction(entityId)
        end
    end)
    ClientEntityActions.ActionThreads[entityId] = thread
end

function DefaultActions.Freeze(entityData, freeze)
    local entity = entityData.spawned
    local entityId = entityData.id

    if not entity or not DoesEntityExist(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end

    FreezeEntityPosition(entity, freeze or true)

    -- This action finishes immediately
    ClientEntityActions.IsActionRunning[entityId] = false
    ClientEntityActions.ProcessNextAction(entityId)
end

function DefaultActions.PlaceOnGround(entityData)
    local entity = entityData.spawned
    local entityId = entityData.id

    if not entity or not DoesEntityExist(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end
    PlaceObjectOnGroundProperly(entity)

    -- This action finishes immediately
    -- ClientEntityActions.IsActionRunning[entityId] = false
    -- ClientEntityActions.ProcessNextAction(entityId)
end

function DefaultActions.BobUpAndDown(entityData, speed, height)
    local entity = entityData.spawned
    local entityId = entityData.id
    if not entity or not DoesEntityExist(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end
    CreateThread(function()
        local coords = GetEntityCoords(entity)
        local originalZ = coords.z
        while DoesEntityExist(entity) do
            -- Calculate the new Z coordinate
            local newZ = originalZ + math.sin(GetGameTimer() * (speed / 1000)) * height
            -- Set the new coordinates
            SetEntityCoords(entity, coords.x, coords.y, newZ)
            -- Wait for 10 milliseconds
            Wait(10)
        end
    end)
    -- ClientEntityActions.IsActionRunning[entityId] = false
    -- ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
end

function DefaultActions.Circle(entityData, radius, speed)
    local entity = entityData.spawned
    local entityId = entityData.id

    if not entity or not DoesEntityExist(entity) then
        ClientEntityActions.IsActionRunning[entityId] = false
        ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
        return
    end

    local coords = GetEntityCoords(entity)
    local angle = 0.0
    CreateThread(function()
        while DoesEntityExist(entity) do
            FreezeEntityPosition(entity, false)
            local pos = LA.Circle(angle, radius, coords)
            SetEntityCoords(entity, pos.x, pos.y, pos.z, false, false, false, false)
            angle = angle + speed * GetFrameTime()
            FreezeEntityPosition(entity, true)
            Wait(0)
        end
    end)
    -- ClientEntityActions.IsActionRunning[entityId] = false
    -- ClientEntityActions.ProcessNextAction(entityId) -- Try next action if this one failed immediately
end

function DefaultActions.Collisions(entityData, enable, keepPhysics)
    local entity = entityData.spawned
    SetEntityCollision(entity, enable, keepPhysics)
end

for name, func in pairs(DefaultActions) do
    ClientEntityActions.RegisterAction(name, func)
end


return ClientEntityActions
