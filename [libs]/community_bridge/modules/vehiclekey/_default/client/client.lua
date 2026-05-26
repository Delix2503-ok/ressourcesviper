---@diagnostic disable: duplicate-set-field
VehicleKey = VehicleKey or {}

---Gives the player (self) the keys of the specified vehicle.
---@param vehicle number The vehicle entity handle.
---@param plate? string The plate of the vehicle.
---@return nil
VehicleKey.GiveKeys = function(vehicle, plate)
    print("There is no compatible vehicle key resource.")
end

---Removes the keys of the specified vehicle from the player (self).
---@param vehicle number The vehicle entity handle.
---@param plate? string The plate of the vehicle.
---@return nil
VehicleKey.RemoveKeys = function(vehicle, plate)
    print("There is no compatible vehicle key resource.")
end

VehicleKey.GetResourceName = function()
    return "default"
end

return VehicleKey