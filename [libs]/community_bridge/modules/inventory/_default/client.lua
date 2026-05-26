---@diagnostic disable: duplicate-set-field
Inventory = Inventory or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "default"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return Framework.GetItemInfo(item)
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return Framework.HasItem(item, requiredCount)
end

---@description This will return their count of the item in the players inventory, if not found will return 0.
---@param item string
---@return number
Inventory.GetItemCount = function(item)
    return Framework.GetItemCount(item)
end

---@description This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    return Framework:GetPlayerInventory()
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    print("No get image path for this inventory, using default.")
    return "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will remove the file extension from the item name if present.
---@param item string
---@return string
Inventory.StripPNG = function(item)
    if string.find(item, ".png") then
        item = string.gsub(item, ".png", "")
    end
    return item
end

---@description This will remove the file extension from the item name if present.
---@param item string
---@return string
Inventory.StripWebp = function(item)
    if string.find(item, ".webp") then
        item = string.gsub(item, ".webp", "")
    end
    return item
end

---@description This will return the entire items table from the inventory.
---@return table
Inventory.Items = function()
    if not Framework.Shared or not Framework.Shared.Items then
        local itemList = Framework.ItemList() or { Items = {} }
        return itemList.Items
    end
    return Framework.Shared.Items
end

return Inventory