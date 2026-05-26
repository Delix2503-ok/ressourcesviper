local pending = {}

RegisterNetEvent('weaponpatch:showHitmarker', function(data)
    table.insert(pending, {
        x          = data.victimX,
        y          = data.victimY,
        z          = data.victimZ + 0.9,
        damage     = data.damage,
        isHeadshot = data.isHeadshot,
        born       = GetGameTimer(),
    })
end)

CreateThread(function()
    while true do
        if #pending == 0 then
            Wait(50)
        else
            Wait(0)
            local now = GetGameTimer()
            for i = #pending, 1, -1 do
                local hm      = pending[i]
                local elapsed = now - hm.born

                if elapsed > 600 then
                    SendNUIMessage({
                        action     = 'showDamageNumber',
                        damage     = math.floor(hm.damage),
                        isHeadshot = hm.isHeadshot,
                        x          = 0.5,
                        y          = 0.42,
                    })
                    table.remove(pending, i)
                else
                    local onScreen, sx, sy = World3dToScreen2d(hm.x, hm.y, hm.z)
                    if onScreen and sx > 0.0 and sx < 1.0 and sy > 0.0 and sy < 1.0 then
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

-- /testhit et /testhithead pour vérifier que le NUI fonctionne
RegisterCommand('testhit', function()
    SendNUIMessage({ action = 'showDamageNumber', damage = 88, isHeadshot = false, x = 0.5, y = 0.5 })
end, false)

RegisterCommand('testhithead', function()
    SendNUIMessage({ action = 'showDamageNumber', damage = 200, isHeadshot = true, x = 0.5, y = 0.42 })
end, false)
