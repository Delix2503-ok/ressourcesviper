---@diagnostic disable: duplicate-set-field

Doorlock = Doorlock or {}

---This will toggle the lock status of the door.
---@param doorID string
---@param toggle boolean
---@return boolean
Doorlock.ToggleDoorLock = function(doorID, toggle)
    return true
end

---This will get the name of the in use resource.
---@return string
Doorlock.GetResourceName = function()
    return 'default'
end

return Doorlock