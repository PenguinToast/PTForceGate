
function startTriggered()
  local aimPos = item.ownerAimPosition()
  aimPos = {math.floor(aimPos[1]), math.floor(aimPos[2])}
  local objects = world.objectQuery(
    aimPos, aimPos,
    {name = "ptforcegate", boundMode = "Position"}
  )
  if #objects == 1 then -- Should not be more than one object at a position
    local ownerPos = item.ownerPosition()
    local players = world.playerQuery(
      ownerPos, ownerPos,
      {boundMode = "Position"}
    )
    if #players == 1 then -- Be sure we have the right player
      local playerUuid = world.entityUuid(players[1])
      local controllers = world.getProperty("ptforcecopy" .. playerUuid)
      if controllers then
        world.callScriptedEntity(objects[1], "receiveControllers", controllers)
      end
    end
  end
end
