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

local url = ""

RegisterServerEvent('initUrl')
AddEventHandler('initUrl', function(u)
    url = u
end)

function notify(d)
    PerformHttpRequest(url, function(err, text, headers) end, 'POST', json.encode(d), { ["Content-Type"] = "application/json" })
end

RegisterServerEvent('triggerNotify')
AddEventHandler('triggerNotify', function(d)
    notify(d)
end)
