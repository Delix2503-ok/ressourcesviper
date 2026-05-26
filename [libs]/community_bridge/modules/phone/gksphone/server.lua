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

---This will get the phone number of the passed source.
---@param src number
---@return number|boolean
Phone.GetPlayerPhone = function(src)
    return exports["gksphone"]:GetPhoneBySource(src) or false
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
Phone.SendEmail = function(src, email, title, message)
    local data = {}
    data.sender = email
    data.image = '/html/static/img/icons/mail.png'
    data.subject = title
    data.message = message
    exports["gksphone"]:SendNewMail(src, data)
    return true
end

return Phone