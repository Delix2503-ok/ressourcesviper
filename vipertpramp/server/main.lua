local NpcsDB  = {}
local ZonesDB = {}

-- ─── Wrappers oxmysql (sans MySQL global — compatible quel que soit l'ordre d'ensure) ──
local function dbExec(query, params)
    local p = promise.new()
    exports['oxmysql']:execute(query, params or {}, function() p:resolve(true) end)
    return Citizen.Await(p)
end

local function dbQuery(query, params)
    local p = promise.new()
    exports['oxmysql']:query(query, params or {}, function(rows) p:resolve(rows or {}) end)
    return Citizen.Await(p)
end

local function dbInsert(query, params)
    local p = promise.new()
    exports['oxmysql']:insert(query, params or {}, function(id) p:resolve(id) end)
    return Citizen.Await(p)
end

-- ─── Admin check (licence FiveM) ─────────────────────────────────────────
local function IsAdmin(src)
    local ids = GetPlayerIdentifiers(src)
    for _, id in ipairs(ids) do
        for _, lic in ipairs(Config.AdminLicenses) do
            if id == lic then return true end
        end
    end
    return false
end

-- ─── Helpers sync ────────────────────────────────────────────────────────
local function BuildLists()
    local npcs, zones = {}, {}
    for _, n in pairs(NpcsDB)  do npcs[#npcs+1]  = n end
    for _, z in pairs(ZonesDB) do zones[#zones+1] = z end
    return npcs, zones
end

local function BroadcastSync()
    local npcs, zones = BuildLists()
    TriggerClientEvent('vipertpramp:sync', -1, npcs, zones)
end

local function SendSync(target)
    local npcs, zones = BuildLists()
    TriggerClientEvent('vipertpramp:sync', target, npcs, zones)
end

-- ─── Init DB (attend oxmysql, puis crée tables + charge données) ─────────
CreateThread(function()
    -- Attendre qu'oxmysql soit démarré, quel que soit l'ordre d'ensure
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(200)
    end
    Wait(300)

    dbExec([[
        CREATE TABLE IF NOT EXISTS `vipertpramp_npcs` (
            `id`      INT AUTO_INCREMENT PRIMARY KEY,
            `name`    VARCHAR(64) NOT NULL DEFAULT 'Ramp',
            `x`       FLOAT NOT NULL,
            `y`       FLOAT NOT NULL,
            `z`       FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0.0,
            `type`    VARCHAR(16) NOT NULL DEFAULT 'npc'
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Migration : ajoute la colonne type si la table existait déjà sans elle
    dbExec("ALTER TABLE `vipertpramp_npcs` ADD COLUMN IF NOT EXISTS `type` VARCHAR(16) NOT NULL DEFAULT 'npc'")

    dbExec([[
        CREATE TABLE IF NOT EXISTS `vipertpramp_zones` (
            `id`     INT AUTO_INCREMENT PRIMARY KEY,
            `name`   VARCHAR(64) NOT NULL DEFAULT 'Zone',
            `x`      FLOAT NOT NULL,
            `y`      FLOAT NOT NULL,
            `z`      FLOAT NOT NULL,
            `radius` FLOAT NOT NULL DEFAULT 50.0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    local rows = dbQuery('SELECT * FROM vipertpramp_npcs')
    for _, r in ipairs(rows) do
        NpcsDB[r.id] = { id = r.id, name = r.name, x = r.x, y = r.y, z = r.z, heading = r.heading, type = r.type or 'npc' }
    end

    local zrows = dbQuery('SELECT * FROM vipertpramp_zones')
    for _, r in ipairs(zrows) do
        ZonesDB[r.id] = { id = r.id, name = r.name, x = r.x, y = r.y, z = r.z, radius = r.radius }
    end
end)

-- ─── Sync joueur ─────────────────────────────────────────────────────────
RegisterNetEvent('vipertpramp:requestSync', function()
    SendSync(source)
end)

-- ─── Admin : ouvrir le panel ──────────────────────────────────────────────
RegisterNetEvent('vipertpramp:admin:open', function()
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('vipertpramp:admin:denied', src)
        return
    end
    local npcs, zones = BuildLists()
    TriggerClientEvent('vipertpramp:admin:opened', src, npcs, zones)
end)

-- ─── NPC CRUD ────────────────────────────────────────────────────────────
RegisterNetEvent('vipertpramp:admin:npc:create', function(name, npcType)
    local src = source
    if not IsAdmin(src) then return end
    local ped = GetPlayerPed(src)
    local c   = GetEntityCoords(ped)
    local h   = GetEntityHeading(ped)
    name    = tostring(name or 'Ramp'):sub(1, 64)
    npcType = (npcType == 'marker') and 'marker' or 'npc'

    local id = dbInsert(
        'INSERT INTO vipertpramp_npcs (name, x, y, z, heading, type) VALUES (?, ?, ?, ?, ?, ?)',
        { name, c.x, c.y, c.z, h, npcType }
    )
    if not id then return end

    NpcsDB[id] = { id = id, name = name, x = c.x, y = c.y, z = c.z, heading = h, type = npcType }
    BroadcastSync()

    local list = {}
    for _, n in pairs(NpcsDB) do list[#list+1] = n end
    TriggerClientEvent('vipertpramp:admin:npcList', src, list)
end)

RegisterNetEvent('vipertpramp:admin:npc:delete', function(id)
    local src = source
    if not IsAdmin(src) then return end
    id = tonumber(id)
    if not id then return end
    NpcsDB[id] = nil
    dbExec('DELETE FROM vipertpramp_npcs WHERE id = ?', { id })
    BroadcastSync()
    local list = {}
    for _, n in pairs(NpcsDB) do list[#list+1] = n end
    TriggerClientEvent('vipertpramp:admin:npcList', src, list)
end)

-- ─── Zone CRUD ───────────────────────────────────────────────────────────
RegisterNetEvent('vipertpramp:admin:zone:create', function(name, radius)
    local src = source
    if not IsAdmin(src) then return end
    local ped = GetPlayerPed(src)
    local c   = GetEntityCoords(ped)
    name   = tostring(name or 'Zone'):sub(1, 64)
    radius = math.max(5.0, math.min(500.0, tonumber(radius) or 50.0))

    local id = dbInsert(
        'INSERT INTO vipertpramp_zones (name, x, y, z, radius) VALUES (?, ?, ?, ?, ?)',
        { name, c.x, c.y, c.z, radius }
    )
    if not id then return end

    ZonesDB[id] = { id = id, name = name, x = c.x, y = c.y, z = c.z, radius = radius }
    BroadcastSync()

    local list = {}
    for _, z in pairs(ZonesDB) do list[#list+1] = z end
    TriggerClientEvent('vipertpramp:admin:zoneList', src, list)
end)

RegisterNetEvent('vipertpramp:admin:zone:delete', function(id)
    local src = source
    if not IsAdmin(src) then return end
    id = tonumber(id)
    if not id then return end
    ZonesDB[id] = nil
    dbExec('DELETE FROM vipertpramp_zones WHERE id = ?', { id })
    BroadcastSync()
    local list = {}
    for _, z in pairs(ZonesDB) do list[#list+1] = z end
    TriggerClientEvent('vipertpramp:admin:zoneList', src, list)
end)

-- ─── /r : auto-revive dans zone ──────────────────────────────────────────
RegisterNetEvent('vipertpramp:selfRevive', function()
    local src = source
    local c   = GetEntityCoords(GetPlayerPed(src))
    for _, z in pairs(ZonesDB) do
        local dx = c.x - z.x
        local dy = c.y - z.y
        if (dx*dx + dy*dy) <= (z.radius * z.radius) then
            TriggerClientEvent('redzone:revived', src)
            return
        end
    end
end)
