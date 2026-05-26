---@diagnostic disable: duplicate-set-field
Skills = Skills or {}
local resourceName = "pickle_xp"
local configValue = BridgeSharedConfig.Skills
if (configValue == "auto" and GetResourceState(resourceName) ~= "started") or (configValue ~= "auto" and configValue ~= resourceName) then return end

---This will get the name of the Skills system being used.
---@return string
function Skills.GetResourceName()
    return resourceName
end

---This will return the skill level of the passed skill name.
---@param skillName string
---@return number
function Skills.GetSkillLevel(skillName)
    local skillData = exports.pickle_xp:GetLevel(skillName)
    return skillData or 0
end

return Skills