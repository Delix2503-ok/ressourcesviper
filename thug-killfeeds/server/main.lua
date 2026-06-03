RegisterServerEvent("thug-killfeed:server:addStreak", function(killerId)
    TriggerClientEvent("thug-killfeed:client:addStreak", killerId)
end)

RegisterServerEvent("thug-killfeed:server:getStreak", function(victimId, attackerId, gunHash, distance)
    TriggerClientEvent("thug-killfeed:client:getStreak", attackerId, {attackerId = attackerId, victimName = GetPlayerName(victimId), killerName = GetPlayerName(attackerId), weapon = gunHash, dist = distance})
end)

RegisterServerEvent("thug-killfeed:server:addFeed", function(streak, data)
    local players = GetPlayers()
    data.streak = streak

    for _, player in pairs(players) do
        local bucket = GetPlayerRoutingBucket(data.attackerId)
        if bucket == GetPlayerRoutingBucket(player) then
            TriggerClientEvent("thug-killfeed:client:addFeed", player, data)
        end
    end
end)

-- Webhook events supprimés : 'initUrl' permettait à n'importe quel client de fixer
-- l'URL du webhook (vol/exfil) et 'triggerNotify' d'envoyer un payload arbitraire.
-- Aucun appelant légitime côté client. Code mort + surface d'attaque → retiré.
