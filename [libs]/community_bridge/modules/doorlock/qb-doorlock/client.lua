---@diagnostic disable: duplicate-set-field
if GetResourceState('qb-doorlock') == 'missing' then return end

Doorlock = Doorlock or {}

---This will get the closest door to the ped
---@return string | nil
Doorlock.GetClosestDoor = function()
    local ped = PlayerPedId()
    local closestDoor = exports["qb-doorlock"]:GetClosestDoor()
    if Table.CheckPopulated(closestDoor) then return closestDoor end
    local allDoors = exports["qb-doorlock"]:GetDoorList()
    local pedCoords = GetEntityCoords(ped)
    local door = 0
    local doorDist = 1000.0
    for doorID, data in pairs(allDoors) do
        local dist = #(pedCoords - data.objCoords)
        if dist < doorDist then
            door = doorID
            doorDist = dist
        end
    end
    return door
end

---This will get the name of the in use resource.
---@return string
Doorlock.GetResourceName = function()
    return 'qb-doorlock'
end

return Doorlock