if not Config.UseTarget then return end

local TargetPeds = {
    Store = {},
    ClothingRoom = {},
    PlayerOutfitRoom = {}
}

-- Peds qui affichent un hologramme [entityHandle] = { label, action }
local LabelPeds = {}

local function drawPedLabel(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.25)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - vector3(x, y, z))
    if dist > 25.0 then return end
    local scale = math.min((1 / dist) * 2.8, 0.6) * (1 / GetGameplayCamFov()) * 100
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(57, 255, 20, 230)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function drawHint(text)
    SetTextFont(0) SetTextProportional(1) SetTextScale(0.38, 0.38)
    SetTextColour(255,255,255,230) SetTextDropShadow() SetTextOutline()
    SetTextEntry('STRING') AddTextComponentString(text) DrawText(0.5, 0.9)
end

CreateThread(function()
    local lastInteract = 0
    while true do
        if next(LabelPeds) then
            Wait(0)
            local myCoords = GetEntityCoords(PlayerPedId())
            local nearest, nearestAction, nearestDist = nil, nil, 3.0

            for ped, data in pairs(LabelPeds) do
                if DoesEntityExist(ped) then
                    local c = GetEntityCoords(ped)
                    drawPedLabel(c.x, c.y, c.z, data.label)
                    local d = #(myCoords - c)
                    if d < nearestDist then
                        nearestDist   = d
                        nearest       = ped
                        nearestAction = data.action
                    end
                else
                    LabelPeds[ped] = nil
                end
            end

            if nearest and nearestAction then
                drawHint('[E] DRESSING')
                if IsControlJustPressed(0, 38) and (GetGameTimer() - lastInteract) > 1000 then
                    lastInteract = GetGameTimer()
                    nearestAction()
                end
            end
        else
            Wait(500)
        end
    end
end)

Target = {}

function Target.IsOX()
    return GetResourceState("ox_target") ~= "missing"
end

function Target.IsQB()
    return GetResourceState("qb-target") ~= "missing"
end

local function RemoveTargetPeds(peds)
    for i = 1, #peds, 1 do
        DeletePed(peds[i])
    end
end

local function RemoveTargets()
    if Config.EnablePedsForShops then
        RemoveTargetPeds(TargetPeds.Store)
    else
        for k, v in pairs(Config.Stores) do
            Target.RemoveZone(v.type .. k)
        end
    end

    if Config.EnablePedsForClothingRooms then
        RemoveTargetPeds(TargetPeds.ClothingRoom)
    else
        for k, v in pairs(Config.ClothingRooms) do
            Target.RemoveZone("clothing_" .. (v.job or v.gang) .. k)
        end
    end

    if Config.EnablePedsForPlayerOutfitRooms then
        RemoveTargetPeds(TargetPeds.PlayerOutfitRoom)
    else
        for k in pairs(Config.PlayerOutfitRooms) do
            Target.RemoveZone("playeroutfitroom_" .. k)
        end
    end
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        if Target.IsTargetStarted() then
            RemoveTargets()
        end
    end
end)

local function CreatePedAtCoords(pedModel, coords, scenario)
    pedModel = type(pedModel) == "string" and joaat(pedModel) or pedModel
    lib.requestModel(pedModel)
    local ped = CreatePed(0, pedModel, coords.x, coords.y, coords.z - 0.98, coords.w, false, false)
    TaskStartScenarioInPlace(ped, scenario, true)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true)
    SetEntityInvincible(ped, true)
    PlaceObjectOnGroundProperly(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    return ped
end

local function SetupStoreTarget(targetConfig, action, k, v)
    local parameters = {
        options = {{
            type = "client",
            action = action,
            icon = targetConfig.icon,
            label = targetConfig.label
        }},
        distance = targetConfig.distance,
        rotation = v.rotation
    }

    if Config.EnablePedsForShops then
        TargetPeds.Store[k] = CreatePedAtCoords(v.targetModel or targetConfig.model, v.coords, v.targetScenario or targetConfig.scenario)
        if v.type == "clothing" then
            LabelPeds[TargetPeds.Store[k]] = {
                label  = 'DRESSING',
                action = action,
            }
        end
        Target.AddTargetEntity(TargetPeds.Store[k], parameters)
    elseif v.usePoly then
        Target.AddPolyZone(v.type .. k, v.points, parameters)
    else
        Target.AddBoxZone(v.type .. k, v.coords, v.size, parameters)
    end
end

local function SetupStoreTargets()
    for k, v in pairs(Config.Stores) do
        local targetConfig = Config.TargetConfig[v.type]
        local action

        if v.type == "barber" then
            action = OpenBarberShop
        elseif v.type == "clothing" then
            action = function()
                TriggerEvent("illenium-appearance:client:openClothingShopMenu")
            end
        elseif v.type == "tattoo" then
            action = OpenTattooShop
        elseif v.type == "surgeon" then
            action = OpenSurgeonShop
        end

        if not (Config.RCoreTattoosCompatibility and v.type == "tattoo") then
            SetupStoreTarget(targetConfig, action, k, v)
        end
    end
end

local function SetupClothingRoomTargets()
    for k, v in pairs(Config.ClothingRooms) do
        local targetConfig = Config.TargetConfig["clothingroom"]
        local action = function()
            local outfits = GetPlayerJobOutfits(v.job)
            TriggerEvent("illenium-appearance:client:openJobOutfitsMenu", outfits)
        end

        local parameters = {
            options = {{
                type = "client",
                action = action,
                icon = targetConfig.icon,
                label = targetConfig.label,
                canInteract = v.job and CheckDuty or nil,
                job = v.job,
                gang = v.gang
            }},
            distance = targetConfig.distance,
            rotation = v.rotation
        }

        local key = "clothing_" .. (v.job or v.gang) .. k
        if Config.EnablePedsForClothingRooms then
            TargetPeds.ClothingRoom[k] = CreatePedAtCoords(v.targetModel or targetConfig.model, v.coords, v.targetScenario or targetConfig.scenario)
            Target.AddTargetEntity(TargetPeds.ClothingRoom[k], parameters)
        elseif v.usePoly then
            Target.AddPolyZone(key, v.points, parameters)
        else
            Target.AddBoxZone(key, v.coords, v.size, parameters)
        end
    end
end

local function SetupPlayerOutfitRoomTargets()
    for k, v in pairs(Config.PlayerOutfitRooms) do
        local targetConfig = Config.TargetConfig["playeroutfitroom"]

        local parameters = {
            options = {{
                type = "client",
                action = function()
                    OpenOutfitRoom(v)
                end,
                icon = targetConfig.icon,
                label = targetConfig.label,
                canInteract = function()
                    return IsPlayerAllowedForOutfitRoom(v)
                end
            }},
            distance = targetConfig.distance,
            rotation = v.rotation
        }

        if Config.EnablePedsForPlayerOutfitRooms then
            TargetPeds.PlayerOutfitRoom[k] = CreatePedAtCoords(v.targetModel or targetConfig.model, v.coords, v.targetScenario or targetConfig.scenario)
            Target.AddTargetEntity(TargetPeds.PlayerOutfitRoom[k], parameters)
        elseif v.usePoly then
            Target.AddPolyZone("playeroutfitroom_" .. k, v.points, parameters)
        else
            Target.AddBoxZone("playeroutfitroom_" .. k, v.coords, v.size, parameters)
        end
    end
end

local function SetupTargets()
    SetupStoreTargets()
    SetupClothingRoomTargets()
    SetupPlayerOutfitRoomTargets()
end

CreateThread(function()
    if Config.UseTarget then
        SetupTargets()
    end
end)
