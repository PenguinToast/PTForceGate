function init(virtual)
  if not virtual and not storage.initialized then
    local storage = storage
    -- Fill connections table with default data
    local connections = storage.connections
    if not connections then
      connections = {}
      storage.connections = connections
    end
    for _,direction in ipairs(Direction.list) do
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
    storage.active = true
    if not storage.monsters then
      storage.monsters = {}
    end
    storage.initialized = true
    updateAnimationState()
  end
end

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
    if mId then
      if world.entityExists(mId) and
        world.callScriptedEntity(mId, "isForceMonster")
      then
        world.callScriptedEntity(mId, "kill")
      end
      monsters[count] = nil
    end
  end
  storage.initialized = false
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
                                   Direction.flip(direction), id, force)
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
      if not world.entityExists(connection.gateId)
        or world.entityName(connection.gateId) ~= "ptforcegate"
      then
        connection.gateId = nil
        updateAnimationState()
      end
    end
  end
end

--- Check LoS to existing connections.
function checkLoS()
  local storage = storage
  local connections = storage.connections
  local pos = entity.position()
  local maxRange = storage.maxRange
  for direction,connection in pairs(connections) do
    if connection.gateId then
      local target = world.entityPosition(connection.gateId)
      local dist = world.magnitude(pos, target)
      if not hasLoS(pos, target) or dist > maxRange then
        connection.gateId = nil
        updateAnimationState()
      end
    end
  end
end

--- Find new connections.
function findConnections()
  local storage = storage
  local connections = storage.connections
  local gates = findGates()
  for _,direction in ipairs(Direction.list) do
    local connection = connections[direction]
    local gate = gates[direction]
    if gate then
      if connection.gateId == nil or connection.gateId ~= gate then
        -- Connection to gate
        connect(direction, gate)
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
    if connection.gateId and connection.owner
      and connection.active and storage.active
    then
      count = count + 1
      if count > 1 then -- Use a monster to apply the force
        local monsterId = monsters[count - 1]
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
          monsters[count - 1] = monsterId
        end
        world.callScriptedEntity(monsterId, "setForceToApply",
                                 connection.forceRegion, connection.force)
      else -- Apply the force by self
        entity.setForceRegion(connection.forceRegion, connection.force)
      end
    end
  end
  -- Clean up unneeded dummy monsters
  local numMonsters = #monsters
  for i = count, numMonsters, 1 do
    local monsterId = monsters[count]
    if monsterId then
      if world.entityExists(monsterId) and
        world.callScriptedEntity(monsterId, "isForceMonster")
      then
        world.callScriptedEntity(monsterId, "kill")
      end
      monsters[count] = nil
    end
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
    if connection.gateId
      and connection.active
      and storage.active
    then
      ang = {ang[1] + connection.forceDirection[1],
             ang[2] + connection.forceDirection[2]}
      if connection.owner then
        entity.rotateGroup("beam" .. count, connection.angle)
        entity.scaleGroup("beam" .. count, connection.beamScale)
        count = count + 1
      end
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
  local response = world.callScriptedEntity(gate,
                                            "connectResponse",
                                            Direction.flip(direction),
                                            entity.id(),
                                            force,
                                            connection.active)
  force = response[1]
  active = response[2]
  local forceDirection, strength = unitVector(force)
  local region = createRegion(direction, gate)
  connection.force = force
  connection.forceDirection = forceDirection
  connection.forceStrength = strength
  connection.forceRegion = region
  connection.active = active
  connection.owner = true

  -- Data needed for visuals
  local dist = entity.distanceToEntity(gate)
  dist = math.sqrt(dist[1] * dist[1] + dist[2] * dist[2])
  connection.beamScale = {(dist - 1) / 10, 1}
  connection.angle = Direction.angle(direction)
  updateAnimationState()
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
  
  -- Data needed for visuals
  connection.forceAngle = math.atan2(force[2], force[1])

  updateAnimationState()
  return {force, active}
end

function setConnectionActive(direction, active)
  local connection = storage.connections[direction]
  if connection.active ~= active then
    connection.active = active
    if connection.gateId then
      world.callScriptedEntity(connection.gateId, "setConnectionActive",
                               Direction.flip(direction), active)
    end
    updateAnimationState()
  end
end

--- Checks if this entity has LoS to the target position.
-- @param source The source position.
-- @param target The position to check LoS to.
-- @return True if this entity has LoS, false if not.
function hasLoS(source, target)
  local col = world.collisionBlocksAlongLine(source, target, true, 1)
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
  for _,objectId in ipairs(objects) do
    local objectPos = world.entityPosition(objectId)
    local dif = world.distance(objectPos, pos)
    if dif[2] == 0 and hasLoS(pos, objectPos) then -- vertical
      if dif[1] > 0 then -- right
        if dif[1] < maxX then
          maxX = dif[1]
          out[Direction.RIGHT] = objectId
        end
      else -- left
        if dif[1] > minX then
          minX = dif[1]
          out[Direction.LEFT] = objectId
        end
      end
    elseif dif[1] == 0 and hasLoS(pos, objectPos) then -- horizontal
      if dif[2] > 0 then -- up
        if dif[2] < maxY then
          maxY = dif[2]
          out[Direction.UP] = objectId
        end
      else -- down
        if dif[2] > minY then
          minY = dif[2]
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
  local dist = entity.distanceToEntity(gate)
  local region
  if direction == Direction.UP then
    region = {source[1], source[2] + 0.5,
              source[1] + 1, source[2] + 0.5 + dist[2]}
  elseif direction == Direction.DOWN then
    region = {source[1], source[2] + 0.5 + dist[2],
              source[1] + 1, source[2] + 0.5}
  elseif direction == Direction.LEFT then
    region = {source[1] + 0.5 + dist[1], source[2],
              source[1] + 0.5, source[2] + 1}
  elseif direction == Direction.RIGHT then
    region = {source[1] + 0.5, source[2],
              source[1] + 0.5 + dist[1], source[2] + 1}
  else
    assert(false, "Direction was not valid.")
  end
  return region
end
