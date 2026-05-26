local QBCore    = exports['qb-core']:GetCoreObject()
local NPCList   = {}
local NPCPeds   = {}
local NPCSpawning = {}  -- garde : évite plusieurs threads de spawn pour le même NPC

local placing    = 'IDLE'
local pendingNPC = {}
local lastMenuTime = 0   -- cooldown anti-spam menu (remplace menuOpen)

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function applyPedFlags(ped)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeDraggedOut(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, false)
    SetEntityCollision(ped, false, false)  -- on peut passer à travers
    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)
end

local function spawnPed(npc)
    local model = GetHashKey(Config.NpcModel)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) do
        if GetGameTimer() - t > 10000 then return end
        Wait(100)
    end

    local ped = CreatePed(4, model, npc.x, npc.y, npc.z, npc.heading, false, true)
    NPCPeds[npc.id] = ped
    SetModelAsNoLongerNeeded(model)

    -- Flags de comportement — collision reste ON pour le snap au sol
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeDraggedOut(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, false)
    TaskStandStill(ped, -1)

    -- Attendre que la collision du monde soit chargée
    local w = 0
    while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
        Wait(200)
        w = w + 1
    end

    local finalZ  = npc.z
    local snapped = false
    for _ = 1, 30 do
        if not DoesEntityExist(ped) then return end
        local found, gz = GetGroundZFor_3dCoord(npc.x, npc.y, npc.z + 10.0, false)
        if found and gz > 0.0 and gz >= npc.z - 2.0 and gz <= npc.z + 1.0 then
            SetEntityCoords(ped, npc.x, npc.y, gz, false, false, false, false)
            finalZ  = gz
            snapped = true
            break
        end
        Wait(200)
    end
    if not snapped and DoesEntityExist(ped) then
        SetEntityCoords(ped, npc.x, npc.y, npc.z, false, false, false, false)
    end

    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)
    end

    Citizen.CreateThread(function()
        local snapTick = 0
        while DoesEntityExist(ped) and NPCPeds[npc.id] == ped do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            snapTick = snapTick + 1
            if snapTick >= 5 then
                snapTick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= npc.z - 2.0 and gz <= npc.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                    finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, npc.x, npc.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

local function deletePed(id)
    if NPCPeds[id] and DoesEntityExist(NPCPeds[id]) then
        DeleteEntity(NPCPeds[id])
    end
    NPCPeds[id] = nil
end

-- ─── Hologramme ───────────────────────────────────────────────────────────────

local function drawHologram(coords, dist)
    if dist < 20.0 then
        local t     = GetGameTimer() / 1000.0
        local pulse = (math.sin(t * 2.5) + 1.0) * 0.5
        local alpha = math.floor(160 + 95 * pulse)
        DrawMarker(28, coords.x, coords.y, coords.z - 0.95,
            0.0,0.0,0.0, 0.0,0.0,0.0, 0.8,0.8,0.06,
            Config.HologramColor.r, Config.HologramColor.g, Config.HologramColor.b,
            math.floor(alpha*0.4), false,false,2,false,nil,nil,false)
    end

    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z + 1.25)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoords()
    local d = #(camCoords - vector3(coords.x, coords.y, coords.z))
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
    AddTextComponentSubstringPlayerName('GARAGE')
    EndTextCommandDisplayText(sx, sy)
end

local function drawHint(text)
    SetTextFont(0) SetTextProportional(1) SetTextScale(0.38, 0.38)
    SetTextColour(255,255,255,230) SetTextDropShadow() SetTextOutline()
    SetTextEntry('STRING') AddTextComponentString(text) DrawText(0.5, 0.88)
end

-- ─── Menu véhicule (ox_lib) ───────────────────────────────────────────────────

local function openVehicleMenu(npc)
    local options = {}
    for _, v in ipairs(Config.Vehicles) do
        local vData   = v
        local npcData = npc
        options[#options + 1] = {
            title       = vData.label,
            description = vData.desc .. ' — Gratuit',
            icon        = vData.icon,
            onSelect    = function()
                local idx = math.random(1, 4)
                TriggerServerEvent('vipercar:server:SpawnVehicle', vData.model, {
                    x       = npcData['spawn_x'       .. idx],
                    y       = npcData['spawn_y'       .. idx],
                    z       = npcData['spawn_z'       .. idx],
                    heading = npcData['spawn_heading' .. idx],
                })
            end,
        }
    end
    lib.registerContext({ id = 'vipercar_pick_'..npc.id, title = '  Choisir un vehicule', options = options })
    lib.showContext('vipercar_pick_'..npc.id)
end

-- ─── Panel admin (ox_lib) ─────────────────────────────────────────────────────

local function openAdminMenu(npcs)
    local options = {
        {
            title       = 'Ajouter un PNJ',
            description = 'Placer un nouveau PNJ vendeur de vehicules',
            icon        = 'fa-solid fa-plus',
            onSelect    = function()
                local input = lib.inputDialog('Nouveau PNJ', {
                    { type = 'input', label = 'Nom du garage', placeholder = 'Ex: Garage Principal', required = true, min = 1, max = 32 }
                })
                if not input or not input[1] or input[1] == '' then return end
                placing    = 'NPC'
                pendingNPC = { name = input[1] }
                QBCore.Functions.Notify('Allez a la position du PNJ et appuyez ~g~[E]~w~ | ~r~[X]~w~ Annuler', 'primary', 7000)
            end,
        },
    }

    if #npcs == 0 then
        options[#options + 1] = {
            title       = 'Aucun PNJ deploye',
            description = 'Utilisez "Ajouter un PNJ" pour en creer un',
            icon        = 'fa-solid fa-circle-info',
            disabled    = true,
        }
    else
        for _, npc in ipairs(npcs) do
            local n = npc
            options[#options + 1] = {
                title       = 'Supprimer — ' .. (n.name or 'PNJ #' .. n.id),
                description = ('Position : X:%.1f  Y:%.1f  Z:%.1f'):format(n.x, n.y, n.z),
                icon        = 'fa-solid fa-trash',
                iconColor   = '#ff3a3a',
                onSelect    = function()
                    lib.registerContext({
                        id      = 'vipercar_confirm_del',
                        title   = 'Confirmer la suppression',
                        options = {
                            {
                                title     = 'Supprimer le PNJ #' .. n.id,
                                icon      = 'fa-solid fa-trash',
                                iconColor = '#ff3a3a',
                                onSelect  = function()
                                    TriggerServerEvent('vipercar:server:DeleteNPC', n.id)
                                    QBCore.Functions.Notify((n.name or 'PNJ #'..n.id)..' supprime', 'success', 3000)
                                end,
                            },
                            {
                                title    = 'Annuler',
                                icon     = 'fa-solid fa-xmark',
                                onSelect = function()
                                    lib.showContext('vipercar_admin')
                                end,
                            },
                        },
                    })
                    lib.showContext('vipercar_confirm_del')
                end,
            }
        end
    end

    lib.registerContext({ id = 'vipercar_admin', title = '  ViperCar — Admin', options = options })
    lib.showContext('vipercar_admin')
end

-- ─── Boucle principale ────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if #NPCList == 0 then Wait(500) end

        local playerPed    = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearNPC      = nil

        for _, npc in ipairs(NPCList) do
            local npcPos = vector3(npc.x, npc.y, npc.z)
            local dist   = #(playerCoords - npcPos)

            drawHologram(npcPos, dist)

            local ped = NPCPeds[npc.id]
            if not (ped and DoesEntityExist(ped)) and not NPCSpawning[npc.id] then
                NPCPeds[npc.id] = nil
                NPCSpawning[npc.id] = true
                Citizen.CreateThread(function()
                    spawnPed(npc)
                    NPCSpawning[npc.id] = nil
                end)
            end

            if ped and DoesEntityExist(ped) and dist < Config.InteractionDistance then
                nearNPC = npc
            end
        end

        -- Interaction : cooldown 1.5s au lieu d'un booléen qui peut se bloquer
        local canMenu = GetGameTimer() - lastMenuTime > 1500
        if nearNPC and canMenu and not IsPedInAnyVehicle(playerPed, false) then
            drawHint('~g~[E]~w~ Choisir un vehicule')
            if IsControlJustPressed(0, 38) then
                lastMenuTime = GetGameTimer()
                openVehicleMenu(nearNPC)
            end
        end
    end
end)

-- ─── Thread : maintenir les flags du ped toutes les 2s ───────────────────────

Citizen.CreateThread(function()
    while true do
        Wait(2000)
        for id, ped in pairs(NPCPeds) do
            if type(id) == 'number' and ped and DoesEntityExist(ped) then
                applyPedFlags(ped)
            end
        end
    end
end)

-- ─── Boucle placement admin ───────────────────────────────────────────────────

local placingHints = {
    NPC    = 'Position du PNJ — ~g~[E]~w~ confirmer | ~r~[X]~w~ Annuler',
    SPAWN1 = 'Point spawn 1/4 — ~g~[E]~w~ confirmer | ~r~[X]~w~ Annuler',
    SPAWN2 = 'Point spawn 2/4 — ~g~[E]~w~ confirmer | ~r~[X]~w~ Annuler',
    SPAWN3 = 'Point spawn 3/4 — ~g~[E]~w~ confirmer | ~r~[X]~w~ Annuler',
    SPAWN4 = 'Point spawn 4/4 — ~g~[E]~w~ confirmer | ~r~[X]~w~ Annuler',
}

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if placing == 'IDLE' then Wait(200) end

        if placing ~= 'IDLE' then
            drawHint(placingHints[placing] or '')

            if IsControlJustPressed(0, 38) then
                local c = GetEntityCoords(PlayerPedId())
                local h = GetEntityHeading(PlayerPedId())

                if placing == 'NPC' then
                    pendingNPC.x       = c.x
                    pendingNPC.y       = c.y
                    pendingNPC.z       = c.z
                    pendingNPC.heading = h
                    placing = 'SPAWN1'
                    QBCore.Functions.Notify('PNJ place ! Point spawn ~g~1/4~w~ — appuyez [E]', 'primary', 5000)

                elseif placing == 'SPAWN1' then
                    pendingNPC.spawn_x1       = c.x
                    pendingNPC.spawn_y1       = c.y
                    pendingNPC.spawn_z1       = c.z
                    pendingNPC.spawn_heading1 = h
                    placing = 'SPAWN2'
                    QBCore.Functions.Notify('Spawn 1/4 ok ! Point ~g~2/4~w~ — appuyez [E]', 'primary', 5000)

                elseif placing == 'SPAWN2' then
                    pendingNPC.spawn_x2       = c.x
                    pendingNPC.spawn_y2       = c.y
                    pendingNPC.spawn_z2       = c.z
                    pendingNPC.spawn_heading2 = h
                    placing = 'SPAWN3'
                    QBCore.Functions.Notify('Spawn 2/4 ok ! Point ~g~3/4~w~ — appuyez [E]', 'primary', 5000)

                elseif placing == 'SPAWN3' then
                    pendingNPC.spawn_x3       = c.x
                    pendingNPC.spawn_y3       = c.y
                    pendingNPC.spawn_z3       = c.z
                    pendingNPC.spawn_heading3 = h
                    placing = 'SPAWN4'
                    QBCore.Functions.Notify('Spawn 3/4 ok ! Dernier point ~g~4/4~w~ — appuyez [E]', 'primary', 5000)

                elseif placing == 'SPAWN4' then
                    pendingNPC.spawn_x4       = c.x
                    pendingNPC.spawn_y4       = c.y
                    pendingNPC.spawn_z4       = c.z
                    pendingNPC.spawn_heading4 = h
                    placing = 'IDLE'
                    TriggerServerEvent('vipercar:server:AddNPC', pendingNPC)
                    pendingNPC = {}
                    QBCore.Functions.Notify('PNJ cree avec succes !', 'success', 4000)
                end

            elseif IsControlJustPressed(0, 76) then
                placing    = 'IDLE'
                pendingNPC = {}
                QBCore.Functions.Notify('Placement annule', 'error', 3000)
            end
        end
    end
end)

-- ─── Événements réseau ────────────────────────────────────────────────────────

RegisterNetEvent('vipercar:client:LoadNPCs', function(npcs)
    for id, ped in pairs(NPCPeds) do
        if type(id) == 'number' and ped and DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    NPCPeds = {}
    NPCSpawning = {}
    -- Déduplique : ignore tout NPC à moins de 2m d'un déjà accepté
    local deduped = {}
    for _, npc in ipairs(npcs) do
        local duplicate = false
        for _, kept in ipairs(deduped) do
            if #(vector3(npc.x, npc.y, npc.z) - vector3(kept.x, kept.y, kept.z)) < 2.0 then
                duplicate = true
                break
            end
        end
        if not duplicate then
            deduped[#deduped + 1] = npc
        end
    end
    NPCList = deduped
    -- Le spawn est géré exclusivement par la boucle principale (avec le garde NPCSpawning)
end)

RegisterNetEvent('vipercar:client:SpawnNPC', function(npc)
    for _, n in ipairs(NPCList) do
        if n.id == npc.id then return end
    end
    NPCList[#NPCList + 1] = npc
    Citizen.CreateThread(function() spawnPed(npc) end)
end)

RegisterNetEvent('vipercar:client:RemoveNPC', function(id)
    deletePed(id)
    for i, npc in ipairs(NPCList) do
        if npc.id == id then table.remove(NPCList, i) break end
    end
end)

RegisterNetEvent('vipercar:client:OpenAdmin', function(npcs)
    NPCList = npcs
    openAdminMenu(npcs)
end)

RegisterNetEvent('vipercar:client:AdminNPCCreated', function(npc)
    openAdminMenu(NPCList)
end)

RegisterNetEvent('vipercar:client:DoSpawnVehicle', function(model, spawnData)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 10000 then
            QBCore.Functions.Notify('Modele introuvable', 'error', 3000)
            return
        end
        Wait(100)
    end
    local veh = CreateVehicle(hash, spawnData.x, spawnData.y, spawnData.z, spawnData.heading, true, false)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    Wait(200)
    local plate = QBCore.Functions.GetPlate(veh)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
    SetVehicleEngineOn(veh, true, true, false)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    SetEntityAsMissionEntity(veh, true, true)
    SetModelAsNoLongerNeeded(hash)
    QBCore.Functions.Notify('Vehicule spawne !', 'success', 3000)
end)

-- ─── Commande admin ───────────────────────────────────────────────────────────

RegisterCommand('vipercaradmin', function()
    TriggerServerEvent('vipercar:server:CheckAdmin')
end, false)

-- ─── Chargement initial ───────────────────────────────────────────────────────
-- Un seul GetNPCs au démarrage : onClientResourceStart a priorité.
-- Si les deux events se déclenchent (restart + reconnect), le flag évite le double spawn.

local npcLoaded = false

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(1000)
    npcLoaded = true
    TriggerServerEvent('vipercar:server:GetNPCs')
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    if npcLoaded then return end  -- déjà envoyé par onClientResourceStart
    npcLoaded = true
    TriggerServerEvent('vipercar:server:GetNPCs')
end)
