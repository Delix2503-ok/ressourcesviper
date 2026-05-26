function GetName(source)
    return GetPlayerName(source)
end

if Config.Framework == "esx" then
    ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == "qb" then
    QBCore = exports["qb-core"]:GetCoreObject()
end

function AddItem(source, item, count, label)
    if Config.Framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(source)
        xPlayer.addInventoryItem(item, count)
    elseif Config.Framework == "qb" then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then Player.Functions.AddItem(item, count) end
    else
        exports["ox_inventory"]:AddItem(source, item, count)
    end
    Notify(source, Locales["got_reward"]:format(count, label))
end

-- Récompense toujours en black_money via ox_inventory (serveur PVP QBCore)
function AddMoney(source, amount)
    if amount == 0 then return end
    exports.ox_inventory:AddItem(source, 'black_money', amount)
    Notify(source, Locales["got_reward"]:format(amount, "Black Money"))
end

function Notify(source, text)
    if Config.Framework == "esx" then
        TriggerClientEvent("esx:showNotification", source, text)
    elseif Config.Framework == "qb" then
        TriggerClientEvent("QBCore:Notify", source, text, "primary", 5000)
    else
        TriggerClientEvent("chat:addMessage", source == -1 and -1 or source, { args = {"^1GFX", text} })
    end
end
