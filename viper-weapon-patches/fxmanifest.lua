shared_script '@xeroshieldv3/init.lua'
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/weapons.lua',
    'client/hitmarkers.lua',
}

server_scripts {
    'server/weapons.lua',
}

files {
    'html/index.html',
    'html/js/hitmarkers.js',
    'metas/weapon_pistol_mk2.meta',
    'metas/weaponsnspistol.meta',
    'metas/weapon_pistol50.meta',
    'metas/pedaiming.meta',
}

data_file 'WEAPONINFO_FILE_PATCH' 'metas/weapon_pistol_mk2.meta'
data_file 'WEAPONINFO_FILE_PATCH' 'metas/weaponsnspistol.meta'
data_file 'WEAPONINFO_FILE_PATCH' 'metas/weapon_pistol50.meta'
data_file 'PEDAIMING_FILE'        'metas/pedaiming.meta'

dependencies {
    'qb-core',
}
