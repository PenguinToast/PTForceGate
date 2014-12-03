--- Details
local Direction = {
  LEFT = -2,
  RIGHT = 2,
  DOWN = -1,
  UP = 1,
  isVertical = function(direction)
    return direction == Direction.UP or direction == Direction.DOWN
  end,
  sign = function(direction)
    if direction < 0 then
      return -1
    elseif direction > 0 then
      return 1
    else
      return 0
    end
  end,
  getVector = function(direction)
    local out = {0, 0}
    if Direction.isVertical(direction) then
      out[2] = Direction.sign(direction)
    else
      out[1] = Direction.sign(direction)
    end
    return out
  end,
  rotate = function(direction) -- Rotate counter-clockwise.
    if direction == Direction.LEFT then
      return Direction.DOWN
    elseif direction == Direction.RIGHT then
      return Direction.UP
    elseif direction == Direction.DOWN then
      return Direction.LEFT
    else
      return Direction.RIGHT
    end
  end
}

function init(virtual)
  if not virtual then
    -- Fill connections table with default data
    local storage = storage
    local connections = storage.connections
    for _,direction in pairs(Direction) do
      connections[direction] = {
        gateId = nil, -- Entity ID of the connected gate
        forceDirection = nil, -- The direction of the force
        forceStrength = nil, -- The magnitude of the force
        force = nil, -- The force
        active = true -- Connections are active by default
      }
    end
    storage.maxRange = 15
    storage.forceStrength = 300
  end
end

-- TODO take into account gate activeness
function update(dt)
  -- Update global values (maxRange, force)
  loadGlobal()
  -- Check for no longer existing connections
  cleanConnections()
  -- Check LoS on existing connections
  checkLoS()
  -- Find new gates to connect to
  findConnections()
  -- Apply the forces
  applyForces()
end

function die()
  -- Kill any attached force monsters.
  local monsters = storage.monsters
  for count = 1, #monsters, 1 do
    local mId = monsters[count]
    if world.entityExists(mId) and
      world.callScriptedEntity(mId, "isForceMonster")
    then
      world.callScriptedEntity(mId, "kill")
    end
    monsters[count] = nil
  end
end

--- Loads any global properties.
function loadGlobal()
  local storage = storage
  local globalProperties = world.getProperty("ptforcegate")
  if globalProperties then
    if globalProperties.maxRange ~= storage.maxRange then
      storage.maxRange = globalProperties.maxRange
    end
    if globalProperties.forceStrength ~= storage.forceStrength then
      local id = entity.id()
      local strength = globalProperties.forceStrength
      storage.forceStrength = strength
      -- Update each connection
      for direction,connection in pairs(storage.connections) do
        connection.forceStrength = strength
        local dir = connection.forceDirection
        local force = {dir[1] * strength, dir[2] * strength}
        connection.force = force
        if connection.gateId then
          world.callScriptedEntity(connection.gateId, "connectResponse",
                                     -direction, id, force)
        end
      end
    end
  end
end

--- Cleans any dead connections.
function cleanConnections()
  local storage = storage
  local connections = storage.connections
  for direction,connection in pairs(connections) do
    if connection.gateId then
      if not world.entityExists(connection.gateId) then
        connection.gateId = nil
      end
    end
  end
end

--- Check LoS to existing connections.
function checkLoS()
  local storage = storage
  local connections = storage.connections
  for direction,connection in pairs(connections) do
    if connection.gateId then
      if not hasLoS(world.entityPosition(connection.gateId)) then
        connection.gateId = nil
      end
    end
  end
end

--- Find new connections.
function findConnections()
  local storage = storage
  local connections = storage.connections
  local gates = findGates()
  for _,direction in pairs(Direction) do
    local connection = connections[direction]
    local gate = gates[direction]
    if gate then
      if connection.gateId == nil or connection.gateID ~= gate then
        -- Connection to gate
        connect(gate)
      end
    end
  end
end

--- Apply the forces of the connections,
function applyForces()
  local storage = storage
  local connections = storage.connections
  local count = 0
  local monsters = storage.monsters
  local pos
  for direction,connection in pairs(connections) do
    if connection.owner and connection.active and storage.active then
      count = count + 1
      if count > 1 then -- Use a monster to apply the force
        local monsterId = monsters[forceCount - 1]
        if monsterId == nil
          or not world.entityExists(monsterId)
          or not world.callScriptedEntity(monsterId, "isForceMonster")
        then
          if not pos then
            pos = entity.position()
            pos[1] = pos[1] + 0.5
            pos[2] = pos[2] + 0.5
          end
          monsterId = world.spawnMonster("ptforcemonster", pos)
          monsters[forceCount - 1] = monsterId
        end
        world.callScriptedEntity(monsterId, "setForceToApply",
                                 connection.forceRegion, connection.force)
      else -- Apply the force by self
        entity.setForceRegion(connection.forceRegion, connection.force)
      end
    end
  end
  -- Clean up unneeded dummy monsters
  for i = count, #monsters, 1 do
    local monsterId = monsters[count]
    if world.entityExists(monsterId) and
      world.callScriptedEntity(monsterId, "isForceMonster")
    then
      world.callScriptedEntity(monsterId, "kill")
    end
    storage.forceMonsters[count] = nil
  end
end

--- Update the animations.
function updateAnimationState()
  if storage.active then
    entity.setAnimationState("gatestate", "on")
  else
    entity.setAnimationState("gatestate", "off")
  end
  local ang = {0, 0}
  local count = 1
  -- Draw gate beams
  for direction,connection in pairs(storage.connections) do
    ang = {ang[1] + connection.forceDirection[1],
           ang[2] + connection.forceDirection[2]}
    if connection.isOwner and connection.active and storage.active then
      entity.rotateGroup("beam" .. count, data.angle)
      entity.scaleGroup("beam" .. count, data.animationScale)
      count = count + 1
    end
  end
  for i = count, 4, 1 do
    entity.scaleGroup("beam" .. i, {0, 1})
  end
  -- Draw direction arrow
  if ang[1] == 0 and ang[2] == 0 then
    entity.setAnimationState("arrowstate", "zero")
    entity.rotateGroup("direction", 0)
  else
    entity.setAnimationState("arrowstate", "normal")
    entity.rotateGroup("direction", math.atan2(ang[2], ang[1]))
  end
end

--- Connects this gate to another.
-- @param direction The direction of the connection.
-- @param gate The entity ID of the gate to connect to.
function connect(direction, gate)
  local storage = storage
  local connection = storage.connections[direction]
  connection.gateId = gate
  local force = connection.force
  force, active = world.callScriptedEntity(gate,
                                           "connectResponse",
                                             -direction,
                                           entity.id(),
                                           force,
                                           connection.active)
  local direction, strength = unitVector(force)
  local region = createRegion(direction, gate)
  connection.force = force
  conenction.forceDirection = direction
  connection.forceStrength = strength
  connection.forceRegion = region
  connection.active = active
  connection.owner = true
end

function connectResponse(direction, gate, force, active)
  local storage = storage
  local connection = storage.connections[direction]
  active = active and connection.active

  if not force then
    if connection.force then
      force = connection.force
    else
      local direction = Direction.getVector(Direction.rotate(direction))
      local strength = storage.forceStrength
      force = {direction[1] * strength, direction[2] * strength}
    end
  end
  connection.force = force
  connection.owner = false
  
  return force, active
end

function setConnectionActive(direction, active)
  local connection = storage.connections[direction]
  if connection.active ~= active then
    connection.active = active
    if connection.gateId then
      world.callScriptedEntity(connection.gateId, "setConnectionActive",
                                 -direction, active)
    end
  end
end

--- Checks if this entity has LoS to the target position.
-- @param source[opt] The source position.
-- @param target The position to check LoS to.
-- @return True if this entity has LoS, false if not.
function hasLoS(source, target)
  local pos
  if target then
    pos = source
  else
    pos = entity.position()
    target = source
  end
  local col = world.collisionBlocksAlongLine(pos, target, true, 1)
  return #col ==  0
end

--- Find the closest gate in each direction.
-- @param A table, with directions as keys and closest gates as values.
function findGates()
  local pos = entity.position()
  local range = storage.maxRange
  local searchStart = {
    pos[1] - range + 0.5,
    pos[2] - range + 0.5
  }
  local searchEnd = {
    pos[1] + range + 0.5,
    pos[2] + range + 0.5
  }
  local objects = world.objectQuery(searchStart, searchEnd,
                                    {withoutEntityId = entity.id(),
                                     name = "ptforcegate"})
  local out = {}
  local minX = -range
  local maxX = range
  local minY = -range
  local maxY = range
  local dif
  for _,objectId in objects do
    local objectPos = world.entityPosition(objectId)
    if objectPos[1] == pos[1] and hasLoS(pos, objectPos) then -- vertical
      dif = objectPos[1] - pos[1]
      if dif > 0 then -- right
        if dif < maxX then
          maxX = dif
          out[Direction.RIGHT] = objectId
        end
      else -- left
        if dif > minX then
          minX = dif
          out[Direction.LEFT] = objectId
        end
      end
    elseif objectPos[2] == pos[2] and hasLoS(pos, objectPos) then -- horizontal
      dif = objectPos[2] - pos[2]
      if dif > 0 then -- up
        if dif < maxY then
          maxY = dif
          out[Direction.UP] = objectId
        end
      else -- down
        if dif > minY then
          minY = dif
          out[Direction.DOWN] = objectId
        end
      end
    end
  end
  return out
end

function unitVector(vec)
  local x = vec[1]
  local y = vec[2]
  local len = math.sqrt(x * x + y * y)
  local direction = {
    x / len,
    y / len
  }
  return direction, len
end

function createRegion(direction, gate)
  local source = entity.position()
  local target = world.entityPosition(gate)
  local region
  if direction == Direction.UP then
    local len = target[2] - source[2]
    region = {source[1] - 0.5, source[2],
              source[1] + 0.5, source[2] + len}
  elseif direction == Direction.DOWN then
    local len = source[2] - target[2]
    region = {source[1] - 0.5, source[2] - len,
              source[1] + 0.5, source[2]}
  elseif direction == Direction.LEFT then
    local len = source[1] - target[1]
    region = {source[1] - len, source[2] - 0.5,
              source[1], source[2] + 0.5}
  elseif direction == Direction.RIGHT then
    local len = target[1] - source[1]
    region = {source[1], source[2] - 0.5,
              source[1] + len, source[2] + 0.5}
  else
    assert(false, "Direction was not valid.")
  end
  return region
end
