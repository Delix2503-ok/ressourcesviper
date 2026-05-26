---@diagnostic disable: duplicate-set-field
if GetResourceState('kartik-mdt') == 'missing' then return end
Dispatch = Dispatch or {}

Dispatch.SendAlert = function(data)
    local repackJobsBools = {}
    for k, v in pairs(data.jobs) do
        if v then
            repackJobsBools[k] = true
        end
    end
    local alertOptions = {
        title = data.message or "Alert",
        code = data.code or '10-80',
        description = data.message,
        type = "Alert",
        coords = data.coords,
        blip = {
            radius = 100.0,
            sprite = data.blipData.sprite or 161,
            color = data.blipData.color or 1,
            scale = data.blipData.scale or 0.8,
            length = 2
        },
        jobs = repackJobsBools,
    }
    exports['kartik-mdt']:CustomAlert(alertOptions)
end

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'kartik-mdt'
end

return Dispatch