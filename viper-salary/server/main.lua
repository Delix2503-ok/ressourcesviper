local Config = {
    Interval = 10 * 60 * 1000, -- 10 minutes en ms
    Salaries = {
        vip_plus = 10000,
        vip      = 5000,
        default  = 1500,
    }
}

local function GetSalary(src)
    if IsPlayerAceAllowed(src, 'group.vip_plus') then
        return Config.Salaries.vip_plus, 'VIP+'
    elseif IsPlayerAceAllowed(src, 'group.vip') then
        return Config.Salaries.vip, 'VIP'
    else
        return Config.Salaries.default, 'Joueur'
    end
end

CreateThread(function()
    while true do
        Wait(Config.Interval)
        for _, src in ipairs(GetPlayers()) do
            local amount, grade = GetSalary(tonumber(src))
            if amount > 0 then
                exports.ox_inventory:AddItem(tonumber(src), 'money', amount)
                TriggerClientEvent('QBCore:Notify', tonumber(src),
                    ('Salaire %s : +$%s'):format(grade, amount), 'success', 5000)
            end
        end
    end
end)
