---@diagnostic disable: duplicate-set-field

Skills = Skills or {}
local resourceName = "OT_skills"
local configValue = BridgeSharedConfig.Skills
if (configValue == "auto" and GetResourceState(resourceName) ~= "started") or (configValue ~= "auto" and configValue ~= resourceName) then return end

---This will return the name of the Skills system being used.
---@return string
function Skills.GetResourceName()
    return resourceName
end

---This will return the skill level of the passed skill name.
---@param src number
---@param skillName string
---@return number
function Skills.GetSkillLevel(src, skillName)
    local skillData = exports.OT_skills:getSkill(src, skillName)
    return skillData.level or 0
end

---This will add xp to the passed skill name.
---@param src number
---@param skillName string
---@param amount number
---@return boolean
function Skills.AddXp(src, skillName, amount)
    local skillData = exports.OT_skills:getSkill(src, skillName)
    if not skillData then return false, print("Skill not found") end
    if not Skills.All[skillName] then
       Skills.All[skillName] = Skills.Create(skillName, 99, 50)
    end
    exports.OT_skills:addXP(src, skillName, amount)
    return true
end

---This will remove xp from the passed skill name.
---@param src number
---@param skillName string
---@param amount number
---@return boolean
function Skills.RemoveXp(src, skillName, amount)
    local skillData = exports.OT_skills:getSkill(src, skillName)
    if not skillData then return false, print("Skill not found") end
    exports.OT_skills:removeXP(src, skillName, amount)
    return true
end

return Skills