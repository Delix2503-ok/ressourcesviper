local activeWeapons = {}

for name, data in pairs(Config.Weapons) do
    activeWeapons[name] = {
        damage     = data.damage,
        headDamage = data.headDamage,
        range      = data.range,
        enabled    = data.enabled,
    }
end

RegisterNetEvent('weaponpatch:requestWeaponConfig', function()
    TriggerClientEvent('weaponpatch:receiveWeaponConfig', source, activeWeapons)
end)

RegisterNetEvent('weaponpatch:hitRegistered', function(data)
    local attackerSrc = tonumber(data.attackerServerId)
    if attackerSrc and GetPlayerPed(attackerSrc) ~= 0 then
        TriggerClientEvent('weaponpatch:showHitmarker', attackerSrc, {
            damage     = data.damage,
            isHeadshot = data.isHeadshot,
            victimX    = data.victimX,
            victimY    = data.victimY,
            victimZ    = data.victimZ,
        })
    end
end)

-- Headshot détecté côté attaquant hors ranked
local lastHeadshotByPlayer = {}
RegisterNetEvent('weaponpatch:headshotConfirmed', function(victimSrc)
    local src = source
    victimSrc = tonumber(victimSrc)
    if not victimSrc or victimSrc == src then return end
    if GetPlayerPed(victimSrc) == 0 then return end

    -- Rate-limit : 1 headshot par 300ms par attaquant
    local now = GetGameTimer()
    if lastHeadshotByPlayer[src] and (now - lastHeadshotByPlayer[src]) < 300 then return end
    lastHeadshotByPlayer[src] = now

    TriggerClientEvent('weaponpatch:forceHeadshot', victimSrc)
end)
