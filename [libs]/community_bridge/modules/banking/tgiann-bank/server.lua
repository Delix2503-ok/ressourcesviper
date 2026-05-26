---@diagnostic disable: duplicate-set-field
if GetResourceState('tgiann-bank') == 'missing' then return end
Banking = Banking or {}

local tgiann = exports["tgiann-bank"]

---This will get the name of the Managment system being being used.
---@return string
Banking.GetManagmentName = function()
    return 'tgiann-bank'
end

---This will get the name of the in use resource.
---@return string
Banking.GetResourceName = function()
    return 'tgiann-bank'
end

---This will return a number
---@param account string
---@return number
Banking.GetAccountMoney = function(account)
    return tgiann:GetJobAccountBalance(account)
end

---This will add money to the specified account of the passed amount
---@param account string
---@param amount number
---@param _ string
---@return boolean
Banking.AddAccountMoney = function(account, amount, _)
    return tgiann:AddJobMoney(account, amount)
end

---This will remove money from the specified account of the passed amount
---@param account string
---@param amount number
---@param _ string
---@return boolean
Banking.RemoveAccountMoney = function(account, amount, _)
    return tgiann:RemoveJobMoney(account, amount)
end

return Banking