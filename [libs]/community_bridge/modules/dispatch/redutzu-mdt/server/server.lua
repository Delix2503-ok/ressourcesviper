if GetResourceState('redutzu-mdt') == 'missing' then return end
Dispatch = Dispatch or {}

RegisterNetEvent("community_bridge:server:dispatch:sendAlert", function(data)
    TriggerEvent('redutzu-mdt:server:addDispatchToMDT', {
        code = data.code,
        title = data.message,
        street = data.street,
        duration = data.time,
        coords = data.coords
    })
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'redutzu-mdt'
end

return Dispatch