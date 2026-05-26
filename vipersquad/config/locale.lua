Locale = 'en'

Locales = {
    ["en"] = {
        squad = "Squad",
        squads = "Squads",
        members = "Members",
        create = "Create",
        createDesc = "Create a new squad",
        createSquadBtn = "Create Squad",
        createSquadDesc = "You can change all of these settings later",
        squadName = "Squad Name",
        squadNamePlaceholder = "Write your squad name",
        squadAvatar = "Squad Avatar",
        squadAvatarPlaceholder = "Paste your image link here",
        squadPrivacy = "Squad Privacy",
        squadPrivacyDesc = "Squad is {value} now",
        memberLimit = "Member Limit",
        memberLimitDesc = "The maximum number of members that can join this squad.",
        imageLink = "Image Link",
        listedCount = "{count} listed",
        search = "Search",
        inviteMember = "Invite Member",
        personalSettings = "Personal Settings",
        ownerSettings = "Owner Settings",
        settings = "Settings",
        deleteSquad = "Delete Squad", 
        deleteSquadDesc = "Double click if you are really sure. There is no coming back!",
        showHideHud = "Show/Hide HUD",
        showHideHudDesc = "HUD is {value}",
        showHideNametags = "Show/Hide Nametags",
        showHideNametagsDesc = "Nametags are {value}",
        showHideBlips = "Show/Hide Blips",
        showHideBlipsDesc = "Blips are {value}",
        leaveSquad = "Leave Squad",
        leaveSquadDesc = "Double click to leave the squad",
        chat = "Chat",
        online = "Online",
        squadChat = "{squadName}'s Chat",
        typeHere = "Type here...",
        hudSettings = "HUD Settings",
        hudAlignment = "HUD Alignment",
        hudAlignmentDesc = "Choose the alignment of the HUD",
        hudPosition = "HUD Position",
        hudPositionDesc = "Click to start dragging the HUD",
        menuDesc = "General squad menu settings and player infos",
        noSquads = "No squads found",
        noMembers = "No members found",
        visible = "visible",
        hidden = "hidden",
        center = "center",
        left = "left",
        right = "right",
        invites = "Invites",
        noInvites = "No invites found",
        updateSettings = "Update Settings",
        updateSettingsDesc = "Update your squad settings",
        returnMembers = "Return to Members",
        member = "Member",
        owner = "Owner",
        leaderboard = "Leaderboard",
        kills = "Kills",
        deaths = "Deaths",
        kd = "K/D",
        noStats = "No stats yet",
        challengeSquadBtn = "Challenge a Squad",
        warChallenge = "War Challenge",
        warChallengeDesc = "wants to challenge your squad!",
        acceptWar = "Accept",
        declineWar = "Decline",
        warInProgress = "War in Progress",
        warVictory = "Victory!",
        warDefeat = "Defeat!",
        warDraw = "Draw!",
        warScore = "Score",
        warTimeLeft = "Time Left",
        noWarTargets = "No available squads",
        warChallenged = "Challenge sent!",
        warDeclined = "Challenge declined",
        selectWarTarget = "Select a squad to challenge",
        warTargets = "War Targets",
        warEnded = "War Ended",
        close = "Close",
        warBettingPhase = "Place Your Bets!",
        betAmount = "Bet Amount",
        placeBet = "Place Bet",
        betPlaced = "Bet Placed!",
        betMin = "Minimum bet: $%s",
        betMax = "Maximum bet: $%s",
        insufficientFunds = "Not enough money",
        alreadyBet = "You already placed a bet",
        warAnnouncement = "War Announcement",
        in_crew = "You are already in a squad",
        not_in_crew = "You are not in a squad"
    },
}

function _L(key)
    if Locales[Locale] == nil then
        return "Locale not found"
    end

    if Locales[Locale][key] == nil then
        return "Key not found"
    end

    return Locales[Locale][key]
end

Citizen.CreateThread(function()
    if not SendReactMessage then return end
    Citizen.Wait(1000)
    SendReactMessage('setLocale', Locales[Locale])
end)