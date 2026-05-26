---@diagnostic disable: duplicate-set-field
Notify = Notify or {}

Notify.GetResourceName = function()
    return "default"
end



---DEPRICATED: PLEASE SWITCH TO Notify.SendNotification
---12/13/25
---@param message string
---@param _type string
---@param time number
---@return nil
Notify.SendNotify = function(message, _type, time)
    time = time or 3000
    return Framework.Notify(message, nil, time)
end

---This will send a notify message of the type and time passed
---@param title string
---@param message string
---@param _type string
---@param time number
---@props table optional
---@return nil
Notify.SendNotification = function(title, message, _type, time, props)
    time = time or 3000
    return Framework.Notify(message, nil, time)
end

RegisterNetEvent('community_bridge:Client:Notify', function(title, message, _type, time, props)
    Notify.SendNotification(title, message, _type, time, props)
end)

---------[[Depricated Stuff Below, please adjust to the HelpText module instead]]--------
---Depricated: This will hide the help text message on the screen
---@return nil
Notify.HideHelpText = function()
    return HelpText.HideHelpText()
end

---Depricated: This will show a help text message at the screen position passed
---@param message string
---@return nil
Notify.ShowHelpText = function(message, position)
    return HelpText.ShowHelpText(message, position)
end

return Notify