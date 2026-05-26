---@diagnostic disable: duplicate-set-field
HelpText = HelpText or {}
local resourceName = "jg-textui"
local configValue = BridgeSharedConfig.HelpText
if (configValue == "auto" and GetResourceState(resourceName) ~= "started") or (configValue ~= "auto" and configValue ~= resourceName) then return end

---This will show a help text message at the screen position passed
---@param message string
---@param _position string
---@return nil
HelpText.ShowHelpText = function(message, _position)
    return exports['jg-textui']:DrawText(message)
end

---This will get the name of the in use resource.
---@return string
HelpText.GetResourceName = function()
    return resourceName
end

---This will hide the help text message on the screen
---@return nil
HelpText.HideHelpText = function()
    return exports['jg-textui']:HideText()
end

return HelpText