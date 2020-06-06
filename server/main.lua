local PV = {
  players = {},
  vehicles = {},
  waiting = 0,
  debugging = Config.debug,
}

-- events
RegisterServerEvent('persistent-vehicles/server/register-vehicle')
AddEventHandler('persistent-vehicles/server/register-vehicle', function (netId, props)
  local _source = source
  if type(netId) ~= 'number' then return end
  PV.players[_source] = true
  PV.RegisterVehicle(netId, props)
end)

RegisterServerEvent('persistent-vehicles/server/forget-vehicle')
AddEventHandler('persistent-vehicles/server/forget-vehicle', function (plate)
  PV.ForgetVehicle(plate)
end)

-- must be called from the server with TriggerEvent('persistent-vehicles/save-vehicles-to-file')
RegisterServerEvent('persistent-vehicles/save-vehicles-to-file')
AddEventHandler('persistent-vehicles/save-vehicles-to-file', function ()
  if not GetInvokingResource() then return end
  PV.SavedPlayerVehiclesToFile()
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
        PV.vehicles[data.plate].entity = entity
      end
    end
    PV.waiting[_source] = nil
  end

  if PV.debugging then
    local _source = source
    print('Persistent Vehicles: Server received client spawn confirmation from:', _source)
  end
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
  print('Persistent Vehicles: Toggled debugging')
end, true)

RegisterCommand('pv-shutdown', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  for i = GetNumResources(), 1, -1 do
      local resource = GetResourceByFindIndex(i)
      StopResource(resource)
  end
end, true)

-- pv-spawn-test <number of vehicles> <vehicle model name>
--[[ local total = 0
RegisterCommand('pv-spawn-test', function (source, args, rawCommand)
	local num = 0.4
  local ped = GetPlayerPed(source)
  local coords = GetEntityCoords(ped)
  local amount = args[1] or 1
  for i = 1, tonumber(amount) do
    local plate = tostring(total)
    local data = {
      props = {model = args[2] or 'blista', plate = plate },
      pos = {x = coords.x + num, y = coords.y + num, z = coords.z + 0.1, h = 40.0},
    }
    num = num + 1.45
    total = total + 1
    PV.vehicles[data.props.plate] = data
    print('Debugging: Added Vehicles')
  end
end, true) ]]

-- global functions
function PV.GetVehicleEntityFromNetId(netId)
  local vehicles = GetAllVehicles()
  for i = 1, #vehicles do
    if NetworkGetNetworkIdFromEntity(vehicles[i]) == netId then
      return vehicles[i]
    end
  end
  return false
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

function PV.DistanceFrom(x1, y1, z1, x2, y2, z2) 
  return  math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

function PV.GetClosestPlayerToCoords(coords)
  local closestDist, closestPlayerId

  for playerId in pairs(PV.players) do
    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
    local dist = PV.DistanceFrom(coords.x, coords.y, coords.z, playerCoords.x, playerCoords.y, playerCoords.z)
    if not closestDist or dist <= closestDist then
        closestDist = dist
        closestPlayerId = playerId
    end
  end
  return closestPlayerId, closestDist
end

function PV.Tablelength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

function PV.RegisterVehicle(netId, props)
  if PV.vehicles[props.plate] ~= nil then return end
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

function PV.ForgetVehicle(plate)
  if not plate then return end
  PV.vehicles[plate] = nil
  if PV.debugging then
    print('Persistent Vehicles: Forgotten Vehicle', plate)
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

function PV.SavedPlayerVehiclesToFile()
  SaveResourceFile(GetCurrentResourceName(), "vehicle-data.json", json.encode(PV.vehicles), -1)
  print('Persistent Vehicles: All vehicles saved to file')
end

function PV.LoadVehiclesFromFile() 
  local SavedPlayerVehicles = LoadResourceFile(GetCurrentResourceName(), "vehicle-data.json")
  if SavedPlayerVehicles ~= '' then
      PV.vehicles = json.decode(SavedPlayerVehicles)
      if not PV.vehicles then
          PV.vehicles = {}
      end
      if PV.debugging then
          print('Persistent Vehicles: Loaded '.. PV.Tablelength(PV.vehicles) .. ' Vehicle(s) from file')
      end
  end
end

-- main thread
Citizen.CreateThread(function ()

  local players = {}
  local payloads = {}
  local hasRequests = false

  if Config.populateOnReboot then
    PV.LoadVehiclesFromFile() 
  end
  
  while true do
    
    repeat
      Citizen.Wait(Config.runEvery * 1000)
      players = PV.GetPlayers()
    until #players > 0
    
    local threadTime = os.clock()

    payloads = {}
    hasRequests = false

    for plate, data in pairs(PV.vehicles) do

      -- if vehicle entity exists, update it's data
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

        if data.props then
          data.props.locked = GetVehicleDoorLockStatus(data.entity)
          data.props.bodyHealth = GetVehicleBodyHealth(data.entity)
          data.props.tankHealth = GetVehiclePetrolTankHealth(data.entity)
          --data.props.fuelLevel = 25 -- maybe GetVehicleFuelLevel() will be implemented server side one day?
          --data.props.engineHealth = GetVehicleEngineHealth(data.entity) -- not working properly atm
          --data.props.dirtLevel = GetVehicleDirtLevel(data.entity) -- not working properly atm
        end

        -- forget vehicle if destroyed
        if Config.forgetOnDestroyed and (tonumber(data.props.bodyHealth) == 0 or not data.props.tankHealth) then
          PV.ForgetVehicle(data.props.plate)
        end

      -- entity doesn't exist, attempt to create spawn event for this vehicle
      elseif data.pos then

        local closestPlayerId, closestDistance

        if data.closestPlayerId then
          closestPlayerId = data.closestPlayerId
          closestDistance = data.closestDistance
          data.closestPlayerId = nil 
          data.closestDistance = nil
        else
          closestPlayerId, closestDistance = PV.GetClosestPlayerToCoords(data.pos)
        end
       
        -- only spawn the vehicle if a client is close enough
        if closestPlayerId ~= nil and closestDistance < Config.respawnDistance then
          
          if payloads[closestPlayerId] == nil then
            payloads[closestPlayerId] = {}
            hasRequests = true
          end

          -- to prevent exceeding the gfx pool size
          if #payloads[closestPlayerId] < 51 then
            table.insert(payloads[closestPlayerId], data)
          else
            -- but we'll cache this for next time as getting the closest player is pretty expensive
            data.closestPlayerId  = closestPlayerId
            data.closestDistance  = closestDistance
          end

        end

      else
        PV.ForgetVehicle(data.props.plate)
        if PV.debugging then
          print('Persistent Vehicles: Warning', data.props.plate, 'did have time to update its position before it was deleted')
        end
      end
    end


    if hasRequests then

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
        Citizen.Wait(100)
        waited = waited + 1

        if PV.debugging and waited == 60 then
          print('Persistent Vehicles: Waited too long for the clients to respawn vehicles')
        end

      until PV.Tablelength(PV.waiting) == 0 or waited == 60
    end

  end
end)

if Config.entityManagement then
  Citizen.CreateThread(function()
    while true do 
      Wait(3000)
      
      local payloads = {}
      local vehicles = GetAllVehicles()

      for i = 1, #vehicles do
        local entity = vehicles[i]
        if entity > 0 and DoesEntityExist(entity) then
          local coords = GetEntityCoords(entity)
          local closestPlayerId, closestDistance = PV.GetClosestPlayerToCoords(coords)
          if closestDistance ~= nil and closestDistance > Config.entityManagementDistance then
            local playerSource = NetworkGetEntityOwner(entity)
            if not payloads[playerSource] then
              payloads[playerSource] = {}
            end
            table.insert(payloads[playerSource], NetworkGetNetworkIdFromEntity(entity))
          end
        end
      end

      for _source, payload in pairs(payloads) do
        print('removing vehicle')
        TriggerClientEvent('persistent-vehicles/remove-vehicle', _source, payload)
        if PV.debugging then
          print('Persistent Vehicles: Deleting Distant Entities | Amount:', #payload, 'Client:', _source, 'Entities\' NetIds:', table.concat( payload, ", "))
        end
      end
    end
  end)
end
