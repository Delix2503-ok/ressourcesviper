local modules = exports["gfx-lib"]:getModules()

Config = {
    DiscordBotToken = "",
    WarDuration = 300, -- War duration in seconds (5 minutes)
    Notify = function(source, message)
        modules.Notify(source, message)
    end, -- you can change your notify function here

    -- Routing Buckets: isolate war members in their own routing bucket
    WarBucketEnabled = true,

    -- Betting System
    BetEnabled = true,
    BetMultiplier = 2,      -- Winners get bet * multiplier
    BetWaitTime = 15,       -- Seconds to place bets after war is accepted
    MinBet = 100,
    MaxBet = 10000,
}
