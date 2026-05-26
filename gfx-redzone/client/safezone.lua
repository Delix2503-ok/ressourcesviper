local QBCore = exports['qb-core']:GetCoreObject()

local SafeZones     = {}   -- [id] = zone data
local TpNpcs        = {}   -- [id] = npc data
local SpawnedTpNpcs = {}   -- [id] = ped entity handle
local SafeZoneBlips = {}
local TpSelectOpen  = false
local TpNpcSyncGen  = 0

InSafeZone = false   -- global : lu par death.lua

-- ─── Destination de revive (global pour death.lua) ────────────────────────────
function GfxGetReviveDestination()
    local myCoords = GetEntityCoords(PlayerPedId())

    -- 1. NPC TP le plus proche
    local bestNpc, bestDist = nil, math.huge
    for _, npc in pairs(TpNpcs) do
        local d = #(myCoords - vector3(npc.x, npc.y, npc.z))
        if d < bestDist then bestDist = d; bestNpc = npc end
    end
    if bestNpc then return bestNpc.x, bestNpc.y, bestNpc.z end

    -- 2. Centre de la safezone la plus proche
    local bestSz, bestDist2 = nil, math.huge
    for _, z in pairs(SafeZones) do
        if z.active then
            local dx = myCoords.x - z.x
            local dy = myCoords.y - z.y
            local d  = dx*dx + dy*dy
            if d < bestDist2 then bestDist2 = d; bestSz = z end
        end
    end
    if bestSz then return bestSz.x, bestSz.y, bestSz.z end

    return nil
end

-- ─── Hologramme 3D (style vipercar) ──────────────────────────────────────────
local function DrawHoloText(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.25)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoords()
    local d = #(camCoords - vector3(x, y, z))
    if d > 25.0 then return end
    local scale = math.min((1 / d) * 2.8, 0.6) * (1 / GetGameplayCamFov()) * 100
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(57, 255, 20, 230)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- ─── Blips safezones (toujours visibles, verts) ───────────────────────────────
local function ClearSafeZoneBlips()
    if #SafeZoneBlips > 0 then
        pcall(function() exports['viper-hud']:UnregisterProtectedBlips(SafeZoneBlips) end)
    end
    for _, b in pairs(SafeZoneBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    SafeZoneBlips = {}
end

local function UpdateSafeZoneBlips()
    ClearSafeZoneBlips()
    for _, z in pairs(SafeZones) do
        local x, y, zz = tonumber(z.x), tonumber(z.y), tonumber(z.z)
        local r = tonumber(z.radius)

        local bm = AddBlipForRadius(x, y, zz, r)
        SetBlipHighDetail(bm, true)
        SetBlipColour(bm, 2)
        SetBlipAlpha(bm, 160)
        SetBlipDisplay(bm, 4)
        SafeZoneBlips[#SafeZoneBlips + 1] = bm

        -- DEBUG
        print(('[gfx-sz] blip handle=%d sprite=%d alpha=%d exists=%s x=%.1f r=%.1f'):format(
            bm, GetBlipSprite(bm), GetBlipAlpha(bm), tostring(DoesBlipExist(bm)), x, r))
    end
    print('[gfx-sz] total SafeZoneBlips=' .. #SafeZoneBlips)
    if #SafeZoneBlips > 0 then
        pcall(function() exports['viper-hud']:RegisterProtectedBlips(SafeZoneBlips) end)
    end
end

-- Thread de maintien : re-applique l'alpha toutes les 5s (viper-hud noBlips cache les blips non protégés toutes les 15s)
CreateThread(function()
    while true do
        Wait(5000)
        for _, b in ipairs(SafeZoneBlips) do
            if DoesBlipExist(b) then
                SetBlipAlpha(b, 220)
                SetBlipColour(b, 2)
            end
        end
        if #SafeZoneBlips > 0 then
            pcall(function() exports['viper-hud']:RegisterProtectedBlips(SafeZoneBlips) end)
        end
    end
end)

-- ─── Spawn NPC TP (identique à viperpvp_redzone) ─────────────────────────────
local function SpawnTpNpc(npcData, gen)
    CreateThread(function()
        if SpawnedTpNpcs[npcData.id] and DoesEntityExist(SpawnedTpNpcs[npcData.id]) then
            DeleteEntity(SpawnedTpNpcs[npcData.id])
            SpawnedTpNpcs[npcData.id] = nil
        end

        local modelHash = GetHashKey('a_m_m_business_01')
        RequestModel(modelHash)
        local t = 0
        while not HasModelLoaded(modelHash) and t < 40 do Wait(50); t = t + 1 end
        if not HasModelLoaded(modelHash) then return end
        if gen ~= TpNpcSyncGen then SetModelAsNoLongerNeeded(modelHash); return end

        local ped = CreatePed(4, modelHash, npcData.x, npcData.y, npcData.z, npcData.heading, false, true)
        SetModelAsNoLongerNeeded(modelHash)

        -- OBLIGATOIRE : entité mission → pvputils ne la supprime pas (popType 4+)
        SetEntityAsMissionEntity(ped, true, true)

        SetEntityInvincible(ped, true)
        SetEntityCanBeDamaged(ped, false)
        SetPedCanRagdoll(ped, false)
        SetPedCanBeDraggedOut(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, false)
        TaskStandStill(ped, -1)

        -- Attendre collision
        local w = 0
        while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
            Wait(200); w = w + 1
        end

        -- Ground snap
        local finalZ  = npcData.z
        local snapped = false
        for _ = 1, 30 do
            if not DoesEntityExist(ped) then return end
            local found, gz = GetGroundZFor_3dCoord(npcData.x, npcData.y, npcData.z + 10.0, false)
            if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 then
                SetEntityCoords(ped, npcData.x, npcData.y, gz, false, false, false, false)
                finalZ  = gz
                snapped = true; break
            end
            Wait(200)
        end
        if not snapped and DoesEntityExist(ped) then
            SetEntityCoords(ped, npcData.x, npcData.y, npcData.z, false, false, false, false)
        end

        if gen ~= TpNpcSyncGen then
            if DoesEntityExist(ped) then DeleteEntity(ped) end
            return
        end

        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            TaskStandStill(ped, -1)
        end

        SpawnedTpNpcs[npcData.id] = ped

        -- Thread de maintien + re-snap toutes les 500ms
        local snapTick = 0
        while DoesEntityExist(ped) and SpawnedTpNpcs[npcData.id] == ped do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            snapTick = snapTick + 1
            if snapTick >= 5 then
                snapTick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 then
                    if math.abs(gz - cz) > 0.15 then
                        SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                        finalZ = gz
                    end
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, npcData.x, npcData.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

-- ─── Sync serveur ─────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:syncSafezones', function(szList)
    SafeZones = {}
    for _, z in ipairs(szList) do SafeZones[z.id] = z end
    UpdateSafeZoneBlips()
    print('[gfx-redzone] syncSafezones recu : ' .. #szList .. ' safezone(s)')
end)

RegisterNetEvent('gfx-redzone:syncTpNpcs', function(npcList)
    TpNpcSyncGen = TpNpcSyncGen + 1
    local gen = TpNpcSyncGen

    for _, ped in pairs(SpawnedTpNpcs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    SpawnedTpNpcs = {}
    TpNpcs        = {}

    print('[gfx-redzone] syncTpNpcs recu : ' .. #npcList .. ' NPC(s)')
    if #npcList == 0 then return end

    -- Déduplique par proximité < 2m (comme viperpvp_redzone)
    local deduped = {}
    for _, n in ipairs(npcList) do
        local dup = false
        for _, kept in ipairs(deduped) do
            if #(vector3(n.x, n.y, n.z) - vector3(kept.x, kept.y, kept.z)) < 2.0 then
                dup = true; break
            end
        end
        if not dup then deduped[#deduped + 1] = n end
    end

    print('[gfx-redzone] ' .. #deduped .. ' NPC(s) TP apres dedup, spawn en cours...')
    for _, n in ipairs(deduped) do
        TpNpcs[n.id] = n
        SpawnTpNpc(n, gen)
    end
end)

-- ─── Init ─────────────────────────────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(1000)
    TriggerServerEvent('gfx-redzone:requestSafezoneSync')
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('gfx-redzone:requestSafezoneSync')
end)

-- ─── Détection InSafeZone ─────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(500)
        local coords = GetEntityCoords(PlayerPedId())
        local inSz   = false
        for _, z in pairs(SafeZones) do
            if z.active then
                local dx = coords.x - z.x
                local dy = coords.y - z.y
                if (dx*dx + dy*dy) <= (z.radius * z.radius) then inSz = true; break end
            end
        end
        local ped = PlayerPedId()
        if inSz ~= InSafeZone then
            InSafeZone = inSz
            SetEntityInvincible(ped, inSz)
            SetEntityCanBeDamaged(ped, not inSz)
            if inSz then
                QBCore.Functions.Notify("Zone sécurisée — tir désactivé.", 'primary', 4000)
                if IsCarrying then
                    IsCarrying = false
                    TriggerServerEvent('gfx-redzone:carry:stop')
                    QBCore.Functions.Notify("Portage arrêté (safezone).", 'error', 3000)
                end
            else
                SetEntityInvincible(ped, false)
                SetEntityCanBeDamaged(ped, true)
                QBCore.Functions.Notify("Vous quittez la zone sécurisée.", 'primary', 3000)
            end
        end
        -- Maintien continu en safezone
        if InSafeZone then
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)
        end
    end
end)

-- ─── Bloquer tir en safezone ──────────────────────────────────────────────────

CreateThread(function()
    while true do
        if InSafeZone then
            Wait(0)
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24,  true)
            DisableControlAction(0, 257, true)
        else
            Wait(200)
        end
    end
end)

-- ─── NPC TP : hologramme + marqueur + touche E ───────────────────────────────

CreateThread(function()
    while true do
        if next(SpawnedTpNpcs) == nil then
            Wait(500)
        else
            Wait(0)
            local myCoords = GetEntityCoords(PlayerPedId())
            local nearId   = nil
            local minDist  = 3.0

            for id, ped in pairs(SpawnedTpNpcs) do
                if DoesEntityExist(ped) then
                    local c = GetEntityCoords(ped)
                    local d = #(myCoords - c)

                    if d < 25.0 then
                        DrawHoloText(c.x, c.y, c.z, 'TP SAFEZONE')
                    end

                    if d < minDist then
                        minDist = d
                        nearId  = id
                    end
                end
            end

            if nearId then
                local npc    = TpNpcs[nearId]
                local npcPed = SpawnedTpNpcs[nearId]
                if npc then
                    local pedCoords = npcPed and DoesEntityExist(npcPed) and GetEntityCoords(npcPed) or vector3(npc.x, npc.y, npc.z)
                    local pulse = (math.sin(GetGameTimer() / 400.0) + 1.0) * 0.5
                    DrawMarker(28, pedCoords.x, pedCoords.y, pedCoords.z - 0.95, 0,0,0, 0,0,0,
                        0.8 + pulse*0.15, 0.8 + pulse*0.15, 0.06,
                        57, 255, 20, math.floor((100 + 60*pulse)*0.4), false, false, 2, false, nil, nil, false)
                end

                if not TpSelectOpen then
                    -- Prompt [E]
                    SetTextScale(0.4, 0.4)
                    SetTextFont(0)
                    SetTextProportional(true)
                    SetTextColour(255, 255, 255, 220)
                    SetTextOutline()
                    SetTextEntry('STRING')
                    SetTextCentre(true)
                    AddTextComponentString('[E] Teleporter')
                    DrawText(0.5, 0.9)

                    if IsControlJustPressed(0, 38) then
                        local szList = {}
                        for _, z in pairs(SafeZones) do
                            -- Destination = NPC dans cette safezone, sinon centre
                            local destX, destY, destZ = z.x, z.y, z.z
                            for _, n in pairs(TpNpcs) do
                                local d = #(vector3(n.x, n.y, n.z) - vector3(z.x, z.y, z.z))
                                if d <= (z.radius or 60.0) then
                                    destX, destY, destZ = n.x, n.y, n.z; break
                                end
                            end
                            szList[#szList + 1] = { id = z.id, name = z.name or 'Safezone', x = destX, y = destY, z = destZ }
                        end
                        table.sort(szList, function(a, b) return a.name < b.name end)
                        if #szList == 0 then
                            QBCore.Functions.Notify("Aucune safezone configurée.", 'error', 3000)
                        else
                            TpSelectOpen = true
                            SetNuiFocus(true, true)
                            SendNUIMessage({ type = 'tpSelect', zones = szList })
                        end
                    end
                end
            end
        end
    end
end)

-- ─── NUI Callbacks ────────────────────────────────────────────────────────────

RegisterNUICallback('tpSelectClose', function(_, cb)
    TpSelectOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('tpToSafezone', function(data, cb)
    TpSelectOpen = false
    SetNuiFocus(false, false)
    cb('ok')
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not x then
        -- Fallback : chercher par id
        local targetId = tonumber(data.id)
        if targetId and SafeZones[targetId] then
            local tz = SafeZones[targetId]
            x, y, z = tz.x, tz.y, tz.z
            for _, n in pairs(TpNpcs) do
                local d = #(vector3(n.x, n.y, n.z) - vector3(tz.x, tz.y, tz.z))
                if d <= (tz.radius or 60.0) then x, y, z = n.x, n.y, n.z; break end
            end
        end
    end
    if not x then return end
    SetEntityCoords(PlayerPedId(), x, y, z, false, false, false, false)
    QBCore.Functions.Notify("Téléporté vers la safezone.", 'primary', 2000)
end)
