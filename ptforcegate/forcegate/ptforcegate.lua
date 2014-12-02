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
        force = nil -- The force
      }
    end
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

--- Loads any global properties.
function loadGlobal()
  local storage = storage
  local globalProperties = world.getProperty("ptforcegate")
  if globalProperties then
    if globalProperties.maxRange ~= storage.maxRange then
      storage.maxRange = globalProperties.maxRange
    end
    if globalProperties.forceStrength ~= storage.forceStrength then
      -- Update each connection
      -- TODO
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
        -- TODO
      end
    end
  end
end

--- Apply the forces of the connections,
function applyForces()

end

--- Connects this gate to another.
-- @param direction The direction of the connection.
-- @param gate The entity ID of the gate to connect to.
function connect(direction, gate)
  local storage = storage
  local connection = storage.connections[direction]
  connection.gateId = gate
  local force = connection.force
  force = world.callScriptedEntity(gate,
                                   "connectResponse",
                                     -direction,
                                   entity.id(),
                                   force)
  local direction, strength = unitVector(force)
  connection.force = force
  conenction.forceDirection = direction
  connection.forceStrength = strength
end

function connectResponse(direction, gate, force)
  
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
