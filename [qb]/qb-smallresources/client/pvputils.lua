-- Réinitialiser le multiplicateur de vitesse laissé par l'ancienne stamina infinie
CreateThread(function()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    SetPlayerSprintStaminaReplenishmentModifier(PlayerId(), 1.0)
end)

-- ─── Zéro spawn de peds/véhicules GTA de base ────────────────────────────────
CreateThread(function()
    while true do
        Wait(0)
        SetPedDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetAllLowPriorityVehicleGeneratorsActive(false)
        SetNumberOfParkedVehicles(0)
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
    end
end)

-- ─── Supprimer peds ambient + leurs véhicules + trains + hélicos ────────────
-- popType 1-3 = ambient pur. 4+ = scenario/script → ne pas toucher
-- Les trains ignorent le density=0 → DeleteAllTrains() obligatoire
-- Les véhicules NPC sont supprimés avec leur ped pour couper les sons (klaxon, sirène, moteur)
CreateThread(function()
    while true do
        Wait(1000)
        local myPed = PlayerPedId()

        -- Collecter les véhicules NPC avant suppression des peds
        local npcVehs = {}
        for _, e in ipairs(GetGamePool('CPed')) do
            if e ~= myPed and not IsPedAPlayer(e) then
                local pt = GetEntityPopulationType(e)
                if pt >= 1 and pt <= 3 then
                    local v = GetVehiclePedIsIn(e, false)
                    if v ~= 0 and DoesEntityExist(v) then npcVehs[v] = true end
                    SetEntityAsMissionEntity(e, true, true)
                    DeletePed(e)
                end
            end
        end

        -- Supprimer véhicules NPC (voitures, motos)
        -- NetworkGetEntityOwner == PlayerId() : on n'est responsable QUE de nos propres entités
        -- GetEntityPopulationType < 4 : mission entity (spawné par script joueur) → ne jamais supprimer
        for veh in pairs(npcVehs) do
            if DoesEntityExist(veh)
               and NetworkGetEntityOwner(veh) == PlayerId()
               and GetEntityPopulationType(veh) < 4
               and not IsEntityAMissionEntity(veh)
            then
                local hasPlayer = false
                for _, pid in ipairs(GetActivePlayers()) do
                    if GetVehiclePedIsIn(GetPlayerPed(pid), false) == veh then
                        hasPlayer = true; break
                    end
                end
                if not hasPlayer then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                end
            end
        end

        -- Supprimer tous les trains (ignorent density=0)
        DeleteAllTrains()

        -- Supprimer hélicos et avions ambiants sans joueur
        -- Même règle : seulement si on est le network owner ET pas mission entity
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh)
               and NetworkGetEntityOwner(veh) == PlayerId()
               and GetEntityPopulationType(veh) < 4
            then
                local cls = GetVehicleClass(veh)
                if cls == 15 or cls == 16 then  -- 15=Heli, 16=Plane
                    local hasPlayer = false
                    for _, pid in ipairs(GetActivePlayers()) do
                        if GetVehiclePedIsIn(GetPlayerPed(pid), false) == veh then
                            hasPlayer = true; break
                        end
                    end
                    if not hasPlayer then
                        SetEntityAsMissionEntity(veh, true, true)
                        DeleteVehicle(veh)
                    end
                end
            end
        end
    end
end)

-- ─── Zéro collision véhicules / joueurs ──────────────────────────────────────
-- thisFrame=true OBLIGATOIRE chaque frame : GTA override le flag permanent via réseau
CreateThread(function()
    while true do
        Wait(0)
        local ped   = PlayerPedId()
        local myVeh = GetVehiclePedIsIn(ped, false)
        local vehs  = GetGamePool('CVehicle')

        -- Mon ped passe à travers tous les véhicules
        for _, veh in ipairs(vehs) do
            if DoesEntityExist(veh) then
                SetEntityNoCollisionEntity(ped, veh, true)
            end
        end

        -- Si je conduis : mon véhicule passe à travers les peds ET les autres véhicules
        if myVeh ~= 0 and DoesEntityExist(myVeh) then
            for _, pid in ipairs(GetActivePlayers()) do
                if pid ~= PlayerId() then
                    local otherPed = GetPlayerPed(pid)
                    if DoesEntityExist(otherPed) then
                        SetEntityNoCollisionEntity(myVeh, otherPed, true)
                    end
                end
            end
            for _, veh in ipairs(vehs) do
                if DoesEntityExist(veh) and veh ~= myVeh then
                    SetEntityNoCollisionEntity(myVeh, veh, true)
                end
            end
        end
    end
end)

-- ─── Pas de ragdoll + snap debout + crash/mur/obstacle = 0 dégât ────────────
-- collisionProof=true (arg4) bloque crash/mur/moto/prop ; bulletProof=false (arg2) = balles font des dégâts
CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        SetPedCanRagdoll(ped, false)
        SetPedCanRagdollFromPlayerImpact(ped, false)
        SetPedRagdollOnCollision(ped, false)
        if IsPedRagdoll(ped) then
            ClearPedTasksImmediately(ped)
        end
        -- bulletProof=false, fireProof=true, explosionProof=true, collisionProof=true, meleeProof=false
        SetEntityProofs(ped, false, true, true, true, false, false, false, false)
    end
end)

-- ─── Zéro dégâts de chute + atterrissage debout instantané ──────────────────
CreateThread(function()
    local wasFalling = false
    while true do
        Wait(0)
        local ped     = PlayerPedId()
        local falling = IsPedFalling(ped)

        if falling then
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)
        elseif wasFalling then
            ClearPedTasksImmediately(ped)
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)
            Wait(300)
            SetEntityInvincible(ped, false)
            SetEntityCanBeDamaged(ped, true)
        end

        wasFalling = falling
    end
end)


-- ─── Filet de sécurité : mort par crash/mur/obstacle → revive immédiat sur place ─
-- Si mort ET aucun joueur ne nous a tiré dessus → ce n'est pas un kill PVP → on revive
CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if IsEntityDead(ped) then
            -- En ranked, viper_ranked gère la mort (forceKill + playerDied)
            -- Ne pas interférer : le ped mort sans attaquant GTA enregistré ne doit pas être ressuscité
            if LocalPlayer.state.inRankedMatch then
                Wait(500)
            else
                local byPlayer = false
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= PlayerId() then
                        if HasEntityBeenDamagedByEntity(ped, GetPlayerPed(pid), false) then
                            byPlayer = true
                            break
                        end
                    end
                end
                if not byPlayer then
                    local c = GetEntityCoords(ped)
                    local h = GetEntityHeading(ped)
                    NetworkResurrectLocalPlayer(c.x, c.y, c.z, h, false, false)
                    Wait(200)
                    local newPed = PlayerPedId()
                    SetEntityHealth(newPed, 200)
                    SetEntityProofs(newPed, false, true, true, true, false, false, false, false)
                else
                    Wait(500) -- Laisser viperpvp_redzone gérer la mort joueur normalement
                end
            end
        end
    end
end)

-- ─── Véhicules blindés : invincibilité joueur + véhicule ─────────────────────
local BLINDES = {
    [GetHashKey('m3g80')]           = true,
    [GetHashKey('DBMG63PxxBK')]     = true,
    [GetHashKey('DBsou_chargerpd')] = true,
    [GetHashKey('DBm323')]          = true,
}

CreateThread(function()
    local InBlinde = false
    while true do
        Wait(0)
        local ped    = PlayerPedId()
        local veh    = GetVehiclePedIsIn(ped, false)
        local dedans = veh ~= 0 and BLINDES[GetEntityModel(veh)] == true

        if dedans then
            InBlinde = true
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)
            SetPlayerInvincible(PlayerId(), true)
            SetPedSuffersCriticalHits(ped, false)
            SetEntityInvincible(veh, true)
            SetEntityCanBeDamaged(veh, false)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 5000.0)
            SetVehiclePetrolTankHealth(veh, 1000.0)
        elseif InBlinde then
            InBlinde = false
            SetEntityInvincible(ped, false)
            SetEntityCanBeDamaged(ped, true)
            SetPlayerInvincible(PlayerId(), false)
            SetPedSuffersCriticalHits(ped, true)
        end
    end
end)
