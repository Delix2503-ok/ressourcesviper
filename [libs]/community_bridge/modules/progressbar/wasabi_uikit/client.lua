---@diagnostic disable: duplicate-set-field
local resourceName = "wasabi_uikit"
local configValue = BridgeClientConfig.ProgressBarSystem
if (configValue == "auto" and GetResourceState(resourceName) ~= "started") or (configValue ~= "auto" and configValue ~= resourceName) then return end

ProgressBar = ProgressBar or {}

---This function converts a QB progress bar options table to an Ox progress bar options table.
---@param options table
---@return table
local function convertFromQB(options)
    if not options then return options end
    local prop1 = options.prop or {}
    local prop2 = options.propTwo or {}
    local props = {
        {
            model = prop1.model,
            bone = prop1.bone,
            pos = prop1.coords,
            rot = prop1.rotation,
        },
        {
            model = prop2.model,
            bone = prop2.bone,
            pos = prop2.coords,
            rot = prop2.rotation,
        }
    }
    return {
        duration = options.duration,
        label = options.label,
        position = 'bottom',
        useWhileDead = options.useWhileDead,
        canCancel = options.canCancel,
        disable = {
            move = options.controlDisables?.disableMovement,
            car = options.controlDisables?.disableCarMovement,
            combat = options.controlDisables?.disableCombat,
            mouse = options.controlDisables?.disableMouse
        },
        anim = {
            dict = options.animation?.animDict,
            clip = options.animation?.anim,
            flag = options.animation?.flags or 49,
        },
        prop = props,
    }
end

---This function opens a progress bar.
---@param options table
---@param cb any
---@param isQBInput boolean||optional
---@return boolean
function ProgressBar.Open(options, cb, isQBInput)
    if isQBInput then
        options = convertFromQB(options)
    end

    local style = options.style or 'bar'
    local success = style == 'circle' and exports.wasabi_uikit:ProgressBar(options, 'circle') or exports.wasabi_uikit:ProgressBar(options, 'bar')

    if cb then cb(success) end
    return success
end

ProgressBar.GetResourceName = function()
    return resourceName
end

return ProgressBar