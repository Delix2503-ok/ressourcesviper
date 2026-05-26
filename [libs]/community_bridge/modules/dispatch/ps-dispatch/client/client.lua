---@diagnostic disable: duplicate-set-field
if GetResourceState('ps-dispatch') == 'missing' then return end
if GetResourceState('lb-tablet') == 'started' then return end
Dispatch = Dispatch or {}

Dispatch.SendAlert = function(data)
    local alertData = {
        message = data.message or "No message provided",
        code = data.code or '10-80',
        icon = data.icon or 'fas fa-question',
        priority = data.priority or 2,
        coords = data.coords or GetEntityCoords(PlayerPedId()),
        vehicle = data.vehicle,
        plate = data.plate,
        alertTime = data.time and (data.time / 1000) or nil,
        radius = data.blipData and data.blipData.radius or 0,
        sprite = data.blipData and data.blipData.sprite or 161,
        color = data.blipData and data.blipData.color or 84,
        scale = data.blipData and data.blipData.scale or 1.0,
        length = 2,
        sound = "Lose_1st",
        sound2 = "GTAO_FM_Events_Soundset",
        offset = false,
        flash = data.blipData and data.blipData.flash or false,
        jobs = data.jobs or data.job or "police"
    }
    exports["ps-dispatch"]:CustomAlert(alertData)
end

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'ps-dispatch'
end

return Dispatch