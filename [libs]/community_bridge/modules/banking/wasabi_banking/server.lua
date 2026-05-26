---@diagnostic disable: duplicate-set-field
if GetResourceState('wasabi_banking') == 'missing' then return end
Banking = Banking or {}

local wasabi_banking = exports['wasabi_banking']

---This will get the name of the Managment system being being used.
---@return string
Banking.GetManagmentName = function()
    return 'wasabi_banking'
end

---This will get the name of the in use resource.
---@return string
Banking.GetResourceName = function()
    return 'wasabi_banking'
end

---This will return a number
---@param account string
---@return number
Banking.GetAccountMoney = function(account)
    local balance = wasabi_banking:GetAccountBalance(account, 'society')
    return balance or 0
end

---This will add money to the specified account of the passed amount
---@param account string
---@param amount number
---@param reason string
---@return boolean
Banking.AddAccountMoney = function(account, amount, reason)
    return wasabi_banking:AddMoney('society', account, amount)
end

---This will remove money from the specified account of the passed amount
---@param account string
---@param amount number
---@param reason string
---@return boolean
Banking.RemoveAccountMoney = function(account, amount, reason)
    return wasabi_banking:RemoveMoney('society', account, amount)
end

return Banking