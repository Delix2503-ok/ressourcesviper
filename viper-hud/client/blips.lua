local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Registre de blips protégés ──────────────────────────────────────────────
-- D'autres ressources peuvent enregistrer leurs blips ici pour les exclure
-- de la suppression automatique (ex: gfx-redzone)

local protectedBlips = {}

exports('RegisterProtectedBlips', function(handles)
    if type(handles) ~= 'table' then return end
    for _, h in ipairs(handles) do
        protectedBlips[h] = true
    end
end)

exports('UnregisterProtectedBlips', function(handles)
    if type(handles) ~= 'table' then return end
    for _, h in ipairs(handles) do
        protectedBlips[h] = nil
    end
end)

-- ─── Suppression des blips script ─────────────────────────────────────────────

local function hideAllScriptBlips()
    -- Parcourt tous les types de sprites et cache les blips non-essentiels
    -- Garde : waypoint (sprite 8), blips enregistrés comme protégés
    for sprite = 2, 826 do
        if sprite ~= 8 then
            local blip = GetFirstBlipInfoId(sprite)
            while DoesBlipExist(blip) do
                local next = GetNextBlipInfoId(sprite)
                if not protectedBlips[blip] then
                    SetBlipAlpha(blip, 0)
                end
                blip = next
                if not DoesBlipExist(blip) then break end
            end
        end
    end
end

CreateThread(function()
    if not Config.World.noBlips then return end
    Wait(8000)
    hideAllScriptBlips()
    while Config.World.noBlips do
        Wait(15000)
        hideAllScriptBlips()
    end
end)

RegisterNetEvent('viper-hud:client:hideBlips', function()
    hideAllScriptBlips()
    QBCore.Functions.Notify('Blips supprimés', 'success', 2500)
end)

RegisterNetEvent('viper-hud:client:showBlips', function()
    for sprite = 2, 826 do
        local blip = GetFirstBlipInfoId(sprite)
        while DoesBlipExist(blip) do
            local next = GetNextBlipInfoId(sprite)
            SetBlipAlpha(blip, 255)
            blip = next
            if not DoesBlipExist(blip) then break end
        end
    end
    QBCore.Functions.Notify('Blips visibles', 'primary', 2500)
end)
