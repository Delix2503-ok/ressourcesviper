local resourceName = "lation_ui"
local configValue = BridgeClientConfig.MenuSystem
if (configValue == "auto" and GetResourceState(resourceName) ~= "started") or (configValue ~= "auto" and configValue ~= resourceName) then return end
Menus = Menus or {}

local function runCheckForImageIcon(icon)
    local iconStr = tostring(icon):lower()
    if iconStr:match("^https?://") or iconStr:match("^nui://") or iconStr:match("^file://") then
        return true
    end

    local extensions = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg", ".webp", ".ico"}
    for _, ext in pairs(extensions) do
        if iconStr:match(ext .. "$") then
            return true
        end
    end

    return false
end

---Converts a QB menu to an Lation menu.
---@param id string The menu ID.
---@param menu table The QB menu data.
---@return table The Lation menu data.
local function QBToLationMenu(id, menu)
    local lationMenu = {
        id = id,
        title = "",
        canClose = true,
        options = {},
    }
    for i, v in pairs(menu) do
        if v.isMenuHeader then
            if lationMenu.title == "" then
                lationMenu.title = v.header
            end
        else
            local option = {
                title = v.header,
                description = v.txt,
                icon = v.icon,
                args = v.params.args,
                onSelect = function(selected, secondary, args)
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
            table.insert(lationMenu.options, option)
        end
    end
    return lationMenu
end

local function OxToLationMenu(data)
    local repack = {
        id = data.id,
        title = data.title or "",
        canClose = data.canClose ~= false,
        options = {}
    }
    -- Handle icon colors: remove for image icons, convert strings to hex for others
    for k, v in pairs(data.options) do
        if v.iconColor then
            if v.icon and runCheckForImageIcon(v.icon) then
                v.iconColor = nil
            end
        end
        table.insert(repack.options, v)
    end

    return repack
end

function OpenMenu(id, data, useQBinput)
    if useQBinput then
        data = QBToLationMenu(id, data)
    else
        data = OxToLationMenu(data)
    end
    exports.lation_ui:registerMenu(data)
    exports.lation_ui:showMenu(id)
    return data
end

function GetMenuResourceName()
    return resourceName
end