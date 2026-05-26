---@diagnostic disable: duplicate-set-field
if GetResourceState('doors_creator') == 'missing' then return end

Doorlock = Doorlock or {}


---This will toggle the lock status of the door.
---@param doorID string
---@param toggle boolean
---@return boolean
Doorlock.ToggleDoorLock = function(doorID, toggle)
    local state = toggle
    if state then
        exports["doors_creator"]:setDoorState(doorID, 1)
    else
        exports["doors_creator"]:setDoorState(doorID, 0)
    end
    return true
end

---This will get the name of the in use resource.
---@return string
Doorlock.GetResourceName = function()
    return 'doors_creator'
end

return Doorlock