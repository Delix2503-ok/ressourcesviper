-- Table de tous les PNJ actifs : { [dbId] = pedHandle }
local chestPeds = {}
local textShown = false

-- ----------------------------------------------------------------
-- Texte 3D flottant au-dessus du PNJ
-- ----------------------------------------------------------------
local function drawPedLabel(x, y, z)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.25)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - vector3(x, y, z))
    if dist > 25.0 then return end

    local scale = math.min((1 / dist) * 2.8, 0.6)
    local fov   = (1 / GetGameplayCamFov()) * 100
    scale       = scale * fov

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
    AddTextComponentSubstringPlayerName('COFFRES')
    EndTextCommandDisplayText(sx, sy)
end

-- ----------------------------------------------------------------
-- Spawn d'un PNJ individuel + snap au sol
-- ----------------------------------------------------------------
local function spawnSinglePed(data)
    -- Supprime l'éventuel PNJ déjà présent pour cet ID
    if chestPeds[data.id] and DoesEntityExist(chestPeds[data.id]) then
        DeleteEntity(chestPeds[data.id])
        chestPeds[data.id] = nil
    end

    if not data.model or data.model == '' then data.model = 's_m_y_dealer_01' end
    local model = GetHashKey(data.model)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    if not HasModelLoaded(model) then return end

    local ped = CreatePed(4, model, data.x, data.y, data.z, data.heading, false, true)

    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 292, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    -- NE PAS désactiver la collision ici : SetEntityOnGroundProperly en a besoin
    TaskStandStill(ped, -1)
    SetModelAsNoLongerNeeded(model)

    chestPeds[data.id] = ped

    -- Thread : attend la collision, pose sur le sol, GEL, PUIS désactive la collision
    CreateThread(function()
        -- Attend que la collision du monde soit chargée autour du ped
        local wait = 0
        while DoesEntityExist(ped) and wait < 50 do
            if HasCollisionLoadedAroundEntity(ped) then break end
            Wait(200)
            wait = wait + 1
        end

        -- Snap au sol — borne serrée : gz doit être à ±0.5-1m du z enregistré
        local finalZ  = data.z
        local snapped = false
        for _ = 1, 30 do
            if not DoesEntityExist(ped) then return end
            local found, gz = GetGroundZFor_3dCoord(data.x, data.y, data.z + 10.0, false)
            if found and gz > 0.0 and gz >= data.z - 2.0 and gz <= data.z + 1.0 then
                SetEntityCoords(ped, data.x, data.y, gz, false, false, false, false)
                finalZ  = gz
                snapped = true
                break
            end
            Wait(200)
        end
        -- Snap invalide ou introuvable → forcer la position exacte enregistrée
        if not snapped and DoesEntityExist(ped) then
            SetEntityCoords(ped, data.x, data.y, data.z, false, false, false, false)
        end

        if not DoesEntityExist(ped) then return end

        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)

        local snapTick = 0
        while DoesEntityExist(ped) do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            snapTick = snapTick + 1
            if snapTick >= 5 then
                snapTick = 0
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local found, gz = GetGroundZFor_3dCoord(cx, cy, cz + 5.0, false)
                if found and gz > 0.0 and gz >= data.z - 2.0 and gz <= data.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                    finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, data.x, data.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

-- ----------------------------------------------------------------
-- Synchronisation complète de la liste des PNJ (reçue du serveur)
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:syncPeds', function(peds)
    -- Supprime tous les PNJ existants
    for id, handle in pairs(chestPeds) do
        if DoesEntityExist(handle) then DeleteEntity(handle) end
    end
    chestPeds = {}

    -- Respawn de tous les PNJ
    for _, pedData in ipairs(peds) do
        spawnSinglePed(pedData)
    end
end)

-- Suppression ciblée d'un PNJ par son ID de BDD
RegisterNetEvent('vipergun:removePedById', function(pedId)
    if chestPeds[pedId] and DoesEntityExist(chestPeds[pedId]) then
        DeleteEntity(chestPeds[pedId])
        chestPeds[pedId] = nil
    end
end)

-- ----------------------------------------------------------------
-- Boucle d'interaction (gère plusieurs PNJ)
-- ----------------------------------------------------------------
CreateThread(function()
    while true do
        -- Ralentit quand aucun PNJ n'est présent
        if not next(chestPeds) then
            Wait(1000)
        else
            Wait(0)

            local playerCoords = GetEntityCoords(PlayerPedId())
            local closest      = nil
            local closestDist  = Config.Coffres.interactionDistance + 0.1

            for id, handle in pairs(chestPeds) do
                if DoesEntityExist(handle) then
                    local d = #(GetEntityCoords(handle) - playerCoords)
                    if d < closestDist then
                        closestDist = d
                        closest     = id
                    end
                end
            end

            -- Dessine le label 3D au-dessus de chaque PNJ visible
            for _, handle in pairs(chestPeds) do
                if DoesEntityExist(handle) then
                    local c = GetEntityCoords(handle)
                    drawPedLabel(c.x, c.y, c.z)
                end
            end

            if closest then
                if not textShown then
                    lib.showTextUI('[E] Ouvrir les coffres', { position = 'left-center', icon = 'box-open' })
                    textShown = true
                end
                if IsControlJustPressed(0, 38) then
                    TriggerEvent('vipergun:openCoffresMenu')
                end
            else
                if textShown then
                    lib.hideTextUI()
                    textShown = false
                end
            end
        end
    end
end)

-- ----------------------------------------------------------------
-- Requête au serveur : envoie tous les PNJ au joueur qui rejoint
-- ----------------------------------------------------------------
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('vipergun:requestPedSpawn')
end)

TriggerServerEvent('vipergun:requestPedSpawn')

-- ----------------------------------------------------------------
-- Nettoyage
-- ----------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, handle in pairs(chestPeds) do
        if DoesEntityExist(handle) then DeleteEntity(handle) end
    end
    if textShown then lib.hideTextUI() end
end)
