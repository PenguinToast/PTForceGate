function init(virtual)
  if virtual == false and not storage.initialized then
    local storage = storage
    storage.states = {
      {stateName = "On"},
      {stateName = "Off"}
    }
    storage.state = 1
    storage.initialized = true
    local uuid = getUuid()
    storage.uuid = uuid
    entity.setInteractive(true)

    -- Register with world properties
    local ctrlList = world.getProperty("ptforcegateCtrlList")
    if not ctrlList then
      ctrlList = {}
    end
    table.insert(ctrlList, uuid)
    world.setProperty("ptforcegateCtrlList", ctrlList)
    
    for state,control in pairs(storage.states) do
      control.name = "Controller " .. uuid
      for _,direction in ipairs(Direction.list) do
        control[direction] = {}
      end
    end
    world.setProperty("ptforcegateCtrl" .. uuid, storage.states[storage.state])
    
    updateAnimation()
  end
end

function die()
  local storage = storage
  storage.initialized = false
  local ctrlList = world.getProperty("ptforcegateCtrlList")
  for i,uuid in ipairs(ctrlList) do
    if uuid == storage.uuid then
      table.remove(ctrlList, i)
      break
    end
  end
  world.setProperty("ptforcegateCtrlList", ctrlList)
  world.setProperty("ptforcegateCtrl" .. storage.uuid, nil)
end

function updateProperties()
  local storage = storage
  local world = world
  local control = storage.states[storage.state]
  if storage.name then
    control.name = storage.name
  end
  world.setProperty("ptforcegateCtrl" .. storage.uuid, control)
end

function receiveConsoleStates(consoleStates)
  storage.states = consoleStates
  updateProperties()
end

function onNodeConnectionChange()
  checkNodes()
  updateProperties()
  updateAnimation()
end

function onInboundNodeChange(args)
  checkNodes()
  updateProperties()
  updateAnimation()
end

function checkNodes()
  if entity.isInboundNodeConnected(0) then
    storage.state = entity.getInboundNodeLevel(0) and 1 or 2
  end
end

function updateAnimation()
  entity.setAnimationState("onoff", storage.state == 1 and "on" or "off")
end

function onInteraction(args)
  -- Show GUI if player is holding wiretool, else toggle state.
  if world.entityHandItem(args.sourceId, "primary") == "wiretool" then
    local consoleConfig = entity.configParameter("consoleConfig")
    world.logInfo("consoleConfig: %s", consoleConfig)
    consoleConfig.states = storage.states
    consoleConfig.numStates = storage.numStates
    return {"ScriptConsole", consoleConfig}
  else -- Flip the connections
    storage.state = storage.state == 1 and 2 or 1
    updateProperties()
    updateAnimation()
  end
end

function getUuid()
  local len = 6
  local ctrlCount = world.getProperty("ptforcegateCtrlCount")
  local out
  if not ctrlCount then
    out = ""
    for i=1,len,1 do
      out = out .. "0"
    end
  else
    local bytes = table.pack(ctrlCount:byte(1, #ctrlCount))
    for i=#bytes,1,-1 do
      local n = bytes[i] + 1
      if n == 58 then
        bytes[i] = 65
        break
      elseif n == 91 then
        bytes[i] = 97
        break
      elseif n == 123 then
        bytes[i] = 48
      else
        bytes[i] = n
        break
      end
    end
    out = string.char(unpack(bytes))
  end
  world.setProperty("ptforcegateCtrlCount", out)
  return out
end
