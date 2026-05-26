local LastPositions = {}


RegisterNetEvent('viper-id:updatePos')
AddEventHandler('viper-id:updatePos', function(x, y, z)
    LastPositions[source] = { x = x, y = y, z = z }
end)

AddEventHandler('playerDropped', function(reason)
    local src  = source
    local name = GetPlayerName(src) or 'Inconnu'
    local pos  = LastPositions[src]
    LastPositions[src] = nil

    if pos then
        TriggerClientEvent('viper-id:showHologram', -1, pos.x, pos.y, pos.z, src, name, reason or 'Inconnue')
    end
end)
