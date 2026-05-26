---@diagnostic disable: duplicate-set-field
local resourceName = "ox_lib"
local configValue = BridgeClientConfig.InputSystem
if (configValue == "auto" and GetResourceState(resourceName) == "missing") or (configValue ~= "auto" and configValue ~= resourceName) then return end

Input = {}

function Input.Open(title, data, isQBFormat, submitText)
    local inputs = data.inputs
    if isQBFormat then
        local convertedData = {}
        local returnData = lib.inputDialog(title, QBToOxInput(inputs))
        for i, v in pairs(inputs) do
            for k, j in pairs(returnData or {}) do
                if k == v.name then
                    convertedData[v.name] = j
                end
            end
        end
        return convertedData
    else
        return lib.inputDialog(title, data)
    end
end

function Input.GetResourceName()
    return resourceName
end

return Input