if GetResourceState('tk_dispatch') == 'missing' then return end
Dispatch = Dispatch or {}

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'tk_dispatch'
end

return Dispatch