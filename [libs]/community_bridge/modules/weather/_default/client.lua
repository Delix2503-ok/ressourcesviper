---@diagnostic disable: duplicate-set-field
Weather = Weather or {}

---This will toggle the players weather/time sync
---@param toggle boolean
---@return nil
Weather.ToggleSync = function(toggle)

end

Weather.GetResourceName = function()
    return "default"
end

return Weather