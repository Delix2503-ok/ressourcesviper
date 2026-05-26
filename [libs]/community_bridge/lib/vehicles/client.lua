---@diagnostic disable: duplicate-set-field
Vehicles = Vehicles or {}

-- Vehicle properties setter function
-- 
-- Inspired by and derived from vehicle property handlers in:
--   ESX Framework (https://github.com/esx-framework/esx_core) [License: GPLv3]
--   QBCore Framework (https://github.com/qbcore-framework/qb-core) [License: GPLv3]
--
-- Note: The ox_lib version (https://github.com/overextended/ox_lib) [License: LGPLv3] also draws heavily from these projects.
--
-- This code is licensed under the GNU General Public License v3.0 (GPLv3).
-- You may use, modify, and distribute this code under the terms of the GPLv3.
-- See LICENSE file for full details.

if not DecorIsRegisteredAsType("Player_Vehicle", 3) then DecorRegister("Player_Vehicle", 3) end

---@alias RGBColor number[] RGB color array [r, g, b] where each component is 0-255
---@alias VehicleExtras table<number, number> Vehicle extras where key is extra ID and value is state (0=enabled, 1=disabled)

---@class VehicleProperties
---@field model? number Vehicle model hash
---@field plate? string License plate text
---@field plateIndex? number License plate style index (0-5)
---@field bodyHealth? number Body health (0-1000)
---@field engineHealth? number Engine health (0-1000)
---@field tankHealth? number Tank health (0-1000)
---@field fuelLevel? number Fuel level (0-100)
---@field oilLevel? number Oil level (0-100)
---@field dirtLevel? number Dirt level (0-15)
---@field paintType1? number Primary paint type
---@field paintType2? number Secondary paint type
---@field color1? number|RGBColor Primary color (color index or RGB values)
---@field color2? number|RGBColor Secondary color (color index or RGB values)
---@field pearlescentColor? number Pearlescent color index
---@field interiorColor? number Interior color index
---@field dashboardColor? number Dashboard color index
---@field wheelColor? number Wheel color index
---@field wheelWidth? number Wheel width
---@field wheelSize? number Wheel size
---@field wheels? number Wheel type
---@field windowTint? number Window tint level (0-6)
---@field xenonColor? number Xenon headlight color
---@field neonEnabled? boolean[] Neon light states [left, right, front, back]
---@field neonColor? RGBColor Neon light color RGB values
---@field extras? VehicleExtras Vehicle extras configuration
---@field tyreSmokeColor? RGBColor Tyre smoke color RGB values
---@field modSpoilers? number Spoiler modification (-1 to max)
---@field modFrontBumper? number Front bumper modification (-1 to max)
---@field modRearBumper? number Rear bumper modification (-1 to max)
---@field modSideSkirt? number Side skirt modification (-1 to max)
---@field modExhaust? number Exhaust modification (-1 to max)
---@field modFrame? number Frame modification (-1 to max)
---@field modGrille? number Grille modification (-1 to max)
---@field modHood? number Hood modification (-1 to max)
---@field modFender? number Fender modification (-1 to max)
---@field modRightFender? number Right fender modification (-1 to max)
---@field modRoof? number Roof modification (-1 to max)
---@field modEngine? number Engine modification (-1 to max)
---@field modBrakes? number Brakes modification (-1 to max)
---@field modTransmission? number Transmission modification (-1 to max)
---@field modSuspension? number Suspension modification (-1 to max)
---@field modArmor? number Armor modification (-1 to max)
---@field modNitrous? number Nitrous modification (-1 to max)
---@field modHorns? number Horn modification (-1 to max)
---@field modSubwoofer? number Subwoofer modification (-1 to max)
---@field modTurbo? boolean Turbo toggle
---@field modSmokeEnabled? boolean Tyre smoke toggle
---@field modHydraulics? boolean Hydraulics toggle
---@field modXenon? boolean Xenon lights toggle
---@field modFrontWheels? number Front wheels modification (-1 to max)
---@field modBackWheels? number Back wheels modification (-1 to max)
---@field modCustomTiresF? boolean Custom front tires enabled
---@field modCustomTiresR? boolean Custom rear tires enabled
---@field modPlateHolder? number Plate holder modification (-1 to max)
---@field modVanityPlate? number Vanity plate modification (-1 to max)
---@field modTrimA? number Trim A modification (-1 to max)
---@field modOrnaments? number Ornaments modification (-1 to max)
---@field modDashboard? number Dashboard modification (-1 to max)
---@field modDial? number Dial modification (-1 to max)
---@field modDoorSpeaker? number Door speaker modification (-1 to max)
---@field modSeats? number Seats modification (-1 to max)
---@field modSteeringWheel? number Steering wheel modification (-1 to max)
---@field modShifterLeavers? number Shifter levers modification (-1 to max)
---@field modAPlate? number A-plate modification (-1 to max)
---@field modSpeakers? number Speakers modification (-1 to max)
---@field modTrunk? number Trunk modification (-1 to max)
---@field modHydrolic? number Hydraulic modification (-1 to max)
---@field modEngineBlock? number Engine block modification (-1 to max)
---@field modAirFilter? number Air filter modification (-1 to max)
---@field modStruts? number Struts modification (-1 to max)
---@field modArchCover? number Arch cover modification (-1 to max)
---@field modAerials? number Aerials modification (-1 to max)
---@field modTrimB? number Trim B modification (-1 to max)
---@field modTank? number Tank modification (-1 to max)
---@field modWindows? number Windows modification (-1 to max)
---@field modDoorR? number Door R modification (-1 to max)
---@field modLivery? number Livery modification (-1 to max)
---@field modLightbar? number Lightbar modification (-1 to max)
---@field modRoofLivery? number Roof livery modification (-1 to max)
---@field livery? number Vehicle livery (-1 to max)
---@field windows? number[] Array of damaged window indices
---@field doors? number[] Array of damaged door indices
---@field tyres? table<number, number> Map of tyre index to damage state (1=burst, 2=destroyed)
---@field bulletProofTyres? boolean Bulletproof tyres enabled
---@field driftTyres? boolean Drift tyres enabled
---@field doorLockStatus? number Door lock status (0=none, 1=unlocked, 2=locked, 3=lockout, 4=can't enter)
---@field brokenWheels? number|number[] Single wheel index or array of wheel indices to break off (0-7)

-- Handle state bag changes for vehicle properties
AddStateBagChangeHandler('community_bridge:SetVehicleProperties', '', function(bagName, _, value)
    if not value or not GetEntityFromStateBagName then return end

    -- Wait for entity to exist with timeout
    local entity = nil
    local attempts = 0
    local maxAttempts = 100 -- 10 seconds at 100ms intervals

    while not entity and attempts < maxAttempts do
        local tempEntity = GetEntityFromStateBagName(bagName)
        if tempEntity and tempEntity > 0 and DoesEntityExist(tempEntity) then
            entity = tempEntity
            break
        end
        attempts = attempts + 1
        Wait(100)
    end

    if not entity then return end

    -- Apply vehicle properties from state bag (prevents infinite loops)
    Vehicles.SetVehicleProperties(entity, value, true)
    Wait(500)

    -- Clear state if we own the entity (prevents accumulation)
    if NetworkGetEntityOwner(entity) == PlayerId() then
        Vehicles.SetVehicleProperties(entity, value, true)
        Entity(entity).state:set('community_bridge:SetVehicleProperties', nil, false)
    end
end)

local gameBuild = GetGameBuildNumber()

---Get comprehensive vehicle properties
---@param vehicle number The vehicle entity handle
---@return VehicleProperties|nil properties Table containing all vehicle properties, or nil if vehicle doesn't exist
function Vehicles.GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local paintType1 = GetVehicleModColor_1(vehicle)
    local paintType2 = GetVehicleModColor_2(vehicle)

    -- Handle custom colors (can be either number or table)
    local primaryColor = colorPrimary --[[@as number|table]]
    local secondaryColor = colorSecondary --[[@as number|table]]

    if GetIsVehiclePrimaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
        primaryColor = { r, g, b }
    end

    if GetIsVehicleSecondaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
        secondaryColor = { r, g, b }
    end

    -- Get vehicle extras
    local extras = {}
    for i = 1, 15 do
        if DoesExtraExist(vehicle, i) then
            extras[i] = IsVehicleExtraTurnedOn(vehicle, i) and 0 or 1
        end
    end

    -- Get vehicle damage information
    local damage = {
        windows = {},
        doors = {},
        tyres = {},
        brokenWheels = {},
    }

    -- Check window damage
    local windows = 0
    for i = 0, 7 do
        RollUpWindow(vehicle, i)
        if not IsVehicleWindowIntact(vehicle, i) then
            windows += 1
            damage.windows[windows] = i
        end
    end

    -- Check door damage
    local doors = 0
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then
            doors += 1
            damage.doors[doors] = i
        end
    end

    -- Check tyre damage
    for i = 0, 7 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            damage.tyres[i] = IsVehicleTyreBurst(vehicle, i, true) and 2 or 1
        end
    end

    -- Check broken wheels
    for i = 0, 7 do
        if IsVehicleWheelBrokenOff(vehicle, i) then
            table.insert(damage.brokenWheels, i)
        end
    end

    -- Get neon light status
    local neons = {}
    for i = 0, 3 do
        neons[i + 1] = IsVehicleNeonLightEnabled(vehicle, i)
    end

    return {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = math.floor(GetVehicleBodyHealth(vehicle) + 0.5),
        engineHealth = math.floor(GetVehicleEngineHealth(vehicle) + 0.5),
        tankHealth = math.floor(GetVehiclePetrolTankHealth(vehicle) + 0.5),
        fuelLevel = math.floor(GetVehicleFuelLevel(vehicle) + 0.5),
        oilLevel = math.floor(GetVehicleOilLevel(vehicle) + 0.5),
        dirtLevel = math.floor(GetVehicleDirtLevel(vehicle) + 0.5),
        paintType1 = paintType1,
        paintType2 = paintType2,
        color1 = primaryColor,
        color2 = secondaryColor,
        pearlescentColor = pearlescentColor,
        interiorColor = GetVehicleInteriorColor(vehicle),
        dashboardColor = GetVehicleDashboardColour(vehicle),
        wheelColor = wheelColor,
        wheelWidth = GetVehicleWheelWidth(vehicle),
        wheelSize = GetVehicleWheelSize(vehicle),
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonEnabled = neons,
        neonColor = { GetVehicleNeonLightsColour(vehicle) },
        extras = extras,
        tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
        modSpoilers = GetVehicleMod(vehicle, 0),
        modFrontBumper = GetVehicleMod(vehicle, 1),
        modRearBumper = GetVehicleMod(vehicle, 2),
        modSideSkirt = GetVehicleMod(vehicle, 3),
        modExhaust = GetVehicleMod(vehicle, 4),
        modFrame = GetVehicleMod(vehicle, 5),
        modGrille = GetVehicleMod(vehicle, 6),
        modHood = GetVehicleMod(vehicle, 7),
        modFender = GetVehicleMod(vehicle, 8),
        modRightFender = GetVehicleMod(vehicle, 9),
        modRoof = GetVehicleMod(vehicle, 10),
        modEngine = GetVehicleMod(vehicle, 11),
        modBrakes = GetVehicleMod(vehicle, 12),
        modTransmission = GetVehicleMod(vehicle, 13),
        modHorns = GetVehicleMod(vehicle, 14),
        modSuspension = GetVehicleMod(vehicle, 15),
        modArmor = GetVehicleMod(vehicle, 16),
        modNitrous = GetVehicleMod(vehicle, 17),
        modTurbo = IsToggleModOn(vehicle, 18),
        modSubwoofer = GetVehicleMod(vehicle, 19),
        modSmokeEnabled = IsToggleModOn(vehicle, 20),
        modHydraulics = IsToggleModOn(vehicle, 21),
        modXenon = IsToggleModOn(vehicle, 22),
        modFrontWheels = GetVehicleMod(vehicle, 23),
        modBackWheels = GetVehicleMod(vehicle, 24),
        modCustomTiresF = GetVehicleModVariation(vehicle, 23),
        modCustomTiresR = GetVehicleModVariation(vehicle, 24),
        modPlateHolder = GetVehicleMod(vehicle, 25),
        modVanityPlate = GetVehicleMod(vehicle, 26),
        modTrimA = GetVehicleMod(vehicle, 27),
        modOrnaments = GetVehicleMod(vehicle, 28),
        modDashboard = GetVehicleMod(vehicle, 29),
        modDial = GetVehicleMod(vehicle, 30),
        modDoorSpeaker = GetVehicleMod(vehicle, 31),
        modSeats = GetVehicleMod(vehicle, 32),
        modSteeringWheel = GetVehicleMod(vehicle, 33),
        modShifterLeavers = GetVehicleMod(vehicle, 34),
        modAPlate = GetVehicleMod(vehicle, 35),
        modSpeakers = GetVehicleMod(vehicle, 36),
        modTrunk = GetVehicleMod(vehicle, 37),
        modHydrolic = GetVehicleMod(vehicle, 38),
        modEngineBlock = GetVehicleMod(vehicle, 39),
        modAirFilter = GetVehicleMod(vehicle, 40),
        modStruts = GetVehicleMod(vehicle, 41),
        modArchCover = GetVehicleMod(vehicle, 42),
        modAerials = GetVehicleMod(vehicle, 43),
        modTrimB = GetVehicleMod(vehicle, 44),
        modTank = GetVehicleMod(vehicle, 45),
        modWindows = GetVehicleMod(vehicle, 46),
        modDoorR = GetVehicleMod(vehicle, 47),
        modLivery = GetVehicleMod(vehicle, 48),
        modRoofLivery = GetVehicleRoofLivery(vehicle),
        modLightbar = GetVehicleMod(vehicle, 49),
        livery = GetVehicleLivery(vehicle),
        windows = damage.windows,
        doors = damage.doors,
        tyres = damage.tyres,
        brokenWheels = damage.brokenWheels,
        bulletProofTyres = GetVehicleTyresCanBurst(vehicle),
        driftTyres = gameBuild >= 2372 and GetDriftTyresEnabled(vehicle),
        doorLockStatus = GetVehicleDoorLockStatus(vehicle),
    }
end

---Apply vehicle properties to a vehicle
---@param vehicle number The vehicle entity handle
---@param props VehicleProperties Table containing vehicle properties to apply
---@param fromStateBag? boolean Internal flag to prevent infinite loops when called from state bag handler
function Vehicles.SetVehicleProperties(vehicle, props, fromStateBag)
    if not DoesEntityExist(vehicle) then return false end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    SetVehicleModKit(vehicle, 0)

    -- Apply vehicle extras
    if props.extras then
        for id, disable in pairs(props.extras) do
            local extraId = tonumber(id)
            if extraId then
                SetVehicleExtra(vehicle, extraId, disable == 1)
            end
        end
    end

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.oilLevel then SetVehicleOilLevel(vehicle, props.oilLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end

    -- Apply vehicle colors
    if props.color1 then
        if type(props.color1) == 'number' then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1 --[[@as number]], colorSecondary --[[@as number]])
        else
            if props.paintType1 then
                SetVehicleModColor_1(vehicle, props.paintType1, 0, props.pearlescentColor or 0)
            end
            SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])
        end
    end

    if props.color2 then
        if type(props.color2) == 'number' then
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1 or colorPrimary --[[@as number]], props.color2 --[[@as number]])
        else
            if props.paintType2 then
                SetVehicleModColor_2(vehicle, props.paintType2, 0)
            end
            SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3])
        end
    end

    if props.pearlescentColor or props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor or wheelColor)
    end

    if props.interiorColor then SetVehicleInteriorColor(vehicle, props.interiorColor) end

    if props.dashboardColor then SetVehicleDashboardColor(vehicle, props.dashboardColor) end

    -- Apply wheel properties
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end

    if props.wheelSize then SetVehicleWheelSize(vehicle, props.wheelSize) end

    if props.wheelWidth then
        SetVehicleWheelWidth(vehicle, props.wheelWidth)
    end

    -- Apply window and lighting properties
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

    if props.neonEnabled then
        for i = 1, #props.neonEnabled do
            SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i])
        end
    end

    if props.neonColor then SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3]) end

    -- Apply vehicle damage
    if props.windows then
        for i = 1, #props.windows do
            RemoveVehicleWindow(vehicle, props.windows[i])
        end
    end

    if props.doors then
        for i = 1, #props.doors do
            SetVehicleDoorBroken(vehicle, props.doors[i], true)
        end
    end

    if props.tyres then
        for tyre, state in pairs(props.tyres) do
            SetVehicleTyreBurst(vehicle, tonumber(tyre) --[[@as number]], state == 2, 1000.0)
        end
    end

    if props.brokenWheels then
        if type(props.brokenWheels) == 'number' then
            BreakOffVehicleWheel(vehicle, props.brokenWheels --[[@as number]], false, true, true, false)
        else
            for i = 1, #props.brokenWheels do
                BreakOffVehicleWheel(vehicle, props.brokenWheels[i], false, true, true, false)
            end
        end
    end

    if props.modSmokeEnabled ~= nil then ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled) end

    if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3]) end

    if props.modSpoilers then SetVehicleMod(vehicle, 0, props.modSpoilers, false) end
    if props.modFrontBumper then SetVehicleMod(vehicle, 1, props.modFrontBumper, false) end
    if props.modRearBumper then SetVehicleMod(vehicle, 2, props.modRearBumper, false) end
    if props.modSideSkirt then SetVehicleMod(vehicle, 3, props.modSideSkirt, false) end
    if props.modExhaust then SetVehicleMod(vehicle, 4, props.modExhaust, false) end
    if props.modFrame then SetVehicleMod(vehicle, 5, props.modFrame, false) end
    if props.modGrille then SetVehicleMod(vehicle, 6, props.modGrille, false) end
    if props.modHood then SetVehicleMod(vehicle, 7, props.modHood, false) end
    if props.modFender then SetVehicleMod(vehicle, 8, props.modFender, false) end
    if props.modRightFender then SetVehicleMod(vehicle, 9, props.modRightFender, false) end
    if props.modRoof then SetVehicleMod(vehicle, 10, props.modRoof, false) end

    if props.modEngine then SetVehicleMod(vehicle, 11, props.modEngine, false) end
    if props.modBrakes then SetVehicleMod(vehicle, 12, props.modBrakes, false) end
    if props.modTransmission then SetVehicleMod(vehicle, 13, props.modTransmission, false) end
    if props.modSuspension then SetVehicleMod(vehicle, 15, props.modSuspension, false) end
    if props.modArmor then SetVehicleMod(vehicle, 16, props.modArmor, false) end
    if props.modNitrous then SetVehicleMod(vehicle, 17, props.modNitrous, false) end

    if props.modTurbo ~= nil then ToggleVehicleMod(vehicle, 18, props.modTurbo) end
    if props.modSubwoofer ~= nil then ToggleVehicleMod(vehicle, 19, props.modSubwoofer) end
    if props.modHydraulics ~= nil then ToggleVehicleMod(vehicle, 21, props.modHydraulics) end
    if props.modXenon ~= nil then ToggleVehicleMod(vehicle, 22, props.modXenon) end

    if props.modHorns then SetVehicleMod(vehicle, 14, props.modHorns, false) end
    if props.xenonColor then SetVehicleXenonLightsColor(vehicle, props.xenonColor) end

    if props.modFrontWheels then SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF) end
    if props.modBackWheels then SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR) end

    if props.modPlateHolder then SetVehicleMod(vehicle, 25, props.modPlateHolder, false) end
    if props.modVanityPlate then SetVehicleMod(vehicle, 26, props.modVanityPlate, false) end
    if props.modTrimA then SetVehicleMod(vehicle, 27, props.modTrimA, false) end
    if props.modOrnaments then SetVehicleMod(vehicle, 28, props.modOrnaments, false) end
    if props.modDashboard then SetVehicleMod(vehicle, 29, props.modDashboard, false) end
    if props.modDial then SetVehicleMod(vehicle, 30, props.modDial, false) end
    if props.modDoorSpeaker then SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false) end
    if props.modSeats then SetVehicleMod(vehicle, 32, props.modSeats, false) end
    if props.modSteeringWheel then SetVehicleMod(vehicle, 33, props.modSteeringWheel, false) end
    if props.modShifterLeavers then SetVehicleMod(vehicle, 34, props.modShifterLeavers, false) end

    if props.modAPlate then SetVehicleMod(vehicle, 35, props.modAPlate, false) end
    if props.modSpeakers then SetVehicleMod(vehicle, 36, props.modSpeakers, false) end
    if props.modTrunk then SetVehicleMod(vehicle, 37, props.modTrunk, false) end
    if props.modHydrolic then SetVehicleMod(vehicle, 38, props.modHydrolic, false) end
    if props.modEngineBlock then SetVehicleMod(vehicle, 39, props.modEngineBlock, false) end
    if props.modAirFilter then SetVehicleMod(vehicle, 40, props.modAirFilter, false) end
    if props.modStruts then SetVehicleMod(vehicle, 41, props.modStruts, false) end
    if props.modArchCover then SetVehicleMod(vehicle, 42, props.modArchCover, false) end
    if props.modAerials then SetVehicleMod(vehicle, 43, props.modAerials, false) end
    if props.modTrimB then SetVehicleMod(vehicle, 44, props.modTrimB, false) end
    if props.modTank then SetVehicleMod(vehicle, 45, props.modTank, false) end
    if props.modWindows then SetVehicleMod(vehicle, 46, props.modWindows, false) end
    if props.modDoorR then SetVehicleMod(vehicle, 47, props.modDoorR, false) end
    if props.modLivery then SetVehicleMod(vehicle, 48, props.modLivery, false) end
    if props.modLightbar then SetVehicleMod(vehicle, 49, props.modLightbar, false) end

    if props.modRoofLivery then SetVehicleRoofLivery(vehicle, props.modRoofLivery) end
    if props.livery then SetVehicleLivery(vehicle, props.livery) end

    if props.bulletProofTyres ~= nil then SetVehicleTyresCanBurst(vehicle, props.bulletProofTyres) end
    if gameBuild >= 2372 and props.driftTyres then SetDriftTyresEnabled(vehicle, true) end

    if props.doorLockStatus then
        SetVehicleDoorsLocked(vehicle, props.doorLockStatus)
    end

    if not DecorExistOn(vehicle, "Player_Vehicle") then DecorSetInt(vehicle, "Player_Vehicle", -1) end

    -- Only sync to other clients if not called from state bag AND we own the entity
    if not fromStateBag and NetworkGetEntityIsNetworked(vehicle) and NetworkGetEntityOwner(vehicle) == PlayerId() then
        Entity(vehicle).state:set('community_bridge:SetVehicleProperties', props, true)
        if props.doorLockStatus then Entity(vehicle).state:set('door', tonumber(props.doorLockStatus), true) end
    end

    return true
end

return Vehicles