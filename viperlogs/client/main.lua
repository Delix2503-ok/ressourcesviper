local IsOpen = false

-- ─── Commande ────────────────────────────────────────────────────────────────
RegisterCommand('viperlogs', function()
    SendNUIMessage({ type = 'open' })
    SetNuiFocus(true, true)
    IsOpen = true
end, false)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    IsOpen = false
    cb('ok')
end)

RegisterNUICallback('searchKills', function(data, cb)
    TriggerServerEvent('viperlogs:getKills', data.license or '')
    cb('ok')
end)

RegisterNUICallback('searchLoot', function(data, cb)
    TriggerServerEvent('viperlogs:getLoot', data.license or '')
    cb('ok')
end)

-- ─── Réception résultats ─────────────────────────────────────────────────────
RegisterNetEvent('viperlogs:receiveKills', function(rows)
    SendNUIMessage({ type = 'receiveKills', data = rows })
end)

RegisterNetEvent('viperlogs:receiveLoot', function(rows)
    SendNUIMessage({ type = 'receiveLoot', data = rows })
end)

-- ─── Fermer avec Échap ───────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(0)
        if IsOpen and IsControlJustPressed(0, 200) then
            SetNuiFocus(false, false)
            SendNUIMessage({ type = 'close' })
            IsOpen = false
        end
    end
end)
