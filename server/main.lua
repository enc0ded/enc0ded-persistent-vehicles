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

RegisterServerEvent('persistent-vehicles/server/update-vehicle')
AddEventHandler('persistent-vehicles/server/update-vehicle', function (plate, props)
  if PV.vehicles[plate] == nil then return end
  PV.vehicles[plate].props = props
  if PV.debugging then
    print('Persistent Vehicles: Update Vehicle Props - ' .. plate)
  end
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
      elseif(PV.vehicles[data.plate]) then
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
  print('Persistent Vehicles: Toggled debugging', PV.debugging)
end, true)

RegisterCommand('pv-num-spawned', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  print('Persistent Vehicles: Number of vehicles currently spawned including unregistered:' .. PV.Tablelength(GetAllVehicles()) .. ' Number of registered spawned: ' .. PV.NumberSpawned())
end, true)

RegisterCommand('pv-num-registered', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  print('Persistent Vehicles: Number of persistent vehicles registered: ' .. PV.Tablelength(PV.vehicles))
end, true)

RegisterCommand('pv-shutdown', function (source, args, rawCommand)
  if tonumber(source) > 0 then return end
  for i = GetNumResources(), 1, -1 do
      local resource = GetResourceByFindIndex(i)
      StopResource(resource)
  end
end, true)

-- pv-spawn-test <number of vehicles> <vehicle model name>
--[[ RegisterCommand('pv-spawn-test', function (source, args, rawCommand)
  local total = PV.Tablelength(PV.vehicles) + 1
	local num = 0.5
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
function PV.Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

function PV.Tablelength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
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

function PV.GetVehicleEntityFromNetId(netId)
  local vehicles = GetAllVehicles()
  for i = 1, #vehicles do
    if NetworkGetNetworkIdFromEntity(vehicles[i]) == netId then
      return vehicles[i]
    end
  end
  return false
end

function PV.GetClosestPlayerToCoords(coords)
  local closestDist, closestPlayerId, ped, dist, pedCoords
  for playerId in pairs(PV.players) do
    ped = GetPlayerPed(playerId)
    if ped > 0 then
      pedCoords = GetEntityCoords(ped)
      dist = PV.DistanceFrom(coords.x, coords.y, coords.z, pedCoords.x, pedCoords.y, pedCoords.z)
      if not closestDist or dist < closestDist then
          closestDist = dist
          closestPlayerId = playerId
      end
    end
  end
  return closestPlayerId, closestDist
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

function PV.NumberSpawned()
  local num = 0
  for plate, data in pairs(PV.vehicles) do
    if DoesEntityExist(data.entity) then
      num = num + 1
    end
  end
  return num
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
  local num = PV.Tablelength(PV.vehicles)
  PV.vehicles = {}
  PV.SavedPlayerVehiclesToFile()
  print('Persistent Vehicles: Forgotten '..num..' vehicles. No vehicles are now persistent.')
end

function PV.SavedPlayerVehiclesToFile()
  SaveResourceFile(GetCurrentResourceName(), "vehicle-data.json", json.encode(PV.vehicles), -1)
  print('Persistent Vehicles: '.. PV.Tablelength(PV.vehicles) .. ' vehicles saved to file')
end

function PV:LoadVehiclesFromFile()
  Wait(0)
  local SavedPlayerVehicles = LoadResourceFile(GetCurrentResourceName(), "vehicle-data.json")
  if SavedPlayerVehicles ~= '' then
      Wait(0)
      self.vehicles = json.decode(SavedPlayerVehicles)
      if not self.vehicles then
          self.vehicles = {}
      end
      if self.debugging then
          print('Persistent Vehicles: Loaded '.. self.Tablelength(self.vehicles) .. ' Vehicle(s) from file')
      end
  end
end

function PV:TriggerSpawnEvents()

  local payloads = {}
  local requests = 0
  local spawned = 0
  for plate, data in pairs(self.vehicles) do
    if not DoesEntityExist(data.entity) then
      if data.pos then
        -- throttle if request gets too large
        requests = requests + 1
        if requests % 3 == 0 then
          Citizen.Wait(0)
        end

        local closestPlayerId, closestDistance = self.GetClosestPlayerToCoords(data.pos)
        
        -- only spawn the vehicle if a client is close enough
        if closestDistance and closestDistance < Config.respawnDistance then

          if payloads[closestPlayerId] == nil then
            payloads[closestPlayerId] = {}
            spawned = spawned + 1
          end
          
          if #payloads[closestPlayerId] < 51 then
            table.insert(payloads[closestPlayerId], data)
          end

        end

      else
        self.ForgetVehicle(plate)
        if self.debugging then
          print('Persistent Vehicles: Warning', plate, 'did NOT have time to update its position before it was deleted')
        end
      end
    end
  end
  
  if spawned > 0 then
    Citizen.Wait(0)
    self.waiting = {}
    -- consume any respawn requests we have
    for id, payload in pairs(payloads) do
      if DoesEntityExist(GetPlayerPed(id)) then
        TriggerClientEvent('persistent-vehicles/spawn-vehicles', id, payload)
        self.waiting[id] = true
        if self.debugging then
          print('Persistent Vehicles: Sent', #payload, ' vehicles to client', id, 'for spawning.')
        end
      end
    end

    -- wait for the clients to report that they've finished spawning
    local waited = 0
    repeat
      Citizen.Wait(100)
      waited = waited + 1

      if self.debugging and waited == 60 then
        print('Persistent Vehicles: Waited too long for the clients to respawn vehicles')
      end

    until self.Tablelength(self.waiting) == 0 or waited == 60
  end

end

function PV:UpdateAllVehicleData()

  for plate, data in pairs(self.vehicles) do

    if not data.entity or not DoesEntityExist(data.entity) then
      data.entity = nil
    else
      local coords =  GetEntityCoords(data.entity)
      local rot = GetEntityRotation(data.entity)
      
      -- coords sometimes returns nil for no reason
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
	      data.props.engine = GetIsVehicleEngineRunning(data.entity)
        --data.props.fuelLevel = 25 -- maybe GetVehicleFuelLevel() will be implemented server side one day?
        --data.props.engineHealth = GetVehicleEngineHealth(data.entity) -- not working properly atm
        --data.props.dirtLevel = GetVehicleDirtLevel(data.entity) -- not working properly atm

        -- forget vehicle if destroyed
        if Config.forgetOnDestroyed and (tonumber(data.props.bodyHealth) == 0 or not data.props.tankHealth) then
          PV.ForgetVehicle(plate)
        end

      else
        PV.ForgetVehicle(plate)
      end
      
    end
  end
end
 
function PV:RunEntityMangement()
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
    TriggerClientEvent('persistent-vehicles/remove-vehicle', _source, payload)
    if PV.debugging then
      print('Persistent Vehicles: Deleting Distant Entities | Amount:', #payload, 'Client:', _source, 'Entities\' NetIds:', table.concat( payload, ", "))
    end
  end
end

-- main thread
Citizen.CreateThread(function ()

  if Config.populateOnReboot then
    PV:LoadVehiclesFromFile() 
  end
  
  while true do
    Citizen.Wait(1500)
    PV:TriggerSpawnEvents()

    Citizen.Wait(0)
    PV:UpdateAllVehicleData()
    
    if Config.entityManagement then
      Citizen.Wait(0)
      PV:RunEntityMangement()
    end

  end
end)

