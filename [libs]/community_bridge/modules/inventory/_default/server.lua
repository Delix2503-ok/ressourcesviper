---@diagnostic disable: duplicate-set-field
Inventory = Inventory or {}
Inventory.Stashes = Inventory.Stashes or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "default"
end

---@description This will add an item, and return true or false based on success
---@param src number
---@param item string
---@param count number
---@param slot number
---@param metadata table
---@return boolean
Inventory.AddItem = function(src, item, count, slot, metadata)
    local success = Framework.AddItem(src, item, count, slot, metadata)
    if not success then return false end
    TriggerClientEvent("community_bridge:client:inventory:updateInventory", src, {action = "add", item = item, count = count, slot = slot, metadata = metadata})
    return success
end

---@description This will remove an item, and return true or false based on success
---@param src number
---@param item string
---@param count number
---@param slot number
---@param metadata table
---@return boolean
Inventory.RemoveItem = function(src, item, count, slot, metadata)
    item = type(item) == "table" and item.name or item
    local success = Framework.RemoveItem(src, item, count, slot, metadata)
    if not success then return false end
    TriggerClientEvent("community_bridge:client:inventory:updateInventory", src, {action = "remove", item = item, count = count, slot = slot, metadata = metadata})
    return success
end

---@description This will add items to a trunk, and return true or false based on success
---@param identifier string
---@param items table
---@return boolean
Inventory.AddTrunkItems = function(identifier, items)
    return false, print("This Inventory Has Not Been Bridged For A Trunk Feature.")
end

---@description This will clear the specified inventory, will always return true unless a value isnt passed correctly.
---@param id string
---@return boolean
Inventory.ClearStash = function(id, _type)
    if Inventory.Stashes[id] then Inventory.Stashes[id] = nil end
    return false, print("This Inventory Has Not Been Bridged For A ClearStash Feature.")
end

---@description This will return a table with the item info, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return Framework.GetItemInfo(item)
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

---@description This will return the count of the item in the players inventory, if not found will return 0.
---@param src number
---@param item string
---@param metadata table (optional)
---@return number
Inventory.GetItemCount = function(src, item, metadata)
    return Framework.GetItemCount(src, item, metadata)
end

---@description This wil return the players inventory.
---@param src number
---@return table
Inventory.GetPlayerInventory = function(src)
    return Framework.GetPlayerInventory(src)
end

---@description Returns the specified slot data as a table.
---@param src number
---@param slot number
---@return table {weight, name, metadata, slot, label, count}
Inventory.GetItemBySlot = function(src, slot)
    return Framework.GetItemBySlot(src, slot)
end

---@description This will set the metadata of an item in the inventory.
---@param src number
---@param item string
---@param slot number
---@param metadata table
---@return nil
Inventory.SetMetadata = function(src, item, slot, metadata)
    return Framework.SetMetadata(src, item, slot, metadata)
end

---@description This will open the specified stash for the src passed.
---@param src number
---@param _type string "stash", "trunk", "glovebox"
---@param id string
---@return nil
Inventory.OpenStash = function(src, _type, id)
    return false, print("This Inventory Has Not Been Bridged For A Stash Feature.")
end

---@description This will register a stash
---@param id number|string
---@param label string
---@param slots number
---@param weight number
---@param owner string (optional)
---@param groups table (optional)
---@param coords table (optional)
---@return boolean
---@return string|number
Inventory.RegisterStash = function(id, label, slots, weight, owner, groups, coords)
    if Inventory.Stashes[id] then return true, id end
    Inventory.Stashes[id] = {id = id, label = label, slots = slots, weight = weight, owner = owner, groups = groups, coords = coords}
    return true, id
end

---@description This will return a boolean if the player has the item.
---@param src number
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(src, item, requiredCount)
    return Framework.HasItem(src, item, requiredCount)
end

---@description This is to get if there is available space in the inventory, will return boolean.
---@param src number
---@param item string
---@param count number
---@return boolean
Inventory.CanCarryItem = function(src, item, count)
    return true, print("This Inventory Has Not Been Bridged For A CanCarryItem Feature.")
end

---@description This will update the plate to the vehicle inside the inventory. (It will also update with jg-mechanic if using it)
---@param oldplate string
---@param newplate string
---@return boolean
Inventory.UpdatePlate = function(oldplate, newplate)
    return false, print("This Inventory Has Not Been Bridged For A UpdatePlate Feature.")
end

---@description This will open the specified shop for the src passed.
---@param src number
---@param shopTitle string
Inventory.OpenShop = function(src, shopTitle)
    return Bridge.Shops.OpenShop(src, shopTitle)
end

---@description This will register a shop, if it already exists it will return true.
---@param shopTitle string
---@param shopInventory table
---@param shopCoords table
---@param shopGroups table
Inventory.RegisterShop = function(shopTitle, shopInventory, shopCoords, shopGroups)
    return Bridge.Shops.CreateShop(shopTitle, shopInventory, shopCoords, shopGroups)
end

---@description This will get the image path for an item, it is an alternate option to GetItemInfo. If a image isnt found will revert to community_bridge logo (useful for menus)
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    return "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will remove the file extension from the item name if present.
---example: "item.png" will become "item"
---@param item string
---@return string
Inventory.StripPNG = function(item)
    if string.find(item, ".png") then
        item = string.gsub(item, ".png", "")
    end
    return item
end

---@description This will remove the file extension from the item name if present.
---example: "item.webp" will become "item"
---@param item string
---@return string
Inventory.StripWebp = function(item)
    if string.find(item, ".webp") then
        item = string.gsub(item, ".webp", "")
    end
    return item
end

---@description Opens another player's inventory for inspection/interaction
---@param src number The source player who is opening the inventory
---@param targetSrc number The target player whose inventory is being opened
---@return boolean
Inventory.OpenPlayerInventory = function(src, targetSrc)
    return false, print("OpenPlayerInventory is not implemented in this inventory, because of this we dont have a way to open a players inventory.")
end

return Inventory