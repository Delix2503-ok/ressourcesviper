---@diagnostic disable: duplicate-set-field
local resourceName = "gksphone"
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
    return exports["gksphone"]:SendNewMail({ sender = email, image = '/html/static/img/icons/mail.png', subject = title, message = message })
end

return Phone