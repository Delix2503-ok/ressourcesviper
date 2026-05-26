---@diagnostic disable: duplicate-set-field
if GetResourceState('ox_doorlock') == 'missing' then return end

Doorlock = Doorlock or {}

---This will get the closest door to the ped
---@return string | nil
Doorlock.GetClosestDoor = function()
    local doorData = exports.ox_doorlock:getClosestDoor()
    if not doorData then return end
    return tostring(doorData.id) or nil
end

---This will get the name of the in use resource.
---@return string
Doorlock.GetResourceName = function()
    return 'ox_doorlock'
end

return Doorlock