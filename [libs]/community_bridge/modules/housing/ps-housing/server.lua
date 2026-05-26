if GetResourceState('ps-housing') == 'missing' then return end

Housing = Housing or {}

RegisterNetEvent('ps-housing:server:enterProperty', function(insideId)
    local src = source
    TriggerEvent('community_bridge:Server:_OnPlayerInside', src, insideId)
end)

RegisterNetEvent('ps-housing:server:leaveProperty', function(insideId)
    local src = source
    TriggerEvent('community_bridge:Server:_OnPlayerInside', src, insideId)
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "ps-housing"
end

return Housing