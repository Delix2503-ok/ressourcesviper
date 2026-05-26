---@diagnostic disable: duplicate-set-field
if GetResourceState('Renewed-Weathersync') == 'missing' then return end
Weather = Weather or {}

---This will toggle the players weather/time sync
---@param toggle boolean
---@return nil
Weather.ToggleSync = function(toggle)
    LocalPlayer.state.syncWeather = toggle
end

Weather.GetResourceName = function()
    return "renewed-weathersync"
end

return Weather