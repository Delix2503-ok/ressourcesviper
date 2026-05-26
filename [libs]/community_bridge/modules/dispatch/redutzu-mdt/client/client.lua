---@diagnostic disable: duplicate-set-field
if GetResourceState('redutzu-mdt') == 'missing' then return end
Dispatch = Dispatch or {}

Dispatch.SendAlert = function(data)
    local streetName, _ = Utility.GetStreetNameAtCoords(data.coords)
    local alertData = {
        code = data.code or '10-80',
        message = data.message or "Dispatch Alert",
        street = streetName,
        time = data.time or 10000,
        coords = data.coords,
    }
    TriggerServerEvent("community_bridge:server:dispatch:sendAlert", alertData)
end

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'redutzu-mdt'
end


return Dispatch