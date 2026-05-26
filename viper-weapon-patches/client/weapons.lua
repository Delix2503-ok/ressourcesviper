local QBCore = exports['qb-core']:GetCoreObject()

local weaponByHash  = {}
local weaponHashList = {}

-- ─── Désactiver le drive-by sur tous les véhicules ────────────────────────────
CreateThread(function()
    while true do
        Wait(0)
        SetPlayerCanDoDriveBy(PlayerId(), false)
    end
end)

-- ─── Auto-scope : GiveWeaponToPed en FiveM MP ne donne pas les composants par défaut ─
-- Sans scope component, le zoom fonctionne (lié au type GROUP_SNIPER) mais l'overlay
-- visuel circulaire n'apparaît pas. On l'applique automatiquement à l'équipement.
local SNIPER_SCOPES = {
    [`weapon_sniperrifle`]       = `COMPONENT_AT_SCOPE_LARGE`,
    [`weapon_heavysniper`]       = `COMPONENT_AT_SCOPE_MAX`,
    [`weapon_heavysniper_mk2`]   = `COMPONENT_AT_SCOPE_LARGE_MK2`,
    [`weapon_marksmanrifle`]     = `COMPONENT_AT_SCOPE_LARGE`,
    [`weapon_marksmanrifle_mk2`] = `COMPONENT_AT_SCOPE_LARGE_MK2`,
    [`weapon_precisionrifle`]    = `COMPONENT_AT_SCOPE_LARGE_MK2`,
}

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
    if not weapon then return end
    local scopeHash = SNIPER_SCOPES[weapon.hash]
    if not scopeHash then return end
    local ped = PlayerPedId()
    if not HasPedGotWeaponComponent(ped, weapon.hash, scopeHash) then
        GiveWeaponComponentToPed(ped, weapon.hash, scopeHash)
    end
end)

local prevHealth = 200
local prevArmor  = 100

local function toUnsigned(h)
    if h < 0 then return h + 4294967296 end
    return h
end

local function buildLookup(weapons)
    weaponByHash  = {}
    weaponHashList = {}
    for name, data in pairs(weapons) do
        if data.enabled then
            local hash = toUnsigned(GetHashKey(name))
            weaponByHash[hash]             = { name = name, cfg = data }
            weaponHashList[#weaponHashList + 1] = hash
        end
    end
    print('[VIPER] ' .. #weaponHashList .. ' armes chargees')
end

local function applyBodyDamage(ped, damage, hp, armor)
    local remaining = damage
    local newArmor  = armor
    local newHealth = hp

    if newArmor > 0 then
        local absorbed = math.min(newArmor, remaining)
        newArmor  = newArmor  - absorbed
        remaining = remaining - absorbed
    end

    if remaining > 0 then
        newHealth = newHealth - remaining
    end

    if newHealth <= 100 then
        SetEntityHealth(ped, 0)
    else
        SetEntityHealth(ped, newHealth)
        SetPedArmour(ped, newArmor)
    end
end

local function applyHeadDamage(ped, damage, hp)
    local newHealth = hp - damage
    if newHealth <= 100 then
        SetEntityHealth(ped, 0)
    else
        SetEntityHealth(ped, newHealth)
    end
end

-- Approche par monitoring de santé + HasEntityBeenDamagedByWeapon
-- Plus fiable que gameEventTriggered qui peut être instable selon la version FiveM
local lastDamageTime = 0
local wasDead        = false

CreateThread(function()
    while true do
        local ped    = PlayerPedId()
        local isDead = IsPedDeadOrDying(ped, true)

        -- Traiter aussi la frame où l'on vient de mourir (headshot fatal instantané)
        -- Sans ça, IsPedDeadOrDying=true saute le bloc et le hitmarker n'est jamais envoyé.
        local justDied = isDead and not wasDead and prevHealth > 100

        if not isDead or justDied then
            local curHealth = GetEntityHealth(ped)
            local curArmor  = GetPedArmour(ped)
            local now       = GetGameTimer()

            local healthLost = prevHealth - curHealth
            local armorLost  = prevArmor  - curArmor

            if (healthLost > 2 or armorLost > 2) and (now - lastDamageTime) > 100 then
                lastDamageTime = now

                local hitInfo = nil
                for _, hash in ipairs(weaponHashList) do
                    if HasEntityBeenDamagedByWeapon(ped, hash, 0) then
                        hitInfo = weaponByHash[hash]
                        break
                    end
                end

                if hitInfo then
                    local cfg       = hitInfo.cfg
                    local victimPos = GetEntityCoords(ped)

                    local attackerNetId = -1
                    local attackerPos   = nil
                    local closestDist   = math.huge

                    for _, pid in ipairs(GetActivePlayers()) do
                        if pid ~= PlayerId() then
                            local attackerPed = GetPlayerPed(pid)
                            if HasEntityBeenDamagedByEntity(ped, attackerPed, false) then
                                local aPos = GetEntityCoords(attackerPed)
                                local dist = #(aPos - victimPos)
                                if dist < closestDist then
                                    closestDist   = dist
                                    attackerNetId = pid
                                    attackerPos   = aPos
                                end
                            end
                        end
                    end

                    if attackerPos and closestDist > cfg.range then
                        if not justDied then
                            SetEntityHealth(ped, prevHealth)
                            SetPedArmour(ped, prevArmor)
                            ClearEntityLastDamageEntity(ped)
                        end
                    else
                        local _, boneIndex = GetPedLastDamageBone(ped)
                        local isHeadshot   = (boneIndex == 31086)

                        if not justDied then
                            SetEntityHealth(ped, prevHealth)
                            SetPedArmour(ped, prevArmor)
                            if isHeadshot then
                                applyHeadDamage(ped, cfg.headDamage, prevHealth)
                            else
                                applyBodyDamage(ped, cfg.damage, prevHealth, prevArmor)
                            end
                        end

                        if attackerNetId ~= -1 then
                            TriggerServerEvent('weaponpatch:hitRegistered', {
                                attackerServerId = GetPlayerServerId(attackerNetId),
                                damage           = isHeadshot and cfg.headDamage or cfg.damage,
                                isHeadshot       = isHeadshot,
                                victimX          = victimPos.x,
                                victimY          = victimPos.y,
                                victimZ          = victimPos.z,
                            })
                        end
                    end
                end

                prevHealth = justDied and 100 or GetEntityHealth(ped)
                prevArmor  = justDied and 0   or GetPedArmour(ped)
            else
                prevHealth = isDead and prevHealth or curHealth
                prevArmor  = isDead and prevArmor  or curArmor
            end
        end

        wasDead = isDead
        Wait(0)
    end
end)

RegisterNetEvent('weaponpatch:receiveWeaponConfig', function(weapons)
    buildLookup(weapons)
end)

-- ─── Headshot côté attaquant (hors ranked) ───────────────────────────────────
-- Même logique que viper_ranked mais actif en dehors des matchs.
-- GetEntityLastWeaponImpactCoord + GetPedBoneCoords(31086) = détection fiable à toute distance.
-- Le serveur valide et déclenche le kill sur la victime.
CreateThread(function()
    local lastShotTime = 0
    while true do
        -- En ranked, viper_ranked gère les headshots
        if not LocalPlayer.state.inRankedMatch then
            local myPed = PlayerPedId()
            local now   = GetGameTimer()
            if IsPedShooting(myPed) and (now - lastShotTime) > 150 then
                local myWeaponHash = toUnsigned(GetSelectedPedWeapon(myPed))
                local weaponCfg    = weaponByHash[myWeaponHash]
                if weaponCfg and GetEntityLastWeaponImpactCoord then
                    local found, ix, iy, iz = GetEntityLastWeaponImpactCoord(myPed)
                    if found then
                        local impactPos = vector3(ix, iy, iz)
                        local myPos     = GetEntityCoords(myPed)
                        for _, pid in ipairs(GetActivePlayers()) do
                            if pid ~= PlayerId() then
                                local tPed = GetPlayerPed(pid)
                                if DoesEntityExist(tPed) and not IsEntityDead(tPed) then
                                    local tPos = GetEntityCoords(tPed)
                                    -- Bullet dans la range de l'arme
                                    if #(myPos - tPos) <= weaponCfg.cfg.range then
                                        -- Bullet passé près de ce joueur
                                        if #(impactPos - tPos) < 2.5 then
                                            -- Vérifier bone tête (31086)
                                            local hx, hy, hz = GetPedBoneCoords(tPed, 31086, 0.0, 0.0, 0.0)
                                            if #(impactPos - vector3(hx, hy, hz)) < 0.35 then
                                                lastShotTime = now
                                                TriggerServerEvent('weaponpatch:headshotConfirmed', GetPlayerServerId(pid))
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Reçu par la victime : le serveur a confirmé le headshot hors ranked
RegisterNetEvent('weaponpatch:forceHeadshot', function()
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then return end
    SetEntityHealth(ped, 0)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('weaponpatch:requestWeaponConfig')
end)

TriggerServerEvent('weaponpatch:requestWeaponConfig')

-- ─── Hitmarkers ───────────────────────────────────────────────────────────────
local hmPending = {}

RegisterNetEvent('weaponpatch:showHitmarker')
AddEventHandler('weaponpatch:showHitmarker', function(data)
    table.insert(hmPending, {
        x      = data.victimX,
        y      = data.victimY,
        z      = data.victimZ + 0.9,
        damage = math.floor(data.damage),
        isHead = data.isHeadshot,
        born   = GetGameTimer(),
        sx     = nil,
        sy     = nil,
    })
end)

CreateThread(function()
    print('[HITMARKER] thread actif')
    while true do
        if #hmPending == 0 then
            Wait(50)
        else
            Wait(0)
            local now = GetGameTimer()
            for i = #hmPending, 1, -1 do
                local hm      = hmPending[i]
                local elapsed = (now - hm.born) / 1000.0

                if not hm.sx then
                    local ok, sx, sy = World3dToScreen2d(hm.x, hm.y, hm.z)
                    if ok and sx > 0.0 and sx < 1.0 and sy > 0.0 and sy < 1.0 then
                        hm.sx = sx
                        hm.sy = sy
                    elseif (now - hm.born) > (hm.isHead and 200 or 600) then
                        hm.sx = 0.5
                        hm.sy = 0.38
                    end
                end

                if hm.sx then
                    local alpha  = math.max(0, math.floor(255 * (1.0 - elapsed)))
                    local drawY  = hm.sy - elapsed * 0.10
                    if hm.isHead then
                        SetTextFont(7)
                        SetTextScale(0.0, 0.55)
                        SetTextColour(255, 20, 20, alpha)
                    else
                        SetTextFont(7)
                        SetTextScale(0.0, 0.40)
                        SetTextColour(255, 255, 255, alpha)
                    end
                    SetTextOutline()
                    SetTextCentre(true)
                    SetTextEntry('STRING')
                    AddTextComponentString(tostring(hm.damage))
                    DrawText(hm.sx, drawY)
                end

                if elapsed >= 1.0 then
                    table.remove(hmPending, i)
                end
            end
        end
    end
end)
