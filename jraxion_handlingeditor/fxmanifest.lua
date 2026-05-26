shared_script '@xeroshieldv3/init.lua'
fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'jraxion_handlingeditor'
version '1.0.0'
description 'Handling Editor'
author 'JRaxion'
url 'https://jraxion.tebex.io/'

client_scripts {
    'config.lua',
    'client/client.lua'
}

server_scripts {
    'config.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.js',
    'html/*.js',

    'handling.meta',
}

data_file 'HANDLING_FILE' 'handling.meta'

escrow_ignore {
    'config.lua',
    'server/server.lua',
}

dependency '/assetpacks'