---@diagnostic disable: duplicate-set-field
if GetResourceState('okokBanking') == 'missing' then return end
Banking = Banking or {}

local okokBanking = exports['okokBanking']

---This will get the name of the Managment system being being used.
---@return string
Banking.GetManagmentName = function()
    return 'okokBanking'
end

---This will get the name of the in use resource.
---@return string
Banking.GetResourceName = function()
    return 'okokBanking'
end

---This will return a number
---@param account string
---@return number
Banking.GetAccountMoney = function(account)
    return okokBanking:GetAccount(account)
end

---This will add money to the specified account of the passed amount
---@param account string
---@param amount number
---@param _ string
---@return boolean
Banking.AddAccountMoney = function(account, amount, _)
    return okokBanking:AddMoney(account, amount)
end

---This will remove money from the specified account of the passed amount
---@param account string
---@param amount number
---@param _ string
---@return boolean
Banking.RemoveAccountMoney = function(account, amount, _)
    return okokBanking:RemoveMoney(account, amount)
end

return Banking