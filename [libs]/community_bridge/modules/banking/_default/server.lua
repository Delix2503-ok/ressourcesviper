---@diagnostic disable: duplicate-set-field
Banking = Banking or {}

---This will get the name of the Managment system being being used.
---@return string
Banking.GetManagmentName = function()
    return 'default'
end

---This will get the name of the in use resource.
---@return string
Banking.GetResourceName = function()
    return 'default'
end

---This will return a number
---@param account string
---@return number
Banking.GetAccountMoney = function(account)
    return 0, print("The resource you are using does not support this function.")
end

---This will add money to the specified account of the passed amount
---@param account string
---@param amount number
---@param reason string
---@return boolean
Banking.AddAccountMoney = function(account, amount, reason)
    return false, print("The resource you are using does not support this function.")
end

---This will remove money from the specified account of the passed amount
---@param account string
---@param amount number
---@param reason string
---@return boolean
Banking.RemoveAccountMoney = function(account, amount, reason)
    return false, print("The resource you are using does not support this function.")
end

return Banking