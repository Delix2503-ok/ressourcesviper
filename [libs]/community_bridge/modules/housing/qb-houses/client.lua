if GetResourceState('qb-houses') == 'missing' then return end

Housing = Housing or {}

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "qb-houses"
end

return Housing