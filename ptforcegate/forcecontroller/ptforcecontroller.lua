function init(virtual)
  if not virtual and not storage.initialized then
    local storage = storage
    storage.active = false
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
    local control = {}
    for _,direction in ipairs(Direction.list) do
      control[direction] = {}
    end
    world.setProperty("ptforcegateCtrl" .. uuid, control)
    
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

function onNodeConnectionChange()
  checkNodes()
  updateAnimation()
end

function onInboundNodeChange(args)
  checkNodes()
  updateAnimation()
end

function checkNodes()
  if entity.isInboundNodeConnected(0) then
    storage.active = entity.getInboundNodeLevel(0)
  end
end

function updateAnimation()
  entity.setAnimationState("onoff", storage.active and "on" or "off")
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
