---@diagnostic disable: duplicate-set-field
if GetResourceState('core_inventory') == 'missing' then return end
local core = exports.core_inventory
-- Core inventory docs available at https://docs.c8re.store/core-inventory/api/server#getitemslist
Callback = Callback or Require("lib/callback/shared/callback.lua")

Inventory = Inventory or {}

---This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "core_inventory"
end

local cachedItemList = nil
--- Return the item info in oxs format, {name, label, stack, weight, description, image}
--- https://docs.c8re.store/core-inventory/api/server#getitemslist
--- @param item string
--- @return table
Inventory.GetItemInfo = function(item)
    local itemList = Inventory.Items()
    return itemList[item] or {}
end

---This will return the entire items table from the inventory.
---@return table 
Inventory.Items = function()
    local frameworkName = Framework.GetFrameworkName()
    if not frameworkName then return {} end
    local dataRepack = {}
    if frameworkName == 'es_extended' then
        if not cachedItemList then cachedItemList = Callback.Trigger('community_bridge:Callback:core_inventory', false) end
        dataRepack = cachedItemList or {}
    elseif frameworkName == 'qb-core' then
        dataRepack = Framework.Shared.Items or {}
    end
    for itemName, itemData in pairs(dataRepack) do
        if itemData and itemData.name then
            dataRepack[itemName].image = Inventory.GetImagePath(itemData.name)
            dataRepack[itemName].stack = dataRepack[itemName].unique or false
        end
    end
    return dataRepack
end

---Will return boolean if the player has the item.
---@param item string
---@return boolean
Inventory.HasItem = function(item)
    return core:hasItem(item, 1)
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return core:getItemCount(item) >= (requiredCount or 1)
end

---This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("core_inventory", string.format("html/img/%s.png", item))
    local imagePath = file and string.format("nui://core_inventory/html/img/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    local playerItems = core:getInventory()
    local repackedTable = {}
    for _, v in pairs(playerItems) do
        table.insert(repackedTable, {
            name = v.name,
            count = v.count or v.amount,
            metadata = v.metadata or v.info,
            slot = v.id or v.slot,
        })
    end
    return repackedTable
end

return Inventory