local blips = {}
local warBlips = {}

CreateThread(function()
    while true do
        Wait(5000)
        removeBlipp()
        AddSquadBlip()
        if IsInWar then
            RemoveWarBlips()
            AddWarBlips()
        end
    end
end)

function AddSquadBlip()
    if not PersonalSettings.blipsVisible then return end
        
    if SquadMembers and #SquadMembers > 0 then
        for i = 1, #SquadMembers do
            local v = SquadMembers[i]
            local playerCoords = TriggerCallback('gfx-crew:getMemberCoords', v.id)
            if v then
                if not v.blip or v.blip == 0 then
                    if v.id ~= GetPlayerServerId(PlayerId()) then
                        local blip = AddBlipForCoord(playerCoords.x, playerCoords.y, playerCoords.z)
                        SetBlipSprite(blip, 1)
                        ShowFriendIndicatorOnBlip(blip, true)
                        SetBlipColour(blip, 37)
                        SetBlipScale(blip, 0.75)
                        SetBlipShowCone(blip, true)
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString(v.name)
                        EndTextCommandSetBlipName(blip)
                        table.insert(blips, {
                            id = v.id,
                            blip = blip
                        })
                    end
                end
            end
        end
    end
end

function removeBlipp()
    for i = #blips, 1, -1 do
        RemoveBlip(blips[i].blip)
        table.remove(blips, i)
    end
end


function RemoveSquadBlips(id)

    if not id then
        for i = 1, #blips do
            if blips[i] then
                if blips[i].blip then
                    RemoveBlip(blips[i].blip)
                    blips[i].blip = nil
                end
            end
        end
        return
    end

    
    for i = 1, #blips do
        if blips[i] then
            if blips[i].id == id then
                if blips[i].blip then
                    RemoveBlip(blips[i].blip)
                    blips[i].blip = nil
                end
                break
            end
        end
    end
end

function AddWarBlips()
    if not IsInWar then return end
    local enemies = TriggerCallback('getWarEnemyCoords')
    if not enemies or type(enemies) ~= 'table' then return end

    for i = 1, #enemies do
        local enemy = enemies[i]
        local blip = AddBlipForCoord(enemy.x, enemy.y, enemy.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.85)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(enemy.name)
        EndTextCommandSetBlipName(blip)
        table.insert(warBlips, blip)
    end
end

function RemoveWarBlips()
    for i = #warBlips, 1, -1 do
        RemoveBlip(warBlips[i])
        table.remove(warBlips, i)
    end
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        RemoveSquadBlips()
        RemoveWarBlips()
    end
end)