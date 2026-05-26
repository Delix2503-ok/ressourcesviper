---@diagnostic disable: duplicate-set-field
if GetResourceState('tgiann-inventory') == 'missing' then return end

local tgiann = exports["tgiann-inventory"]

Inventory = Inventory or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "tgiann-inventory"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    local itemData = tgiann:GetItemList()
    if not itemData[item] then return {} end
    itemData = itemData[item]
    return {
        name = itemData.name or "Missing Name",
        label = itemData.label or "Missing Label",
        stack = itemData.unique or "false",
        weight = itemData.weight or "0",
        description = itemData.description or "none",
        image = Inventory.GetImagePath(item),
    }
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return tgiann:HasItem(item, requiredCount)
end

---@description This will return their count of the item in the players inventory, if not found will return 0.
---@param item string
---@return number
Inventory.GetItemCount = function(item)
    local searchItem = tgiann:GetItemCount(item, nil, false)
    return searchItem or 0
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    local pngItem = Inventory.StripPNG(item)
    local webpItem = Inventory.StripWebp(item)
    local pngPath = LoadResourceFile("inventory_images", string.format("/images/%s.png", pngItem))
    local webpPath = LoadResourceFile("inventory_images", string.format("/images/%s.webp", webpItem))
    local imagePath = pngPath and string.format("nui://inventory_images/images/%s.png", pngItem) or webpPath and string.format("nui://inventory_images/images/%s.webp", webpItem)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    local items = {}
    local inventory = tgiann:GetPlayerItems()
    for _, v in pairs(inventory) do
        table.insert(items, {
            name = v.name,
            label = v.label,
            count = v.amount,
            slot = v.slot,
            metadata = v.info,
            stack = v.unique,
            close = v.useable,
            weight = v.weight
        })
    end
    return items
end

return Inventory