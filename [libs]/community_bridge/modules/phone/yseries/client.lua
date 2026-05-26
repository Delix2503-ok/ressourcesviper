---@diagnostic disable: duplicate-set-field
local resourceName = "yseries"
if GetResourceState(resourceName) == 'missing' then return end
Phone = Phone or {}

---This will get the name of the Phone system being being used.
---@return string
Phone.GetPhoneName = function()
    return resourceName
end

Phone.GetResourceName = function()
    return resourceName
end

---This will send an email to the passed email address with the title and message.
---@param email string
---@param title string
---@param message string
---@return boolean
Phone.SendEmail = function(email, title, message)
    TriggerServerEvent('community_bridge:Server:genericEmail', {email = email, title = title, message = message})
    return true
end

return Phone