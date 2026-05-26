---@diagnostic disable: duplicate-set-field
local resourceName = "qb-phone"
if GetResourceState(resourceName) == 'missing' then return end
if GetResourceState("lb-phone") ~= 'missing' then return end
if GetResourceState("gksphone") ~= 'missing' then return end
if GetResourceState("okokPhone") ~= 'missing' then return end
if GetResourceState("qs-smartphone") ~= 'missing' then return end
if GetResourceState("yseries") ~= 'missing' then return end
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
end

return Phone