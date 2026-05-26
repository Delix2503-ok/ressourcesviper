---@diagnostic disable: duplicate-set-field
if GetResourceState('ox_doorlock') == 'missing' then return end

Doorlock = Doorlock or {}

---This will toggle the lock status of the door.
---@param doorID string|number
---@param toggle boolean
---@return boolean
Doorlock.ToggleDoorLock = function(doorID, toggle)
    if type(doorID) == 'string' then
        doorID = tonumber(doorID)
    end
    local state = toggle
    if state then
        exports.ox_doorlock:setDoorState(doorID, 1)
    else
        exports.ox_doorlock:setDoorState(doorID, 0)
    end
    return true
end

---This will get the name of the in use resource.
---@return string
Doorlock.GetResourceName = function()
    return 'ox_doorlock'
end

return Doorlock