local QBCore     = exports['qb-core']:GetCoreObject()
local ActiveJails = {}   -- [src] = { citizenid, remaining, location = {x,y,z,heading} }
local Locations   = {}   -- [id] = { id, name, x, y, z, heading }

-- ─── oxmysql wrappers ────────────────────────────────────────────────────────
local function dbExec(q, p)
    exports['oxmysql']:execute(q, p or {}, function() end)
end

local function dbQuery(q, p)
    local pr = promise.new()
    exports['oxmysql']:query(q, p or {}, function(rows) pr:resolve(rows or {}) end)
    return Citizen.Await(pr)
end

local function dbInsert(q, p)
    local pr = promise.new()
    exports['oxmysql']:insert(q, p or {}, function(id) pr:resolve(id) end)
    return Citizen.Await(pr)
end

-- ─── Init DB ─────────────────────────────────────────────────────────────────
CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(200) end
    Wait(400)

    local p1 = promise.new()
    exports['oxmysql']:execute([[
        CREATE TABLE IF NOT EXISTS `viperjail_locations` (
            `id`      INT AUTO_INCREMENT PRIMARY KEY,
            `name`    VARCHAR(64) NOT NULL DEFAULT 'Cellule',
            `x`       FLOAT NOT NULL,
            `y`       FLOAT NOT NULL,
            `z`       FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0.0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function() p1:resolve(true) end)
    Citizen.Await(p1)

    local p2 = promise.new()
    exports['oxmysql']:execute([[
        CREATE TABLE IF NOT EXISTS `viperjail_prisoners` (
            `citizenid`        VARCHAR(50) PRIMARY KEY,
            `player_name`      VARCHAR(64) NOT NULL DEFAULT '',
            `remaining_seconds` INT        NOT NULL DEFAULT 0,
            `loc_x`            FLOAT       NOT NULL DEFAULT 0,
            `loc_y`            FLOAT       NOT NULL DEFAULT 0,
            `loc_z`            FLOAT       NOT NULL DEFAULT 0,
            `loc_heading`      FLOAT       NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function() p2:resolve(true) end)
    Citizen.Await(p2)

    local p3 = promise.new()
    exports['oxmysql']:execute([[
        CREATE TABLE IF NOT EXISTS `viperjail_logs` (
            `id`                 INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid`          VARCHAR(50)  NOT NULL,
            `player_license`     VARCHAR(100) NOT NULL DEFAULT '',
            `player_name`        VARCHAR(64)  NOT NULL DEFAULT '',
            `staff_license`      VARCHAR(100) NOT NULL DEFAULT '',
            `staff_name`         VARCHAR(64)  NOT NULL DEFAULT '',
            `action`             VARCHAR(16)  NOT NULL DEFAULT 'JAIL',
            `duration_minutes`   INT          NULL,
            `jail_location_name` VARCHAR(64)  NULL,
            `reason`             VARCHAR(255) NULL,
            `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function() p3:resolve(true) end)
    Citizen.Await(p3)

    -- migration tables existantes
    dbExec("ALTER TABLE `viperjail_logs` ADD COLUMN IF NOT EXISTS `player_license` VARCHAR(100) NOT NULL DEFAULT '' AFTER `citizenid`", {})
    dbExec("ALTER TABLE `viperjail_logs` ADD COLUMN IF NOT EXISTS `reason` VARCHAR(255) NULL AFTER `jail_location_name`", {})

    local rows = dbQuery('SELECT * FROM viperjail_locations')
    for _, r in ipairs(rows) do
        Locations[r.id] = { id = r.id, name = r.name, x = r.x, y = r.y, z = r.z, heading = r.heading }
    end
end)

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function IsStaff(src)
    return IsPlayerAceAllowed(src, 'viper.modo')
end

local function LogJailAction(staffSrc, playerName, playerLicense, citizenid, action, durationMinutes, locationName, reason)
    local sLicense = (staffSrc and staffSrc > 0)
        and (GetPlayerIdentifierByType(tostring(staffSrc), 'license') or 'inconnu')
        or 'system'
    local sName = (staffSrc and staffSrc > 0) and (GetPlayerName(staffSrc) or '?') or 'Système'
    dbExec(
        'INSERT INTO viperjail_logs (citizenid, player_license, player_name, staff_license, staff_name, action, duration_minutes, jail_location_name, reason) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { citizenid, playerLicense or '', playerName, sLicense, sName, action, durationMinutes, locationName, reason }
    )
end

local function BuildLocationList()
    local list = {}
    for _, loc in pairs(Locations) do list[#list+1] = loc end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function BuildOnlineList()
    local list = {}
    for _, pidStr in ipairs(GetPlayers()) do
        local pid = tonumber(pidStr)
        local qp  = QBCore.Functions.GetPlayer(pid)
        if qp then
            local jail = ActiveJails[pid]
            list[#list+1] = {
                src       = pid,
                name      = GetPlayerName(pid) or '?',
                citizenid = qp.PlayerData.citizenid,
                jailed    = jail ~= nil,
                remaining = jail and jail.remaining or 0,
            }
        end
    end
    return list
end

local function OpenAdminPanel(src)
    local online = BuildOnlineList()
    local allDB  = dbQuery('SELECT citizenid, player_name, remaining_seconds FROM viperjail_prisoners')
    local onlineCids = {}
    for _, p in ipairs(online) do onlineCids[p.citizenid] = true end
    local offline = {}
    for _, r in ipairs(allDB) do
        if not onlineCids[r.citizenid] then
            offline[#offline+1] = { citizenid = r.citizenid, name = r.player_name, remaining = r.remaining_seconds }
        end
    end
    TriggerClientEvent('viperjail:admin:open', src, online, offline, BuildLocationList())
end

-- ─── Jail / Release ──────────────────────────────────────────────────────────
local function DoJail(src, citizenid, seconds, location, staffSrc, reason)
    local playerName    = GetPlayerName(src) or '?'
    local playerLicense = GetPlayerIdentifierByType(tostring(src), 'license') or ''
    ActiveJails[src] = { citizenid = citizenid, remaining = seconds, location = location }
    dbExec([[
        INSERT INTO viperjail_prisoners
            (citizenid, player_name, remaining_seconds, loc_x, loc_y, loc_z, loc_heading)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            player_name      = VALUES(player_name),
            remaining_seconds = VALUES(remaining_seconds),
            loc_x            = VALUES(loc_x),
            loc_y            = VALUES(loc_y),
            loc_z            = VALUES(loc_z),
            loc_heading      = VALUES(loc_heading)
    ]], { citizenid, playerName, seconds,
          location.x, location.y, location.z, location.heading })
    LogJailAction(staffSrc, playerName, playerLicense, citizenid, 'JAIL', math.floor(seconds / 60), location.name, reason)
    TriggerClientEvent('viperjail:start', src, seconds, location)
end

local function DoRelease(src, staffSrc)
    local data = ActiveJails[src]
    if not data then return end
    local playerName    = GetPlayerName(src) or data.citizenid
    local playerLicense = GetPlayerIdentifierByType(tostring(src), 'license') or ''
    dbExec('DELETE FROM viperjail_prisoners WHERE citizenid = ?', { data.citizenid })
    LogJailAction(staffSrc, playerName, playerLicense, data.citizenid, 'UNJAIL', nil, nil, nil)
    ActiveJails[src] = nil
    TriggerClientEvent('viperjail:release', src, Config.ReleaseSpawn)
end

-- ─── Tick ────────────────────────────────────────────────────────────────────
local saveTick = 0
CreateThread(function()
    while true do
        Wait(1000)
        saveTick = saveTick + 1
        local toRelease = {}
        for src, data in pairs(ActiveJails) do
            data.remaining = data.remaining - 1
            TriggerClientEvent('viperjail:tick', src, data.remaining)
            if data.remaining <= 0 then
                toRelease[#toRelease+1] = src
            elseif saveTick % 10 == 0 then
                dbExec('UPDATE viperjail_prisoners SET remaining_seconds = ? WHERE citizenid = ?',
                    { data.remaining, data.citizenid })
            end
        end
        for _, src in ipairs(toRelease) do DoRelease(src, nil) end
    end
end)

-- ─── Player events ───────────────────────────────────────────────────────────
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    local cid = Player.PlayerData.citizenid
    local rows = dbQuery('SELECT * FROM viperjail_prisoners WHERE citizenid = ?', { cid })
    if rows and rows[1] and rows[1].remaining_seconds > 0 then
        local r = rows[1]
        ActiveJails[src] = {
            citizenid = cid,
            remaining = r.remaining_seconds,
            location  = { x = r.loc_x, y = r.loc_y, z = r.loc_z, heading = r.loc_heading }
        }
    end
end)

RegisterNetEvent('viperjail:requestSync', function()
    local src  = source
    local data = ActiveJails[src]
    if data then
        TriggerClientEvent('viperjail:start', src, data.remaining, data.location)
    end
end)

AddEventHandler('playerDropped', function()
    local src  = source
    local data = ActiveJails[src]
    if data then
        dbExec('UPDATE viperjail_prisoners SET remaining_seconds = ? WHERE citizenid = ?',
            { data.remaining, data.citizenid })
        ActiveJails[src] = nil
    end
end)

-- ─── /adminjail ──────────────────────────────────────────────────────────────
RegisterCommand('adminjail', function(src)
    if src == 0 then return end
    if not IsStaff(src) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Accès refusé.', type = 'error' })
        return
    end
    OpenAdminPanel(src)
end, false)

-- ─── Admin net events ────────────────────────────────────────────────────────
RegisterNetEvent('viperjail:admin:refresh', function()
    local src = source
    if not IsStaff(src) then return end
    OpenAdminPanel(src)
end)

RegisterNetEvent('viperjail:admin:jailPlayer', function(targetSrc, minutes, locationId, reason)
    local src = source
    if not IsStaff(src) then return end
    targetSrc  = tonumber(targetSrc)
    minutes    = math.max(1, math.min(10080, tonumber(minutes) or 5))
    locationId = tonumber(locationId)
    local loc  = Locations[locationId]
    if not loc then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Cellule introuvable.', type = 'error' })
        return
    end
    local qp = QBCore.Functions.GetPlayer(targetSrc)
    if not qp then return end
    reason = reason and tostring(reason):sub(1, 255) or nil
    DoJail(targetSrc, qp.PlayerData.citizenid, minutes * 60, loc, src, reason)
end)

RegisterNetEvent('viperjail:admin:unjailPlayer', function(targetSrc)
    local src = source
    if not IsStaff(src) then return end
    DoRelease(tonumber(targetSrc), src)
end)

RegisterNetEvent('viperjail:admin:unjailOffline', function(citizenid)
    local src = source
    if not IsStaff(src) then return end
    local cid  = tostring(citizenid)
    local rows = dbQuery('SELECT player_name FROM viperjail_prisoners WHERE citizenid = ?', { cid })
    local pName = (rows and rows[1]) and rows[1].player_name or cid
    dbExec('DELETE FROM viperjail_prisoners WHERE citizenid = ?', { cid })
    LogJailAction(src, pName, cid, 'UNJAIL', nil, nil)
end)

RegisterNetEvent('viperjail:admin:addLocation', function(name)
    local src = source
    if not IsStaff(src) then return end
    local ped = GetPlayerPed(src)
    local c   = GetEntityCoords(ped)
    local h   = GetEntityHeading(ped)
    name = tostring(name or 'Cellule'):sub(1, 64)
    local id = dbInsert(
        'INSERT INTO viperjail_locations (name, x, y, z, heading) VALUES (?, ?, ?, ?, ?)',
        { name, c.x, c.y, c.z, h }
    )
    if not id then return end
    Locations[id] = { id = id, name = name, x = c.x, y = c.y, z = c.z, heading = h }
    TriggerClientEvent('viperjail:admin:locationAdded', src, Locations[id])
end)

RegisterNetEvent('viperjail:admin:deleteLocation', function(locId)
    local src = source
    if not IsStaff(src) then return end
    locId = tonumber(locId)
    if not Locations[locId] then return end
    Locations[locId] = nil
    dbExec('DELETE FROM viperjail_locations WHERE id = ?', { locId })
    TriggerClientEvent('viperjail:admin:locationDeleted', src, locId)
end)

-- ─── Logs ─────────────────────────────────────────────────────────────────────
RegisterNetEvent('viperjail:admin:getLogs', function(license)
    local src = source
    if not IsStaff(src) then return end
    if not license or license == '' then
        TriggerClientEvent('viperjail:admin:logsData', src, {})
        return
    end
    local rows = dbQuery(
        'SELECT id, citizenid, player_license, player_name, staff_name, action, duration_minutes, jail_location_name, reason, created_at FROM viperjail_logs WHERE player_license = ? ORDER BY created_at DESC LIMIT 100',
        { tostring(license) }
    )
    TriggerClientEvent('viperjail:admin:logsData', src, rows)
end)
