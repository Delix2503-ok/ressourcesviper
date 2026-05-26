---@diagnostic disable: duplicate-set-field
local resourceName = "default"
ProgressBar = ProgressBar or {}

---This function opens a progress bar.
---@param options table
---@param cb any
---@param isQBInput boolean||optional
---@return boolean
function ProgressBar.Open(options, cb, isQBInput)
    return true, print("No supported progress bar system found.")
end

ProgressBar.GetResourceName = function()
    return resourceName
end

return ProgressBar