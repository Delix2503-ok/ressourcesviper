---@diagnostic disable: duplicate-set-field
Skills = Skills or {}

local cachedXp = {}

function Skills.GetResourceName()
    return "default"
end

---Calculate XP required for a level using RuneScape algorithm (with caching)
---@param level number
---@return number
function Skills.GetXPForLevel(level)
    if not level or level < 1 then return 0 end
    if level == 1 then return 0 end  -- Level 1 requires 0 XP

    if cachedXp[level] then return cachedXp[level] end

    local xp = 0
    for n = 1, level - 1 do
        xp = xp + math.floor(n + 300 * (2 ^ (n / 7)))
    end
    local result = math.floor(xp / 4)
    cachedXp[level] = result

    return result
end

---Create a skill (for initialization)
---@param name string
---@param maxLevel number
---@param baseXP number
---@return table
function Skills.Create(name, maxLevel, baseXP)
    if not name then return end
    Skills.All[name] = { name = name, maxLevel = maxLevel or 99, baseXP = baseXP or 50 }
    return Skills.All[name]
end

---Get scaled XP based on player level
---@param baseXP number
---@param playerLevel number
---@return number
function Skills.GetScaledXP(baseXP, playerLevel)
    return math.floor(baseXP * (1 + playerLevel * 0.05))
end

-- Get XP required to complete the current level
---@param level number
---@return number
function Skills.GetXPRequiredForLevel(level)
    if not level or level < 1 then return 0 end
    if level == 1 then return 83 end  -- Level 1 to 2 requires 83 XP
    return Skills.GetXPForLevel(level)
end

---This will get the skill level of the passed skill name. (returns 1 if not found)
---@param skillName string
---@return number
function Skills.GetSkillLevel(skillName)
    if not skillName then return 0 end
    local plyrSkills = Bridge.Framework.GetPlayerMetaData("community_bridge_skills")
    if not plyrSkills or not plyrSkills[skillName] then return 1 end
    return plyrSkills[skillName].level or 1
end

---This will get the skill xp of the passed skill name. (returns 1 if not found)
---@param skillName string
---@return number
function Skills.GetXP(skillName)
    if not skillName then return 0 end
    local plyrSkills = Bridge.Framework.GetPlayerMetaData("community_bridge_skills")
    if not plyrSkills or not plyrSkills[skillName] then return 1 end
    return plyrSkills[skillName].currentXP or 1
end

return Skills