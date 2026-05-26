Config = {}

-- Staff access groups (must match QBCore groups)
Config.StaffGroups = {
    'admin',
    'god',
    'mod',
    'staff'
}

-- UI Configuration
Config.UI = {
    PrimaryColor = '#8a2be2',        -- Purple electric
    SecondaryColor = '#2c2c2c',      -- Dark gray
    InactiveColor = '#666666',       -- Medium gray
    BackgroundColor = '#1a1a1a',     -- Anthracite
    BorderRadius = '15px',           -- Rounded corners
    TransitionSpeed = '0.3s'         -- Smooth transitions
}

-- Server statistics refresh interval (seconds)
Config.StatsRefresh = 30

-- Player actions configuration
Config.PlayerActions = {
    MoneyTypes = {'cash', 'bank', 'crypto'},
    MaxMoneyAmount = 1000000
}

-- Business configuration
Config.Business = {
    DefaultLogo = 'web/images/business-default.png'
}

-- Key bindings
Config.KeyBind = {
    OpenMenu = 'F10',
    Command = 'staffmenu'
}

-- Logging
Config.LogActions = true
Config.LogFile = 'staff_logs.txt'