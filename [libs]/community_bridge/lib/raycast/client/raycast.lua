Raycast = {}

--Rework of oxs Raycast system
function Raycast.GetForwardVector(rotation)
    local camRot = rotation or GetFinalRenderedCamRot(2)

    -- Convert each component to radians
    local rx = math.rad(camRot.x)
    local ry = math.rad(camRot.y)
    local rz = math.rad(camRot.z)

    -- Calculate sin and cos for each axis
    local sx = math.sin(rx)
    local cx = math.cos(rx)
    local sy = math.sin(ry)
    local cy = math.cos(ry)
    local sz = math.sin(rz)
    local cz = math.cos(rz)

    -- Create forward vector components
    local x = -sz * math.abs(cx)
    local y = cz * math.abs(cx)
    local z = sx

    return vector3(x, y, z)
end

function Raycast.ToCoords(startCoords, endCoords, flag, ignore)
    local probe = StartShapeTestLosProbe(startCoords.x, startCoords.y, startCoords.z, endCoords.x, endCoords.y, endCoords.z, flag or 511, PlayerPedId(), ignore or 4)
    local retval, entity, finalCoords, normals, material  = 1, nil, nil, nil, nil

    local timeout = 500
    while retval == 1 and timeout > 0 do
        retval, entity, finalCoords, normals, material = GetShapeTestResultIncludingMaterial(probe)
        timeout = timeout - 1
        Wait(0)
    end
    return retval, entity, finalCoords, normals, material
end

function Raycast.FromCamera(flags, ignore, distance)
    local coords = GetFinalRenderedCamCoord()
    distance = distance or 10
    local destination = coords + Raycast.GetForwardVector() * distance
    local retval, entity, finalCoords, normals, material = Raycast.ToCoords(coords, destination, flags, ignore)
    if retval ~= 1 then
        local newDest = destination - vector3(0, 0, 10)
        return Raycast.ToCoords(destination, newDest, flags, ignore)
    end
    return retval, entity, finalCoords, normals, material
end

return Raycast