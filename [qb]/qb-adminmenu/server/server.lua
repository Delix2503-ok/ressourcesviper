-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local frozen = false

-- Modo+ : noclip, ban, kick, TP
local function IsModo(src)
    return IsPlayerAceAllowed(src, 'group.modo') or IsPlayerAceAllowed(src, 'command')
end

-- Admin+ : tout Modo + give item / inventaire
local function IsAdmin(src)
    return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'command')
end

-- God / Responsable : commandes destructives (kickall, setpermissions)
local function IsGod(src)
    return IsPlayerAceAllowed(src, 'viper.fondateur') or IsPlayerAceAllowed(src, 'command')
end

function GetQBPlayers()
    local playerReturn = {}
    local players = QBCore.Functions.GetQBPlayers()
    
    for id, player in pairs(players) do
        local playerPed = GetPlayerPed(id)
        local name = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
        playerReturn[#playerReturn + 1] = {
            name = name .. ' | (' .. (player.PlayerData.name or '') .. ')',
            id = id,
            coords = GetEntityCoords(playerPed),
            cid = name,
            citizenid = player.PlayerData.citizenid,
            sources = playerPed,
            sourceplayer = id
        }
    end
    return playerReturn
end

-- Get Dealers
QBCore.Functions.CreateCallback('test:getdealers', function(_, cb)
    cb(exports['qb-drugs']:GetDealers())
end)

-- Get Players
QBCore.Functions.CreateCallback('test:getplayers', function(_, cb) -- WORKS
    local players =  GetQBPlayers()
    cb(players)
end)

QBCore.Functions.CreateCallback('qb-admin:isAdmin', function(src, cb)
    cb(IsModo(src))
end)

QBCore.Functions.CreateCallback('qb-admin:server:getrank', function(source, cb)
    cb(IsAdmin(source))
end)

-- Functions
local function tablelength(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

local function BanPlayer(src)
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        GetPlayerName(src),
        QBCore.Functions.GetIdentifier(src, 'license'),
        QBCore.Functions.GetIdentifier(src, 'discord'),
        QBCore.Functions.GetIdentifier(src, 'ip'),
        'Trying to revive theirselves or other players',
        2147483647,
        'qb-adminmenu'
    })
    TriggerEvent('qb-log:server:CreateLog', 'adminmenu', 'Player Banned', 'red', string.format('%s was banned by %s for %s', GetPlayerName(src), 'qb-adminmenu', 'Trying to trigger admin options which they dont have permission for'), true)
    DropPlayer(src, 'You were permanently banned by the server for: Exploiting')
end

-- Events
RegisterNetEvent('qb-admin:server:GetPlayersForBlips', function()
    local src = source
    local players = GetQBPlayers()
    TriggerClientEvent('qb-admin:client:Show', src, players)
end)

RegisterNetEvent('qb-admin:server:kill', function(player)
    local src = source
    if IsModo(src) then
        TriggerClientEvent('hospital:client:KillPlayer', player.id)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:revive', function(player)
    local src = source
    if IsModo(src) then
        TriggerClientEvent('hospital:client:Revive', player.id)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:kick', function(player, reason)
    local src = source
    if IsModo(src) then
        TriggerEvent('qb-log:server:CreateLog', 'bans', 'Player Kicked', 'red', string.format('%s was kicked by %s for %s', GetPlayerName(player.id), GetPlayerName(src), reason), true)
        DropPlayer(player.id, Lang:t('info.kicked_server') .. ':\n' .. reason .. '\n\n' .. Lang:t('info.check_discord') .. QBCore.Config.Server.Discord)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:ban', function(player, time, reason)
    local src = source
    if IsModo(src) then
        time = tonumber(time)
        local banTime = tonumber(os.time() + time)
        if banTime > 2147483647 then
            banTime = 2147483647
        end
        local timeTable = os.date('*t', banTime)
        MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            GetPlayerName(player.id),
            QBCore.Functions.GetIdentifier(player.id, 'license'),
            QBCore.Functions.GetIdentifier(player.id, 'discord'),
            QBCore.Functions.GetIdentifier(player.id, 'ip'),
            reason,
            banTime,
            GetPlayerName(src)
        })
        TriggerClientEvent('chat:addMessage', -1, {
            template = "<div class=chat-message server'><strong>ANNOUNCEMENT | {0} has been banned:</strong> {1}</div>",
            args = { GetPlayerName(player.id), reason }
        })
        TriggerEvent('qb-log:server:CreateLog', 'bans', 'Player Banned', 'red', string.format('%s was banned by %s for %s', GetPlayerName(player.id), GetPlayerName(src), reason), true)
        if banTime >= 2147483647 then
            DropPlayer(player.id, Lang:t('info.banned') .. '\n' .. reason .. Lang:t('info.ban_perm') .. QBCore.Config.Server.Discord)
        else
            DropPlayer(player.id, Lang:t('info.banned') .. '\n' .. reason .. Lang:t('info.ban_expires') .. timeTable['day'] .. '/' .. timeTable['month'] .. '/' .. timeTable['year'] .. ' ' .. timeTable['hour'] .. ':' .. timeTable['min'] .. '\n🔸 Check our Discord for more information: ' .. QBCore.Config.Server.Discord)
        end
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:spectate', function(player)
    local src = source
    if IsModo(src) then
        local targetped = GetPlayerPed(player.id)
        local coords = GetEntityCoords(targetped)
        TriggerClientEvent('qb-admin:client:spectate', src, player.id, coords)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:freeze', function(player)
    local src = source
    if IsModo(src) then
        local target = GetPlayerPed(player.id)
        if not frozen then
            frozen = true
            FreezeEntityPosition(target, true)
        else
            frozen = false
            FreezeEntityPosition(target, false)
        end
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:goto', function(player)
    local src = source
    if IsModo(src) then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(GetPlayerPed(player.id))
        SetEntityCoords(admin, coords)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:intovehicle', function(player)
    local src = source
    if IsModo(src) then
        local admin = GetPlayerPed(src)
        local targetPed = GetPlayerPed(player.id)
        local vehicle = GetVehiclePedIsIn(targetPed, false)
        local seat = -1
        if vehicle ~= 0 then
            for i = 0, 8, 1 do
                if GetPedInVehicleSeat(vehicle, i) == 0 then
                    seat = i
                    break
                end
            end
            if seat ~= -1 then
                SetPedIntoVehicle(admin, vehicle, seat)
                TriggerClientEvent('QBCore:Notify', src, Lang:t('sucess.entered_vehicle'), 'success', 5000)
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_free_seats'), 'danger', 5000)
            end
        end
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:bring', function(player)
    local src = source
    if IsModo(src) then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(admin)
        local target = GetPlayerPed(player.id)
        SetEntityCoords(target, coords)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:inventory', function(player)
    local src = source
    if IsAdmin(src) then  -- give item = admin+
        exports['qb-inventory']:OpenInventoryById(src, player.id)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:cloth', function(player)
    local src = source
    if IsAdmin(src) then
        TriggerClientEvent('qb-clothing:client:openMenu', player.id)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:setPermissions', function(targetId, group)
    local src = source
    if IsGod(src) then
        QBCore.Functions.AddPermission(targetId, group[1].rank)
        TriggerClientEvent('QBCore:Notify', targetId, Lang:t('info.rank_level') .. group[1].label)
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:SendReport', function(name, targetSrc, msg)
    local src = source
    if IsModo(src) then
        if QBCore.Functions.IsOptin(src) then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 0, 0 },
                multiline = true,
                args = { Lang:t('info.admin_report') .. name .. ' (' .. targetSrc .. ')', msg }
            })
        end
    end
end)

RegisterServerEvent('qb-admin:giveWeapon', function(weapon)
    local src = source
    if IsAdmin(src) then
        exports['qb-inventory']:AddItem(src, weapon, 1, false, false, 'qb-admin:giveWeapon')
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-admin:server:SaveCar', function(mods, vehicle, _, plate)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
        local Player = QBCore.Functions.GetPlayer(src)
        local result = MySQL.query.await('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
        if result[1] == nil then
            MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                Player.PlayerData.license,
                Player.PlayerData.citizenid,
                vehicle.model,
                vehicle.hash,
                json.encode(mods),
                plate,
                0
            })
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.success_vehicle_owner'), 'success', 5000)
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.failed_vehicle_owner'), 'error', 3000)
        end
    else
        BanPlayer(src)
    end
end)

-- Commands

QBCore.Commands.Add('maxmods', Lang:t('desc.max_mod_desc'), {}, false, function(source)
    if not IsAdmin(source) then return end
    TriggerClientEvent('qb-admin:client:maxmodVehicle', source)
end, 'user')

QBCore.Commands.Add('blips', Lang:t('commands.blips_for_player'), {}, false, function(source)
    if not IsModo(source) then return end
    TriggerClientEvent('qb-admin:client:toggleBlips', source)
end, 'user')

QBCore.Commands.Add('names', Lang:t('commands.player_name_overhead'), {}, false, function(source)
    if not IsModo(source) then return end
    TriggerClientEvent('qb-admin:client:toggleNames', source)
end, 'user')

QBCore.Commands.Add('coords', Lang:t('commands.coords_dev_command'), {}, false, function(source)
    if not IsModo(source) then return end
    TriggerClientEvent('qb-admin:client:ToggleCoords', source)
end, 'user')

QBCore.Commands.Add('noclip', Lang:t('commands.toogle_noclip'), {}, false, function(source)
    if not IsModo(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Permission refusée', 'error', 3000)
        return
    end
    TriggerClientEvent('qb-admin:client:ToggleNoClip', source)
end, 'user')

QBCore.Commands.Add('admincar', Lang:t('commands.save_vehicle_garage'), {}, false, function(source, _)
    if not IsAdmin(source) then return end
    TriggerClientEvent('qb-admin:client:SaveCar', source)
end, 'user')

QBCore.Commands.Add('announce', Lang:t('commands.make_announcement'), {}, false, function(source, args)
    if not IsModo(source) then return end
    local msg = table.concat(args, ' ')
    if msg == '' then return end
    TriggerClientEvent('chat:addMessage', -1, {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 'Announcement', msg }
    })
end, 'user')

QBCore.Commands.Add('admin', Lang:t('commands.open_admin'), {}, false, function(source, _)
    if not IsModo(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Permission refusée', 'error', 3000)
        return
    end
    TriggerClientEvent('qb-admin:client:openMenu', source)
end, 'user')

-- /report désactivé : remplacé par Rup-ReportMenu (/reports)

QBCore.Commands.Add('staffchat', Lang:t('commands.staffchat_message'), { { name = 'message', help = 'Message' } }, true, function(source, args)
    if not IsModo(source) then return end
    local msg = table.concat(args, ' ')
    local name = GetPlayerName(source)

    local plrs = GetPlayers()

    for _, plr in ipairs(plrs) do
        plr = tonumber(plr)
        if plr then
            if IsModo(plr) then
                if QBCore.Functions.IsOptin(plr) then
                    TriggerClientEvent('chat:addMessage', plr, {
                        color = { 255, 0, 0 },
                        multiline = true,
                        args = { Lang:t('info.staffchat') .. name, msg }
                    })
                end
            end
        end
    end
end, 'admin')

QBCore.Commands.Add('givenuifocus', Lang:t('commands.nui_focus'), { { name = 'id', help = 'Player id' }, { name = 'focus', help = 'Set focus on/off' }, { name = 'mouse', help = 'Set mouse on/off' } }, true, function(_, args)
    local playerid = tonumber(args[1])
    local focus = args[2]
    local mouse = args[3]
    TriggerClientEvent('qb-admin:client:GiveNuiFocus', playerid, focus, mouse)
end, 'admin')

QBCore.Commands.Add('warn', Lang:t('commands.warn_a_player'), { { name = 'ID', help = 'Player' }, { name = 'Reason', help = 'Mention a reason' } }, true, function(source, args)
    if not IsModo(source) then return end
    local targetPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local senderPlayer = QBCore.Functions.GetPlayer(source)
    table.remove(args, 1)
    local msg = table.concat(args, ' ')
    local warnId = 'WARN-' .. math.random(1111, 9999)
    if targetPlayer ~= nil then
        TriggerClientEvent('chat:addMessage', targetPlayer.PlayerData.source, { args = { 'SYSTEM', Lang:t('info.warning_chat_message') .. GetPlayerName(source) .. ',' .. Lang:t('info.reason') .. ': ' .. msg }, color = 255, 0, 0 })
        TriggerClientEvent('chat:addMessage', source, { args = { 'SYSTEM', Lang:t('info.warning_staff_message') .. GetPlayerName(targetPlayer.PlayerData.source) .. ', for: ' .. msg }, color = 255, 0, 0 })
        MySQL.insert('INSERT INTO player_warns (senderIdentifier, targetIdentifier, reason, warnId) VALUES (?, ?, ?, ?)', {
            senderPlayer.PlayerData.license,
            targetPlayer.PlayerData.license,
            msg,
            warnId
        })
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('checkwarns', Lang:t('commands.check_player_warning'), { { name = 'id', help = 'Player' }, { name = 'Warning', help = 'Number of warning, (1, 2 or 3 etc..)' } }, false, function(source, args)
    if args[2] == nil then
        local targetPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
        local result = MySQL.query.await('SELECT * FROM player_warns WHERE targetIdentifier = ?', { targetPlayer.PlayerData.license })
        TriggerClientEvent('chat:addMessage', source, 'SYSTEM', 'warning', targetPlayer.PlayerData.name .. ' has ' .. tablelength(result) .. ' warnings!')
    else
        local targetPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
        local warnings = MySQL.query.await('SELECT * FROM player_warns WHERE targetIdentifier = ?', { targetPlayer.PlayerData.license })
        local selectedWarning = tonumber(args[2])
        if warnings[selectedWarning] ~= nil then
            local sender = QBCore.Functions.GetPlayer(warnings[selectedWarning].senderIdentifier)
            TriggerClientEvent('chat:addMessage', source, 'SYSTEM', 'warning', targetPlayer.PlayerData.name .. ' has been warned by ' .. sender.PlayerData.name .. ', Reason: ' .. warnings[selectedWarning].reason)
        end
    end
end, 'admin')

QBCore.Commands.Add('delwarn', Lang:t('commands.delete_player_warning'), { { name = 'id', help = 'Player' }, { name = 'Warning', help = 'Number of warning, (1, 2 or 3 etc..)' } }, true, function(source, args)
    local targetPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local warnings = MySQL.query.await('SELECT * FROM player_warns WHERE targetIdentifier = ?', { targetPlayer.PlayerData.license })
    local selectedWarning = tonumber(args[2])
    if warnings[selectedWarning] ~= nil then
        TriggerClientEvent('chat:addMessage', source, 'SYSTEM', 'warning', 'You have deleted warning (' .. selectedWarning .. ') , Reason: ' .. warnings[selectedWarning].reason)
        MySQL.query('DELETE FROM player_warns WHERE warnId = ?', { warnings[selectedWarning].warnId })
    end
end, 'admin')

QBCore.Commands.Add('reportr', Lang:t('commands.reply_to_report'), { { name = 'id', help = 'Player' }, { name = 'message', help = 'Message to respond with' } }, false, function(source, args)
    local src = source
    local playerId = tonumber(args[1])
    table.remove(args, 1)
    local msg = table.concat(args, ' ')
    local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
    if msg == '' then return end
    if not OtherPlayer then return TriggerClientEvent('QBCore:Notify', src, 'Player is not online', 'error') end
    if not QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') ~= 1 then return end
    TriggerClientEvent('chat:addMessage', playerId, {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 'Admin Response', msg }
    })
    TriggerClientEvent('chat:addMessage', src, {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 'Report Response (' .. playerId .. ')', msg }
    })
    TriggerClientEvent('QBCore:Notify', src, 'Reply Sent')
    TriggerEvent('qb-log:server:CreateLog', 'report', 'Report Reply', 'red', '**' .. GetPlayerName(src) .. '** replied on: **' .. OtherPlayer.PlayerData.name .. ' **(ID: ' .. OtherPlayer.PlayerData.source .. ') **Message:** ' .. msg, false)
end, 'admin')

QBCore.Commands.Add('setmodel', Lang:t('commands.change_ped_model'), { { name = 'model', help = 'Name of the model' }, { name = 'id', help = 'Id of the Player (empty for yourself)' } }, false, function(source, args)
    local model = args[1]
    local target = tonumber(args[2])
    if model ~= nil or model ~= '' then
        if target == nil then
            TriggerClientEvent('qb-admin:client:SetModel', source, tostring(model))
        else
            local Trgt = QBCore.Functions.GetPlayer(target)
            if Trgt ~= nil then
                TriggerClientEvent('qb-admin:client:SetModel', target, tostring(model))
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
            end
        end
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.failed_set_model'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('setspeed', Lang:t('commands.set_player_foot_speed'), {}, false, function(source, args)
    local speed = args[1]
    if speed ~= nil then
        TriggerClientEvent('qb-admin:client:SetSpeed', source, tostring(speed))
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.failed_set_speed'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('reporttoggle', Lang:t('commands.report_toggle'), {}, false, function(source, _)
    local src = source
    QBCore.Functions.ToggleOptin(src)
    if QBCore.Functions.IsOptin(src) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.receive_reports'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_receive_report'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('kickall', Lang:t('commands.kick_all'), {}, false, function(source, args)
    local src = source
    if src > 0 then
        local reason = table.concat(args, ' ')
        if IsGod(src) then
            if reason and reason ~= '' then
                local players = GetPlayers()
                for _, playerId in ipairs(players) do
                    DropPlayer(playerId, reason)
                end
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t('info.no_reason_specified'), 'error')
            end
        end
    else
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            DropPlayer(playerId, Lang:t('info.server_restart') .. QBCore.Config.Server.Discord)
        end
    end
end, 'god')

QBCore.Commands.Add('setammo', Lang:t('commands.ammo_amount_set'), { { name = 'amount', help = 'Amount of bullets, for example: 20' } }, false, function(source, args)
    if not IsAdmin(source) then return end
    local src = source
    local ped = GetPlayerPed(src)
    local amount = tonumber(args[1])
    local weapon = GetSelectedPedWeapon(ped)
    if weapon and amount then
        SetPedAmmo(ped, weapon, amount)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('info.ammoforthe', { value = amount, weapon = QBCore.Shared.Weapons[weapon]['label'] }), 'success')
    end
end, 'user')

QBCore.Commands.Add('vector2', 'Copy vector2 to clipboard', {}, false, function(source)
    if not IsModo(source) then return end
    TriggerClientEvent('qb-admin:client:copyToClipboard', source, 'coords2')
end, 'user')

QBCore.Commands.Add('vector3', 'Copy vector3 to clipboard', {}, false, function(source)
    if not IsModo(source) then return end
    TriggerClientEvent('qb-admin:client:copyToClipboard', source, 'coords3')
end, 'user')

QBCore.Commands.Add('vector4', 'Copy vector4 to clipboard', {}, false, function(source)
    if not IsModo(source) then return end
    TriggerClientEvent('qb-admin:client:copyToClipboard', source, 'coords4')
end, 'user')

QBCore.Commands.Add('heading', 'Copy heading to clipboard', {}, false, function(source)
    if not IsModo(source) then return end
    TriggerClientEvent('qb-admin:client:copyToClipboard', source, 'heading')
end, 'user')
