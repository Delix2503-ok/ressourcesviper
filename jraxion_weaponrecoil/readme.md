
# JRaxion Weapon Recoil System

## Description
JRaxion Weapon Recoil is a premium FiveM resource that enhances the shooting experience by implementing realistic weapon recoil mechanics. This script adds both vertical and horizontal recoil to weapons, making combat more challenging and immersive.

## Features
- **Customizable Recoil Settings**: Configure vertical and horizontal recoil values for each weapon
- **Movement-Based Recoil**: Recoil increases with player movement speed for added realism
- **Vehicle Shooting Support**: Optional recoil adjustments when shooting from vehicles
- **Easy Configuration**: Simple config file to adjust all settings
- **Performance Optimized**: Minimal resource usage

## Installation
1. Extract the resource to your server's resources folder
2. Ensure the folder is named exactly `jraxion-weaponrecoil` (required)
3. Add `ensure jraxion-weaponrecoil` to your server.cfg
4. Configure weapons in the config.lua file
5. Restart your server

## Configuration
Easily customize recoil settings for each weapon in the config.lua file:
```lua
Config.RecoilNumbers = {
    [`WEAPON_SMG`] = {
        ['vertical'] = 1.0,    -- Vertical recoil multiplier
        ['horizontal'] = 2.0,  -- Horizontal recoil multiplier
    },
}
```

## Vehicle Settings
```lua
Config.EnableVehicleRecoil = true  -- Enable/disable recoil in vehicles
Config.VehicleRecoil = 0.8         -- Vehicle recoil multiplier
```

## Support
For support, please join our Discord: [discord.gg/jraxion](https://discord.gg/jraxion)

## License
This resource is protected by copyright. Unauthorized distribution, modification, or resale is strictly prohibited.
```