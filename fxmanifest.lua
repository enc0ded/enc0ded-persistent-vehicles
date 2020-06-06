fx_version 'adamant'

game 'gta5'

description 'Persistent Vehicles Mod: '

version '1.0.0'

client_scripts {
	'config.lua',
	'client/entityiter.lua',
	'client/_utils.lua',
	'client/main.lua',
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'@async/async.lua',
	'config.lua',
	'server/main.lua',
}
