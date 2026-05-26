local ESX = exports[Config.Settings.Core]:getSharedObject()

function Notify(player, message, type, duration)
    if duration == nil then
        duration = 3000
    end

    if Config.Settings.Notify == 'ft_notification' then
        TriggerClientEvent('ft_notification:ShowNotify', player, message, type, duration)
    elseif Config.Settings.Notify == 'esx' then
        TriggerClientEvent('esx:showNotification', player, message)
    elseif Config.Settings.Notify == 'ox_lib' then
        lib.notify(player, { title = L('notify.title'),  description = message, position = 'top', type, showDuration = duration })
    end
end

function IsPlayerAdmin(source, cb)
    local playerIdentifiers = GetPlayerIdentifiers(source)
    local discordId, licenseId = nil, nil

    for _, identifier in ipairs(playerIdentifiers) do
        if string.find(identifier, "discord:") then
            discordId = identifier:gsub("discord:", "")
        elseif string.find(identifier, "license:") then
            licenseId = identifier:gsub("license:", "")
        end
    end

    for _, adminId in ipairs(Config.Admins or {}) do
        if adminId == licenseId or adminId == discordId then
            local perms = {
                superadmin = true
            }
            cb(true, perms)
            return
        end
    end

    if not licenseId then
        cb(false, nil)
        return
    end

    local result = Query('SELECT permissions FROM ft_admins WHERE license = ? LIMIT 1', { licenseId })

    if result and result[1] and result[1].permissions then
        local ok, perms = pcall(function()
            return json.decode(result[1].permissions)
        end)

        if ok and perms then
            cb(true, perms)
            return
        else
            cb(false, nil)
            return
        end
    else
        cb(false, nil)
    end
end

RegisterServerEvent('ft_admin:BringPlayer')
AddEventHandler('ft_admin:BringPlayer', function(targetId)
    local src = source
    local target = tonumber(targetId)

    if GetPlayerPing(target) then
        local coords = GetEntityCoords(GetPlayerPed(src))
        TriggerClientEvent('ft_admin:TeleportToPlayerCoords', target, coords)
        Notify(src, L('notify.brought'), 'success')
        Notify(target, L('notify.were_brought'), 'info')

        local targetName = GetPlayerName(targetId) or ("ID " .. targetId)
        local message    = string.format("BringPlayer %s *(%d)*", targetName, targetId)
        SendWebhook(webhooks.gotobring, message)
    else
        Notify(src, L('notify.Invalid_ID'), 'error')
    end
end)

RegisterServerEvent('ft_admin:GotoPlayer')
AddEventHandler('ft_admin:GotoPlayer', function(targetId)
    local src = source
    local target = tonumber(targetId)

    if GetPlayerPing(target) then
        local coords = GetEntityCoords(GetPlayerPed(target))
        TriggerClientEvent('ft_admin:TeleportToPlayerCoords', src, coords)
        Notify(src, L('notify.teleported'), 'success')

        local targetName = GetPlayerName(targetId) or ("ID " .. targetId)
        local message    = string.format("Goto %s *(%d)*", targetName, targetId)
        SendWebhook(webhooks.gotobring, message)
    else
        Notify(src, L('notify.Invalid_ID'), 'error')
    end
end)

function GeneratePlate()
    local plate = GetRandomLetter(3) .. tostring(math.random(1000, 9999))
    local result = Query('SELECT plate FROM owned_vehicles WHERE plate = ?', { plate })[1]
    
    if result then
        return GeneratePlate()
    else
        return plate:upper()
    end
end

ESX.RegisterServerCallback('ft_admin:GiveVehicleToPlayer', function(source, cb, targetId, model)

    local xPlayer = ESX.GetPlayerFromId(tonumber(targetId))
    if not xPlayer then
        Notify(source, L('notify.not_found'), 'error')
        return cb(false)
    end

    local modelHash = GetHashKey(model)

    if not modelHash then
        Notify(source, (L('notify.Vehicle_not_exist')):format(model or "nil"), 'error')
        return cb(false)
    end

    local plate = GeneratePlate()

    local vehicleData = {
        model = modelHash,
        plate = plate
    }

    local rawName    = GetPlayerName(targetId) or ("ID "..targetId)
    local targetName = string.format("%s (%d)", string.upper(rawName), targetId)
    local actionMsg = string.format(
        "Gave vehicle **%s** with plate **%s** to %s",
        model, plate, targetName )
    SendWebhook(webhooks.giveremovevehicle, actionMsg, source)

    Query('INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)', {
        xPlayer.getIdentifier(),
        plate,
        json.encode(vehicleData)
    }, function()
        Notify(source, (L('notify.Gave_vehicle')):format(model, plate, GetPlayerName(targetId)), 'success')
        Notify(targetId, (L('notify.received_plate')):format(model, plate), 'info')
        cb({ model = model, plate = plate })
    end)
end)

-- report

function GetPlayerByLicense(licenseToFind)
    if not licenseToFind or licenseToFind == "" then return nil end
    if not string.find(licenseToFind, "license:") then
        licenseToFind = "license:" .. licenseToFind
    end

    for _, playerId in ipairs(GetPlayers()) do
        for _, id in ipairs(GetPlayerIdentifiers(playerId)) do
            if id == licenseToFind then
                return tonumber(playerId)
            end
        end
    end

    return nil
end

RegisterServerEvent("ft_admin:handleReportAction")
AddEventHandler("ft_admin:handleReportAction", function(data)
    local src = source
    local action = data.action
    local license = data.license
    local reportId = data.reportId

    local target = GetPlayerByLicense(license)

    print(target)
    if action == 'goto' and target then
        local ped = GetPlayerPed(target)
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('ft_admin:TeleportToPlayerCoords', src, coords)

    elseif action == 'bring' and target then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('ft_admin:TeleportToPlayerCoords', src, coords)

    elseif action == 'conclude' then
        Query("DELETE FROM ft_admin_reports WHERE id = ?", {reportId})
    end
end)

