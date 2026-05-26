---@diagnostic disable: duplicate-set-field
local resourceName = "wasabi_carlock"
if GetResourceState(resourceName) == 'missing' then return end

VehicleKey = VehicleKey or {}

---Gives the player (self) the keys of the specified vehicle.
---@param vehicle number The vehicle entity handle.
---@param plate? string The plate of the vehicle.
---@return nil
VehicleKey.GiveKeys = function(vehicle, plate)
    assert(vehicle, "vehicle is nil")
    assert(DoesEntityExist(vehicle), "vehicle does not exist")
    
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end
    
    exports.wasabi_carlock:GiveKey(plate)
end

---Removes the keys of the specified vehicle from the player (self).
---@param vehicle number The vehicle entity handle.
---@param plate? string The plate of the vehicle.
---@return nil
VehicleKey.RemoveKeys = function(vehicle, plate)
    assert(vehicle, "vehicle is nil")
    assert(DoesEntityExist(vehicle), "vehicle does not exist")
    
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end
    
    exports.wasabi_carlock:RemoveKey(plate)
end

VehicleKey.GetResourceName = function()
    return resourceName
end

return VehicleKey