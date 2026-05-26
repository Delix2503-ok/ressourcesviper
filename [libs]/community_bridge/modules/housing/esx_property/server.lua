if GetResourceState('esx_property') == 'missing' then return end

Housing = Housing or {}

RegisterNetEvent('esx_property:enter', function(insideId)
    local src = source
    TriggerEvent('community_bridge:Server:_OnPlayerInside', src, insideId)
end)

RegisterNetEvent('esx_property:leave', function(insideId)
    local src = source
    TriggerEvent('community_bridge:Server:_OnPlayerInside', src, insideId)
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "esx_property"
end

return Housing