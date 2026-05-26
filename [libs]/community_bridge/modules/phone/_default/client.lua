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

---This will send an email to the passed email address with the title and message.
---@param email string
---@param title string
---@param message string
---@return boolean
Phone.SendEmail = function(email, title, message)
    return false, print('^6 There is no phone bridged in community_bridge. ^0')
end

return Phone