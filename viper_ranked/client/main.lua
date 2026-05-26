local QBCore = exports['qb-core']:GetCoreObject()

exports('IsInRankedMatch', function() return InMatch end)

local NPCHandle      = nil
local NPCCoords      = nil
local InMatch        = false
local InQueue        = false
local InRematch      = false
local CurrentMatchId = nil
local DeadReported   = false
local ArenaBoundary  = nil
local BoundaryWarnStart = nil
local BoundaryActive = false
local HoloPos        = nil
local HoloTop3       = {}

local CurrentMode    = nil   -- '1v1' | '2v2' | '3v3'
local MyTeammates    = {}    -- server IDs des coéquipiers (pour anti-friendly fire)

local function Notify(title, desc, ntype, duration)
    lib.notify({ title=title, description=desc, type=ntype, duration=duration or 4000 })
end

-- ─── Hologramme NPC (style vipergun coffres) ─────────────────────────────────
local function DrawNPCHologram(x, y, z, dist)
    -- Anneau pulsant au sol (DrawMarker 28 = disque plat)
    if dist < 20.0 then
        local t     = GetGameTimer() / 1000.0
        local pulse = (math.sin(t * 2.5) + 1.0) * 0.5
        local alpha = math.floor(160 + 95 * pulse)
        DrawMarker(28, x, y, z - 0.95,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            0.8, 0.8, 0.06,
            57, 255, 20,
            math.floor(alpha * 0.4), false, false, 2, false, nil, nil, false)
    end

    -- Texte "RANKED" flottant au-dessus (style identique à vipergun)
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
    AddTextComponentSubstringPlayerName('RANKED')
    EndTextCommandDisplayText(sx, sy)
end

-- ─── Spawn PNJ ───────────────────────────────────────────────────────────────
local function SpawnNPC(coords)
    if NPCHandle and DoesEntityExist(NPCHandle) then
        DeletePed(NPCHandle)
        NPCHandle = nil
    end
    if not coords then return end
    NPCCoords = coords

    local hash = GetHashKey(Config.NPCModel)

    -- Nettoyer tout PNJ résiduel du même modèle (survit au restart ressource via MissionEntity)
    for _, p in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(p) and GetEntityModel(p) == hash then
            local d = #(GetEntityCoords(p) - vector3(coords.x, coords.y, coords.z))
            if d < 5.0 then
                SetEntityAsMissionEntity(p, true, true)
                DeletePed(p)
            end
        end
    end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 50 do Wait(100); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, coords.w, false, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, 0)
    SetEntityAsMissionEntity(ped, true, true)
    TaskStandStill(ped, -1)
    SetModelAsNoLongerNeeded(hash)
    NPCHandle = ped

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 280)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Viper Ranked')
    EndTextCommandSetBlipName(blip)

    -- Ground snap + freeze + maintenance (thread séparé pour ne pas bloquer)
    CreateThread(function()
        local w = 0
        while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
            Wait(200); w = w + 1
        end

        local snapped = false
        for _ = 1, 30 do
            if not DoesEntityExist(ped) then return end
            local found, gz = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)
            if found and gz > 0.0 and gz <= coords.z + 1.0 then
                SetEntityCoords(ped, coords.x, coords.y, gz, false, false, false, false)
                snapped = true
                break
            end
            Wait(200)
        end

        if not DoesEntityExist(ped) then return end
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        TaskStandStill(ped, -1)

        -- Boucle de maintien : GTA peut override le freeze sans ça
        while DoesEntityExist(ped) and NPCHandle == ped do
            Wait(100)
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
        end
    end)
end

RegisterNetEvent('viper_ranked:syncNPCCoords', function(coords) SpawnNPC(coords) end)

AddEventHandler('onClientResourceStart', function(name)
    if name == GetCurrentResourceName() then
        TriggerServerEvent('viper_ranked:requestNPCCoords')
        TriggerServerEvent('viper_ranked:requestHoloData')
    end
end)

-- ─── Boucle interaction PNJ ──────────────────────────────────────────────────
CreateThread(function()
    while true do
        if NPCHandle and DoesEntityExist(NPCHandle) then
            local myCoords = GetEntityCoords(PlayerPedId())
            local dist     = #(myCoords - GetEntityCoords(NPCHandle))

            if dist < 30.0 then
                -- Hologramme + interaction : nécessite un rendu frame-par-frame
                if NPCCoords then
                    DrawNPCHologram(NPCCoords.x, NPCCoords.y, NPCCoords.z, dist)
                end

                if dist < Config.InteractDistance then
                    SetTextScale(0.4, 0.4)
                    SetTextFont(0)
                    SetTextProportional(1)
                    SetTextColour(255, 255, 255, 220)
                    SetTextOutline()
                    SetTextEntry('STRING')
                    SetTextCentre(true)
                    AddTextComponentString('[E] Viper Ranked')
                    DrawText(0.5, 0.9)

                    if IsControlJustPressed(0, 38) then OpenMainMenu() end
                end

                Wait(0)
            else
                Wait(500)
            end
        else
            Wait(1000)
        end
    end
end)

-- ─── Menu principal ──────────────────────────────────────────────────────────
function OpenMainMenu()
    if InMatch  then Notify('Ranked', 'Tu es déjà en match!', 'error'); return end
    if InQueue  then Notify('Ranked', 'Tu es déjà en file — annule avec [X].', 'warning'); return end
    if InRematch then Notify('Ranked', 'Un rematch est en cours — attends ou annule avec [X].', 'warning'); return end

    lib.registerContext({
        id = 'ranked_main',
        title = '⚔️  VIPER RANKED',
        options = {
            { title='⚔️  1V1 — Solo',  description='File individuelle, 1 contre 1', disabled=InQueue,
              onSelect=function() TriggerServerEvent('viper_ranked:joinQueue','1v1') end },
            { title='⚔️  2V2 — Duo',   description='Groupe de 2, face à 2 adversaires', disabled=InQueue,
              onSelect=function() OpenGroupMenu('2v2') end },
            { title='⚔️  3V3 — Trio',  description='Groupe de 3, face à 3 adversaires', disabled=InQueue,
              onSelect=function() OpenGroupMenu('3v3') end },
            { title='🏆  Classement',  description='Top 50 des meilleurs joueurs',
              onSelect=function() TriggerServerEvent('viper_ranked:getLeaderboard') end },
            { title='🛒  Boutique',    description='Dépense tes RankedCoins',
              onSelect=function() TriggerServerEvent('viper_ranked:getShop') end },
        },
    })
    lib.showContext('ranked_main')
end

-- ─── Menu groupe ─────────────────────────────────────────────────────────────
function OpenGroupMenu(mode)
    lib.registerContext({
        id = 'ranked_group',
        title = '👥  GROUPE ' .. mode:upper(),
        options = {
            { title='📋  Créer un groupe', description='Génère un code à partager',
              onSelect=function() TriggerServerEvent('viper_ranked:createGroup', mode) end },
            { title='🔗  Rejoindre un groupe', description='Entre le code reçu par ton chef',
              onSelect=function()
                  local input = lib.inputDialog('Rejoindre un groupe', {
                      { type='input', label='Code du groupe', placeholder='ABC123', required=true, min=6, max=6 },
                  })
                  if input and input[1] then
                      TriggerServerEvent('viper_ranked:joinGroup', input[1]:upper(), mode)
                  end
              end },
        },
    })
    lib.showContext('ranked_group')
end

-- ─── Groupe / File ───────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:groupCreated', function(code, mode, maxSize)
    InQueue = true
    SendNUIMessage({ type='showGroup', code=code, mode=mode, n=1, max=maxSize })
end)

RegisterNetEvent('viper_ranked:groupJoined', function(code, mode, n, max)
    InQueue = true
    SendNUIMessage({ type='showGroup', code=code, mode=mode, n=n, max=max })
    Notify('Groupe rejoint', 'Membres : '..n..'/'..max, 'success')
end)

RegisterNetEvent('viper_ranked:groupUpdate', function(n, max)
    SendNUIMessage({ type='updateGroupCount', n=n, max=max })
end)

RegisterNetEvent('viper_ranked:groupFull', function()
    Notify('Groupe', 'Groupe complet ! Mise en file...', 'info')
end)

RegisterNetEvent('viper_ranked:queueJoined', function(mode)
    InQueue = true
    SendNUIMessage({ type='showQueue', mode=mode })
end)

RegisterNetEvent('viper_ranked:queueLeft', function()
    InQueue = false
    SendNUIMessage({ type='hideQueue' })
end)

RegisterNetEvent('viper_ranked:groupRestored', function(code, mode, n, maxSize)
    InQueue = true
    SendNUIMessage({ type='showGroup', code=code, mode=mode, n=n, max=maxSize })
    Notify('Groupe', 'Votre groupe a été restauré. Code : ' .. code, 'info')
end)

RegisterNetEvent('viper_ranked:rematchCountdown', function(seconds)
    InRematch = true
    SendNUIMessage({ type='showRematch', seconds=seconds })
end)

RegisterNetEvent('viper_ranked:rematchCancelled', function()
    InRematch = false
    SendNUIMessage({ type='hideQueue' })
end)

-- ─── Helpers redzone ─────────────────────────────────────────────────────────
-- viperpvp_redzone ressuscite immédiatement le joueur pour bloquer l'écran natif
-- et gère un état coma Lua (IsDead). La mort réelle se lit via le state bag rzDead.
local function IsRzdead()
    return LocalPlayer.state.rzDead == true
end

local function ForceExitRedzoneDeath()
    if IsRzdead() then
        TriggerEvent('redzone:revived')  -- déclenche ExitDeathState dans viperpvp_redzone
        Wait(300)
    end
end

-- ─── Match ───────────────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:matchStart', function(d)
    InMatch=true; InQueue=false; CurrentMatchId=d.matchId; DeadReported=false
    ArenaBoundary = d.boundary; BoundaryWarnStart = nil; BoundaryActive = false
    CurrentMode   = d.mode
    MyTeammates   = d.teammates or {}
    LocalPlayer.state:set('inRankedMatch', true, false)
    SendNUIMessage({ type='hideQueue' })

    ForceExitRedzoneDeath()

    local ped = PlayerPedId()
    local c   = d.spawnCoords
    if c then
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        SetEntityHeading(ped, c.w or 0.0)
    end
    SetEntityHealth(ped, 200); SetPedArmour(ped, 100)

    FreezeEntityPosition(ped, true)
    local secs = d.countdown or 3
    CreateThread(function()
        Wait(secs * 1000)
        if InMatch then FreezeEntityPosition(PlayerPedId(), false); BoundaryActive = true end
    end)
    -- Recharge les munitions de réserve une seule fois au début du freeze
    do
        local pistol50 = GetHashKey('weapon_pistol50')
        local p = PlayerPedId()
        SetPedAmmo(p, pistol50, 9999)
    end

    SendNUIMessage({ type='showScore', team1Name=d.team1Name, team2Name=d.team2Name,
                     team1Score=0, team2Score=0, round=1 })
    SendNUIMessage({ type='showCountdown', seconds=secs })
    Notify('Match!', 'Mode '..d.mode..' — Bonne chance!', 'info')
end)

RegisterNetEvent('viper_ranked:roundStart', function(d)
    DeadReported = false
    BoundaryWarnStart = nil; BoundaryActive = false
    if d.boundary then ArenaBoundary = d.boundary end
    local c = d.spawnCoords

    ForceExitRedzoneDeath()

    local ped = PlayerPedId()

    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
        NetworkResurrectLocalPlayer(c and c.x or 0, c and c.y or 0, c and c.z or 0, c and c.w or 0, true, false)
        Wait(200)
        ped = PlayerPedId()
    end

    if c then
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        SetEntityHeading(ped, c.w or 0.0)
    end
    SetEntityHealth(ped, 200); SetPedArmour(ped, 100)

    FreezeEntityPosition(ped, true)
    local secs = d.countdown or 3
    CreateThread(function()
        Wait(secs * 1000)
        if InMatch then FreezeEntityPosition(PlayerPedId(), false); BoundaryActive = true end
    end)
    -- Recharge les munitions de réserve une seule fois au début du freeze
    do
        local pistol50 = GetHashKey('weapon_pistol50')
        local p = PlayerPedId()
        SetPedAmmo(p, pistol50, 9999)
    end

    SendNUIMessage({ type='updateScore', team1Score=d.team1Score, team2Score=d.team2Score, round=d.round })
    SendNUIMessage({ type='showCountdown', seconds=secs })
end)

RegisterNetEvent('viper_ranked:updateScore', function(t1, t2, round)
    SendNUIMessage({ type='updateScore', team1Score=t1, team2Score=t2, round=round })
end)

RegisterNetEvent('viper_ranked:matchEnd', function(d)
    InMatch=false; CurrentMatchId=nil
    LocalPlayer.state:set('inRankedMatch', false, false)
    ArenaBoundary = nil; BoundaryWarnStart = nil; BoundaryActive = false
    CurrentMode = nil; MyTeammates = {}
    FreezeEntityPosition(PlayerPedId(), false)  -- toujours dégeler (ff pendant countdown, etc.)
    SendNUIMessage({ type='showResult', win=d.win,
        text=d.win and 'VICTOIRE!' or 'DÉFAITE...',
        eloChange= d.win and ('+'..d.eloGain) or ('-'..d.eloLoss),
        coins= d.coinsGain or 0,
    })
    CreateThread(function()
        Wait(3800)
        SendNUIMessage({ type='hideResult' })
        SendNUIMessage({ type='hideScore' })

        -- Sortir du deathscreen redzone avant de téléporter
        ForceExitRedzoneDeath()

        local ped = PlayerPedId()
        -- Résurrection GTA standard si encore mort (même pattern que roundStart)
        if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
            local c = GetEntityCoords(ped)
            NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), false, false)
            Wait(200)
            ped = PlayerPedId()
        end

        SetEntityHealth(ped, 200)
        SetPedArmour(ped, 100)

        local npc = d.npcCoords or NPCCoords
        if npc then
            SetEntityCoords(ped, npc.x+math.random(-2,2), npc.y+math.random(-2,2), npc.z, false,false,false,false)
        end
    end)
end)

-- ─── Leaderboard ─────────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:receiveLeaderboard', function(data)
    SendNUIMessage({ type='openHub', tab='leaderboard', rows=data })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('viper_ranked:updateLeaderboard', function(data)
    SendNUIMessage({ type='updateLeaderboard', rows=data })
end)

-- ─── Hologramme Top 3 ────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:syncHoloData', function(pos, top3)
    HoloPos  = pos
    HoloTop3 = top3 or {}
end)

local function DrawHoloLine(x, y, z, text, r, g, b, a, dist)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    local scale = math.min((1.0 / dist) * 2.2, 0.50) * (1.0 / GetGameplayCamFov()) * 100.0
    if scale < 0.10 then return end
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    while true do
        if HoloPos then
            local pc   = GetEntityCoords(PlayerPedId())
            local dist = #(pc - vector3(HoloPos.x, HoloPos.y, HoloPos.z))
            if dist < 30.0 then
                local bx, by, bz = HoloPos.x, HoloPos.y, HoloPos.z
                DrawHoloLine(bx, by, bz + 1.8, 'TOP RANKED', 255, 200, 50, 240, dist)

                local p1 = HoloTop3[1]
                local p2 = HoloTop3[2]
                local p3 = HoloTop3[3]
                if p1 then
                    DrawHoloLine(bx, by, bz + 1.3, '#1  ' .. (p1.name or '?'):sub(1,22) .. '  ' .. (p1.elo or 0) .. ' ELO', 255, 215, 0,   255, dist)
                end
                if p2 then
                    DrawHoloLine(bx, by, bz + 0.8, '#2  ' .. (p2.name or '?'):sub(1,22) .. '  ' .. (p2.elo or 0) .. ' ELO', 192, 192, 192, 230, dist)
                end
                if p3 then
                    DrawHoloLine(bx, by, bz + 0.3, '#3  ' .. (p3.name or '?'):sub(1,22) .. '  ' .. (p3.elo or 0) .. ' ELO', 205, 127, 50,  210, dist)
                end
                Wait(0)
            else
                Wait(1000)
            end
        else
            Wait(2000)
        end
    end
end)

-- ─── Boutique ────────────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:receiveShop', function(data)
    SendNUIMessage({ type='openHub', tab='shop', shopData=data })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('viper_ranked:shopBought', function(d)
    SendNUIMessage({ type='itemBought', itemId=d.itemId, newCoins=d.newCoins })
    Notify('Boutique', d.label..' obtenu!', 'success')
end)

-- ─── NUI callbacks ───────────────────────────────────────────────────────────
RegisterNUICallback('closeHub', function(_, cb)
    SetNuiFocus(false, false); cb('ok')
end)

-- Libération d'urgence du focus NUI (commande debug)
RegisterCommand('rankedclosehub', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ type='closeHub' })
end, false)

RegisterNUICallback('leaveQueue', function(_, cb)
    TriggerServerEvent('viper_ranked:leaveQueue'); cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('viper_ranked:buyItem', data.itemId); cb('ok')
end)

RegisterNUICallback('refreshLeaderboard', function(_, cb)
    cb('ok')
    TriggerServerEvent('viper_ranked:refreshLeaderboard')
end)

RegisterNUICallback('refreshShop', function(_, cb)
    cb('ok')
    TriggerServerEvent('viper_ranked:refreshShop')
end)

RegisterNetEvent('viper_ranked:updateShop', function(data)
    SendNUIMessage({ type='updateShop', shopData=data })
end)

-- ─── Anti-friendly fire (2v2 / 3v3) ─────────────────────────────────────────
-- Surveille la santé chaque frame. Si un allié cause des dégâts → restaure la santé.
CreateThread(function()
    local prevHealth = 200
    while true do
        if InMatch and (CurrentMode == '2v2' or CurrentMode == '3v3') and #MyTeammates > 0 then
            Wait(0)
            local ped = PlayerPedId()
            if not IsEntityDead(ped) and not IsPedDeadOrDying(ped, true) and not IsRzdead() then
                local hp = GetEntityHealth(ped)
                if hp < prevHealth then
                    for _, tmSrc in ipairs(MyTeammates) do
                        local pid = GetPlayerFromServerId(tmSrc)
                        if pid ~= -1 then
                            local tmPed = GetPlayerPed(pid)
                            if DoesEntityExist(tmPed) and HasEntityBeenDamagedByEntity(ped, tmPed, true) then
                                SetEntityHealth(ped, prevHealth)
                                ClearEntityLastDamageEntity(ped)
                                break
                            end
                        end
                    end
                end
                prevHealth = GetEntityHealth(ped)
            else
                prevHealth = 200
            end
        else
            prevHealth = 200
            Wait(300)
        end
    end
end)

-- ─── Ranked : headshot = kill instantané (côté ATTAQUANT, fiable à toute distance) ─
-- GetEntityLastWeaponImpactCoord + GetPedBoneCoords = détection côté attaquant.
-- Le serveur valide (même match, équipes opposées) et trigger le kill sur la victime.
CreateThread(function()
    local lastShotTime = 0
    while true do
        if InMatch and CurrentMatchId then
            Wait(0)
            local myPed = PlayerPedId()
            local now   = GetGameTimer()
            if IsPedShooting(myPed) and (now - lastShotTime) > 150 then
                local found, ix, iy, iz = GetEntityLastWeaponImpactCoord(myPed)
                if found then
                    local impactPos = vector3(ix, iy, iz)
                    for _, pid in ipairs(GetActivePlayers()) do
                        if pid ~= PlayerId() then
                            local tPed = GetPlayerPed(pid)
                            if DoesEntityExist(tPed) and not IsEntityDead(tPed) then
                                -- Bullet doit être passé près du joueur
                                if #(impactPos - GetEntityCoords(tPed)) < 2.5 then
                                    -- Vérifier que l'impact est près du bone tête (31086)
                                    local hx, hy, hz = GetPedBoneCoords(tPed, 31086, 0.0, 0.0, 0.0)
                                    if #(impactPos - vector3(hx, hy, hz)) < 0.35 then
                                        lastShotTime = now
                                        TriggerServerEvent('viper_ranked:headshot', CurrentMatchId, GetPlayerServerId(pid))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            Wait(300)
        end
    end
end)

-- Reçu par la victime quand le serveur confirme le headshot
RegisterNetEvent('viper_ranked:forceKill', function()
    if not InMatch or DeadReported then return end
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) or IsRzdead() then return end
    -- Marquer mort immédiatement (ne pas attendre le poll 300ms)
    -- pvputils ne ressuscitera pas car inRankedMatch=true
    DeadReported = true
    SetEntityHealth(ped, 0)
    TriggerServerEvent('viper_ranked:playerDied', CurrentMatchId)
end)

-- ─── Détection mort ──────────────────────────────────────────────────────────
-- IsEntityDead ne suffit pas : viperpvp_redzone ressuscite immédiatement le joueur
-- et gère l'état coma via LocalPlayer.state.rzDead (state bag synchronisé).
CreateThread(function()
    while true do
        Wait(300)
        if InMatch and CurrentMatchId and not DeadReported then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsRzdead() then
                DeadReported = true
                TriggerServerEvent('viper_ranked:playerDied', CurrentMatchId)
            end
        end
    end
end)

-- ─── Keybind X : quitter la file / annuler le rematch ───────────────────────
RegisterCommand('ranked_leavequeuebind', function()
    if InRematch then
        InRematch = false
        TriggerServerEvent('viper_ranked:cancelRematch')
        SendNUIMessage({ type='hideQueue' })
        return
    end
    if not InQueue then return end
    TriggerServerEvent('viper_ranked:leaveQueue')
end, false)

RegisterKeyMapping('ranked_leavequeuebind', 'Viper Ranked — Quitter la file d\'attente', 'keyboard', 'X')

-- ─── /ff ─────────────────────────────────────────────────────────────────────
RegisterCommand('ff', function()
    if not InMatch then Notify('Ranked', 'Tu n\'es pas en match!', 'error'); return end
    CreateThread(function()
        local r = lib.alertDialog({
            header='Abandonner le match?',
            content='Tu perdras le match et de l\'ELO.',
            centered=true, cancel=true,
            labels={ confirm='Abandonner', cancel='Annuler' },
        })
        if r == 'confirm' then TriggerServerEvent('viper_ranked:forfeit', CurrentMatchId) end
    end)
end, false)

-- ─── Nettoyage au stop ressource ─────────────────────────────────────────────
-- Libère le focus NUI pour ne pas bloquer l'inventaire après restart
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    ArenaBoundary = nil; BoundaryWarnStart = nil; BoundaryActive = false
    if NPCHandle and DoesEntityExist(NPCHandle) then
        DeleteEntity(NPCHandle)
        NPCHandle = nil
    end
end)

-- ─── Périmètre d'arène — rendu visuel ────────────────────────────────────────
CreateThread(function()
    while true do
        if InMatch and ArenaBoundary then
            local b  = ArenaBoundary
            local pc = GetEntityCoords(PlayerPedId())
            local dx = pc.x - b.x
            local dy = pc.y - b.y
            local out = (dx*dx + dy*dy) > (b.radius * b.radius)
            local r_c = out and 255 or 100
            local g_c = out and 50  or 200
            local b_c = out and 50  or 255
            local al  = out and 210 or 90
            for i = 0, 35 do
                local angle = (i / 36.0) * math.pi * 2.0
                DrawMarker(1,
                    b.x + math.cos(angle) * b.radius,
                    b.y + math.sin(angle) * b.radius,
                    b.z,
                    0.0,0.0,0.0, 0.0,0.0,0.0, 0.5,0.5,1.8,
                    r_c, g_c, b_c, al,
                    false, false, 2, false, nil, nil, false)
            end
            if out and BoundaryWarnStart then
                local rem = math.max(0, math.ceil(3.0 - (GetGameTimer() - BoundaryWarnStart) / 1000.0))
                SetTextScale(0.0, 0.6)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextColour(255, 50, 50, 255)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry('STRING')
                SetTextCentre(true)
                AddTextComponentString('HORS ZONE — ' .. rem .. 's')
                DrawText(0.5, 0.08)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ─── Périmètre d'arène — vérification ────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(300)
        if InMatch and ArenaBoundary and BoundaryActive and not DeadReported then
            local b  = ArenaBoundary
            local pc = GetEntityCoords(PlayerPedId())
            local dx = pc.x - b.x
            local dy = pc.y - b.y
            if math.sqrt(dx*dx + dy*dy) > b.radius then
                if not BoundaryWarnStart then
                    BoundaryWarnStart = GetGameTimer()
                    lib.notify({ title='⚠️ Hors zone!',
                        description='Reviens dans la zone dans 3 secondes ou tu perds!',
                        type='error', duration=3500 })
                elseif (GetGameTimer() - BoundaryWarnStart) >= 3000 then
                    BoundaryWarnStart = nil; ArenaBoundary = nil; BoundaryActive = false
                    TriggerServerEvent('viper_ranked:boundaryViolation', CurrentMatchId)
                end
            else
                if BoundaryWarnStart then
                    BoundaryWarnStart = nil
                    lib.notify({ title='✅ Zone rejointe',
                        description='Tu es de retour dans la zone!',
                        type='success', duration=2000 })
                end
            end
        end
    end
end)

-- ─── Blocage armes non autorisées en match ────────────────────────────────────
-- Seul weapon_pistol50 peut être tiré. Toute autre arme = tir désactivé ce frame.
local AllowedHash = GetHashKey('weapon_pistol50')
local UnarmedHash = GetHashKey('weapon_unarmed')

CreateThread(function()
    while true do
        if InMatch then
            local weapon = GetSelectedPedWeapon(PlayerPedId())
            if weapon ~= AllowedHash and weapon ~= UnarmedHash then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24,  true) -- INPUT_ATTACK
                DisableControlAction(0, 257, true) -- INPUT_ATTACK2
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Stamina infinie + vitesse légèrement augmentée uniquement en ranked
CreateThread(function()
    while true do
        if InMatch then
            local pid = PlayerId()
            ResetPlayerStamina(pid)
            SetRunSprintMultiplierForPlayer(pid, 1.06)
            Wait(0)
        else
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            Wait(500)
        end
    end
end)
