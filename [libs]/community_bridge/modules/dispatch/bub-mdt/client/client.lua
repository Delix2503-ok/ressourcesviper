---@diagnostic disable: duplicate-set-field
if GetResourceState('bub-mdt') == 'missing' then return end
Dispatch = Dispatch or {}

Dispatch.SendAlert = function(data)
    local ped = PlayerPedId()
    local alertData = {
        code = data.code or '10-80',
        offense = data.message,
        coords = data.coords or GetEntityCoords(ped),
        info = { label = data.code or '10-80', icon = data.icon or 'fas fa-question' },
        blip = data.blipData.sprite or 1,
        isEmergency = data.priority == 1 and true or false,
        blipCoords = data.coords or ped and GetEntityCoords(ped) or { x = 0, y = 0},
    }
    exports["bub-mdt"]:CustomAlert(alertData)
end

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'bub-mdt'
end

return Dispatch