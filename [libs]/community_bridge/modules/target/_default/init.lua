-- local Target = Require('modules/target/_default/init.lua')
local requiredModules = {
    'modules/target/_default/client.lua',
    'modules/target/qb-target/client.lua',
    'modules/target/sleepless_interact/client.lua',
    'modules/target/ox_target/client.lua'
}

local Module = nil
for _, path in pairs(requiredModules) do
    local module = Require(path)
    if module then
        Module = module
    end
end

return Module or error('No target module found. Please ensure you have one of the required target modules installed: ' .. table.concat(requiredModules, ', '))