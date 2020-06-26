RegisterNetEvent('persistent-vehicles/register-vehicle')
AddEventHandler('persistent-vehicles/register-vehicle', function (entity, light)
	Wait(0)
	local props = _Utils.GetVehicleProperties(entity, light)
	TriggerServerEvent('persistent-vehicles/server/register-vehicle', NetworkGetNetworkIdFromEntity(entity), props)
end)

RegisterNetEvent('persistent-vehicles/update-vehicle')
AddEventHandler('persistent-vehicles/update-vehicle', function (entity, light)
	Wait(0)
	local plate = _Utils.Trim(GetVehicleNumberPlateText(entity))
	local props = _Utils.GetVehicleProperties(entity, light)
	TriggerServerEvent('persistent-vehicles/server/update-vehicle', plate, props)
end)

RegisterNetEvent('persistent-vehicles/forget-vehicle')
AddEventHandler('persistent-vehicles/forget-vehicle', function (entity)
	local plate = _Utils.Trim(GetVehicleNumberPlateText(entity))
	TriggerServerEvent('persistent-vehicles/server/forget-vehicle', plate)
end)

RegisterNetEvent('persistent-vehicles/spawn-vehicles')
AddEventHandler('persistent-vehicles/spawn-vehicles', function (datas)
	local updatedNetIds = {}
	for i = 1, #datas do
		local data = datas[i]

		-- this is a hacky way of stopping duplicates, until this https://github.com/citizenfx/natives/issues/315 this fixed
		local entity = _Utils.GetDuplicateVehicleCloseby(data.props.plate, data.pos, 25)
		if not entity then
			entity = _Utils.CreateVehicle(data.props.model, data.pos, data.props)
		end
		table.insert(updatedNetIds, {netId = NetworkGetNetworkIdFromEntity(entity), plate = data.props.plate})
	end
	Wait(100)
	TriggerServerEvent('persistent-vehicles/done-spawning', updatedNetIds)
end)

if Config.entityManagement then
	RegisterNetEvent('persistent-vehicles/remove-vehicle')
	AddEventHandler('persistent-vehicles/remove-vehicle', function (netIds)
		for i=1, #netIds do
			DeleteEntity(NetToEnt(netIds[i]))
		end
	end)
end

Citizen.CreateThread(function() 
	while not DoesEntityExist(PlayerPedId(-1)) do
		Wait(100)
	end
	TriggerServerEvent('persistent-vehicles/new-player') 
end)