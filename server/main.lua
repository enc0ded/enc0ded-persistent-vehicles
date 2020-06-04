local PV = {
  players = {},
  vehicles = {},
  waiting = 0,
  debugging = Config.debug,
}

-- events
RegisterServerEvent('persistent-vehicles/register-vehicle')
AddEventHandler('persistent-vehicles/register-vehicle', function (netId, props)
  local _source = source
  if type(netId) ~= 'number' then return end
  PV.RegisterVehicle(netId, props)
  PV.players[_source] = true
end)

RegisterServerEvent('persistent-vehicles/forget-vehicle')
AddEventHandler('persistent-vehicles/forget-vehicle', function (netId)
  if type(netId) ~= 'number' then return end
  PV.ForgetVehicle(netId)
end)


RegisterServerEvent('persistent-vehicles/done-spawning')
AddEventHandler('persistent-vehicles/done-spawning', function (response)
  local _source = source
  if PV.waiting[_source] then 
    for i = 1, #response do
      local data = response[i]    
      local entity = PV.GetVehicleEntityFromNetId(data.netId)
      if not entity then
          PV.ForgetVehicle(data.plate)
      else
        PV.vehicles[data.plate].entity = PV.GetVehicleEntityFromNetId(data.netId)
      end
    end
    PV.waiting[_source] = nil
  end

  if PV.debugging then
    local _source = source
    print('Persistent Vehicles: Server received client spawn confirmation from:', _source)
  end
end)

RegisterServerEvent('persistent-vehicles/save-vehicles-to-file')
AddEventHandler('persistent-vehicles/save-vehicles-to-file', function ()
  PV.SavedPlayerVehiclesToFile()
  print('Persistent Vehicles: All vehicles saved to file')
end)

RegisterServerEvent('persistent-vehicles/new-player')
AddEventHandler('persistent-vehicles/new-player', function()
  local _source = source
  PV.players[_source] = true
end)

AddEventHandler("onResourceStop", function(resource)
  if resource ~= GetCurrentResourceName() then return end
  if Config.populateOnReboot then
    PV.SavedPlayerVehiclesToFile()
  end
end)


-- commands
RegisterCommand('pv-cull', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  PV.CullVehicles(args[1])
  print('Persistent Vehicles: Culled:', args[1] or 10)
end, true)

RegisterCommand('pv-forget-all', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  PV.ForgetAllVehicles()
end, true)

RegisterCommand('pv-save-to-file', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  PV.SavedPlayerVehiclesToFile()
end, true)

RegisterCommand('pv-toggle-debugging', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  PV.debugging = not PV.debugging
  print('Toggled debugging')
end, true)

RegisterCommand('pv-shutdown', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  for i = GetNumResources(), 1, -1 do
      local resource = GetResourceByFindIndex(i)
      StopResource(resource)
  end
end, true)

local total = 0
RegisterCommand('pv-spawn-test', function (source, args, rawCommand)
  local num = args[1] or 1
  for i = 1, tonumber(num) do
    Wait(0) 
    local plate = tostring(total)
      TriggerClientEvent('persistent-vehicles/test-spawn', source, plate, args[2])
      total = total + 1
  end
end, true)

-- global functions
if Config.populateOnReboot then
  local SavedPlayerVehicles = LoadResourceFile(GetCurrentResourceName(), "vehicle-data.json")
  if SavedPlayerVehicles ~= '' then
      PV.vehicles = json.decode(SavedPlayerVehicles)
      if not PV.vehicles then
          PV.vehicles = {}
      end
      if PV.debugging then
          print('Persistent Vehicles: Loaded Vehicles from file')
      end
  end
end

function PV.SavedPlayerVehiclesToFile()
  SaveResourceFile(GetCurrentResourceName(), "vehicle-data.json", json.encode(PV.vehicles), -1)
  if PV.debugging then
    print('Persistent Vehicles: Saved Vehicles to file')
  end
end

function PV.DoesVehicleExist(entity)
  local vehicles = GetAllVehicles()
  for i = 1, #vehicles do
    if vehicles[i] == entity then
      return true
    end
  end
  return false
end

function PV.GetVehicleEntityFromNetId(netId)
  local vehicles = GetAllVehicles()
  for i = 1, #vehicles do
    if NetworkGetNetworkIdFromEntity(vehicles[i]) == netId then
      return vehicles[i]
    end
  end
  return false
end

function PV.DistanceFrom(x1, y1, z1, x2, y2, z2) 
  return  math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

function PV.GetPlayers()
  local players = {}
  for _source,v in pairs(PV.players) do
    local ped = GetPlayerPed(_source)
    if DoesEntityExist(ped) then
      table.insert(players, _source)
    else
      PV.players[_source] = nil
    end
  end
	return players
end


function PV.GetClosestPlayerToCoords(coords)

  local players = PV.GetPlayers()
  if #players == 0 then return end

  local closestDist, closestPlayerId

  for i = 1, #players do
    local playerCoords = GetEntityCoords(GetPlayerPed(players[i]))
    local dist = PV.DistanceFrom(coords.x, coords.y, coords.z, playerCoords.x, playerCoords.y, playerCoords.z)
    
    if not closestDist or dist <= closestDist then
        closestDist = dist
        closestPlayerId = players[i]
    end
  end
  return closestPlayerId, closestDist
end

function PV.RegisterVehicle(netId, props)
  if PV.vehicles[props.plate] ~= nil then return end
  if PV.Tablelength(PV.vehicles) > 90 then
    PV.CullVehicles(2)
  end

  -- don't register the vehicle immediately incase it is deleted straight away
  Citizen.SetTimeout(1500, function ()
    local entity = PV.GetVehicleEntityFromNetId(netId)
    if not entity then return end
    PV.vehicles[props.plate] = {entity = entity, props = props}
    if PV.debugging then
      print('Persistent Vehicles: Registered Vehicle', props.plate, netId, entity)
    end
  end)
end

function PV.Tablelength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

function PV.ForgetVehicle(netId)
  if not netId then return end
  PV.vehicles[netId] = nil
  if PV.debugging then
    print('Persistent Vehicles: Forgotten Vehicle', netId)
  end
end

function PV.CullVehicles(amount)
  local num = amount or 10
  for key, value in pairs(PV.vehicles) do
    PV.ForgetVehicle(key)
    num = num - 1
    if num == 0 then
      break
    end
  end
  if PV.debugging then
    print('Persistent Vehicles: Culled vehicles', num)
  end
end

function PV.ForgetAllVehicles()
  PV.vehicles = {}
  PV.SavedPlayerVehiclesToFile()
  if PV.debugging then
    print('Persistent Vehicles: Forgot all vehicles. No vehicles are now persistent.')
  end
end

Citizen.CreateThread(function ()
  
  local players
  local payloads, requests = {}, 0

  while true do
    repeat
      Citizen.Wait(Config.runEvery * 1000)
      players = PV.GetPlayers()
    until #players > 0
    
    payloads = {}
    requests = 0

    -- get the client which is currently closest to this vehicle
    for plate, data in pairs(PV.vehicles) do
      if DoesEntityExist(data.entity) then
        local coords =  GetEntityCoords(data.entity)
        local rot = GetEntityRotation(data.entity)
        
        data.pos = {
          x = coords.x,
          y = coords.y,
          z = coords.z,
          h = GetEntityHeading(data.entity),
          r = { x = rot.x, y = rot.y, z = rot.z }
        }
        data.props.locked = GetVehicleDoorLockStatus(data.entity)
        data.props.bodyHealth = GetVehicleBodyHealth(data.entity)
        data.props.tankHealth = tonumber(GetVehiclePetrolTankHealth(data.entity))
        data.props.fuelLevel = 25 -- maybe GetVehicleFuelLevel() will be implemented server side one day?
        --data.props.engineHealth = GetVehicleEngineHealth(data.entity) -- not working properly atm
        --data.props.dirtLevel = GetVehicleDirtLevel(data.entity) -- not working properly atm
      else
        local closestPlayerId, closestDistance = PV.GetClosestPlayerToCoords(data.pos)

        -- only spawn the vehicle if a client is close enough
        if closestPlayerId ~= nil and closestDistance < 500 then
          if payloads[closestPlayerId] == nil then
            payloads[closestPlayerId] = {}
          end
          table.insert(payloads[closestPlayerId], data)
          requests = requests + 1
        end
      end
    end

    if requests > 0 then

      PV.waiting = {}
      -- consume any respawn requests we have
      for id, payload in pairs(payloads) do
        if DoesEntityExist(GetPlayerPed(id)) then
          TriggerClientEvent('persistent-vehicles/spawn-vehicles', id, payload)
          PV.waiting[id] = true
          if PV.debugging then
            print('Persistent Vehicles: Sent', #payload, ' vehicles to client', id, 'for spawning.')
          end
        end
      end

      -- wait for the clients to report that they've finished spawning
      local waited = 0
      repeat
        Citizen.Wait(1000)
        waited = waited + 1

        if PV.debugging and waited == 6 then
          print('Persistent Vehicles: Waited too long for the clients to respawn vehicles')
        end

      until PV.Tablelength(PV.waiting) == 0 or waited == 6
    end

  end
end)
