if GetResourceState('linden_outlawalert') == 'missing' then return end
Dispatch = Dispatch or {}

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'linden_outlawalert'
end

return Dispatch