---@diagnostic disable: duplicate-set-field
if GetResourceState('doors_creator') == 'missing' then return end

Doorlock = Doorlock or {}

---This will get the closest door to the ped
---@return string | nil
Doorlock.GetClosestDoor = function()
    return exports["doors_creator"]:getClosestActiveDoor()
end

---This will get the name of the in use resource.
---@return string
Doorlock.GetResourceName = function()
    return 'doors_creator'
end

return Doorlock