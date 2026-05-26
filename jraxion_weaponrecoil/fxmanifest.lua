shared_script '@xeroshieldv3/init.lua'
fx_version 'cerulean'
game 'gta5'

name 'jraxion-weaponrecoil'
version '1.0.0'
description 'Weapon Recoil Script'

client_scripts {
    'config.lua',
    'client/main.lua'
}

escrow_ignore {
    'config.lua',
}

lua54 'yes'
dependency '/assetpacks'