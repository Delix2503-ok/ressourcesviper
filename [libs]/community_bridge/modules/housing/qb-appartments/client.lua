if GetResourceState('qb-appartments') == 'missing' then return end

Housing = Housing or {}

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "qb-appartments"
end

return Housing