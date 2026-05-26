---@diagnostic disable: duplicate-set-field
if GetResourceState('jpr-inventory') == 'missing' then return end
local jpr = exports['jpr-inventory']

Inventory = Inventory or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "jpr-inventory"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    local itemData = Framework.Shared.Items[item]
    if not itemData then return {} end
    return {
        name = itemData.name,
        label = itemData.label,
        stack = itemData.unique,
        weight = itemData.weight,
        description = itemData.description,
        image = Inventory.GetImagePath(itemData.name)
    }
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("jpr-inventory", string.format("html/images/%s.png", item))
    local imagePath = file and string.format("nui://jpr-inventory/html/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

RegisterNetEvent('community_bridge:client:jpr-inventory:openStash', function(id, data)
    if source ~= 65535 then return end
    TriggerEvent("inventory:client:SetCurrentStash", id)
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, { maxweight = data.weight, slots = data.slots })
end)

return Inventory