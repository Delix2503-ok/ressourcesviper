exports('GetSquadMembers', function(source)
    local squadId = MySquad[source]
    if not squadId then
        return {}
    end
    local squad = GetSquadById(squadId)
    if not squad then
        return {}
    end

    local members = {}
    for i = 1, #squad.members do
        local member = squad.members[i]
        if member then
            table.insert(members, member.id)
        end
    end
    return members
end)

exports('GetSquadData', function(source)
    local squadId = MySquad[source]
    if not squadId then
        return {}
    end
    local squad = GetSquadById(squadId)
    if not squad then
        return {}
    end

    return squad
end)

exports('HasMemberGotASquad', function(source)
    local squadId = MySquad[source]
    return squadId ~= nil
end)

exports('GetSquadId', function(source)
    return MySquad[source]
end)

exports('GetSquadLeaderboard', function(source)
    local squadId = MySquad[source]
    if not squadId then return {} end
    local stats = SquadStats[squadId]
    if not stats then return {} end

    local leaderboard = {}
    for _, data in pairs(stats) do
        local kd = data.deaths > 0 and string.format("%.2f", data.kills / data.deaths) or string.format("%.2f", data.kills * 1.0)
        table.insert(leaderboard, {
            name = data.name,
            image = data.image,
            kills = data.kills,
            deaths = data.deaths,
            kd = kd
        })
    end
    table.sort(leaderboard, function(a, b) return a.kills > b.kills end)
    return leaderboard
end)