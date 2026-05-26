fx_version 'cerulean'
game 'gta5'

author 'ViperPVP'
description 'Script de blanchiment d\'argent - ViperPVP'
version '1.1.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/admin.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/logo.png'
}

lua54 'yes'
