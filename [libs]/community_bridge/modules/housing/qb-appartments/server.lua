if GetResourceState('qb-appartments') == 'missing' then return end

Housing = Housing or {}

RegisterNetEvent('qb-apartments:server:SetInsideMeta', function(house, insideId, bool, isVisiting)
    local src = source
    insideId = bool and house .. '-' .. insideId or nil
    TriggerEvent('community_bridge:Server:_OnPlayerInside', src, insideId)
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "qb-appartments"
end


return Housing