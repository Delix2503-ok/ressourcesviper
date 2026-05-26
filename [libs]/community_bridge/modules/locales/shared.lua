local ConvarLang = GetConvar("lang", "none")
local OXLang = GetConvar("ox:locale", "none")
local QBXLang = GetConvar("qb_locale", "none")
local txLang = GetConvar("txAdmin-locale", "none")
local esxLang = GetConvar("esx:locale", "none")

BridgeSharedConfig = Require("settings/sharedConfig.lua")

Lang = ConvarLang ~= "none" and
ConvarLang or BridgeSharedConfig.Lang ~= "auto" and BridgeSharedConfig.Lang or
OXLang ~= "none" and OXLang or
QBXLang ~= "none" and QBXLang or
txLang ~= "none" and txLang or
esxLang ~= "none" and esxLang or
"en"

Language = {}

function Language.Locale(str, ...)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    assert(resource, "Resource name not found")

    local locales = LoadResourceFile(resource, "locales/" .. Lang .. ".json")
    locales = locales and json.decode(locales) or {}

    -- Handle nested tables via dot notation
    local current = locales
    for part in str:gmatch("([^%.]+)") do
        if type(current) ~= "table" then
            warn(("Invalid nested locale path: %s for resource: %s"):format(str, resource))
            return str
        end
        current = current[part]
        if not current then
            warn(("Locale not found for key: %s in language: %s for resource: %s"):format(str, Lang, resource))
            return str
        end
    end

    -- Handle variable replacement
    local args = {...}

    if type(current) == "string" and #args > 0 then
        current = string.format(current, ...)
    end

    return current
end

return Language