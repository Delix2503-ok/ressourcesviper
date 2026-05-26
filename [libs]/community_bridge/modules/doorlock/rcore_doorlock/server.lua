---@diagnostic disable: duplicate-set-field
if GetResourceState('rcore_doorlock') == 'missing' then return end

Doorlock = Doorlock or {}

---This will toggle the lock status of the door.
---@param doorID string
---@param toggle boolean
---@return boolean
Doorlock.ToggleDoorLock = function(doorID, toggle)
    local state = toggle
    if state then
        exports.rcore_doorlock:changeDoorState(doorID, 0)
    else
        exports.rcore_doorlock:changeDoorState(doorID, 1)
    end
    return true
end

---This will get the name of the in use resource.
---@return string
Doorlock.GetResourceName = function()
    return 'rcore_doorlock'
end

return Doorlock