---@diagnostic disable: duplicate-set-field
if GetResourceState('cd_easytime') == 'missing' then return end
Weather = Weather or {}

---This will toggle the players weather/time sync
---@param toggle boolean
---@return nil
Weather.ToggleSync = function(toggle)
    TriggerEvent('cd_easytime:PauseSync', toggle)
end

Weather.GetResourceName = function()
    return "cd_easytime"
end

return Weather