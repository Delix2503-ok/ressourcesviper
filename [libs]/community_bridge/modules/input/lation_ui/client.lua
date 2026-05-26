---@diagnostic disable: duplicate-set-field
local resourceName = "lation_ui"
local configValue = BridgeClientConfig.InputSystem
if (configValue == "auto" and GetResourceState(resourceName) == "missing") or (configValue ~= "auto" and configValue ~= resourceName) then return end

Input = {}

function Input.Open(title, data, isQBFormat, submitText)
    local inputs = data.inputs
    if isQBFormat then
        return exports.lation_ui:input({title = title, inputs = QBToOxInput(inputs)})
    else
        return exports.lation_ui:input({title = title, options = data})
    end
end

function Input.GetResourceName()
    return resourceName
end

return Input