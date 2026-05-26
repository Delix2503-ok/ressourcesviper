local QBCore = exports['qb-core']:GetCoreObject()
local cooldowns = {}

-- Check if player is staff
QBCore.Functions.CreateCallback('qb-staffpanel:server:CheckPermission', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    for _, group in pairs(Config.StaffGroups) do
        if QBCore.Functions.HasPermission(source, group) then
            return cb(true)
        end
    end
    
    cb(false)
end)

-- Get server statistics
QBCore.Functions.CreateCallback('qb-staffpanel:server:GetServerStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    -- Rate limiting
    if cooldowns[source] and os.time() - cooldowns[source] < 5 then return cb(nil) end
    cooldowns[source] = os.time()
    
    local players = QBCore.Functions.GetQBPlayers()
    local onlineCount = 0
    local staffCount = 0
    
    for _, ply in pairs(players) do
        onlineCount = onlineCount + 1
        for _, group in pairs(Config.StaffGroups) do
            if QBCore.Functions.HasPermission(ply.PlayerData.source, group) then
                staffCount = staffCount + 1
                break
            end
        end
    end
    
    cb({
        onlinePlayers = onlineCount,
        onlineStaff = staffCount,
        serverUptime = os.time() - GetGameTimer() / 1000
    })
end)

-- Get online players list
QBCore.Functions.CreateCallback('qb-staffpanel:server:GetOnlinePlayers', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local players = {}
    local qbPlayers = QBCore.Functions.GetQBPlayers()
    
    for _, ply in pairs(qbPlayers) do
        players[#players+1] = {
            id = ply.PlayerData.source,
            name = ply.PlayerData.charinfo.firstname .. ' ' .. ply.PlayerData.charinfo.lastname
        }
    end
    
    cb(players)
end)

-- Get player details
QBCore.Functions.CreateCallback('qb-staffpanel:server:GetPlayerDetails', function(source, cb, targetId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    -- Validate target exists
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Target then return cb(nil) end
    
    cb({
        id = Target.PlayerData.source,
        firstName = Target.PlayerData.charinfo.firstname,
        lastName = Target.PlayerData.charinfo.lastname,
        dob = Target.PlayerData.charinfo.birthdate,
        nationality = Target.PlayerData.charinfo.nationality,
        lastLogin = Target.PlayerData.metadata['lastlogin'] or 'N/A',
        cash = Target.PlayerData.money['cash'],
        bank = Target.PlayerData.money['bank'],
        crypto = Target.PlayerData.money['crypto'] or 0,
        job1 = Target.PlayerData.job.name .. ' - ' .. Target.PlayerData.job.grade.name,
        job2 = Target.PlayerData.gang.name .. ' - ' .. Target.PlayerData.gang.grade.name,
        group = Target.PlayerData.group or 'user'
    })
end)

-- Get businesses list
QBCore.Functions.CreateCallback('qb-staffpanel:server:GetBusinesses', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    -- Placeholder - would query database in real implementation
    local businesses = {
        { id = 1, name = 'Los Santos Customs', employees = 12, balance = 50000 },
        { id = 2, name = 'Bahama Mamas', employees = 25, balance = 120000 },
        { id = 3, name = 'Vanilla Unicorn', employees = 18, balance = 80000 }
    }
    
    cb(businesses)
end)

-- Get business details
QBCore.Functions.CreateCallback('qb-staffpanel:server:GetBusinessDetails', function(source, cb, businessId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    -- Validate business ID
    if type(businessId) ~= 'number' then return cb(nil) end
    if businessId < 1 or businessId > 3 then return cb(nil) end
    
    -- Placeholder data
    cb({
        id = businessId,
        name = 'Business ' .. businessId,
        employees = 15,
        balance = 75000,
        lastWithdrawal = '2024-01-15 14:30:00',
        lastDeposit = '2024-01-15 16:45:00',
        recentMovements = {
            { date = '2024-01-15', amount = 5000, type = 'Withdrawal' },
            { date = '2024-01-14', amount = 10000, type = 'Deposit' }
        },
        employeeList = {
            { name = 'John Doe', rank = 'Manager' },
            { name = 'Jane Smith', rank = 'Employee' }
        }
    })
end)

-- Give money to player
RegisterNetEvent('qb-staffpanel:server:GiveMoney', function(targetId, moneyType, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate input
    if type(targetId) ~= 'number' then return end
    if type(moneyType) ~= 'string' then return end
    if type(amount) ~= 'number' then return end
    
    -- Check permission
    local hasPermission = false
    for _, group in pairs(Config.StaffGroups) do
        if QBCore.Functions.HasPermission(src, group) then
            hasPermission = true
            break
        end
    end
    if not hasPermission then return end
    
    -- Validate money type
    local validType = false
    for _, mt in pairs(Config.PlayerActions.MoneyTypes) do
        if mt == moneyType then
            validType = true
            break
        end
    end
    if not validType then return end
    
    -- Validate amount
    amount = math.floor(amount)
    if amount < 1 or amount > Config.PlayerActions.MaxMoneyAmount then return end
    
    -- Validate target exists
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        QBCore.Functions.Notify(src, 'Target player not found', 'error')
        return
    end
    
    -- Give money
    Target.Functions.AddMoney(moneyType, amount, 'Staff panel gift')
    
    -- Log action
    if Config.LogActions then
        print(string.format('[STAFF] %s gave $%d (%s) to player %s', 
            Player.PlayerData.charinfo.firstname, amount, moneyType, 
            Target.PlayerData.charinfo.firstname))
    end
    
    QBCore.Functions.Notify(src, 'Money given successfully', 'success')
end)

-- Give job to player
RegisterNetEvent('qb-staffpanel:server:GiveJob', function(targetId, jobName, jobGrade)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate input
    if type(targetId) ~= 'number' then return end
    if type(jobName) ~= 'string' then return end
    if type(jobGrade) ~= 'number' then return end
    
    -- Check permission (same as above)
    local hasPermission = false
    for _, group in pairs(Config.StaffGroups) do
        if QBCore.Functions.HasPermission(src, group) then
            hasPermission = true
            break
        end
    end
    if not hasPermission then return end
    
    -- Validate target
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then return end
    
    -- Set job
    Target.Functions.SetJob(jobName, jobGrade)
    
    -- Log action
    if Config.LogActions then
        print(string.format('[STAFF] %s set job %s (grade %d) for player %s', 
            Player.PlayerData.charinfo.firstname, jobName, jobGrade,
            Target.PlayerData.charinfo.firstname))
    end
    
    QBCore.Functions.Notify(src, 'Job updated successfully', 'success')
end)

-- Give item to player
RegisterNetEvent('qb-staffpanel:server:GiveItem', function(targetId, itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate input
    if type(targetId) ~= 'number' then return end
    if type(itemName) ~= 'string' then return end
    if type(amount) ~= 'number' then return end
    
    -- Check permission
    local hasPermission = false
    for _, group in pairs(Config.StaffGroups) do
        if QBCore.Functions.HasPermission(src, group) then
            hasPermission = true
            break
        end
    end
    if not hasPermission then return end
    
    -- Validate amount
    amount = math.floor(amount)
    if amount < 1 or amount > 100 then return end
    
    -- Validate target
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then return end
    
    -- Give item
    Target.Functions.AddItem(itemName, amount)
    
    -- Log action
    if Config.LogActions then
        print(string.format('[STAFF] %s gave %d x %s to player %s', 
            Player.PlayerData.charinfo.firstname, amount, itemName,
            Target.PlayerData.charinfo.firstname))
    end
    
    QBCore.Functions.Notify(src, 'Item given successfully', 'success')
end)

-- Clean up cooldowns on player disconnect
AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)