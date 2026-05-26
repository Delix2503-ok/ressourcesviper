---@diagnostic disable: duplicate-set-field
if GetResourceState('linden_outlawalert') == 'missing' then return end
Dispatch = Dispatch or {}

Dispatch.SendAlert = function(data)
    local ped = PlayerPedId()
    TriggerServerEvent('wf-alerts:svNotify', {
        dispatchData = {
            displayCode = data.code or '211',
            description = data.message or "Alert",
            isImportant = 0,
            recipientList = data.jobs or {'police'},
            length = data.time or '10000',
            infoM = data.icon or 'fas fa-question',
            info = data.message or "Alert"
        },
        caller = 'Anonymous',
        coords = data.coords or GetEntityCoords(ped)
    })
end

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'linden_outlawalert'
end

return Dispatch