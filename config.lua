Config = {

  -- the minimum time the script should wait until it updates
  runEvery = 2, -- (2-10) in seconds.

  -- repopulate the map with vehicles that were lost when the server rebooted
  populateOnReboot = true, 

  -- how close a player needs to get to a deleted persistent vehicle before it is respawned
  respawnDistance = 400, -- (300-500+)

  -- enable debugging to see server console messages
  debug = false, 
}

-- delete vehicle entities that no player is close to, also deletes game spawned npc vehicles. It's practically a more agressive garbage collecter. This could, maybe, might, should, probably improves client performance. 
Config.entityManagement = false

-- the distance a vehicle entity needs to be from all players to be deleted. 
Config.entityManagementDistance = Config.respawnDistance + 50 -- must be higher than 350!