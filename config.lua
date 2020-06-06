Config = {

  -- the minimum time the script should wait until it updates
  runEvery = 2, -- (1-5) in seconds.

  -- repopulate the map with vehicles that were lost when the server rebooted
  populateOnReboot = true, 

  -- how close a player needs to get to a deleted persistent vehicle before it is respawned
  respawnDistance = 350, -- 300+

  -- don't respawn a vehicle if it gets deleted after it is destroyed
  forgetOnDestroyed = true,

  -- enable debugging to see server console messages
  debug = false, 
}
-- This experimental feature increases the total number of vehicles you can spawn on the map at any one time.
-- It works by removing vehicles no one is close to. Persistent vehicles will then respawn when someone is closeby.
-- It will also remove distant NPC vehicles not just registered vehicles, which is an added benefit as it will remove ghost vehicles.
Config.entityManagement = false

-- the distance a player needs to be from the Config.respawnDistance for a vehicle's entity to be deleted 
local deletionDistance = 50 -- (25-1000)

Config.entityManagementDistance = Config.respawnDistance + deletionDistance -- must be equal more than 350!