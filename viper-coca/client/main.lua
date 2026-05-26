local QBCore = exports['qb-core']:GetCoreObject()

-- ─── État ─────────────────────────────────────────────────────────────────────
local Zone      = nil
local SellNpc   = nil
local SellPrice = 0

local CocaBlips  = {}
local SpawnedNpc = nil
local NpcSyncGen = 0

local InZone      = false
local NuiOpen     = false
local lastCollect = 0
local isCollecting = false

local COLLECT_DICT = 'amb@world_human_gardener_plant@male@base'
local COLLECT_CLIP = 'base'

-- ─── Touche X : annuler la récolte ────────────────────────────────────────────

RegisterCommand('+cancelCollect', function()
    if isCollecting then
        isCollecting = false
        ClearPedTasks(PlayerPedId())
    end
end, false)
RegisterCommand('-cancelCollect', function() end, false)  -- évite le message dans le chat au relâchement
RegisterKeyMapping('+cancelCollect', 'Annuler la récolte cocaine', 'keyboard', 'x')

-- ─── Sync ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('vipercoca:sync', function(data)
    Zone      = (data.zone and data.zone.x) and data.zone or nil
    SellNpc   = (data.npc  and data.npc.x)  and data.npc  or nil
    SellPrice = data.price or 0

    RefreshBlip()
    RespawnNpc()

    if NuiOpen then
        SendNUIMessage({ action = 'update', data = data })
    end
end)

-- ─── Retours serveur : récolte ────────────────────────────────────────────────

RegisterNetEvent('vipercoca:collected', function(amount)
    lib.notify({ title = 'Cocaine', description = ('+ %d cocaine'):format(amount), type = 'success', duration = 2500 })
    isCollecting = false
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('vipercoca:collectFull', function()
    lib.notify({ title = 'Cocaine', description = 'Inventaire plein.', type = 'error', duration = 3000 })
    isCollecting = false
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('vipercoca:collectFail', function(reason)
    lib.notify({ title = 'Cocaine', description = reason or 'Erreur.', type = 'error', duration = 3000 })
    isCollecting = false
    ClearPedTasks(PlayerPedId())
end)

-- ─── Blips carte (même pattern que viperpvp_redzone) ─────────────────────────
-- viper-hud cache les sprites 2-826 → on utilise sprite 1 (exclu du nettoyage)

function RefreshBlip()
    for _, b in pairs(CocaBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    CocaBlips = {}

    -- ── Blip revendeur (jaune) ──
    if SellNpc and SellNpc.x then
        local npin = AddBlipForCoord(SellNpc.x, SellNpc.y, SellNpc.z)
        SetBlipSprite(npin, 1)
        SetBlipScale(npin, 1.1)
        SetBlipColour(npin, 5)        -- jaune
        SetBlipAlpha(npin, 255)
        SetBlipAsShortRange(npin, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Revendeur Cocaine')
        EndTextCommandSetBlipName(npin)
        CocaBlips[#CocaBlips + 1] = npin
    end

    if not Zone or not Zone.active then return end

    -- ── Centre zone récolte (bleu) ──
    local pin = AddBlipForCoord(Zone.x, Zone.y, Zone.z)
    SetBlipSprite(pin, 1)
    SetBlipScale(pin, 1.2)
    SetBlipColour(pin, 3)        -- bleu
    SetBlipAlpha(pin, 255)
    SetBlipAsShortRange(pin, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Récolte Cocaine')
    EndTextCommandSetBlipName(pin)
    CocaBlips[#CocaBlips + 1] = pin

    -- ── Cercle minimap (bleu) ──
    local bRadar = AddBlipForRadius(Zone.x, Zone.y, Zone.z, Zone.radius)
    SetBlipColour(bRadar, 3)     -- bleu
    SetBlipAlpha(bRadar, 160)
    SetBlipDisplay(bRadar, 2)
    CocaBlips[#CocaBlips + 1] = bRadar

    -- ── Périmètre grande carte (bleu) ──
    local pts  = math.min(80, math.max(32, math.floor(Zone.radius / 9)))
    local step = (2 * math.pi) / pts
    for i = 0, pts - 1 do
        local a   = i * step
        local bPt = AddBlipForCoord(
            Zone.x + Zone.radius * math.cos(a),
            Zone.y + Zone.radius * math.sin(a),
            Zone.z
        )
        SetBlipSprite(bPt, 1)
        SetBlipColour(bPt, 3)    -- bleu
        SetBlipAlpha(bPt, 220)
        SetBlipScale(bPt, 0.65)
        SetBlipAsShortRange(bPt, false)
        CocaBlips[#CocaBlips + 1] = bPt
    end
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    local cam  = GetGameplayCamCoords()
    local dist = #(vector3(cam.x, cam.y, cam.z) - vector3(x, y, z))
    local scale = math.min(1.0 / dist * 2.0, 0.55)
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextColour(57, 255, 20, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- ─── Animation de récolte ─────────────────────────────────────────────────────

local function StartCollecting()
    isCollecting = true
    lastCollect  = GetGameTimer()

    CreateThread(function()
        local ped = PlayerPedId()

        RequestAnimDict(COLLECT_DICT)
        local t = 0
        while not HasAnimDictLoaded(COLLECT_DICT) and t < 30 do
            Wait(50); t = t + 1
        end

        if not isCollecting then return end

        TaskPlayAnim(ped, COLLECT_DICT, COLLECT_CLIP, 8.0, -8.0, -1, 1, 0, false, false, false)

        local elapsed = 0
        while isCollecting and elapsed < Config.CollectCooldown do
            Wait(100)
            elapsed = elapsed + 100
        end

        if isCollecting then
            TriggerServerEvent('vipercoca:collect')
            -- isCollecting et ClearPedTasks gérés par les retours serveur
            -- (vipercoca:collected / vipercoca:collectFull / vipercoca:collectFail)
        else
            -- Annulé par X ou sortie de zone
            ClearPedTasks(ped)
        end
    end)
end

-- ─── Spawn PNJ revendeur (même pattern que vipergun/viperpvp_redzone) ─────────

local function SpawnSellNpc(npcData, gen)
    CreateThread(function()
        if SpawnedNpc and DoesEntityExist(SpawnedNpc) then
            DeleteEntity(SpawnedNpc); SpawnedNpc = nil
        end

        local model = GetHashKey('s_m_y_dealer_01')
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 40 do Wait(50); t = t + 1 end
        if not HasModelLoaded(model) then return end
        if gen ~= NpcSyncGen then SetModelAsNoLongerNeeded(model); return end

        local ped = CreatePed(4, model, npcData.x, npcData.y, npcData.z, npcData.heading, false, true)
        SetModelAsNoLongerNeeded(model)

        SetEntityInvincible(ped, true)
        SetEntityCanBeDamaged(ped, false)
        SetPedCanRagdoll(ped, false)
        SetPedCanBeDraggedOut(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, false)
        SetEntityAsMissionEntity(ped, true, true)
        TaskStandStill(ped, -1)

        local w = 0
        while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
            Wait(200); w = w + 1
        end

        local finalZ = npcData.z
        local snapped = false
        for _ = 1, 30 do
            if not DoesEntityExist(ped) then return end
            local found, gz = GetGroundZFor_3dCoord(npcData.x, npcData.y, npcData.z + 10.0, false)
            if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 then
                SetEntityCoords(ped, npcData.x, npcData.y, gz, false, false, false, false)
                finalZ = gz; snapped = true; break
            end
            Wait(200)
        end
        if not snapped and DoesEntityExist(ped) then
            SetEntityCoords(ped, npcData.x, npcData.y, npcData.z, false, false, false, false)
        end

        if gen ~= NpcSyncGen then
            if DoesEntityExist(ped) then DeleteEntity(ped) end; return
        end

        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            TaskStandStill(ped, -1)
        end

        SpawnedNpc = ped

        local tick = 0
        while DoesEntityExist(ped) and SpawnedNpc == ped do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            tick = tick + 1
            if tick >= 5 then
                tick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false); finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, npcData.x, npcData.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

function RespawnNpc()
    NpcSyncGen = NpcSyncGen + 1
    local gen = NpcSyncGen
    if SpawnedNpc and DoesEntityExist(SpawnedNpc) then
        DeleteEntity(SpawnedNpc); SpawnedNpc = nil
    end
    if not SellNpc then return end
    SpawnSellNpc(SellNpc, gen)
end

-- ─── Ouverture du menu de vente (côté client, pas de roundtrip serveur) ───────

local function OpenSellMenu()
    local count = exports['ox_inventory']:Search('count', 'cocaine') or 0
    if count <= 0 then
        lib.notify({ title = 'Cocaine', description = 'Tu n\'as pas de cocaine à vendre.', type = 'error', duration = 3000 })
        return
    end

    lib.registerContext({
        id    = 'vipercoca_sell',
        title = ('Revendeur  —  %d cocaine'):format(count),
        options = {
            {
                title       = 'Vendre tout',
                description = ('%d × $%d = $%d argent sale'):format(count, SellPrice, count * SellPrice),
                icon        = 'fa-solid fa-sack-dollar',
                onSelect    = function()
                    TriggerServerEvent('vipercoca:sell', count)
                end
            },
            {
                title       = 'Vendre une quantité',
                description = 'Choisir combien vendre',
                icon        = 'fa-solid fa-hashtag',
                onSelect    = function()
                    local input = lib.inputDialog('Vendre cocaine', {
                        { type = 'number', label = ('Quantité (max %d)'):format(count), min = 1, max = count, required = true }
                    })
                    if input and input[1] then
                        TriggerServerEvent('vipercoca:sell', tonumber(input[1]))
                    end
                end
            }
        }
    })
    lib.showContext('vipercoca_sell')
end

-- ─── Thread principal ─────────────────────────────────────────────────────────

CreateThread(function()
    local uiShown = nil

    while true do
        local ped    = PlayerPedId()
        local myPos  = GetEntityCoords(ped)
        local newUI  = nil
        local draw   = false

        -- ── PNJ revendeur ──
        local nearNpc = false
        if SpawnedNpc and DoesEntityExist(SpawnedNpc) then
            local npcPos = GetEntityCoords(SpawnedNpc)
            local d = #(myPos - npcPos)
            if d < 80.0 then
                draw = true
                DrawText3D(npcPos.x, npcPos.y, npcPos.z + 1.3, 'REVENDEUR')
                DrawMarker(28, npcPos.x, npcPos.y, npcPos.z - 1.0, 0,0,0, 0,0,0,
                    0.6, 0.6, 0.15, 57, 255, 20, 180, false, true, 2, false, nil, nil, false)
            end
            if d < 3.0 then
                nearNpc = true
                newUI = 'npc'
                if IsControlJustPressed(0, 38) then
                    OpenSellMenu()
                end
            end
        end

        -- ── Zone de récolte ──
        if Zone and Zone.active then
            local zPos = vector3(Zone.x, Zone.y, Zone.z)
            local d = #(myPos - zPos)
            InZone = d <= Zone.radius

            if d < Zone.radius + 80.0 then
                draw = true
                DrawMarker(1, Zone.x, Zone.y, Zone.z - 0.5, 0,0,0, 0,0,0,
                    Zone.radius * 2.0, Zone.radius * 2.0, 1.2,
                    255, 0, 0, 35, false, false, 2, false, nil, nil, false)
            end

            if InZone and not nearNpc then
                local ready = (GetGameTimer() - lastCollect) >= Config.CollectCooldown

                if isCollecting then
                    newUI = 'collecting'
                elseif ready then
                    newUI = 'zone'
                    if IsControlJustPressed(0, 38) then
                        StartCollecting()
                    end
                end
            else
                -- Sortie de zone pendant la récolte → annule
                if isCollecting then
                    isCollecting = false
                end
            end
        else
            InZone = false
            if isCollecting then
                isCollecting = false
            end
        end

        -- ── UI ──
        if newUI ~= uiShown then
            if newUI == 'npc' then
                lib.showTextUI(('[E] Vendre cocaine ($%d/u)'):format(SellPrice))
            elseif newUI == 'zone' then
                lib.showTextUI('[E] Récolter cocaine')
            elseif newUI == 'collecting' then
                lib.showTextUI('Récolte en cours... [X] Annuler')
            else
                lib.hideTextUI()
            end
            uiShown = newUI
        end

        if draw then Wait(0) else Wait(500) end
    end
end)

-- ─── Admin panel ──────────────────────────────────────────────────────────────

RegisterCommand('cocaadmin', function()
    TriggerServerEvent('vipercoca:admin:requestPanel')
end, false)

RegisterNetEvent('vipercoca:admin:open', function(data)
    NuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNUICallback('close', function(_, cb)
    NuiOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('setZone', function(data, cb)
    local pos = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('vipercoca:admin:setZone', {
        x = pos.x, y = pos.y, z = pos.z,
        radius = tonumber(data.radius) or 30
    })
    cb({})
end)

RegisterNUICallback('toggleZone', function(_, cb)
    TriggerServerEvent('vipercoca:admin:toggleZone')
    cb({})
end)

RegisterNUICallback('spawnNpc', function(_, cb)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    TriggerServerEvent('vipercoca:admin:setNpc', {
        x = pos.x, y = pos.y, z = pos.z,
        heading = GetEntityHeading(ped)
    })
    cb({})
end)

RegisterNUICallback('deleteNpc', function(_, cb)
    TriggerServerEvent('vipercoca:admin:deleteNpc')
    cb({})
end)

RegisterNUICallback('setPrice', function(data, cb)
    TriggerServerEvent('vipercoca:admin:setPrice', tonumber(data.price) or 0)
    cb({})
end)

-- ─── Init ─────────────────────────────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(2000)
    TriggerServerEvent('vipercoca:requestSync')
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('vipercoca:requestSync')
end)
