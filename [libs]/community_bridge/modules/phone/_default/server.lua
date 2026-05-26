---@diagnostic disable: duplicate-set-field
Phone = Phone or {}

---This will get the name of the Phone system being being used.
---@return string
Phone.GetPhoneName = function()
    return 'default'
end

Phone.GetResourceName = function()
    return "default"
end

---This will get the phone number of the passed source.
---@param src number
---@return number|boolean
Phone.GetPlayerPhone = function(src)
    return false, print('^6 There is no phone bridged in community_bridge. ^0')
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
Phone.SendEmail = function(src, email, title, message)
    return false, print('^6 There is no phone bridged in community_bridge. ^0')
end

return Phone