local SafeZones = {}
local TpNpcs    = {}

-- Chargement depuis les tables de viperpvp_redzone (réutilisées telles quelles)
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Citizen.CreateThread(function()
        Wait(5000)  -- après l'init oxmysql de server.lua
        exports['oxmysql']:query('SELECT * FROM redzone_safezones', {}, function(rows)
            if not rows then return end
            SafeZones = {}
            for _, z in ipairs(rows) do
                SafeZones[z.id] = {
                    id     = z.id,
                    name   = z.name or ('Zone ' .. z.id),
                    x      = z.x, y = z.y, z = z.z,
                    radius = z.radius,
                    active = (z.active == 1 or z.active == true)
                }
            end
            print(('[gfx-redzone] %d safezone(s) chargée(s)'):format(#rows))
            -- Push immédiat vers tous les clients déjà connectés
            local szList = {}
            for _, z in pairs(SafeZones) do szList[#szList + 1] = z end
            TriggerClientEvent('gfx-redzone:syncSafezones', -1, szList)
        end)
        exports['oxmysql']:query('SELECT * FROM redzone_tp_npcs', {}, function(rows)
            if not rows then return end
            TpNpcs = {}
            for _, n in ipairs(rows) do
                TpNpcs[n.id] = {
                    id      = n.id,
                    name    = n.name or '',
                    x       = n.x, y = n.y, z = n.z,
                    heading = n.heading
                }
            end
            print(('[gfx-redzone] %d NPC TP chargé(s)'):format(#rows))
            -- Push immédiat vers tous les clients déjà connectés
            local npcList = {}
            for _, n in pairs(TpNpcs) do npcList[#npcList + 1] = n end
            TriggerClientEvent('gfx-redzone:syncTpNpcs', -1, npcList)
        end)
    end)
end)

RegisterNetEvent('gfx-redzone:requestSafezoneSync', function()
    local src     = source
    local szList  = {}
    local npcList = {}
    for _, z in pairs(SafeZones) do szList[#szList + 1]   = z end
    for _, n in pairs(TpNpcs)    do npcList[#npcList + 1] = n end
    TriggerClientEvent('gfx-redzone:syncSafezones', src, szList)
    TriggerClientEvent('gfx-redzone:syncTpNpcs',    src, npcList)
end)

exports('IsPlayerInSafezone', function(src)
    local ok, pos = pcall(GetEntityCoords, GetPlayerPed(src))
    if not ok then return false end
    for _, z in pairs(SafeZones) do
        if z.active then
            local dx = pos.x - z.x
            local dy = pos.y - z.y
            if (dx * dx + dy * dy) <= (z.radius * z.radius) then return true end
        end
    end
    return false
end)
