local Avatars = {}
local Init = {
    Frameworks  =  { "es_extended", "qb-core" },
    Inventories =  { "qb-inventory", "esx_inventoryhud", "qs-inventory", "codem-inventory", "gfx-inventory", "ox_inventory", "ps-inventory" },
    SkinScripts =  { "esx_skin", "qb-clothing", "skinchanger", "illenium-appearance", "fivem-appearance" },
    SQLScripts  =  { "mysql-async", "ghmattimysql", "oxmysql" },
}

initialized = false
local currentResourceName = GetCurrentResourceName()

---@class Utils

---@param name string The name of the event
---@param cb function The callback function
function RegisterCallback(name, cb)
    RegisterNetEvent(name, function(id, args)
        local src = source
        local eventName = currentResourceName..":triggerCallback:" .. id
        CreateThread(function()
            local ok, result = pcall(cb, src, table.unpack(args))
            if not ok then
                print(("^1[%s] Callback '%s' error: %s^0"):format(currentResourceName, name, tostring(result)))
                TriggerClientEvent(eventName, src, nil)
                return
            end
            TriggerClientEvent(eventName, src, result)
        end)
    end)
end

Utils = {
    Framework,
    FrameworkObject,
    FrameworkShared,
    InventoryName,
    SQLScript
}

function GetFramework()
    return Utils.Framework
end

function GetFrameworkObject()
    return Utils.FrameworkObject
end

function GetFrameworkShared()
    return Utils.FrameworkShared
end

function InitalFunc()
    if initialized then return end

    InitFramework()
    InitInventory()
    InitSkinScript()
    InitSQLScript()
    
    initialized = true

    print("--------------["..currentResourceName.."]-----------------")
    print("Framework: "..(Utils.Framework or "Not found"))
    print("Inventory: "..(Utils.InventoryName or "Not found"))
    print("SkinScript: "..(Utils.SkinScript or "Not found"))
    print("SQLScript: "..(Utils.SQLScript or "Not found"))
    print("-------------- Script has initialized -------------------")
end

function InitFramework()
    if Utils.Framework ~= nil then return end
    for i = 1, #Init.Frameworks do
        if IsDuplicityVersion() then
            if GetResourceState(Init.Frameworks[i]) == "started" then
                Utils.Framework = Init.Frameworks[i]
                Utils.FrameworkObject = InitFrameworkObject()
                Utils.FrameworkShared = InitFrameworkShared()
            end
        else
            if GetResourceState(Init.Frameworks[i]) == "started" then
                Utils.Framework = Init.Frameworks[i]

                Utils.FrameworkObject = InitFrameworkObject()
                Utils.FrameworkShared = InitFrameworkShared()
            end
        end
    end
end

function InitFrameworkObject()
    if Utils.Framework == "es_extended" then
        local ESX = nil
        TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
        Wait(100)
        if ESX == nil then
            ESX = exports["es_extended"]:getSharedObject()
        end
        return ESX
    elseif Utils.Framework == "qb-core" then
        local QBCore = nil
        TriggerEvent("QBCore:GetObject", function(obj) QBCore = obj end)
        Wait(100)
        if QBCore == nil then
            QBCore = exports["qb-core"]:GetCoreObject()
        end
        return QBCore
    end
end

function InitFrameworkShared()
    while Utils.FrameworkObject == nil do
        Citizen.Wait(100)
    end
    if Utils.Framework == "qb-core" then
        return Utils.FrameworkObject.Shared
    elseif Utils.Framework == "es_extended" then
        return Utils.FrameworkObject.Config
    end
end

function InitInventory()
    for i = 1, #Init.Inventories do
        if IsDuplicityVersion() then
            if GetResourceState(Init.Inventories[i]) == "started" then
                Utils.InventoryName = Init.Inventories[i]
            end
        else
            if GetResourceState(Init.Inventories[i]) == "started" then
                Utils.InventoryName = Init.Inventories[i]
            end
        end
    end
end

function InitSkinScript()
    for i = 1, #Init.SkinScripts do
        if IsDuplicityVersion() then
            if GetResourceState(Init.SkinScripts[i]) == "started" then
                Utils.SkinScript = Init.SkinScripts[i]
            end
        else
            if GetResourceState(Init.SkinScripts[i]) == "started" then
                Utils.SkinScript = Init.SkinScripts[i]
            end
        end
    end
end

function InitSQLScript()
    for i = 1, #Init.SQLScripts do
        if IsDuplicityVersion() then
            if GetResourceState(Init.SQLScripts[i]) == "started" then
                Utils.SQLScript = Init.SQLScripts[i]
            end
        else
            if GetResourceState(Init.SQLScripts[i]) == "started" then
                Utils.SQLScript = Init.SQLScripts[i]
            end
        end
    end
end

---@param query string The query to execute
function ExecuteSql(query, parameters, cb)
    local promise = promise:new()
    if Utils.SQLScript == "oxmysql" then
        exports.oxmysql:execute(query, parameters, function(data)
            promise:resolve(data)
            if cb then
                cb(data)
            end
        end)
    elseif Utils.SQLScript == "ghmattimysql" then
        exports.ghmattimysql:execute(query, parameters, function(data)
            promise:resolve(data)
            if cb then
                cb(data)
            end
        end)
    elseif Utils.SQLScript == "mysql-async" then
        MySQL.Async.fetchAll(query, parameters, function(data)
            promise:resolve(data)
            if cb then
                cb(data)
            end
        end)
    end
    return Citizen.Await(promise)
end

---@param source number The players server id
function GetPlayer(source)
    if Utils.Framework == "es_extended" then
        return Utils.FrameworkObject.GetPlayerFromId(source)
    elseif Utils.Framework == "qb-core" then
        return Utils.FrameworkObject.Functions.GetPlayer(source)
    end
end

---@param identifier string The players identifier
function GetPlayerFromIdentifier(identifier)
    if Utils.Framework == "es_extended" then
        return Utils.FrameworkObject.GetPlayerFromIdentifier(identifier)
    elseif Utils.Framework == "qb-core" then
        return Utils.FrameworkObject.Functions.GetPlayerByCitizenId(identifier)
    end
end

---@param charId string The players character id
function GetPlayerFromCharacterId(charId)
    if Utils.Framework == "es_extended" then
        return Utils.FrameworkObject.GetPlayerFromCharacterId(charId)
    elseif Utils.Framework == "qb-core" then
        return Utils.FrameworkObject.Functions.GetPlayerByCitizenId(charId)
    end
end

---@param source number The players server id
function GetIdentifier(source)
    if Utils.Framework == "es_extended" then
        local player = GetPlayer(source)
        if player then return player.identifier end
    elseif Utils.Framework == "qb-core" then
        local player = GetPlayer(source)
        if player then return player.PlayerData.citizenid end
    end
    -- Fallback for unsupported frameworks (vRP etc.)
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and id:find("license:") then
            return id
        end
    end
    return nil
end

---@param source number The players server id
function GetPlayerNameBySource(source)
    if Utils.Framework == "es_extended" then
        local player = GetPlayer(source)
        if not player then return GetPlayerName(source) end
        return player.getName()
    elseif Utils.Framework == "qb-core" then
        local player = GetPlayer(source)
        if not player then return GetPlayerName(source) end
        return player.PlayerData.charinfo.firstname.." "..player.PlayerData.charinfo.lastname
    else
        return GetPlayerName(source)
    end
end

---@param item string The item name
---@param handler function The handler function
function RegisterItem(item, handler)
    if Utils.Framework == "es_extended" then
        Utils.FrameworkObject.RegisterUsableItem(item, handler)
    elseif Utils.Framework == "qb-core" then
        Utils.FrameworkObject.Functions.CreateUseableItem(item, handler)
    end
end

---@param id string|number The players identifier or server id
function GetPlayerSkinData(id)
    id = type(id) == "number" and GetIdentifier(id) or id
    local p = promise:new()
    if Utils.SkinScript == "qb-clothes" then
        ExecuteSql('SELECT * FROM playerskins WHERE citizenid = @citizenid AND active = @active', {
            ['@citizenid'] = id,
            ['@active'] = 1
        }, function(result)
            if result[1] ~= nil then
                p:resolve({tonumber(result[1].model), json.decode(result[1].skin)})
            else
                return p:resolve(nil)
            end
        end)
    elseif Utils.SkinScript == "skinchanger" then
        ExecuteSql('SELECT skin FROM users WHERE identifier = @identifier', {
            ['@identifier'] = id
        }, function(result)
            if result[1] ~= nil then
                p:resolve({GetHashKey(result[1].skin), json.decode(result[1].skin)})
            else
                return p:resolve(nil)
            end
        end)
    elseif Utils.SkinScript == "fivem-appearance" then
        if Config.Framework == "es_extended" then
            ExecuteSql('SELECT skin FROM users WHERE identifier = @identifier', {
                ['@identifier'] = id
            }, function(result)
                if result[1] ~= nil then
                    local resSkin = json.decode(result[1].skin).model
                    p:resolve({resSkin, json.decode(result[1].skin)})
                else
                    return p:resolve(nil)
                end
            end)
        elseif Config.Framework == "qb-core" then
            ExecuteSql('SELECT skin FROM playerskins WHERE citizenid = @citizenid', {
                ['@citizenid'] = id
            }, function(result)
                if result[1] ~= nil then
                    local resSkin = json.decode(result[1].skin).model
                    p:resolve({resSkin, json.decode(result[1].skin)})
                else
                    return p:resolve(nil)
                end
            end)
        end
    elseif Utils.SkinScript == "illenium-appearance" then
        if Utils.Framework == "es_extended" then
            ExecuteSql('SELECT skin FROM users WHERE identifier = @identifier', {
                ['@identifier'] = id
            }, function(result)
                if result[1] ~= nil then
                    local resSkin = json.decode(result[1].skin).model
                    p:resolve({resSkin, json.decode(result[1].skin)})
                else
                    return p:resolve(nil)
                end
            end)
        elseif Utils.Framework == "qb-core" then
            ExecuteSql('SELECT skin FROM playerskins WHERE citizenid = @citizenid', {
                ['@citizenid'] = id
            }, function(result)
                if result[1] ~= nil then
                    local resSkin = json.decode(result[1].skin).model
                    p:resolve({resSkin, json.decode(result[1].skin)})
                else
                    return p:resolve(nil)
                end
            end)
        end
    elseif Utils.SkinScript == "esx_skin" then
        ExecuteSql('SELECT skin FROM users WHERE identifier = @identifier', {
            ['@identifier'] = id
        }, function(result)
            if result[1] ~= nil then
                local resSkin = json.decode(result[1].skin).model
                p:resolve({resSkin, json.decode(result[1].skin)})
            else
                return p:resolve(nil)
            end
        end)
    end
    return Citizen.Await(p)
end

---@param source number The players server id
---@param item string The item name
---@param count number The amount of the item to add
---@param metadata table The metadata of the item
---@param slot number The slot of the item
function AddItem(source, item, count, slot, metadata)
    if AddItemData[Utils.InventoryName] then
        AddItemData[Utils.InventoryName](source, item, count, slot, metadata)
    end
end

AddItemData =  {
    ["esx_inventoryhud"] = function(source, item, count)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        xPlayer.addInventoryItem(item, count)
    end,
    ["qb-inventory"] = function(source, item, count, slot)
        exports["qb-inventory"]:AddItem(source, item, count)
    end,
    ["gfx-inventory"] = function(source, item, count, slot)
        exports["gfx-inventory"]:AddItem(source, "inventory", item, count)
    end,
    ["ox_inventory"] = function(source, item, count, slot, metadata)
        exports["ox_inventory"]:AddItem(source, item, count, metadata, slot)
    end,
    ["codem-inventory"] = function(source, item, count, slot)
        exports["codem-inventory"]:AddItem(source, item, count, slot)
    end,
    ["qs-inventory"] = function(source, item, count, slot, metadata)
        exports["qs-inventory"]:AddItem(source, item, count, slot, metadata)
    end,
    ["ps-inventory"] = function(source, item, count, slot)
        exports["ps-inventory"]:AddItem(source, item, count, slot)
    end
}

---@param source number The players server id
---@param item string The item name
---@param count number The amount of the item to remove
---@param metadata table The metadata of the item
---@param slot number The slot of the item
function RemoveItem(source, item, count, slot, metadata)
    if RemoveItemData[Utils.InventoryName] then
        RemoveItemData[Utils.InventoryName](source, item, count, slot, metadata)
    end
end

RemoveItemData = {
    ["esx_inventoryhud"] = function(source, item, count)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        xPlayer.removeInventoryItem(item, count)
    end,
    ["qb-inventory"] = function(source, item, count, slot)
        exports["qb-inventory"]:RemoveItem(source, item, count, slot)
    end,
    ["gfx-inventory"] = function(source, item, count, slot)
        exports["gfx-inventory"]:RemoveItem(source, "inventory", item, count)
    end,
    ["ox_inventory"] = function(source, item, count, slot, metadata)
        exports["ox_inventory"]:RemoveItem(source, item, count, metadata, slot)
    end,
    ["codem-inventory"] = function(source, item, count, slot)
        exports["codem-inventory"]:RemoveItem(source, item, count, slot)
    end,
    ["qs-inventory"] = function(source, item, count, slot, metadata)
        exports["qs-inventory"]:RemoveItem(source, item, count, slot, metadata)
    end,
    ["ps-inventory"] = function(source, item, count, slot)
        exports["ps-inventory"]:RemoveItem(source, item, count, slot)
    end
}

---@param source number The players server id
function GetInventory(source)
    if GetInventoryData[Utils.InventoryName] then
        local inventory = GetInventoryData[Utils.InventoryName](source)
        for k, v in pairs(inventory) do
            if v.amount then
                v.count = v.amount
            elseif v.count then
                v.amount = v.count
            end
        end
        return inventory
    end
end

GetInventoryData = {
    ["esx_inventoryhud"] = function(source)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        return xPlayer.getInventory()
    end,
    ["qb-inventory"] = function(source)
        local player = GetPlayer(source)
        return player.PlayerData.items
    end,
    ["gfx-inventory"] = function(source)
        return exports["gfx-inventory"]:GetInventory(source, "inventory")
    end,
    ["ox_inventory"] = function(source)
        return exports["ox_inventory"]:GetInventoryItems(source)
    end,
    ["codem-inventory"] = function(source)
        local identifier = type(source) == "string" and source or nil
        return exports["codem-inventory"]:GetInventory(identifier, source)
    end,
    ["qs-inventory"] = function(source)
        return exports["qs-inventory"]:GetInventory(source)
    end,
    ["ps-inventory"] = function(source)
        local identifier = GetIdentifier(source)
        return exports["ps-inventory"]:LoadInventory(source, identifier)
    end
}

GetItemCountData = {
    ["esx_inventoryhud"] = function(source, item)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        return xPlayer.getInventoryItem(item).count
    end,
    ["qb-inventory"] = function(source, item)
        return exports["qb-inventory"]:GetItemCount(source, item)
    end,
    ["gfx-inventory"] = function(source, item)
        local item = exports["gfx-inventory"]:GetItemByName(source, "inventory", item)
        return item and item.count or 0
    end,
    ["ox_inventory"] = function(source, item)
        return exports["ox_inventory"]:GetItemCount(source, item)
    end,
    ["codem-inventory"] = function(source, item)
        return exports["codem-inventory"]:GetItemsTotalAmount(source, item)
    end,
    ["qs-inventory"] = function(source, item)
        return exports["qs-inventory"]:GetItemTotalAmount(source, item)
    end,
    ["ps-inventory"] = function(source, item)
        return exports["ps-inventory"]:GetItemByName(source, item).amount
    end
}

function GetItemCount(source, item)
    if GetItemCountData[Utils.InventoryName] then
        return GetItemCountData[Utils.InventoryName](source, item)
    end
end

---@param source number The players server id
---@param item string The item name
---@param count number The amount of the item to remove
function HasItem(source, item, count)
    if HasItemData[Utils.InventoryName] then
        return HasItemData[Utils.InventoryName](source, item, count)
    end
end

HasItemData = {
    ["esx_inventoryhud"] = function(source, item, count)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        return xPlayer.getInventoryItem(item).count >= count
    end,
    ["qb-inventory"] = function(source, item, count)
        return exports["qb-inventory"]:HasItem(source, item, count)
    end,
    ["gfx-inventory"] = function(source, item, count)
        local item = exports["gfx-inventory"]:GetItemByName(source, "inventory", item)
        return item and item.count >= count or false
    end,
    ["ox_inventory"] = function(source, item, count)
        return exports["ox_inventory"]:GetItemCount(source, item) >= count
    end,
    ["codem-inventory"] = function(source, item, count)
        return exports["codem-inventory"]:HasItem(source, item, count)
    end,
    ["qs-inventory"] = function(source, item, count)
        return exports["qs-inventory"]:GetItemTotalAmount(source, item) >= count
    end,
    ["ps-inventory"] = function(source, item, count)
        return exports["ps-inventory"]:GetItemByName(source, item).amount >= count
    end
}

---@param source number The players server id
function GetMoney(source, moneyType)
    if GetMoneyData[Utils.Framework] then
        return GetMoneyData[Utils.Framework](source, moneyType)
    end
end

GetMoneyData = {
    ["es_extended"] = function(source, moneyType)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        return moneyType == "bank" and xPlayer.getAccount("bank").money or xPlayer.getMoney()
    end,
    ["qb-core"] = function(source, moneyType)
        local player = GetPlayer(source)
        return player.PlayerData.money[moneyType]
    end
}

---@param source number The players server id
---@param amount number The amount of money to add
function AddMoney(source, amount)
    if AddMoneyData[Utils.Framework] then
        AddMoneyData[Utils.Framework](source, amount)
    end
end

AddMoneyData = {
    ["es_extended"] = function(source, amount)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        xPlayer.addMoney(amount)
    end,
    ["qb-core"] = function(source, amount)
        local player = GetPlayer(source)
        player.Functions.AddMoney("cash", amount)
    end
}

---@param source number The players server id
---@param amount number The amount of money to remove
function RemoveMoney(source, amount)
    if RemoveMoneyData[Utils.Framework] then
        RemoveMoneyData[Utils.Framework](source, amount)
    end
end

RemoveMoneyData = {
    ["es_extended"] = function(source, amount)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        xPlayer.removeMoney(amount)
    end,
    ["qb-core"] = function(source, amount)
        local player = GetPlayer(source)
        player.Functions.RemoveMoney("cash", amount)
    end
}

---@param source number The players server id
---@param amount number The amount of money to check
function HasMoney(source, amount)
    if HasMoneyData[Utils.Framework] then
        return HasMoneyData[Utils.Framework](source, amount)
    end
end

HasMoneyData = {
    ["es_extended"] = function(source, amount)
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        return xPlayer.getMoney() >= amount
    end,
    ["qb-core"] = function(source, amount)
        local player = GetPlayer(source)
        return player.PlayerData.money["cash"] >= amount
    end
}

---@param source number The players server id
---@param item string The item name
---@param count number The amount of the item to remove
function AddVehicleToPlayer(source, vehicle, props)
    local xPlayer = GetPlayer(source)
    local plate = CreateRandomPlate()

    if Utils.Framework == "qb-core" then
        local cid = xPlayer.PlayerData.citizenid
        ExecuteSql("INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES ('"..xPlayer.PlayerData.license.."', '"..cid.."', '"..vehicle.."', '"..GetHashKey(vehicle).."', '"..json.encode(props).."', '"..plate.."', '".."pillboxgarage".."', '0')")
    elseif Utils.Framework == "es_extended" then
        local xPlayer = Framework.GetPlayerFromId(source)
        ExecuteSql("INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES ('"..xPlayer.identifier.."', '"..plate.."', '"..json.encode(json.encode(props)).."', '".."car".."', '0')")
    end
end

function GetPlayerPhoto(source)
    if Config.PhotoType == "steam" then
        return GetSteamProfilePicture(source)
    elseif Config.PhotoType == "discord" then
        return GetDiscordProfilePicture(source)
    end
end

function GetDiscordProfilePicture(source)
    return getPlayerAvatar(source)
end

GetSteamProfilePicture = function(source)
    local fallback = (Config and Config.NoImage) or "default.png"
    local identifier = GetIdent(source)
    if not identifier then
        return fallback
    end
    if identifier:match("steam") then
        local callback = promise:new()
        PerformHttpRequest('http://steamcommunity.com/profiles/' .. tonumber(GetIDFromSource('steam', identifier), 16) .. '/?xml=1', function(Error, Content, Head)
            if not Content then
                callback:resolve(fallback)
                return
            end
            local SteamProfileSplitted = stringsplit(Content, '\n')
            if SteamProfileSplitted ~= nil and next(SteamProfileSplitted) ~= nil then
                for i, Line in ipairs(SteamProfileSplitted) do
                    if Line:find('<avatarFull>') then
                        callback:resolve(Line:gsub('	<avatarFull><!%[CDATA%[', ''):gsub(']]></avatarFull>', ''))
                        return
                    end
                end
            end
            callback:resolve(fallback)
        end)
        local avatar = Citizen.Await(callback)
        return avatar
    end
    return fallback
end -- your framework doesn't support steam id : D I think yes IDK by the way what do you recommend now? for what? what do you think about script, i dont think so what is wrong with steam IDK i cant say nothing because i dont know but its 

function GetIDFromSource(Type, CurrentID)
	local ID = stringsplit(CurrentID, ':')
	if (ID[1]:lower() == string.lower(Type)) then
		return ID[2]:lower()
	end
	return nil
end

function stringsplit(input, seperator)
	if seperator == nil then
		seperator = '%s'
	end

	local t={} ; i=1
	if input ~= nil then
		for str in string.gmatch(input, '([^'..seperator..']+)') do
			t[i] = str
			i = i + 1
		end
		return t
	end
end

function GetIdent(source, idType)
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if string.find(id, "steam:") then
            return id
        end
    end
    return false
end

function CreateRandomPlate()
    local plate = ""
    for i = 1, 8 do
        plate = plate .. string.char(math.random(65, 90))
    end
    return plate
end

function getPlayerAvatar(src)
    if not Avatars[src] then
        local identifiers = {}
        local discord = nil

        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local license = GetPlayerIdentifier(src, i)
    
            if string.sub(license, 1, string.len("discord:")) == "discord:" then
                discord = license
            end
        end

        local avatar = nil

        if discord then
            discord = string.sub(discord, 9, string.len(discord))
            local p = promise.new()

            PerformHttpRequest("https://discordapp.com/api/users/" .. discord, function(statusCode, data)
                if statusCode == 200 then
                    data = json.decode(data or "{}")

                    if data.avatar then
                        local animated = data.avatar:gsub(1, 2) == "a_"

                        avatar = "https://cdn.discordapp.com/avatars/" ..
                            discord .. "/" .. data.avatar .. (animated and ".gif" or ".png")
                    end
                end

                p:resolve()
            end, "GET", "", {
                Authorization = "Bot " .. Config.DiscordBotToken
            })

            Citizen.Await(p)
        end

        Avatars[src] = avatar or "default.png"
    end

    return Avatars[src]
end

Citizen.CreateThread(function()
    InitalFunc()
end)

Notify = function(source, message)
    if Config.Notify then
        Config.Notify(source, message)
        return
    end
    if Utils.Framework == "es_extended" then
        local xPlayer = Utils.FrameworkObject.GetPlayerFromId(source)
        xPlayer.showNotification(message)
    elseif Utils.Framework == "qb-core" then
        local player = Utils.FrameworkObject.Functions.GetPlayer(source)
        player.Functions.Notify(message)
    end
end