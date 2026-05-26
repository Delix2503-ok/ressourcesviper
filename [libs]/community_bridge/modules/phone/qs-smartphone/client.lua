---@diagnostic disable: duplicate-set-field
local resourceName = "qs-smartphone"
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
    return true, TriggerServerEvent('qs-smartphone:server:sendNewMail', { sender = email, subject = title, message = message, button = {} })
end

RegisterNetEvent('community_bridge:Server:genericEmail', function(data)
    TriggerServerEvent('qs-smartphone:server:sendNewMail', { sender = data.email, subject = data.title, message = data.message, button = {} })
end)

return Phone