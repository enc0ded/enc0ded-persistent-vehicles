RegisterNetEvent('persistent-vehicles/register-vehicle')
AddEventHandler('persistent-vehicles/register-vehicle', function (entity)
	Wait(0)
	local props = _Utils.GetVehicleProperties(entity)
	TriggerServerEvent('persistent-vehicles/server/register-vehicle', NetworkGetNetworkIdFromEntity(entity), props)
end)

RegisterNetEvent('persistent-vehicles/forget-vehicle')
AddEventHandler('persistent-vehicles/forget-vehicle', function (entity)
	Wait(0)
	TriggerServerEvent('persistent-vehicles/server/forget-vehicle', _Utils.Trim(GetVehicleNumberPlateText(entity)))
end)

RegisterNetEvent('persistent-vehicles/spawn-vehicles')
AddEventHandler('persistent-vehicles/spawn-vehicles', function (datas)
	local updatedNetIds = {}
	for i = 1, #datas do
		local data = datas[i]
		local entity = _Utils.CreateVehicle(data.props.model, data.pos, data.props)
		table.insert(updatedNetIds, {netId = NetworkGetNetworkIdFromEntity(entity), plate = data.props.plate})
	end
	Wait(100)
	TriggerServerEvent('persistent-vehicles/done-spawning', updatedNetIds)
end)

Citizen.CreateThread(function() 
	while not DoesEntityExist(PlayerPedId(-1)) do
		Wait(1000)
	end
	TriggerServerEvent('persistent-vehicles/new-player') 
end)

--[[ 
local num = 0.2
RegisterNetEvent('persistent-vehicles/test-spawn')
AddEventHandler('persistent-vehicles/test-spawn', function (data, model)
		local props = { plate = data, model = model or 'blista' }
		local coords = {}
		local vec = GetEntityCoords(PlayerPedId(-1))
		coords.x = vec.x + num
		coords.y = vec.y + num
		coords.z = vec.z + 0.1
		coords.h = 45.0
		num = num + 1.4
		local entity = _Utils.CreateVehicle(props.model, coords, props, false)
		props = _Utils.GetVehicleProperties(entity)
		TriggerServerEvent('persistent-vehicles/register-vehicle', NetworkGetNetworkIdFromEntity(entity), props)
end) ]]