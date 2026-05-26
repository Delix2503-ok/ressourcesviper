local QBCore = exports['qb-core']:GetCoreObject()

local Zones      = {}    -- [id] = zone
local InZone     = nil   -- id de la zone active dans laquelle le joueur se trouve

exports('IsInRedzone', function() return InZone ~= nil end)
local Blips      = {}    -- blips créés
local AdminOpen       = false
local LeaderboardOpen = false
local VoteOpen        = false
local VoteOptions     = {}    -- options reçues du serveur
local VoteSelected    = 1     -- index 1-based de l'option sélectionnée
local VoteHasVoted    = false
local KillCooldown    = {}    -- [victimServerId] = true, évite le double-fire
local MyZoneKills     = 0     -- kills perso depuis le début de la zone active
local MyZoneDeaths    = 0     -- morts perso depuis le début de la zone active
local ZoneLeaderName  = nil   -- nom du leader actuel de la zone
local ZoneLeaderKills = 0     -- kills du leader

local SafeZones     = {}    -- [id] = safezone
local SafeZoneBlips = {}    -- blips safezones
local InSafeZone    = false -- joueur dans une safezone active

-- NPC TP
local TpNpcs        = {}    -- [id] = NPC data reçu du serveur
local SpawnedTpNpcs = {}    -- [id] = ped entity handle
local TpSelectOpen  = false -- panel de sélection safezone ouvert
local TpDestination = nil   -- {x,y,z,name} — lu par le thread de TP
local TpNpcSyncGen  = 0     -- génération courante : annule les threads de spawn obsolètes

-- Système mort / coma
local IsDead          = false
local CanSelfRevive   = false
local DeathStartTime  = nil
local DeathPosition   = nil   -- coords au moment de la mort (pour se relever sur place)
local SavedAppearance = nil
local lastDeathNUI    = 0

-- Porter / Loot
local IsBeingCarried = false   -- ce joueur est porté par quelqu'un
local IsCarrying     = false   -- ce joueur porte quelqu'un
local IsLooting      = false   -- fouille en cours
local IsReviving     = false   -- réanimation en cours (pour éviter le double-fire)
local CarrierNetId   = nil     -- (côté cible) netId du ped du porteur

-- Kill detection (côté victime)
local lastAttackerServerId = nil   -- server ID du dernier joueur qui nous a touché

-- ─────────────────────────────────────────────────
--  SYNCHRONISATION DES ZONES
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:sync', function(zones)
    Zones = {}
    for _, z in ipairs(zones) do Zones[z.id] = z end
    UpdateBlips()
    UpdateHUD()
end)

RegisterNetEvent('redzone:zoneWinner', function(name, kills, reward)
    QBCore.Functions.Notify(
        ('🏆 %s a gagné la RedZone — %d kills — +%d$ argent sale'):format(name, kills, reward),
        'primary', 8000
    )
end)

RegisterNetEvent('redzone:zoneChanged', function(zones, newName)
    local prevZoneId = InZone  -- zone dans laquelle le joueur était avant le changement
    Zones = {}
    for _, z in ipairs(zones) do Zones[z.id] = z end
    InZone          = nil
    MyZoneKills     = 0
    MyZoneDeaths    = 0
    ZoneLeaderName  = nil
    ZoneLeaderKills = 0
    UpdateBlips()
    UpdateHUD()
    QBCore.Functions.Notify(Config.Locale.zone_changed:format(newName), 'primary', 7000)

    -- Vérifier la position du joueur par rapport aux nouvelles zones
    local coords = GetEntityCoords(PlayerPedId())
    local nowInActiveZone = false
    for _, z in pairs(Zones) do
        if z.active then
            local dx = coords.x - z.x
            local dy = coords.y - z.y
            if (dx * dx + dy * dy) <= (z.radius * z.radius) then
                nowInActiveZone = true
                break
            end
        end
    end

    if nowInActiveZone then
        -- Joueur à l'intérieur de la zone qui vient de s'activer
        QBCore.Functions.Notify("⚠ DANGER : Vous êtes dans la RedZone active ! Quittez la zone !", 'error', 8000)
    elseif prevZoneId then
        -- Joueur était dans une zone qui est maintenant inactive → il peut utiliser /safe
        QBCore.Functions.Notify("La RedZone a changé. Tapez /safe pour vous téléporter en sécurité.", 'primary', 8000)
    end
end)

RegisterNetEvent('redzone:updateKills', function(zoneId, killCount, leaderName, leaderKills)
    if Zones[zoneId] then
        Zones[zoneId].killCount = killCount
        if leaderName then
            ZoneLeaderName  = leaderName
            ZoneLeaderKills = leaderKills or 0
        end
        UpdateHUD()
        -- Retirer blips et HUD immédiatement quand le seuil est atteint
        if killCount >= Zones[zoneId].killThreshold then
            UpdateBlips()
        end
    end
end)

RegisterNetEvent('redzone:notifyKill', function(reward)
    MyZoneKills = MyZoneKills + 1
    UpdateHUD()
    QBCore.Functions.Notify(Config.Locale.kill_reward:format(reward), 'success', 4000)
end)

-- ─────────────────────────────────────────────────
--  BLIPS (minimap + carte)
-- ─────────────────────────────────────────────────

function ClearBlips()
    if #Blips > 0 then
        pcall(function() exports['viper-hud']:UnregisterProtectedBlips(Blips) end)
    end
    for _, b in pairs(Blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    Blips = {}
end

local BlipsNeedRefresh = true

function UpdateBlips()
    BlipsNeedRefresh = true
end

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    while true do
        if BlipsNeedRefresh then
            ClearBlips()
            for _, z in pairs(Zones) do
                -- Toutes les zones affichées (active ou non) pour debug visuel
                local x, y, zz, r = tonumber(z.x), tonumber(z.y), tonumber(z.z), tonumber(z.radius)
                if not x or not y or not zz or not r then goto continue end

                local pin = AddBlipForCoord(x, y, zz)
                SetBlipSprite(pin, 1)
                SetBlipScale(pin, 1.0)
                SetBlipColour(pin, z.active and 1 or 4)
                SetBlipAlpha(pin, 255)
                SetBlipAsShortRange(pin, false)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(z.name .. (z.active and ' [REDZONE]' or ' [INACTIF]'))
                EndTextCommandSetBlipName(pin)
                Blips[#Blips + 1] = pin

                local bm = AddBlipForRadius(x, y, zz, r)
                SetBlipHighDetail(bm, true)
                SetBlipColour(bm, z.active and 1 or 4)
                SetBlipAlpha(bm, 160)
                SetBlipDisplay(bm, 4)
                Blips[#Blips + 1] = bm

                ::continue::
            end
            if #Blips > 0 then
                pcall(function() exports['viper-hud']:RegisterProtectedBlips(Blips) end)
            end
            BlipsNeedRefresh = false
        end
        Citizen.Wait(500)
    end
end)

-- ─────────────────────────────────────────────────
--  BLIPS SAFEZONES (carte — toujours visibles)
-- ─────────────────────────────────────────────────

function ClearSafeZoneBlips()
    if #SafeZoneBlips > 0 then
        pcall(function() exports['viper-hud']:UnregisterProtectedBlips(SafeZoneBlips) end)
    end
    for _, b in pairs(SafeZoneBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    SafeZoneBlips = {}
end

function UpdateSafeZoneBlips()
    ClearSafeZoneBlips()
    for _, z in pairs(SafeZones) do
        local x, y, zz, r = tonumber(z.x), tonumber(z.y), tonumber(z.z), tonumber(z.radius)

        -- Pin central (sprite 1 = non affecté par viper-hud noBlips)
        local pin = AddBlipForCoord(x, y, zz)
        SetBlipSprite(pin, 1)
        SetBlipScale(pin, 0.9)
        SetBlipColour(pin, 2)
        SetBlipAlpha(pin, 255)
        SetBlipAsShortRange(pin, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(z.name .. (z.active and ' [SAFEZONE]' or ' [SAFEZONE - OFF]'))
        EndTextCommandSetBlipName(pin)
        SafeZoneBlips[#SafeZoneBlips + 1] = pin

        -- Cercle semi-transparent (style gfx-redzone installé)
        local bm = AddBlipForRadius(x, y, zz, r)
        SetBlipHighDetail(bm, true)
        SetBlipColour(bm, 2)
        SetBlipAlpha(bm, 160)
        SetBlipDisplay(bm, 4)
        SafeZoneBlips[#SafeZoneBlips + 1] = bm
    end
    if #SafeZoneBlips > 0 then
        pcall(function() exports['viper-hud']:RegisterProtectedBlips(SafeZoneBlips) end)
    end
end

RegisterNetEvent('redzone:syncSafezones', function(safezones)
    SafeZones = {}
    for _, z in ipairs(safezones) do SafeZones[z.id] = z end
    UpdateSafeZoneBlips()
end)

-- Données safezones → panel admin + refresh blips
RegisterNetEvent('redzone:admin:szData', function(safezones)
    SafeZones = {}
    for _, z in ipairs(safezones) do SafeZones[z.id] = z end
    UpdateSafeZoneBlips()
    SendNUIMessage({ type = 'safezoneData', safezones = safezones })
end)

-- ─────────────────────────────────────────────────
--  MORT / COMA
-- ─────────────────────────────────────────────────

local function GetNearestSafezoneToPlayer()
    local c = GetEntityCoords(PlayerPedId())
    local nearest, best = nil, math.huge
    for _, z in pairs(SafeZones) do
        local dx = c.x - z.x
        local dy = c.y - z.y
        local d  = dx*dx + dy*dy
        if d < best then best = d; nearest = z end
    end
    return nearest
end

-- Retourne le NPC TP le plus proche du joueur (spawn point précis dans la safezone)
local function GetNearestTpNpcToPlayer()
    local c = GetEntityCoords(PlayerPedId())
    local nearest, best = nil, math.huge
    for _, npc in pairs(TpNpcs) do
        local dx = c.x - npc.x
        local dy = c.y - npc.y
        local d  = dx*dx + dy*dy
        if d < best then best = d; nearest = npc end
    end
    return nearest
end

local function ExitDeathState(x, y, z)
    if not IsDead then return end
    IsDead        = false
    CanSelfRevive = false
    DeathStartTime = nil
    LocalPlayer.state:set('rzDead', false, true)
    LocalPlayer.state:set('dead', false, true)   -- réouvre l'accès à l'inventaire ox_inventory
    TriggerServerEvent('redzone:death:clear')

    local ped = PlayerPedId()
    local c   = GetEntityCoords(ped)

    -- Ressusciter SUR PLACE pour éviter le crash Pool Full (NetworkResurrectLocalPlayer
    -- avec des coords distantes tente de streamer la nouvelle zone d'un coup)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), false, false)
    Wait(200)
    ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)

    -- Téléporter séparément après la résurrection
    SetEntityCoords(ped, x, y, z, false, false, false, false)

    if SavedAppearance then
        pcall(function()
            exports['illenium-appearance']:setPlayerAppearance(SavedAppearance)
        end)
        SavedAppearance = nil
    end

    SendNUIMessage({ type = 'deathHide' })
end

local function EnterDeathState()
    if IsDead then return end
    -- Annuler fouille en cours
    if IsLooting then
        IsLooting = false
        SendNUIMessage({ type = 'lootCancel' })
    end
    -- Lâcher la personne portée si on mourait en la portant
    if IsCarrying then
        IsCarrying = false
        TriggerServerEvent('redzone:carry:stop')
    end
    IsDead         = true
    CanSelfRevive  = false
    DeathStartTime = GetGameTimer()
    local thisDeathTime = DeathStartTime
    LocalPlayer.state:set('rzDead', true, true)
    LocalPlayer.state:set('dead', true, true)    -- bloque l'accès à son propre inventaire ox_inventory

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    DeathPosition = coords   -- sauvegarder pour relèvement sur place

    -- Sauvegarder l'apparence illenium-appearance
    pcall(function()
        SavedAppearance = exports['illenium-appearance']:getPedAppearance(ped)
    end)

    -- Statistiques de mort en zone
    if InZone then
        MyZoneDeaths = MyZoneDeaths + 1
        UpdateHUD()
    end

    -- Ressusciter immédiatement pour bloquer l'écran natif de mort
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), false, false)
    SetEntityInvincible(ped, true)
    SetEntityHealth(ped, 101)   -- 101 = 0% de vie affiché (100 = seuil de mort)
    SetPedArmour(ped, 0)
    SetPedCanRagdoll(ped, false)
    Wait(200)
    ped = PlayerPedId()
    SetEntityInvincible(ped, true)
    SetEntityHealth(ped, 101)
    SetPedArmour(ped, 0)
    SetPedCanRagdoll(ped, false)

    -- Animation allongé
    RequestAnimDict('dead')
    local t = 0
    while not HasAnimDictLoaded('dead') and t < 50 do Wait(50); t = t + 1 end
    TaskPlayAnim(ped, 'dead', 'dead_a', 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Envoyer la mort au serveur avec l'identité du killer si en zone
    local killerForServer = lastAttackerServerId
    TriggerServerEvent('redzone:death:register', killerForServer, InZone)
    lastAttackerServerId = nil
    if LocalPlayer.state.inRankedMatch then
        SendNUIMessage({ type = 'deathScreen', totalSecs = 900 })
    else
        SendNUIMessage({ type = 'deathScreen', totalSecs = 900, reviveSecs = 30 })
        SetTimeout(30000, function()
            -- Vérifier que c'est bien CE cycle de mort (pas un timer orphelin d'une mort précédente)
            if IsDead and DeathStartTime == thisDeathTime and not LocalPlayer.state.inRankedMatch then
                CanSelfRevive = true
                SendNUIMessage({ type = 'deathEAvailable' })
            end
        end)
    end
end

-- ─────────────────────────────────────────────────
--  HUD (overlay NUI)
-- ─────────────────────────────────────────────────

function UpdateHUD()
    local active = nil
    for _, z in pairs(Zones) do
        if z.active then active = z; break end
    end

    if active and InZone ~= nil and active.killCount < active.killThreshold then
        SendNUIMessage({
            type        = 'updateHUD',
            visible     = true,
            name        = active.name,
            kills       = active.killCount,
            threshold   = active.killThreshold,
            myKills     = MyZoneKills,
            myDeaths    = MyZoneDeaths,
            leaderName  = ZoneLeaderName,
            leaderKills = ZoneLeaderKills,
        })
    else
        SendNUIMessage({ type = 'updateHUD', visible = false })
    end
end

-- Détection primaire (baseevents)
AddEventHandler('baseevents:onPlayerDied', function()
    CreateThread(function()
        EnterDeathState()
    end)
end)

-- Détection universelle : toutes causes (admin, entité, poing, chute, noyade…)
-- IsEntityDead catch ce que baseevents rate parfois
CreateThread(function()
    while true do
        Wait(100)
        if not IsDead and IsEntityDead(PlayerPedId()) then
            CreateThread(function()
                EnterDeathState()
            end)
        end
    end
end)

-- ─────────────────────────────────────────────────
--  BOUCLE DE DÉTECTION DE ZONE
-- ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(500)
        local coords  = GetEntityCoords(PlayerPedId())
        local wasInZone = InZone
        InZone = nil

        for _, z in pairs(Zones) do
            if z.active then
                local dx = coords.x - z.x
                local dy = coords.y - z.y
                if (dx * dx + dy * dy) <= (z.radius * z.radius) then
                    InZone = z.id
                    break
                end
            end
        end

        if InZone ~= wasInZone then
            LocalPlayer.state:set('inRedzone', InZone ~= nil, true)
            TriggerEvent('viperpvp_redzone:zoneChanged', InZone ~= nil)
            if InZone then
                QBCore.Functions.Notify(Config.Locale.entered_zone:format(Zones[InZone].name), 'primary', 3000)
            else
                QBCore.Functions.Notify(Config.Locale.left_zone, 'error', 3000)
            end
            UpdateHUD()
        end
    end
end)

-- ─────────────────────────────────────────────────
--  PÉRIMÈTRE 3D (redzones rouges + safezones vertes)
-- ─────────────────────────────────────────────────

CreateThread(function()
    local steps = 40
    local pi2   = math.pi * 2
    while true do
        local drawn = false

        -- RedZones : disque rouge + contour rouge
        for _, z in pairs(Zones) do
            if z.active then
                drawn = true
                DrawMarker(
                    1,
                    z.x, z.y, z.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    z.radius * 2.0, z.radius * 2.0, 1.5,
                    200, 20, 20, 40,
                    false, false, 2, false, nil, nil, false
                )
                for i = 0, steps - 1 do
                    local a1 = (i       / steps) * pi2
                    local a2 = ((i + 1) / steps) * pi2
                    DrawLine(
                        z.x + z.radius * math.cos(a1), z.y + z.radius * math.sin(a1), z.z + 0.5,
                        z.x + z.radius * math.cos(a2), z.y + z.radius * math.sin(a2), z.z + 0.5,
                        220, 40, 40, 210
                    )
                end
            end
        end

        -- SafeZones : disque vert + contour vert (toutes, pas seulement actives)
        for _, z in pairs(SafeZones) do
            drawn = true
            DrawMarker(
                1,
                z.x, z.y, z.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                z.radius * 2.0, z.radius * 2.0, 1.5,
                20, 200, 20, 35,
                false, false, 2, false, nil, nil, false
            )
            for i = 0, steps - 1 do
                local a1 = (i       / steps) * pi2
                local a2 = ((i + 1) / steps) * pi2
                DrawLine(
                    z.x + z.radius * math.cos(a1), z.y + z.radius * math.sin(a1), z.z + 0.5,
                    z.x + z.radius * math.cos(a2), z.y + z.radius * math.sin(a2), z.z + 0.5,
                    40, 220, 40, 200
                )
            end
        end

        Wait(drawn and 0 or 500)
    end
end)

-- ─────────────────────────────────────────────────
--  DÉTECTION DES KILLS (côté victime — plus fiable)
-- ─────────────────────────────────────────────────
-- On suit le dernier attaquant sur notre propre client.
-- Quand on entre en coma, on envoie le killerId au serveur.
-- Évite toute ambiguité sur le type de isDamageFatal (bool vs int).

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim   = args[1]
    local attacker = args[2]
    -- Uniquement si c'est nous la victime
    if victim ~= PlayerPedId() then return end
    if not IsPedAPlayer(attacker) then return end
    if attacker == PlayerPedId() then return end
    -- Mémoriser le serveur ID de l'attaquant
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerPed(pid) == attacker then
            lastAttackerServerId = GetPlayerServerId(pid)
            break
        end
    end
end)

-- ─────────────────────────────────────────────────
--  SAFEZONE : DÉTECTION ET PRÉVENTION DU TIR
-- ─────────────────────────────────────────────────

CreateThread(function()
    local prevInSafe = false
    while true do
        Wait(500)
        local coords = GetEntityCoords(PlayerPedId())
        InSafeZone = false
        for _, z in pairs(SafeZones) do
            if z.active then
                local dx = coords.x - z.x
                local dy = coords.y - z.y
                if (dx * dx + dy * dy) <= (z.radius * z.radius) then
                    InSafeZone = true
                    break
                end
            end
        end
        if InSafeZone ~= prevInSafe then
            local ped = PlayerPedId()
            SetEntityInvincible(ped, InSafeZone)
            SetEntityCanBeDamaged(ped, not InSafeZone)
            prevInSafe = InSafeZone
            -- Stopper le portage si on entre en safezone
            if InSafeZone and IsCarrying then
                IsCarrying = false
                TriggerServerEvent('redzone:carry:stop')
                QBCore.Functions.Notify("Portage arrêté — zone de sécurité.", 'error', 3000)
            end
        end
    end
end)

CreateThread(function()
    while true do
        if InSafeZone then
            Wait(0)
            local pid = PlayerId()
            local ped = PlayerPedId()

            -- Invincibilité maintenue chaque frame (un autre script pourrait la reset)
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)

            -- Bloque uniquement le tir — la visée reste autorisée
            DisablePlayerFiring(pid, true)

            -- Tir / attaque
            DisableControlAction(0, 24,  true)  -- INPUT_ATTACK
            DisableControlAction(0, 257, true)  -- INPUT_ATTACK2
            -- INPUT_AIM (25) NON bloqué : le joueur peut viser librement

            -- Mêlée
            DisableControlAction(0, 140, true)  -- INPUT_MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true)  -- INPUT_MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true)  -- INPUT_MELEE_ATTACK_ALTERNATE
            DisableControlAction(0, 263, true)  -- INPUT_MELEE_ATTACK1
            DisableControlAction(0, 264, true)  -- INPUT_MELEE_ATTACK2

        else
            -- Hors safezone : s'assurer que l'invincibilité est retirée
            local ped = PlayerPedId()
            SetEntityInvincible(ped, false)
            SetEntityCanBeDamaged(ped, true)
            Wait(200)
        end
    end
end)

-- ─────────────────────────────────────────────────
--  PANEL ADMIN
-- ─────────────────────────────────────────────────

RegisterCommand('rzadmin', function()
    -- Le serveur vérifie la permission et renvoie permDenied si refusé
    AdminOpen = not AdminOpen
    SetNuiFocus(AdminOpen, AdminOpen)
    SendNUIMessage({ type = 'toggleAdmin', visible = AdminOpen })
    if AdminOpen then
        TriggerServerEvent('redzone:admin:get')
        TriggerServerEvent('redzone:admin:sz:get')
    end
end, false)

RegisterCommand('leaderboard', function()
    if LeaderboardOpen then
        LeaderboardOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'toggleLeaderboard', visible = false })
    else
        TriggerServerEvent('redzone:leaderboard:get')
    end
end, false)

RegisterNetEvent('redzone:leaderboard:data', function(players, isAdmin, myStats)
    LeaderboardOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'leaderboardData', players = players, isAdmin = isAdmin, myStats = myStats })
end)

-- ─────────────────────────────────────────────────
--  VOTE
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:vote:start', function(options, duration)
    VoteOpen      = true
    VoteOptions   = options
    VoteSelected  = 1
    VoteHasVoted  = false
    -- Effacer les blips de la zone active pendant le vote
    ClearBlips()
    InZone = nil
    UpdateHUD()
    SendNUIMessage({ type = 'voteStart', options = options, duration = duration })
end)

RegisterNetEvent('redzone:vote:end', function(winnerId, winnerName)
    VoteOpen = false
    SendNUIMessage({ type = 'voteEnd', winnerId = winnerId, winnerName = winnerName })
    SetTimeout(4000, function()
        SendNUIMessage({ type = 'voteHide' })
    end)
end)

RegisterNetEvent('redzone:vote:update', function(counts)
    SendNUIMessage({ type = 'voteUpdate', counts = counts })
end)

-- Contrôles clavier du vote (sans bloquer le joueur — pas de SetNuiFocus)
-- 174 = INPUT_FRONTEND_LEFT  (flèche gauche)
-- 175 = INPUT_FRONTEND_RIGHT (flèche droite)
-- 201 = INPUT_FRONTEND_ACCEPT (Entrée)
CreateThread(function()
    while true do
        if VoteOpen and not VoteHasVoted then
            Wait(0)
            if IsControlJustPressed(0, 174) then
                VoteSelected = math.max(1, VoteSelected - 1)
                SendNUIMessage({ type = 'voteSelect', index = VoteSelected - 1 })
            elseif IsControlJustPressed(0, 175) then
                VoteSelected = math.min(#VoteOptions, VoteSelected + 1)
                SendNUIMessage({ type = 'voteSelect', index = VoteSelected - 1 })
            elseif IsControlJustPressed(0, 201) then
                if VoteOptions[VoteSelected] then
                    VoteHasVoted = true
                    TriggerServerEvent('redzone:vote:submit', VoteOptions[VoteSelected].id)
                    SendNUIMessage({ type = 'voteVoted', index = VoteSelected - 1 })
                end
            end
        else
            Wait(200)
        end
    end
end)

RegisterNUICallback('closeLeaderboard', function(_, cb)
    LeaderboardOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'toggleLeaderboard', visible = false })
    cb({})
end)

RegisterNUICallback('resetLeaderboard', function(_, cb)
    TriggerServerEvent('redzone:leaderboard:reset')
    cb({})
end)

-- Permission refusée par le serveur → fermer le panel
RegisterNetEvent('redzone:admin:permDenied', function()
    AdminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'toggleAdmin', visible = false })
end)

-- Données zones reçues du serveur → panel admin + refresh blips
RegisterNetEvent('redzone:admin:data', function(zones)
    -- Mettre à jour les zones locales pour que les blips reflètent les changements immédiats
    for _, z in ipairs(zones) do Zones[z.id] = z end
    UpdateBlips()
    SendNUIMessage({ type = 'adminData', zones = zones })
end)

-- Callback NUI : récupérer les coordonnées du joueur
RegisterNUICallback('getCoords', function(_, cb)
    local c = GetEntityCoords(PlayerPedId())
    cb({
        x = math.floor(c.x * 10) / 10,
        y = math.floor(c.y * 10) / 10,
        z = math.floor(c.z * 10) / 10,
    })
end)

RegisterNUICallback('createZone', function(data, cb)
    TriggerServerEvent('redzone:admin:create', data)
    cb({})
end)

RegisterNUICallback('updateZone', function(data, cb)
    TriggerServerEvent('redzone:admin:update', data)
    cb({})
end)

RegisterNUICallback('deleteZone', function(data, cb)
    TriggerServerEvent('redzone:admin:delete', data.id)
    cb({})
end)

RegisterNUICallback('activateZone', function(data, cb)
    TriggerServerEvent('redzone:admin:activate', data.id)
    cb({})
end)

RegisterNUICallback('closeAdmin', function(_, cb)
    AdminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'toggleAdmin', visible = false })
    cb({})
end)

RegisterNUICallback('forceVote', function(_, cb)
    TriggerServerEvent('redzone:admin:forceVote')
    cb({})
end)

-- NUI callbacks leaderboard admin
RegisterNUICallback('getAdminLeaderboard', function(_, cb)
    TriggerServerEvent('redzone:admin:lb:get'); cb({})
end)

RegisterNUICallback('deleteLeaderboardPlayers', function(data, cb)
    TriggerServerEvent('redzone:admin:lb:delete', data.citizenids); cb({})
end)

RegisterNetEvent('redzone:admin:lbData', function(players)
    SendNUIMessage({ type = 'adminLbData', players = players })
end)

-- NUI callbacks safezones
RegisterNUICallback('getSafezoneCoords', function(_, cb)
    local c = GetEntityCoords(PlayerPedId())
    cb({ x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, z = math.floor(c.z * 10) / 10 })
end)

RegisterNUICallback('createSafezone', function(data, cb)
    TriggerServerEvent('redzone:admin:sz:create', data); cb({})
end)

RegisterNUICallback('updateSafezone', function(data, cb)
    TriggerServerEvent('redzone:admin:sz:update', data); cb({})
end)

RegisterNUICallback('deleteSafezone', function(data, cb)
    TriggerServerEvent('redzone:admin:sz:delete', data.id); cb({})
end)

RegisterNUICallback('toggleSafezone', function(data, cb)
    TriggerServerEvent('redzone:admin:sz:toggle', data.id); cb({})
end)

RegisterNUICallback('testDeathScreen', function(_, cb)
    AdminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'toggleAdmin', visible = false })
    CreateThread(function()
        Wait(300)
        EnterDeathState()
    end)
    cb({})
end)

RegisterNUICallback('toggleAmbientSounds', function(data, cb)
    TriggerServerEvent('redzone:admin:toggleAmbientSounds', data.muted)
    cb({})
end)

-- ─────────────────────────────────────────────────
--  THREADS COMA + TOUCHE E + /revive
-- ─────────────────────────────────────────────────

local LootStealAllowed = false

RegisterNetEvent('redzone:loot:allowSteal', function(allow)
    LootStealAllowed = allow
    if allow then
        LocalPlayer.state:set('canSteal', true, true)
    else
        LocalPlayer.state:set('canSteal', false, true)
    end
end)

-- Maintenir l'état coma : invincibilité, animation, timer 15 min
CreateThread(function()
    while true do
        if IsDead then
            Wait(0)
            local ped = PlayerPedId()
            -- Bloquer ox_inventory de permettre le loot direct (contourne notre système /loot)
            -- Exception : si loot autorisé par le serveur, laisser canSteal=true passer
            if not LootStealAllowed and LocalPlayer.state.canSteal then
                LocalPlayer.state:set('canSteal', false, true)
            end
            SetEntityInvincible(ped, true)
            SetEntityHealth(ped, 101)
            SetPedArmour(ped, 0)
            SetPedCanRagdoll(ped, false)
            DisableControlAction(0, 30,  true)   -- MoveLeftRight
            DisableControlAction(0, 31,  true)   -- MoveUpDown
            DisableControlAction(0, 22,  true)   -- Jump
            DisableControlAction(0, 24,  true)   -- Attack
            DisableControlAction(0, 25,  true)   -- Aim
            DisableControlAction(0, 257, true)   -- Attack2

            if not IsBeingCarried and not IsEntityPlayingAnim(ped, 'dead', 'dead_a', 3) then
                TaskPlayAnim(ped, 'dead', 'dead_a', 8.0, -8.0, -1, 1, 0, false, false, false)
            end

            -- Mise à jour NUI timer à 1 Hz + force-respawn à 15 min
            local now = GetGameTimer()
            if now - lastDeathNUI >= 1000 then
                lastDeathNUI = now
                if DeathStartTime then
                    local elapsed   = math.floor((now - DeathStartTime) / 1000)
                    local remaining = math.max(0, 900 - elapsed)
                    SendNUIMessage({ type = 'deathTimerUpdate', remaining = remaining })
                    if remaining <= 0 and not LocalPlayer.state.inRankedMatch then
                        local dest = GetNearestTpNpcToPlayer()
                        if not dest then dest = GetNearestSafezoneToPlayer() end
                        if dest then
                            ExitDeathState(dest.x, dest.y, dest.z)
                        else
                            local c = GetEntityCoords(PlayerPedId())
                            ExitDeathState(c.x, c.y, c.z)
                        end
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- Renvoie true si un joueur proche est en train de faire la CPR sur moi
local function IsSomeoneRevivingMe()
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) ~= GetPlayerServerId(PlayerId()) then
            local tPed = GetPlayerPed(pid)
            if #(myCoords - GetEntityCoords(tPed)) < 5.0 and
               IsEntityPlayingAnim(tPed, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 3) then
                return true
            end
        end
    end
    return false
end

-- Touche E pour se relever seul (après 30 s)
CreateThread(function()
    while true do
        if IsDead and CanSelfRevive and not LocalPlayer.state.inRankedMatch then
            Wait(0)
            if IsControlJustPressed(0, 38) and not IsSomeoneRevivingMe() then
                local dest = GetNearestTpNpcToPlayer()
                if not dest then dest = GetNearestSafezoneToPlayer() end
                if dest then
                    ExitDeathState(dest.x, dest.y, dest.z)
                else
                    local c = GetEntityCoords(PlayerPedId())
                    ExitDeathState(c.x, c.y, c.z)
                end
            end
        else
            Wait(200)
        end
    end
end)

-- /autorevive staff : relèvement immédiat sans attente
RegisterNetEvent('redzone:autorevive', function()
    if not IsDead then return end
    local c = GetEntityCoords(PlayerPedId())
    ExitDeathState(c.x, c.y, c.z)
end)

-- Reçu quand un autre joueur nous revive : relèvement à la position actuelle
RegisterNetEvent('redzone:revived', function()
    CreateThread(function()
        -- Stopper le portage avant de lire les coords (évite que le thread carry continue de bouger le ped)
        if IsBeingCarried then
            IsBeingCarried = false
            Wait(0)
        end
        local pos = GetEntityCoords(PlayerPedId())
        ExitDeathState(pos.x, pos.y, pos.z)
    end)
end)

-- Commande /revive : barre 5s + animation CPR, validation serveur après le timer
RegisterCommand('revive', function()
    if IsDead or IsReviving then return end

    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local targetId = nil
    local bestDist = 5.0

    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) ~= GetPlayerServerId(PlayerId()) then
            local tPed  = GetPlayerPed(pid)
            local isDown = Player(pid).state.rzDead == true
                        or IsEntityPlayingAnim(tPed, 'dead', 'dead_a', 3)
            if isDown then
                local tCoords = GetEntityCoords(tPed)
                local dx = myCoords.x - tCoords.x
                local dy = myCoords.y - tCoords.y
                local dz = myCoords.z - tCoords.z
                if math.sqrt(dx*dx + dy*dy + dz*dz) < bestDist then
                    bestDist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    targetId = GetPlayerServerId(pid)
                end
            end
        end
    end

    if not targetId then
        QBCore.Functions.Notify("Aucun joueur à réanimer à proximité.", 'error', 3000)
        return
    end

    IsReviving = true
    local startCoords = GetEntityCoords(myPed)
    SendNUIMessage({ type = 'reviveStart', duration = 5 })

    CreateThread(function()
        -- Animation CPR en boucle pendant les 5 secondes
        local dict = 'mini@cpr@char_a@cpr_str'  -- char_a = le réanimateur (char_b = le patient)
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 40 do Wait(50); t = t + 1 end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(myPed, dict, 'cpr_pumpchest', 8.0, -8.0, -1, 1, 0, false, false, false)
        end

        -- Attendre 5s, annuler si déplacement ou si IsReviving mis à false par X
        local cancelled = false
        for i = 1, 20 do
            Wait(250)
            if not IsReviving then cancelled = true; break end
            if #(GetEntityCoords(myPed) - startCoords) > 1.5 then
                cancelled = true; break
            end
        end

        ClearPedTasks(myPed)
        IsReviving = false
        if cancelled then
            SendNUIMessage({ type = 'reviveCancel' })
            QBCore.Functions.Notify("Réanimation annulée.", 'error', 3000)
        else
            SendNUIMessage({ type = 'reviveDone' })
            TriggerServerEvent('redzone:revive:attempt', targetId)
        end
    end)
end, false)

-- Touche G = raccourci /revive
RegisterKeyMapping('revive', 'Réanimer un joueur au sol', 'keyboard', 'g')

-- ─────────────────────────────────────────────────
--  PORTER
-- ─────────────────────────────────────────────────

-- ══ PORTEUR ══════════════════════════════════════
RegisterNetEvent('redzone:carry:doCarry', function(targetNetId)
    if exports['viper_ranked']:IsInRankedMatch() then return end
    IsCarrying = true
    QBCore.Functions.Notify("Portage en cours — /porter pour poser.", 'success', 4000)

    local dict = 'missfinale_c2mcs_1'
    local anim = 'fin_c2_mcs_1_camman'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 40 do Wait(50); t = t + 1 end

    CreateThread(function()
        while IsCarrying do
            -- F = INPUT_ENTER_VEHICLE (23). L'animation missfinale_c2mcs_1 le bloque
            -- côté moteur GTA, ce qui empêche RegisterKeyMapping de le recevoir.
            -- EnableControlAction force le contrôle à rester actif malgré l'animation.
            EnableControlAction(0, 23, true)
            local ped = PlayerPedId()
            if HasAnimDictLoaded(dict) and not IsEntityPlayingAnim(ped, dict, anim, 3) then
                TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(0)
        end
        ClearPedSecondaryTask(PlayerPedId())
    end)
end)

-- ══ CIBLE ════════════════════════════════════════
RegisterNetEvent('redzone:carry:attachSelf', function(carrierNetId, carrierServerId)
    if exports['viper_ranked']:IsInRankedMatch() then return end
    IsBeingCarried = true
    local myPed = PlayerPedId()

    CreateThread(function()
        -- Trouver le local player ID du porteur via son server ID
        local carrierLocalId = nil
        for _ = 1, 30 do
            for _, pid in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(pid) == carrierServerId then
                    carrierLocalId = pid
                    break
                end
            end
            if carrierLocalId then break end
            Wait(200)
        end

        if not carrierLocalId then
            IsBeingCarried = false
            return
        end

        local carrierPed = GetPlayerPed(carrierLocalId)

        ClearPedTasksImmediately(myPed)
        SetEntityNoCollisionEntity(myPed, carrierPed, true)
        Wait(50)

        -- Animation firemans carry (sur l'épaule)
        local dict = 'nm'
        local anim = 'firemans_carry'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 40 do Wait(50); t = t + 1 end

        -- Attacher au porteur (même paramètres que CarryPeople)
        AttachEntityToEntity(myPed, carrierPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)

        -- Maintenir l'animation en boucle tant que porté
        while IsBeingCarried do
            if HasAnimDictLoaded(dict) and not IsEntityPlayingAnim(myPed, dict, anim, 3) then
                TaskPlayAnim(myPed, dict, anim, 8.0, -8.0, -1, 33, 0, false, false, false)
            end
            Wait(0)
        end

        -- Nettoyer : détacher + animation
        DetachEntity(myPed, true, false)
        ClearPedSecondaryTask(myPed)

        carrierPed = GetPlayerPed(carrierLocalId)
        if DoesEntityExist(carrierPed) then
            SetEntityNoCollisionEntity(myPed, carrierPed, false)
        end

        -- Reprendre l'animation de mort si toujours en coma
        if IsDead then
            local d = 'dead'
            RequestAnimDict(d)
            local t2 = 0
            while not HasAnimDictLoaded(d) and t2 < 20 do Wait(50); t2 = t2 + 1 end
            if HasAnimDictLoaded(d) then
                TaskPlayAnim(myPed, d, 'dead_a', 8.0, -8.0, -1, 1, 0, false, false, false)
            end
        end
    end)
end)

RegisterNetEvent('redzone:carry:released', function()
    IsBeingCarried = false
end)

-- Reçu par le PORTEUR quand la cible s'est libérée elle-même
RegisterNetEvent('redzone:carry:stopped', function()
    IsCarrying = false
end)

-- Bloquer les contrôles de la cible pendant tout le portage
CreateThread(function()
    while true do
        if IsBeingCarried then
            Wait(0)
            DisableControlAction(0, 30,  true)
            DisableControlAction(0, 31,  true)
            DisableControlAction(0, 22,  true)
            DisableControlAction(0, 24,  true)
            DisableControlAction(0, 25,  true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 36,  true)
        else
            Wait(200)
        end
    end
end)

RegisterCommand('porter', function()
    if exports['viper_ranked']:IsInRankedMatch() then
        QBCore.Functions.Notify("Impossible de porter en ranked.", 'error', 3000)
        return
    end
    if IsDead or IsBeingCarried then return end

    -- Même touche pour poser
    if IsCarrying then
        IsCarrying = false
        TriggerServerEvent('redzone:carry:stop')
        return
    end

    if InSafeZone then
        QBCore.Functions.Notify("Impossible de porter dans une safezone.", 'error', 3000)
        return
    end

    local myCoords = GetEntityCoords(PlayerPedId())
    local targetId = nil
    local bestDist = 4.0

    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) ~= GetPlayerServerId(PlayerId()) then
            local pPed = GetPlayerPed(pid)
            if DoesEntityExist(pPed) then
                local d = #(myCoords - GetEntityCoords(pPed))
                if d < bestDist then
                    bestDist = d
                    targetId = GetPlayerServerId(pid)
                end
            end
        end
    end

    if not targetId then
        QBCore.Functions.Notify("Aucun joueur à porter à proximité (max 4m).", 'error', 3000)
        return
    end

    TriggerServerEvent('redzone:carry:start', targetId)
end, false)
RegisterKeyMapping('porter', 'Porter / Poser un joueur', 'keyboard', 'f')

-- ─────────────────────────────────────────────────
--  LOOT
-- ─────────────────────────────────────────────────

RegisterNetEvent('redzone:loot:open', function(targetId)
    -- Essayer le format integer d'abord, puis le format table si nécessaire
    local ok = pcall(function()
        exports['ox_inventory']:openInventory('player', targetId)
    end)
    if not ok then
        pcall(function()
            exports['ox_inventory']:openInventory('player', { id = targetId })
        end)
    end
end)

RegisterCommand('loot', function()
    if IsDead or IsLooting then return end

    local myCoords = GetEntityCoords(PlayerPedId())
    local targetId = nil
    local bestDist = 1.5  -- ox_inventory refuse openInventory au-delà de 1.8m

    -- Chercher un joueur en coma : state bag OU animation dead_a (fallback si bag pas encore sync)
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) ~= GetPlayerServerId(PlayerId()) then
            local tPed  = GetPlayerPed(pid)
            local isDown = Player(pid).state.rzDead == true
                        or IsEntityPlayingAnim(tPed, 'dead', 'dead_a', 3)
            if isDown then
                local d = #(myCoords - GetEntityCoords(tPed))
                if d < bestDist then
                    bestDist = d
                    targetId = GetPlayerServerId(pid)
                end
            end
        end
    end

    if not targetId then
        QBCore.Functions.Notify("Aucun joueur au sol à fouiller à proximité.", 'error', 3000)
        return
    end

    IsLooting = true
    local myPed       = PlayerPedId()
    local startCoords = GetEntityCoords(myPed)

    CreateThread(function()
        -- Charger et jouer l'animation d'accroupissement (un genou au sol)
        local dict = 'amb@medic@standing@kneel@idle_a'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 20 do Wait(50); t = t + 1 end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(myPed, dict, 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)
        end

        SendNUIMessage({ type = 'lootStart', duration = 8 })

        local cancelled = false
        for i = 1, 32 do           -- 32 × 250ms = 8 secondes
            Wait(250)
            -- Annulation externe (touche X) ou mort
            if not IsLooting then
                ClearPedTasks(myPed)
                return
            end
            -- Annulation si déplacement
            if #(GetEntityCoords(myPed) - startCoords) > 1.5 then
                cancelled = true
                break
            end
        end

        ClearPedTasksImmediately(myPed)   -- arrêt immédiat sans animation de transition
        IsLooting = false
        if cancelled then
            SendNUIMessage({ type = 'lootCancel' })
            QBCore.Functions.Notify("Fouille annulée — vous avez bougé.", 'error', 3000)
        else
            SendNUIMessage({ type = 'lootDone' })
            TriggerServerEvent('redzone:loot:request', targetId)
        end
    end)
end, false)

-- ─────────────────────────────────────────────────
--  TOUCHE X — Annuler toute action en cours
-- ─────────────────────────────────────────────────

RegisterCommand('cancelaction', function()
    local ped      = PlayerPedId()
    local notified = false

    -- Se faire lâcher du porteur (vivant seulement, mort = pas le choix)
    if IsBeingCarried and not IsDead then
        IsBeingCarried = false
        TriggerServerEvent('redzone:carry:escape')
        QBCore.Functions.Notify("Tu t'es libéré du porteur.", 'primary', 3000)
        notified = true
    end

    if IsLooting then
        IsLooting = false
        SendNUIMessage({ type = 'lootCancel' })
        QBCore.Functions.Notify("Fouille annulée.", 'error', 3000)
        notified = true
    end

    if IsReviving then
        IsReviving = false
        SendNUIMessage({ type = 'reviveCancel' })
        QBCore.Functions.Notify("Réanimation annulée.", 'error', 3000)
        notified = true
    end

    ClearPedTasks(ped)

    if not notified then
        QBCore.Functions.Notify("Aucune action en cours.", 'error', 2000)
    end
end, false)

RegisterKeyMapping('cancelaction', 'Annuler l\'action en cours (loot / revive)', 'keyboard', 'x')

-- ─────────────────────────────────────────────────
--  LOADOUT + SLOTS ARMES (touches 1-5)
-- ─────────────────────────────────────────────────

local function ApplyLoadout()
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    for i, slot in ipairs(Config.WeaponSlots) do
        if slot.name and slot.name ~= '' then
            local hash = GetHashKey(slot.name)
            GiveWeaponToPed(ped, hash, slot.ammo, false, i == 1)
            SetPedAmmo(ped, hash, slot.ammo)
        end
    end
end

for i = 1, 5 do
    RegisterKeyMapping('pvpslot' .. i, 'Slot arme ' .. i, 'keyboard', tostring(i))
    RegisterCommand('pvpslot' .. i, function()
        local slot = Config.WeaponSlots[i]
        if not slot or slot.name == '' then return end
        local ped  = PlayerPedId()
        local hash = GetHashKey(slot.name)
        if HasPedGotWeapon(ped, hash, false) then
            SetCurrentPedWeapon(ped, hash, true)
        end
    end, false)
end

RegisterCommand('loadout', function()
    ApplyLoadout()
end, false)

-- ─────────────────────────────────────────────────
--  QB-TARGET : voir l'ID de n'importe quel joueur
-- ─────────────────────────────────────────────────

-- AddGlobalPlayer non disponible dans cette version de qb-target

-- ─────────────────────────────────────────────────
--  SUPPRESSION VÉHICULES / PNJ
-- ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        local myPed = PlayerPedId()

        -- Supprimer uniquement les véhicules AMBIENT (populationType 1-3)
        -- Ne pas toucher les véhicules mission (type 4+) créés par des ressources
        local pool = GetGamePool('CVehicle')
        for _, v in ipairs(pool) do
            if DoesEntityExist(v) and not IsEntityAttached(v) then
                local popType = GetEntityPopulationType(v)
                if popType >= 1 and popType <= 3 then
                    local driver = GetPedInVehicleSeat(v, -1)
                    if not IsPedAPlayer(driver) then
                        SetEntityAsMissionEntity(v, true, true)
                        DeleteEntity(v)
                    end
                end
            end
        end

        -- Supprimer uniquement les peds AMBIENT (populationType 1-3)
        -- Ne pas toucher les mission peds (type 4+) utilisés par ox_inventory etc.
        local peds = GetGamePool('CPed')
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) and ped ~= myPed and not IsPedAPlayer(ped) then
                local popType = GetEntityPopulationType(ped)
                if popType >= 1 and popType <= 3 then
                    SetEntityAsMissionEntity(ped, true, true)
                    DeleteEntity(ped)
                end
            end
        end

        Wait(1000)
    end
end)

-- ─────────────────────────────────────────────────
--  NPC TP
-- ─────────────────────────────────────────────────

local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.25)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - vector3(x, y, z))
    if dist > 25.0 then return end
    local scale = math.min((1 / dist) * 2.8, 0.6) * (1 / GetGameplayCamFov()) * 100
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(57, 255, 20, 230)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

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

        -- Flags de base — collision ON intentionnellement pour le snap au sol
        SetEntityInvincible(ped, true)
        SetEntityCanBeDamaged(ped, false)
        SetPedCanRagdoll(ped, false)
        SetPedCanBeDraggedOut(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, false)
        SetEntityAsMissionEntity(ped, true, true)
        TaskStandStill(ped, -1)

        -- Attendre que la collision soit chargée autour du ped
        local w = 0
        while DoesEntityExist(ped) and not HasCollisionLoadedAroundEntity(ped) and w < 50 do
            Wait(200); w = w + 1
        end

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
                if found and gz > 0.0 and gz >= npcData.z - 2.0 and gz <= npcData.z + 1.0 and math.abs(gz - cz) > 0.15 then
                    SetEntityCoords(ped, cx, cy, gz, false, false, false, false)
                    finalZ = gz
                elseif math.abs(cz - finalZ) > 0.25 then
                    SetEntityCoords(ped, npcData.x, npcData.y, finalZ, false, false, false, false)
                end
            end
        end
    end)
end

RegisterNetEvent('redzone:syncTpNpcs', function(npcs)
    TpNpcSyncGen = TpNpcSyncGen + 1
    local myGen = TpNpcSyncGen

    for id, ped in pairs(SpawnedTpNpcs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    SpawnedTpNpcs = {}
    TpNpcs = {}

    -- Déduplique par proximité
    local deduped = {}
    for _, n in ipairs(npcs) do
        local dup = false
        for _, kept in ipairs(deduped) do
            if #(vector3(n.x, n.y, n.z) - vector3(kept.x, kept.y, kept.z)) < 2.0 then
                dup = true; break
            end
        end
        if not dup then deduped[#deduped + 1] = n end
    end

    for _, n in ipairs(deduped) do
        TpNpcs[n.id] = n
        SpawnTpNpc(n, myGen)
    end
end)

RegisterNetEvent('redzone:admin:tpNpcData', function(npcs)
    SendNUIMessage({ type = 'tpNpcData', npcs = npcs })
end)

-- Thread principal : hologramme "TP" + interaction touche E
CreateThread(function()
    while true do
        if next(SpawnedTpNpcs) == nil then
            Wait(500)
        else
            Wait(0)
            local myPed    = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local nearNpcId = nil
            local minDist   = 3.0

            for id, ped in pairs(SpawnedTpNpcs) do
                if DoesEntityExist(ped) then
                    local c = GetEntityCoords(ped)
                    local d = #(myCoords - c)

                    -- Hologramme "TP" visible dans un rayon de 30m
                    if d < 30.0 then
                        DrawText3D(c.x, c.y, c.z, 'TP SAFEZONE')
                    end

                    if d < minDist then
                        minDist  = d
                        nearNpcId = id
                    end
                end
            end

            -- Prompt d'interaction et gestion de la touche E
            if nearNpcId and not TpSelectOpen and not AdminOpen and not LeaderboardOpen and not IsDead then
                SetTextScale(0.4, 0.4)
                SetTextFont(0)
                SetTextProportional(1)
                SetTextColour(255, 255, 255, 220)
                SetTextOutline()
                SetTextEntry('STRING')
                SetTextCentre(true)
                AddTextComponentString('[E] Teleporter')
                DrawText(0.5, 0.9)

                if IsControlJustPressed(0, 38) then  -- E = INPUT_PICKUP
                    local szList = {}
                    for _, z in pairs(SafeZones) do
                        -- Chercher le NPC qui se trouve dans cette safezone
                        local destX, destY, destZ = z.x, z.y, z.z
                        for _, npc in pairs(TpNpcs) do
                            local d = #(vector3(npc.x, npc.y, npc.z) - vector3(z.x, z.y, z.z))
                            if d <= (z.radius or 60.0) then
                                destX, destY, destZ = npc.x, npc.y, npc.z
                                break
                            end
                        end
                        szList[#szList + 1] = { id = z.id, name = z.name, x = destX, y = destY, z = destZ }
                    end
                    -- "Zone Principale" toujours en premier
                    table.sort(szList, function(a, b)
                        if a.name == 'Zone Principale' then return true end
                        if b.name == 'Zone Principale' then return false end
                        return a.name < b.name
                    end)
                    if #szList == 0 then
                        QBCore.Functions.Notify("Aucune safezone configuree.", 'error', 3000)
                    else
                        TpSelectOpen = true
                        SetNuiFocus(true, true)
                        SendNUIMessage({ type = 'showTpSelect', safezones = szList })
                    end
                end
            end
        end
    end
end)

-- Callbacks NUI — NPC TP
RegisterNUICallback('tpSelectClose', function(_, cb)
    TpSelectOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

-- Thread dédié au TP : SetEntityCoords appelé depuis un vrai thread de jeu,
-- pas depuis un callback NUI (évite le crash Pool Full)
CreateThread(function()
    while true do
        if TpDestination then
            local dest = TpDestination
            TpDestination = nil
            DoScreenFadeIn(0)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                SetEntityCoords(veh, dest.x, dest.y, dest.z, false, false, false, false)
            else
                SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, false)
            end
            QBCore.Functions.Notify('Teleporte vers ' .. dest.name, 'success', 3000)
            Wait(500)
        else
            Wait(0)
        end
    end
end)

RegisterNUICallback('tpToSafezone', function(data, cb)
    TpSelectOpen = false
    SetNuiFocus(false, false)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if x and y and z then
        TpDestination = { x = x, y = y, z = z, name = data.name or '?' }
    end
    cb({})
end)

RegisterNUICallback('spawnTpNpc', function(data, cb)
    TriggerServerEvent('redzone:admin:tpnpc:create', data.name or '')
    cb({})
end)

RegisterNUICallback('deleteTpNpc', function(data, cb)
    TriggerServerEvent('redzone:admin:tpnpc:delete', data.id)
    cb({})
end)

RegisterNUICallback('getTpNpcList', function(_, cb)
    TriggerServerEvent('redzone:admin:tpnpc:list')
    -- Envoyer immédiatement la liste des safezones au NUI
    local szList = {}
    for _, z in pairs(SafeZones) do
        szList[#szList + 1] = { id = z.id, name = z.name, x = z.x, y = z.y, z = z.z, active = z.active }
    end
    -- "Zone Principale" toujours en premier
    table.sort(szList, function(a, b)
        if a.name == 'Zone Principale' then return true end
        if b.name == 'Zone Principale' then return false end
        return a.name < b.name
    end)
    SendNUIMessage({ type = 'tpAdminSafezones', safezones = szList })
    cb({})
end)

RegisterNUICallback('adminTpToSafezone', function(data, cb)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if x and y and z then
        TpDestination = { x = x, y = y, z = z, name = data.name or '?' }
    end
    cb({})
end)

-- ─────────────────────────────────────────────────
--  INIT
-- ─────────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(2000)  -- laisser le serveur terminer son chargement DB
    TriggerServerEvent('redzone:requestSync')
    UpdateHUD()
end)

-- Re-sync des NPCs TP après spawn du personnage (qb-multicharacter invalide les entités locales créées avant le spawn)
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('redzone:requestSync')
end)

-- ─────────────────────────────────────────────────
--  NETTOYAGE VÉHICULES
-- ─────────────────────────────────────────────────

-- Thread 1 : suppression globale des véhicules inactifs toutes les 60s
CreateThread(function()
    while true do
        Wait(60000)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if not DoesEntityExist(veh) then goto cont60 end
            if NetworkGetEntityOwner(veh) ~= PlayerId() then goto cont60 end
            local hasPlayer = false
            for _, pid in ipairs(GetActivePlayers()) do
                if GetVehiclePedIsIn(GetPlayerPed(pid), false) == veh then
                    hasPlayer = true
                    break
                end
            end
            if not hasPlayer then
                DeleteVehicle(veh)
            end
            ::cont60::
        end
    end
end)

-- Thread 2 : suppression des véhicules en redzone après 40s (actifs ou inactifs)
local VehZoneEntry = {}
CreateThread(function()
    while true do
        Wait(1000)
        local now     = GetGameTimer()
        local myPed   = PlayerPedId()
        local myVeh   = GetVehiclePedIsIn(myPed, false)
        local toDelete = {}

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if not DoesEntityExist(veh) then goto contz end
            local netId = NetworkGetNetworkIdFromEntity(veh)
            if not netId or netId == 0 then goto contz end

            local vehPos = GetEntityCoords(veh)
            local inZone = false
            for _, zone in pairs(Zones) do
                if #(vehPos - vector3(zone.x, zone.y, zone.z)) <= zone.radius then
                    inZone = true
                    break
                end
            end

            if inZone then
                if not VehZoneEntry[netId] then
                    VehZoneEntry[netId] = now
                    if myVeh == veh then
                        QBCore.Functions.Notify("⚠ Sortez du véhicule ! Il sera supprimé dans 40 secondes.", 'error', 6000)
                    end
                else
                    local elapsed = now - VehZoneEntry[netId]
                    if myVeh == veh then
                        if elapsed >= 20000 and elapsed < 21000 then
                            QBCore.Functions.Notify("⏱ Véhicule en RedZone — 20 secondes avant suppression !", 'error', 4000)
                        elseif elapsed >= 30000 and elapsed < 31000 then
                            QBCore.Functions.Notify("⏱ Véhicule en RedZone — 10 secondes avant suppression !", 'error', 4000)
                        elseif elapsed >= 35000 and elapsed < 36000 then
                            QBCore.Functions.Notify("🚨 Véhicule en RedZone — 5 secondes avant suppression !", 'error', 5000)
                        end
                    end
                    -- Suppression à 40s
                    if elapsed >= 40000 then
                        toDelete[#toDelete + 1] = { veh = veh, netId = netId }
                    end
                end
            else
                VehZoneEntry[netId] = nil
            end
            ::contz::
        end

        -- Supprimer les véhicules expirés (owner check pour éviter doublons réseau)
        for _, item in ipairs(toDelete) do
            if DoesEntityExist(item.veh) and NetworkGetEntityOwner(item.veh) == PlayerId() then
                if GetVehiclePedIsIn(myPed, false) == item.veh then
                    TaskLeaveVehicle(myPed, item.veh, 0)
                    Wait(500)
                end
                DeleteVehicle(item.veh)
            end
            VehZoneEntry[item.netId] = nil
        end

        -- Nettoyer les entrées pour véhicules déjà supprimés
        for netId in pairs(VehZoneEntry) do
            local e = NetworkGetEntityFromNetworkId(netId)
            if not e or not DoesEntityExist(e) then
                VehZoneEntry[netId] = nil
            end
        end
    end
end)
