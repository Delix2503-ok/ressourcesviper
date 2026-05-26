local pending = {}   -- hitmarkers en attente d'une position écran valide

-- ----------------------------------------------------------------
-- Réception depuis le serveur (relayé par la victime)
-- ----------------------------------------------------------------
RegisterNetEvent('vipergun:showHitmarker', function(data)
    if not Config.Hitmarkers.enabled then return end
    table.insert(pending, {
        x          = data.victimX,
        y          = data.victimY,
        z          = data.victimZ + 1.0,
        damage     = data.damage,
        isHeadshot = data.isHeadshot,
        born       = GetGameTimer(),
    })
end)

-- ----------------------------------------------------------------
-- Thread : chaque frame, tente de convertir la position 3D → 2D
-- puis envoie au NUI (une seule fois par hitmarker)
-- ----------------------------------------------------------------
CreateThread(function()
    while true do
        if #pending == 0 then
            Wait(50)
        else
            Wait(0)
            local now = GetGameTimer()
            for i = #pending, 1, -1 do
                local hm = pending[i]
                -- Supprime si trop vieux (ennemi hors écran)
                if now - hm.born > 800 then
                    table.remove(pending, i)
                else
                    local onScreen, sx, sy = World3dToScreen2d(hm.x, hm.y, hm.z)
                    if onScreen then
                        SendNUIMessage({
                            action     = 'showDamageNumber',
                            damage     = math.floor(hm.damage),
                            isHeadshot = hm.isHeadshot,
                            x          = sx,
                            y          = sy,
                        })
                        table.remove(pending, i)
                    end
                end
            end
        end
    end
end)
