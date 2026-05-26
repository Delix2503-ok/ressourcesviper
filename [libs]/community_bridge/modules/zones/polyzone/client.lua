---@diagnostic disable: duplicate-set-field

local resourceName = "PolyZone"
if GetResourceState(resourceName) == 'missing' or GetResourceState('ox_lib') ~= 'missing' then return end

Require("client.lua", resourceName)
Require("BoxZone.lua", resourceName)
Require("EntityZone.lua", resourceName)
Require("CircleZone.lua", resourceName)
Require("ComboZone.lua", resourceName)
Ids = Ids or Require('lib/utility/shared/ids.lua')
cZones = {
    All = {}
}
--- Create a zone of the specified type.
--- Supported types: "box", "sphere", "poly"
---@param type ZoneType
---@param data ZoneData
---@return string|nil id Returns the generated zone id on success, or nil on failure
function cZones.Create(type, data)
    assert(type, "Requires zone type ('box', 'sphere', or 'poly')")
    assert(data, "Requires data table")
    data.id = Ids.CreateUniqueId(cZones.All)
    data.invoking = GetInvokingResource() or "unknown"
    local zone = nil
    if type == "box" then
        assert(data.coords, "Requires .coords as vector3 in data")
        local width = data.size.x or data.length or 1.0
        local height = data.size.y or data.width or 1.0
        local z = data.size?.z or data.height or 1.0
        data.size = vec3(width, height, z)
        data.heading = data.heading or data.rotation
        data.rotation = data.heading
        zone = BoxZone:Create(data.coords, width, height, {
            name = data.id,
            debugPoly = data.debug,
            minZ = data.coords.z - 0.5,
            maxZ = data.coords.z + z - 0.5,
            heading = data.heading or data.rotation
        })
    elseif type == "sphere" then
        assert(data.coords, "Requires .coords as vector3 in data")
        data.radius = data.radius or data.size?.x or 1
        zone = CircleZone:Create(data.coords, data.radius, {
            name = data.id,
            debugPoly = data.debug,
        })
    elseif type == "poly" then
        assert(data.points, "Requires an array of vector2 in .points")
        assert(#data.points > 2, "Requires at least three points in .points")
        local zSize = data.minZ or data.size?.z or data.height or data.thickness or 2
        local firstPoint = data.points[1]
        local firstZ = firstPoint.z
        zone = PolyZone:Create(data.points, {
            name = data.id,
            debugPoly = data.debug,
            minZ = firstZ - 0.5,
            maxZ = firstZ and (firstZ + zSize - 0.5) or nil,
        })      
    end
    if not zone then return end
    data.zone = zone   
    zone:onPlayerInOut(function(isInside, _)
        if isInside then
            if data.onEnter or data.OnEnter then
                (data.onEnter or data.OnEnter)(data)
            end
        else
            if data.onExit or data.OnExit then
                (data.onExit or data.OnExit)(data)
            end
        end
    end)
         
    cZones.All[data.id] = data
    return data.id
end

--- Destroy a zone by id.
---@param id string
---@return boolean success True if destroyed, false otherwise
function cZones.Destroy(id)
    if not id then return false end
    local zone = cZones.All[id].zone
    if not zone then return false end
    zone:destroy()
    cZones.All[id] = nil
    return true
end

--- Destroy all zones created by a specific resource.
---@param resource string Name of the invoking resource
---@return boolean success True if operation completed (no guarantee zones existed)
function cZones.DestroyByResource(resource)
    if not resource then return false end
    for id, zone in pairs(cZones.All) do
        if zone.invoking == resource then
            zone.zone:destroy()
        end
    end
    return true
end

--- Retrieve zone data by id.
---@param id string
---@return ZoneData|nil
function cZones.Get(id)
    if not id then return nil end
    return cZones.All[id]
end

--- Event handler: clean up zones when a resource stops.
---@param resource string
RegisterNetEvent("onResourceStop", function(resource)
    cZones.DestroyByResource(resource)
end)
