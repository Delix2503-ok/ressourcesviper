---@diagnostic disable: duplicate-set-field
Skills = Skills or {}
Skills.All = Skills.All or {}

-- XP Cache for performance
local cachedXp = {}
-- Default skill object: currentXP (0 to required), level
local defaultSkills = { currentXP = 0, level = 1 }

function Skills.GetResourceName()
    return "default"
end

-- Helper function to get or create a skill object
---@param src number
---@param skillName string
---@return table
local function getOrCreateSkill(src, skillName)
    if not src or not skillName then return table.clone(defaultSkills) end

    local playerSkills = Framework.GetPlayerMetadata(src, "community_bridge_skills") or {}
    if not playerSkills[skillName] then
        playerSkills[skillName] = table.clone(defaultSkills)
    end

    return playerSkills[skillName]
end

---Calculate XP required for a level using RuneScape algorithm (with caching)
---@param level number
---@return number
function Skills.GetXPForLevel(level)
    if not level or level < 1 then return 0 end
    if level == 1 then return 0 end  -- Level 1 requires 0 XP

    -- Check cache first
    if cachedXp[level] then
        return cachedXp[level]
    end

    -- Calculate and cache
    local xp = 0
    for n = 1, level - 1 do
        xp = xp + math.floor(n + 300 * (2 ^ (n / 7)))
    end
    local result = math.floor(xp / 4)
    cachedXp[level] = result

    return result
end

-- Create a skill (for initialization)
---@param name string
---@param maxLevel number
---@param baseXP number
---@return table
function Skills.Create(name, maxLevel, baseXP)
    if not name then return {} end
    Skills.All[name] = { name = name, maxLevel = maxLevel or 99, baseXP = baseXP or 50 }
    return Skills.All[name]
end

-- Get player's current level
---@param src number
---@param skillName string
---@return number
function Skills.GetSkillLevel(src, skillName)
    if not src or not skillName then return 1 end
    local skill = getOrCreateSkill(src, skillName)
    return skill.level or 1
end

-- returns scaled XP based on player level
---@param baseXP number
---@param playerLevel number
---@return integer
function Skills.GetScaledXP(baseXP, playerLevel)
    return math.floor(baseXP * (1 + playerLevel * 0.05))
end
-- Get current XP (0 to required XP for current level)
---@param src number
---@param skillName string
---@return number
function Skills.GetXP(src, skillName)
    if not src or not skillName then return 0 end
    local skill = getOrCreateSkill(src, skillName)
    local currentXP = skill.currentXP or 0
    return currentXP
end

-- Get XP required to complete the current level
---@param level number
---@return number
function Skills.GetXPRequiredForLevel(level)
    if not level or level < 1 then return 0 end
    if level == 1 then return 83 end  -- Level 1 to 2 requires 83 XP
    return Skills.GetXPForLevel(level)
end

-- Add XP and handle level ups
---@param src number
---@param skillName string
---@param xp number
---@return boolean, number, number
function Skills.AddXP(src, skillName, xp)
    if not src or not skillName then return false, 0, 0 end

    if not xp or xp <= 0 then
        xp = Skills.GetScaledXP(50, Skills.GetSkillLevel(src, skillName))
    end

    local playerSkills = Framework.GetPlayerMetadata(src, "community_bridge_skills") or {}
    local skill = playerSkills[skillName]
    if not skill then
        skill = table.clone(defaultSkills)
        playerSkills[skillName] = skill
    end

    local oldLevel = skill.level or 1
    local currentXP = skill.currentXP or 0

    currentXP = currentXP + xp

    local xpNeeded = Skills.GetXPRequiredForLevel(oldLevel + 1)
    if currentXP >= xpNeeded then
        currentXP = currentXP - xpNeeded
        oldLevel = oldLevel + 1
    end

    skill.level = oldLevel
    skill.currentXP = currentXP
    playerSkills[skillName] = skill

    Framework.SetPlayerMetadata(src, "community_bridge_skills", playerSkills)

    return true, oldLevel, currentXP
end

-- Set skill level directly (resets currentXP to 0)
---@param src number
---@param skillName string
---@param level number
---@return boolean
function Skills.SetSkillLevel(src, skillName, level)
    if not src or not skillName or not level or level < 1 then return false end

    local playerSkills = Framework.GetPlayerMetadata(src, "community_bridge_skills") or {}
    local skill = playerSkills[skillName] or table.clone(defaultSkills)

    level = math.min(math.max(1, level), 99)
    skill.level = level
    skill.currentXP = 0

    playerSkills[skillName] = skill
    Framework.SetPlayerMetadata(src, "community_bridge_skills", playerSkills)
    return true
end

-- Set current XP directly
---@param src number
---@param skillName string
---@param xp number
---@return boolean
function Skills.SetXP(src, skillName, xp)
    if not src or not skillName or not xp or xp < 0 then return false end

    local playerSkills = Framework.GetPlayerMetadata(src, "community_bridge_skills") or {}
    local skill = playerSkills[skillName] or table.clone(defaultSkills)

    skill.currentXP = xp
    playerSkills[skillName] = skill

    Framework.SetPlayerMetadata(src, "community_bridge_skills", playerSkills)
    return true
end

return Skills