---@diagnostic disable: duplicate-set-field
if GetResourceState('tgg-banking') == 'missing' then return end
Banking = Banking or {}

local tgg = exports['tgg-banking']

---This will get the name of the Managment system being being used.
---@return string
Banking.GetManagmentName = function()
    return 'tgg-banking'
end

---This will get the name of the in use resource.
---@return string
Banking.GetResourceName = function()
    return 'tgg-banking'
end

---This will return a number
---@param account string
---@return number
Banking.GetAccountMoney = function(account)
    return tgg:GetSocietyAccountMoney(account) or 0
end

---This will add money to the specified account of the passed amount
---@param account string
---@param amount number
---@param _ string
---@return boolean
Banking.AddAccountMoney = function(account, amount, _)
    return tgg:AddSocietyMoney(account, amount)
end

---This will remove money from the specified account of the passed amount
---@param account string
---@param amount number
---@param _ string
---@return boolean
Banking.RemoveAccountMoney = function(account, amount, _)
    return tgg:RemoveSocietyMoney(account, amount)
end

return Banking