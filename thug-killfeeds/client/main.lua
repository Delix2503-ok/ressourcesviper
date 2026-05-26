local streak = 0

AddEventHandler('gameEventTriggered', function(event, data)
    if event == "CEventNetworkEntityDamage" then
        local victim, attacker, victimDied, weapon = data[1], data[2], data[4], data[7]
        if not IsEntityAPed(victim) then return end
        if victimDied and NetworkGetPlayerIndexFromPed(victim) == PlayerId() and IsEntityDead(PlayerPedId()) then
            if not isDead then
                TriggerEvent("esx:onPlayerDeath", data)
                TriggerServerEvent("esx:onPlayerDeath", data)
                if attacker ~= -1 then 
                    streak = 0
                    SendNUIMessage({action = "resetStreak"})
                    if attacker == PlayerPedId() then return end
                    local killerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(attacker))
                    local victimId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(victim))

                    local weapon = GetSelectedPedWeapon(attacker)
                    gunHash = Weapons[weapon].name
    
                    local distance = #(GetEntityCoords(victim) - GetEntityCoords(attacker))
    
                    TriggerServerEvent("thug-killfeed:server:addStreak", killerId)
                    TriggerServerEvent("thug-killfeed:server:getStreak", victimId, killerId, gunHash, math.ceil(distance))
                end
            end
        end
    end
end)

RegisterCommand(Config.Command, function()
    SetNuiFocus(1, 1)
    SendNUIMessage({action = "editing"})
    DisplayRadar(1)
end)

RegisterNUICallback("save", function()
    TriggerEvent("ta-base:stopEditing")
    SetNuiFocus(0, 0)
    DisplayRadar(0)
end)

RegisterNUICallback("loaded", function(_, cb)
    cb(Config.Colors)
end)

RegisterNetEvent("thug-killfeed:client:addStreak", function()
    streak = streak + 1
    SendNUIMessage({action = "addStreak", streak = streak})
end)

RegisterNetEvent("thug-killfeed:client:getStreak", function(data)
    TriggerServerEvent("thug-killfeed:server:addFeed", streak, data)
end)

RegisterNetEvent("thug-killfeed:client:addFeed", function(data)
    SendNUIMessage({action = "addFeed", data = data})
end)