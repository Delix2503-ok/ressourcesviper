---@diagnostic disable: duplicate-set-field
if GetResourceState('ox_inventory') == 'missing' then return end
if GetResourceState('tgiann-inventory') ~= 'missing' then return end
if GetResourceState('qs-inventory') ~= 'missing' then return end
if GetResourceState('origen_inventory') ~= 'missing' then return end
--check for providers =/

local ox_inventory = exports.ox_inventory

Inventory = Inventory or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "ox_inventory"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    local itemData = ox_inventory:Items(item)
    if not itemData then return {} end
    return {
        name = itemData.name or "Missing Name",
        label = itemData.label or "Missing Label",
        stack = itemData.stack or "true",
        weight = itemData.weight or "0",
        description = itemData.description or "none",
        image = (itemData.client and itemData.client.image) or Inventory.GetImagePath(item),
    }
end

---@description This will return the entire items table from the inventory.
---@return table 
Inventory.Items = function()
    return ox_inventory:Items()
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return ox_inventory:Search('count', item, nil) >= (requiredCount or 1)
end

---@description This will return their count of the item in the players inventory, if not found will return 0.
---@param item string
---@return number
Inventory.GetItemCount = function(item)
    return ox_inventory:GetItemCount(item, nil, false)
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("ox_inventory", string.format("web/images/%s.png", item))
    local imagePath = file and string.format("nui://ox_inventory/web/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    return ox_inventory:GetPlayerItems()
end

return Inventory