fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'MATO'
description 'Modern staff panel for QBCore'
version '1.0.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/style.css',
    'web/js/script.js',
    'web/images/*.png'
}

dependencies {
    'qb-core'
}