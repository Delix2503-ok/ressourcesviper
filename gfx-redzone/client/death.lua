local QBCore = exports['qb-core']:GetCoreObject()

-- Variables partagées avec client.lua (globales)
-- isPlayerInZone et zoneIndex sont mis à jour dans client.lua

local IsDead          = false
local CanSelfRevive   = false
local DeathStartTime  = nil
local lastDeathNUI    = 0

local IsBeingCarried  = false
IsCarrying            = false   -- global : lu par safezone.lua
local IsLooting       = false
local IsReviving      = false
local LootStealAllowed = false

local lastAttackerServerId = nil

-- ─── Tracker attaquant ────────────────────────────────────────────────────────

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim   = args[1]
    local attacker = args[2]
    if victim ~= PlayerPedId() then return end
    if not IsPedAPlayer(attacker) then return end
    if attacker == PlayerPedId() then return end
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerPed(pid) == attacker then
            lastAttackerServerId = GetPlayerServerId(pid)
            break
        end
    end
end)

-- ─── Fonctions utilitaires ────────────────────────────────────────────────────

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

local function ExitDeathState(x, y, z)
    if not IsDead then return end
    IsDead        = false
    CanSelfRevive = false
    DeathStartTime = nil
    LocalPlayer.state:set('rzDead', false, true)
    LocalPlayer.state:set('dead',   false, true)
    TriggerServerEvent('gfx-redzone:death:clear')

    local ped = PlayerPedId()
    local c   = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), false, false)
    Wait(200)
    ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SendNUIMessage({ type = 'deathHide' })
    -- La protection chute (pvputils) peut re-appliquer invincible+canBeDamaged=false pendant 300ms
    -- On re-nettoie après ce délai pour garantir aucun godmode résiduel
    CreateThread(function()
        Wait(400)
        if not IsDead then
            local p = PlayerPedId()
            SetEntityInvincible(p, false)
            SetEntityCanBeDamaged(p, true)
            SetPlayerInvincible(PlayerId(), false)
        end
    end)
end

local function EnterDeathState()
    if IsDead then return end
    if IsLooting then
        IsLooting = false
        SendNUIMessage({ type = 'lootCancel' })
    end
    if IsCarrying then
        IsCarrying = false
        ClearPedTasksImmediately(PlayerPedId())
        TriggerServerEvent('gfx-redzone:carry:stop')
    end
    if IsBeingCarried then
        IsBeingCarried = false
        TriggerServerEvent('gfx-redzone:carry:escape')
    end

    IsDead         = true
    CanSelfRevive  = false
    DeathStartTime = GetGameTimer()
    local thisDeathTime = DeathStartTime

    LocalPlayer.state:set('rzDead', true, true)
    LocalPlayer.state:set('dead',   true, true)

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- Envoyer kill + mort au serveur
    local killerForServer = lastAttackerServerId
    TriggerServerEvent('gfx-redzone:death:register', killerForServer, zoneIndex or false)
    lastAttackerServerId = nil

    -- Ressusciter sur place pour bloquer l'écran natif de mort
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), false, false)
    SetEntityInvincible(ped, true)
    SetEntityHealth(ped, 101)
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

    SendNUIMessage({ type = 'deathScreen', totalSecs = 900, reviveSecs = 30 })
    SetTimeout(30000, function()
        if IsDead and DeathStartTime == thisDeathTime and not LocalPlayer.state.inRankedMatch then
            CanSelfRevive = true
            SendNUIMessage({ type = 'deathEAvailable' })
        end
    end)
end

-- ─── Détection de mort ────────────────────────────────────────────────────────

AddEventHandler('baseevents:onPlayerDied', function()
    CreateThread(function() EnterDeathState() end)
end)

CreateThread(function()
    while true do
        Wait(100)
        if not IsDead and IsEntityDead(PlayerPedId()) then
            CreateThread(function() EnterDeathState() end)
        end
    end
end)

-- ─── Thread coma ──────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:loot:allowSteal', function(allow)
    LootStealAllowed = allow
    LocalPlayer.state:set('canSteal', allow, true)
end)

CreateThread(function()
    while true do
        if IsDead then
            Wait(0)
            local ped = PlayerPedId()
            if not LootStealAllowed and LocalPlayer.state.canSteal then
                LocalPlayer.state:set('canSteal', false, true)
            end
            SetEntityInvincible(ped, true)
            SetEntityHealth(ped, 101)
            SetPedArmour(ped, 0)
            SetPedCanRagdoll(ped, false)
            DisableControlAction(0, 30,  true)
            DisableControlAction(0, 31,  true)
            DisableControlAction(0, 22,  true)
            DisableControlAction(0, 24,  true)
            DisableControlAction(0, 25,  true)
            DisableControlAction(0, 257, true)

            if not IsBeingCarried and not IsEntityPlayingAnim(ped, 'dead', 'dead_a', 3) then
                TaskPlayAnim(ped, 'dead', 'dead_a', 8.0, -8.0, -1, 1, 0, false, false, false)
            end

            local now = GetGameTimer()
            if now - lastDeathNUI >= 1000 then
                lastDeathNUI = now
                if DeathStartTime then
                    local elapsed   = math.floor((now - DeathStartTime) / 1000)
                    local remaining = math.max(0, 900 - elapsed)
                    SendNUIMessage({ type = 'deathTimerUpdate', remaining = remaining })
                    if remaining <= 0 then
                        local c = GetEntityCoords(PlayerPedId())
                        ExitDeathState(c.x, c.y, c.z)
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- ─── Touche E + /r : auto-relèvement après 30s ───────────────────────────────

CreateThread(function()
    while true do
        if IsDead and CanSelfRevive then
            Wait(0)
            if IsControlJustPressed(0, 38) and not IsSomeoneRevivingMe() then
                local x, y, z = GfxGetReviveDestination()
                if x then
                    ExitDeathState(x, y, z)
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

RegisterCommand('r', function()
    if not IsDead then return end
    if LocalPlayer.state.inRankedMatch then return end
    local c = GetEntityCoords(PlayerPedId())
    ExitDeathState(c.x, c.y, c.z)
end, false)

-- ─── Events reçus ─────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:autorevive', function()
    if not IsDead then return end
    local c = GetEntityCoords(PlayerPedId())
    ExitDeathState(c.x, c.y, c.z)
end)

RegisterNetEvent('gfx-redzone:revived', function()
    CreateThread(function()
        if IsBeingCarried then IsBeingCarried = false; Wait(0) end
        local pos = GetEntityCoords(PlayerPedId())
        ExitDeathState(pos.x, pos.y, pos.z)
    end)
end)

-- ─── /revive (G) ─────────────────────────────────────────────────────────────

RegisterCommand('revive', function()
    if IsDead or IsReviving then return end
    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local targetId, bestDist = nil, 5.0
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) ~= GetPlayerServerId(PlayerId()) then
            local tPed  = GetPlayerPed(pid)
            local isDown = Player(pid).state.rzDead == true
                        or IsEntityPlayingAnim(tPed, 'dead', 'dead_a', 3)
            if isDown then
                local d = #(myCoords - GetEntityCoords(tPed))
                if d < bestDist then bestDist = d; targetId = GetPlayerServerId(pid) end
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
        local dict = 'mini@cpr@char_a@cpr_str'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 40 do Wait(50); t = t + 1 end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(myPed, dict, 'cpr_pumpchest', 8.0, -8.0, -1, 1, 0, false, false, false)
        end
        local cancelled = false
        for i = 1, 20 do
            Wait(250)
            if not IsReviving then cancelled = true; break end
            if #(GetEntityCoords(myPed) - startCoords) > 1.5 then cancelled = true; break end
        end
        ClearPedTasks(myPed)
        IsReviving = false
        if cancelled then
            SendNUIMessage({ type = 'reviveCancel' })
            QBCore.Functions.Notify("Réanimation annulée.", 'error', 3000)
        else
            SendNUIMessage({ type = 'reviveDone' })
            TriggerServerEvent('gfx-redzone:revive:attempt', targetId)
        end
    end)
end, false)
RegisterKeyMapping('revive', 'Réanimer un joueur au sol', 'keyboard', 'g')

-- ─── Porter (/porter = F) ─────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:carry:doCarry', function(targetNetId)
    IsCarrying = true
    QBCore.Functions.Notify("Portage en cours — /porter pour poser.", 'success', 4000)
    local dict = 'missfinale_c2mcs_1'
    local anim = 'fin_c2_mcs_1_camman'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 40 do Wait(50); t = t + 1 end
    CreateThread(function()
        while IsCarrying do
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

RegisterNetEvent('gfx-redzone:carry:attachSelf', function(carrierNetId, carrierServerId)
    IsBeingCarried = true
    local myPed = PlayerPedId()
    CreateThread(function()
        local carrierLocalId = nil
        for _ = 1, 30 do
            for _, pid in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(pid) == carrierServerId then
                    carrierLocalId = pid; break
                end
            end
            if carrierLocalId then break end
            Wait(200)
        end
        if not carrierLocalId then IsBeingCarried = false; return end

        local carrierPed = GetPlayerPed(carrierLocalId)
        ClearPedTasksImmediately(myPed)
        SetEntityNoCollisionEntity(myPed, carrierPed, true)
        Wait(50)

        local dict = 'nm'
        local anim = 'firemans_carry'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 40 do Wait(50); t = t + 1 end
        AttachEntityToEntity(myPed, carrierPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)

        while IsBeingCarried do
            if HasAnimDictLoaded(dict) and not IsEntityPlayingAnim(myPed, dict, anim, 3) then
                TaskPlayAnim(myPed, dict, anim, 8.0, -8.0, -1, 33, 0, false, false, false)
            end
            Wait(0)
        end

        DetachEntity(myPed, true, false)
        ClearPedSecondaryTask(myPed)
        carrierPed = GetPlayerPed(carrierLocalId)
        if DoesEntityExist(carrierPed) then
            SetEntityNoCollisionEntity(myPed, carrierPed, false)
        end
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

RegisterNetEvent('gfx-redzone:carry:released', function()
    IsBeingCarried = false
end)

RegisterNetEvent('gfx-redzone:carry:stopped', function()
    IsCarrying = false
end)

RegisterNetEvent('gfx-redzone:carry:detach', function(targetNetId)
    local ped = NetworkGetEntityFromNetworkId(targetNetId)
    if ped and DoesEntityExist(ped) and IsEntityAttached(ped) then
        DetachEntity(ped, true, false)
    end
end)

-- Bloquer les contrôles de la cible pendant le portage
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
    if IsDead or IsBeingCarried then return end
    if InSafeZone then
        QBCore.Functions.Notify("Impossible de porter en safezone.", 'error', 3000)
        return
    end
    if IsCarrying then
        IsCarrying = false
        TriggerServerEvent('gfx-redzone:carry:stop')
        return
    end
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        QBCore.Functions.Notify("Impossible de porter depuis un véhicule.", 'error', 3000)
        return
    end
    local myCoords = GetEntityCoords(PlayerPedId())
    local targetId, bestDist, targetInVehicle = nil, 4.0, false
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) ~= GetPlayerServerId(PlayerId()) then
            local pPed = GetPlayerPed(pid)
            if DoesEntityExist(pPed) then
                local d = #(myCoords - GetEntityCoords(pPed))
                if d < bestDist then
                    bestDist = d
                    targetId = GetPlayerServerId(pid)
                    targetInVehicle = GetVehiclePedIsIn(pPed, false) ~= 0
                end
            end
        end
    end
    if not targetId then
        QBCore.Functions.Notify("Aucun joueur à porter à proximité (max 4m).", 'error', 3000)
        return
    end
    if targetInVehicle then
        QBCore.Functions.Notify("Impossible de porter un joueur en véhicule.", 'error', 3000)
        return
    end
    TriggerServerEvent('gfx-redzone:carry:start', targetId)
end, false)
RegisterKeyMapping('porter', 'Porter / Poser un joueur', 'keyboard', 'f')

-- ─── Loot (/loot) ─────────────────────────────────────────────────────────────

RegisterNetEvent('gfx-redzone:loot:open', function(targetId)
    local ok = pcall(function() exports['ox_inventory']:openInventory('player', targetId) end)
    if not ok then
        pcall(function() exports['ox_inventory']:openInventory('player', { id = targetId }) end)
    end
end)

RegisterCommand('loot', function()
    if IsDead or IsLooting then return end
    local myCoords = GetEntityCoords(PlayerPedId())
    local targetId, bestDist = nil, 1.5
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) ~= GetPlayerServerId(PlayerId()) then
            local tPed  = GetPlayerPed(pid)
            local isDown = Player(pid).state.rzDead == true
                        or IsEntityPlayingAnim(tPed, 'dead', 'dead_a', 3)
            if isDown then
                local d = #(myCoords - GetEntityCoords(tPed))
                if d < bestDist then bestDist = d; targetId = GetPlayerServerId(pid) end
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
        local dict = 'amb@medic@standing@kneel@idle_a'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 20 do Wait(50); t = t + 1 end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(myPed, dict, 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)
        end
        SendNUIMessage({ type = 'lootStart', duration = 8 })
        local cancelled = false
        for i = 1, 32 do
            Wait(250)
            if not IsLooting then ClearPedTasks(myPed); return end
            if #(GetEntityCoords(myPed) - startCoords) > 1.5 then cancelled = true; break end
        end
        ClearPedTasksImmediately(myPed)
        IsLooting = false
        if cancelled then
            SendNUIMessage({ type = 'lootCancel' })
            QBCore.Functions.Notify("Fouille annulée — vous avez bougé.", 'error', 3000)
        else
            SendNUIMessage({ type = 'lootDone' })
            TriggerServerEvent('gfx-redzone:loot:request', targetId)
        end
    end)
end, false)

-- ─── Touche X : annuler toute action ─────────────────────────────────────────

RegisterCommand('cancelaction', function()
    local ped      = PlayerPedId()
    local notified = false
    if IsBeingCarried and not IsDead then
        IsBeingCarried = false
        TriggerServerEvent('gfx-redzone:carry:escape')
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
RegisterKeyMapping('cancelaction', "Annuler l'action en cours (loot / revive)", 'keyboard', 'x')
