if GetResourceState('origen_police') == 'missing' then return end
Dispatch = Dispatch or {}

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'origen_police'
end

return Dispatch