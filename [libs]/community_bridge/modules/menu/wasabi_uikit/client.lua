local resourceName = "wasabi_uikit"
local configValue = BridgeClientConfig.MenuSystem
if (configValue == "auto" and GetResourceState(resourceName) ~= "started") or (configValue ~= "auto" and configValue ~= resourceName) then return end
Menus = Menus or {}

---Converts a QB menu to an Wasabi menu.
---@param id string The menu ID.
---@param menu table The QB menu data.
---@return table The Wasabi menu data.
local function QBToWasabiMenu(id, menu)
    local wasabiMenu = {
        id = id,
        title = "",
        canClose = true,
        options = {},
    }
    for i, v in pairs(menu) do
        if v.isMenuHeader then
            if wasabiMenu.title == "" then
                wasabiMenu.title = v.header
            end
        else
            local option = {
                title = v.header,
                description = v.txt,
                icon = v.icon,
                args = v.params.args,
                onSelect = v.action or function(selected, secondary, args)
                    local params = menu[id]?.options?[selected]?.params
                    if not params then return end
                    local event = params.event
                    local isServer = params.isServer
                    if not event then return end
                    if isServer then
                        return TriggerServerEvent(event, args)
                    end
                    return TriggerEvent(event, args)
                end

            }
            table.insert(wasabiMenu.options, option)
        end
    end
    return wasabiMenu
end

function OpenMenu(id, data, useQBinput)
    if useQBinput then
        data = QBToWasabiMenu(id, data)
    end
    exports.wasabi_uikit:RegisterContextMenu(data)
    exports.wasabi_uikit:OpenContextMenu(id)
    return data
end

GetMenuResourceName = function()
    return resourceName
end