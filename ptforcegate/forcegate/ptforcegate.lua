function init(virtual)
  if virtual == false and not storage.initialized then
    local storage = storage
    -- Fill connections table with default data
    local connections = storage.connections
    if not connections then
      connections = {}
      storage.connections = connections
    end
    storage.controlled = {} -- State of controllers
    for _,direction in ipairs(Direction.list) do
      local angle = Direction.angle(direction)
      connections[direction] = {
        gateId = nil, -- Entity ID of the connected gate
        force = nil, -- The force
        active = true, -- Connections are active by default
        angle = angle
      }
      entity.rotateGroup("beam" .. direction, angle)
      storage.controlled[direction] = {}
    end
    
    -- Constants for now, will be made configurable in a later version.
    storage.maxRange = 15
    storage.forceStrength = 300
    
    if not storage.monsters then
      storage.monsters = {}
    end
    storage.controllers = {} -- Controlling controllers
    storage.initialized = true
    entity.setAnimationState("gatestate", "off")
    updateAnimationState()
    entity.setInteractive(true)
  end
end

function update(dt)
  -- Check for no longer existing connections
  cleanConnections()
  -- Update global values (maxRange, force)\
  -- TODO not yet configurable
  -- loadGlobal()
  -- Update controllers
  updateControllers()
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

function onInteraction(args)
  -- Show GUI if the player is holding the wiretool.
  if world.entityHandItem(args.sourceId, "primary") == "ptforceconfigtool" then
    local consoleConfig = entity.configParameter("consoleConfig")
    consoleConfig.controllers = storage.controllers
    consoleConfig.sourceUuid = world.entityUuid(args.sourceId)
    return {"ScriptConsole", consoleConfig}
  else -- Flip the connections
    local connections = storage.connections
    local id = entity.id()
    for direction,connection in pairs(connections) do
      if connection.gateId and connection.active then
        local dir = unitVector(connection.force)
        dir = {-dir[1], -dir[2]}
        setConnectionAngle(direction, dir)
      end
    end
    updateAnimationState()
  end
end

--- Loads any global properties.
function loadGlobal()
  local storage = storage
  local globalProperties = world.getProperty("ptforcegateGlobal")
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
        local dir = unitVector(connection.force)
        -- TODO connection strength
      end
    end
  end
end

--- Updates any values from controllers.
function updateControllers()
  local controllers = storage.controllers
  local world = world
  local connections = storage.connections
  local controlled = {}
  for _,direction in ipairs(Direction.list) do
    controlled[direction] = {}
  end
  for i=#controllers,1,-1 do
    local controllerId = controllers[i]
    local controller = world.getProperty(
      "ptforcegateCtrl" .. controllerId)
    if controller then
      -- Copy settings
      for direction, connection in pairs(storage.connections) do
        local directionControl = controller[tostring(direction)]
        if directionControl.active ~= nil then
          controlled[direction].active = directionControl.active
          if directionControl.active ~= connection.active then
            setConnectionActive(direction, directionControl.active)
          end
        end
        if directionControl.forceDirection ~= nil then
          local newDir = directionControl.forceDirection
          local connection = connections[direction]
          if connection.gateId then
            controlled[direction].forceDirection = newDir
            local dir, str = unitVector(connections[direction].force)
            if not vectorEq(dir, newDir) then
              setConnectionAngle(direction, newDir)
            end
          end
        end
        if directionControl.forceStrength ~= nil then
          local newStrength = directionControl.forceStrength
          local connection = connections[direction]
          if connection.gateId then
            controlled[direction].forceStrength = newStrength
            local dir, str = unitVector(connections[direction].force)
            if str ~= newStrength then
              setConnectionStrength(direction, newStrength)
            end
          end
        end
      end
    else
      table.remove(controllers, i)
    end
  end
  storage.controlled = controlled
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
    if connection.gateId and connection.owner and connection.active then
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
  local ang = {0, 0}
  -- Draw gate beams
  for direction,connection in pairs(storage.connections) do
    local directionString
    if direction == Direction.UP then
      directionString = "top"
    elseif direction == Direction.DOWN then
      directionString = "bottom"
    elseif direction == Direction.LEFT then
      directionString = "left"
    else -- Direction.RIGHT
      directionString = "right"
    end
    if not connection.active or not connection.gateId or not connection.owner
    then
      entity.scaleGroup("beam" .. direction, {0, 1})
    end
      
    if connection.active then
      entity.setAnimationState(directionString .. "gatestate", "on")
      if connection.gateId then
        ang = {ang[1] + connection.force[1],
               ang[2] + connection.force[2]}
        if connection.owner then
          entity.scaleGroup("beam" .. direction, connection.beamScale)
        end
      end
    else
      entity.setAnimationState(directionString .. "gatestate", "off")
    end
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
  connection.forceRegion = region
  connection.active = active
  connection.owner = true

  -- Data needed for visuals
  local dist = entity.distanceToEntity(gate)
  dist = math.sqrt(dist[1] * dist[1] + dist[2] * dist[2])
  connection.beamScale = {(dist - 1) / 10, 1}
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

  updateAnimationState()
  return {force, active}
end

function setConnectionStrength(direction, newStr)
  local connection = storage.connections[direction]
  local dir, str = unitVector(connection.force)
  
  if str ~= newStr then
    if connection.gateId then
      if world.callScriptedEntity(connection.gateId,
                                  "setConnectionStrengthHelper",
                                  Direction.flip(direction),
                                  newStr) then
        connection.force = {
          newStr * dir[1],
          newStr * dir[2]
        }
        updateAnimationState()
      end
    else
      connection.force = {
        newStr * dir[1],
        newStr * dir[2]
      }
      updateAnimationState()
    end
  end
end

function setConnectionStrengthHelper(direction, newStr)
  local connection = storage.connections[direction]
  local dir, str = unitVector(connection.force)
  
  if str ~= newStr then
    -- Check priority
    -- TOP and RIGHT receive priority
    local controlled = storage.controlled
    if direction == Direction.TOP or direction == Direction.RIGHT then
      local controlledConnection = controlled[direction]
      if controlledConnection.forceStrength ~= nil then
        return false
      end
    end
    connection.force = {
      newStr * dir[1],
      newStr * dir[2]
    }
    updateAnimationState()
    return true
  else
    return true
  end
end

function setConnectionAngle(direction, newDir)
  local connection = storage.connections[direction]
  local dir, str = unitVector(connection.force)
  
  if not vectorEq(dir, newDir) then
    if connection.gateId then
      if world.callScriptedEntity(connection.gateId,
                                  "setConnectionAngleHelper",
                                  Direction.flip(direction),
                                  newDir) then
        connection.force = {
          str * newDir[1],
          str * newDir[2]
        }
        updateAnimationState()
      end
    else
      connection.force = {
        str * newDir[1],
        str * newDir[2]
      }
      updateAnimationState()
    end
  end
end

function setConnectionAngleHelper(direction, newDir)
  local connection = storage.connections[direction]
  local dir, str = unitVector(connection.force)
  
  if not vectorEq(dir, newDir) then
    -- Check priority
    -- TOP and RIGHT receive priority
    local controlled = storage.controlled
    if direction == Direction.TOP or direction == Direction.RIGHT then
      local controlledConnection = controlled[direction]
      if controlledConnection.forceDirection ~= nil then
        return false
      end
    end
    connection.force = {
      str * newDir[1],
      str * newDir[2]
    }
    updateAnimationState()
    return true
  else
    return true
  end
end

function setConnectionActive(direction, active)
  local connection = storage.connections[direction]
  if connection.active ~= active then
    if connection.gateId then
      if world.callScriptedEntity(connection.gateId,
                                  "setConnectionActiveHelper",
                                  Direction.flip(direction), active) then
        connection.active = active
        updateAnimationState()
      end
    else
      connection.active = active
      updateAnimationState()
    end
  end
end

function setConnectionActiveHelper(direction, active)
  local connection = storage.connections[direction]
  if connection.active ~= active then
    -- Check priority
    -- TOP and RIGHT receive priority
    local controlled = storage.controlled
    if direction == Direction.TOP or direction == Direction.RIGHT then
      local controlledConnection = controlled[direction]
      if controlledConnection.active ~= nil then
        return false
      end
    end
    connection.active = active
    updateAnimationState()
    return true
  else
    return true
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

function onNodeConnectionChange()
  checkNodes()
end

function onInboundNodeChange(args)
  checkNodes()
end

function checkNodes()
  if entity.isInboundNodeConnected(0) then
    local connections = storage.connections
    for direction,connection in pairs(connections) do
      setConnectionActive(direction, entity.getInboundNodeLevel(0))
    end
    updateAnimationState()    
  end
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

function vectorEq(a, b)
  return a[1] == b[1] and a[2] == b[2]
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

function receiveControllers(controllers)
  storage.controllers = controllers
  -- Play visual effect
  entity.burstParticleEmitter("controllersReceived")
end




