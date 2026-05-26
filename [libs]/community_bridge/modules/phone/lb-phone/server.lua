---@diagnostic disable: duplicate-set-field
local resourceName = "lb-phone"
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
    return exports["lb-phone"]:GetEquippedPhoneNumber(src) or false
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
Phone.SendEmail = function(src, email, title, message)
    local numberNumber = exports["lb-phone"]:GetEquippedPhoneNumber(src)
    if not numberNumber then return false, print(" ^6 Could not Find Phone number ^0") end
    local playerEmail = exports["lb-phone"]:GetEmailAddress(numberNumber)
    if not playerEmail then return false, print(" ^6 Could not Find email ^0")  end
    local success, id = exports["lb-phone"]:SendMail({
        to = playerEmail,
        sender = email,
        subject = title,
        message = message,
    })
    return success or false
end

RegisterNetEvent('community_bridge:Server:genericEmail', function(data)
    local src = source
    return Phone.SendEmail(src, data.email, data.title, data.message)
end)

return Phone