---@diagnostic disable: duplicate-set-field
if GetResourceState('qb-weathersync') == 'missing' then return end
Weather = Weather or {}

---This will toggle the players weather/time sync
---@param toggle boolean
---@return nil
Weather.ToggleSync = function(toggle)
    if toggle then
        TriggerEvent("qb-weathersync:client:EnableSync")
    else
        TriggerEvent("qb-weathersync:client:DisableSync")
    end
end

Weather.GetResourceName = function()
    return "qb-weathersync"
end

return Weather