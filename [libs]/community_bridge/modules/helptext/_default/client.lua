---@diagnostic disable: duplicate-set-field
HelpText = HelpText or {}

---This will show a help text message at the screen position passed
---@param message string
---@param _position string
---@return nil
HelpText.ShowHelpText = function(message, _position)
    return Framework.ShowHelpText(message, _position)
end

---This will get the name of the in use resource.
---@return string
HelpText.GetResourceName = function()
    return "default"
end

---This will hide the help text message on the screen
---@return nil
HelpText.HideHelpText = function()
    return Framework.HideHelpText()
end

RegisterNetEvent('community_bridge:Client:ShowHelpText', function(message, position)
    HelpText.ShowHelpText(message, position)
end)

RegisterNetEvent('community_bridge:Client:HideHelpText', function()
    HelpText.HideHelpText()
end)

return HelpText