local QBCore = exports['qb-core']:GetCoreObject()

local Zone      = nil   -- { x, y, z, radius, active }
local SellNpc   = nil   -- { x, y, z, heading }
local SellPrice = Config.DefaultPrice
local CollectCD = {}    -- [src] = GetGameTimer() dernière récolte

-- ─── Admin ───────────────────────────────────────────────────────────────────

local function IsAdmin(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        for _, lic in ipairs(Config.AdminLicenses) do
            if id == lic then return true end
        end
    end
    local p = QBCore.Functions.GetPlayer(src)
    return p and (p.PlayerData.group == 'admin' or p.PlayerData.group == 'god')
end

-- ─── DB ──────────────────────────────────────────────────────────────────────

local function LoadData()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS vipercoca_data (
            `key`   VARCHAR(32) PRIMARY KEY,
            `value` TEXT NOT NULL
        )
    ]])
    local rows = MySQL.query.await('SELECT * FROM vipercoca_data')
    if rows then
        for _, r in ipairs(rows) do
            if r.key == 'zone' then
                local d = json.decode(r.value)
                if d and d.x then Zone = d end
            elseif r.key == 'npc' then
                local d = json.decode(r.value)
                if d and d.x then SellNpc = d end
            elseif r.key == 'price' then
                SellPrice = tonumber(r.value) or Config.DefaultPrice
            end
        end
    end
    print(('[viper-coca] Zone: %s | NPC: %s | Prix: $%d'):format(
        Zone and 'OK' or 'aucune',
        SellNpc and 'OK' or 'aucun',
        SellPrice
    ))
end

local function Save(key, value)
    local v = type(value) == 'table' and json.encode(value) or tostring(value)
    MySQL.execute(
        'INSERT INTO vipercoca_data (`key`,`value`) VALUES (?,?) ON DUPLICATE KEY UPDATE `value`=VALUES(`value`)',
        { key, v }
    )
end

-- ─── Sync ─────────────────────────────────────────────────────────────────────

local function Snap()
    return { zone = Zone, npc = SellNpc, price = SellPrice }
end

local function Broadcast()
    TriggerClientEvent('vipercoca:sync', -1, Snap())
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(500)
    LoadData()
    Broadcast()
end)

AddEventHandler('playerJoining', function()
    TriggerClientEvent('vipercoca:sync', source, Snap())
end)

RegisterNetEvent('vipercoca:requestSync', function()
    TriggerClientEvent('vipercoca:sync', source, Snap())
end)

AddEventHandler('playerDropped', function()
    CollectCD[source] = nil
end)

-- ─── Récolte ──────────────────────────────────────────────────────────────────

RegisterNetEvent('vipercoca:collect', function()
    local src = source

    if not Zone or not Zone.active then
        TriggerClientEvent('vipercoca:collectFail', src, 'Zone de récolte inactive.')
        return
    end

    local now = GetGameTimer()
    if CollectCD[src] and (now - CollectCD[src]) < Config.CollectCooldown then
        TriggerClientEvent('vipercoca:collectFail', src, 'Récolte trop rapide.')
        return
    end

    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    local dx  = pos.x - Zone.x
    local dy  = pos.y - Zone.y
    if (dx * dx + dy * dy) > (Zone.radius + 5.0) ^ 2 then
        TriggerClientEvent('vipercoca:collectFail', src, 'Tu es hors de la zone.')
        return
    end

    CollectCD[src] = now
    local amount = math.random(Config.CollectMin, Config.CollectMax)

    local ok = exports['ox_inventory']:AddItem(src, 'cocaine', amount)
    if ok then
        TriggerClientEvent('vipercoca:collected', src, amount)
    else
        TriggerClientEvent('vipercoca:collectFull', src)
    end
end)

-- ─── Vente ────────────────────────────────────────────────────────────────────

RegisterNetEvent('vipercoca:sell', function(amount)
    local src = source

    if not SellNpc then
        TriggerClientEvent('QBCore:Notify', src, 'Aucun revendeur disponible.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local pos  = GetEntityCoords(ped)
    local dx   = pos.x - SellNpc.x
    local dy   = pos.y - SellNpc.y
    if (dx * dx + dy * dy) > 100.0 then
        TriggerClientEvent('QBCore:Notify', src, 'Trop loin du revendeur.', 'error')
        return
    end

    local count = exports['ox_inventory']:GetItemCount(src, 'cocaine')
    if not count or count <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Tu n\'as pas de cocaine à vendre.', 'error')
        return
    end

    local toSell = count
    if amount then
        toSell = math.max(1, math.min(math.floor(tonumber(amount) or count), count))
    end

    if exports['ox_inventory']:RemoveItem(src, 'cocaine', toSell) then
        local total = toSell * SellPrice
        exports['ox_inventory']:AddItem(src, 'black_money', total)
        TriggerClientEvent('QBCore:Notify', src, ('Vendu %d cocaine pour $%d.'):format(toSell, total), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Erreur lors de la vente.', 'error')
    end
end)

-- ─── Admin : zone ─────────────────────────────────────────────────────────────

RegisterNetEvent('vipercoca:admin:setZone', function(data)
    local src = source
    if not IsAdmin(src) then return end
    local r = math.max(5.0, math.min(500.0, tonumber(data.radius) or 30.0))
    Zone = { x = data.x, y = data.y, z = data.z, radius = r, active = true }
    Save('zone', Zone)
    Broadcast()
    TriggerClientEvent('QBCore:Notify', src, ('Zone définie (rayon %dm).'):format(r), 'success')
end)

RegisterNetEvent('vipercoca:admin:toggleZone', function()
    local src = source
    if not IsAdmin(src) then return end
    if not Zone then
        TriggerClientEvent('QBCore:Notify', src, 'Aucune zone définie.', 'error'); return
    end
    Zone.active = not Zone.active
    Save('zone', Zone)
    Broadcast()
    TriggerClientEvent('QBCore:Notify', src, ('Zone %s.'):format(Zone.active and 'activée' or 'désactivée'),
        Zone.active and 'success' or 'error')
end)

-- ─── Admin : NPC ──────────────────────────────────────────────────────────────

RegisterNetEvent('vipercoca:admin:setNpc', function(data)
    local src = source
    if not IsAdmin(src) then return end
    SellNpc = { x = data.x, y = data.y, z = data.z, heading = data.heading }
    Save('npc', SellNpc)
    Broadcast()
    TriggerClientEvent('QBCore:Notify', src, 'PNJ revendeur placé.', 'success')
end)

RegisterNetEvent('vipercoca:admin:deleteNpc', function()
    local src = source
    if not IsAdmin(src) then return end
    SellNpc = nil
    MySQL.execute('DELETE FROM vipercoca_data WHERE `key` = ?', { 'npc' })
    Broadcast()
    TriggerClientEvent('QBCore:Notify', src, 'PNJ revendeur supprimé.', 'success')
end)

-- ─── Admin : prix ─────────────────────────────────────────────────────────────

RegisterNetEvent('vipercoca:admin:setPrice', function(price)
    local src = source
    if not IsAdmin(src) then return end
    price = math.max(0, math.floor(tonumber(price) or 0))
    SellPrice = price
    Save('price', price)
    Broadcast()
    TriggerClientEvent('QBCore:Notify', src, ('Prix de vente: $%d/cocaine'):format(price), 'success')
end)

-- ─── Admin : ouvrir panel ─────────────────────────────────────────────────────

RegisterNetEvent('vipercoca:admin:requestPanel', function()
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, 'Accès refusé.', 'error'); return
    end
    TriggerClientEvent('vipercoca:admin:open', src, Snap())
end)
