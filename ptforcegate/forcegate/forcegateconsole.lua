function init()
  controllers = console.configParameter("controllers")
  local controllers = controllers
  local guiConfig = console.configParameter("gui")
  local canvasRect = guiConfig.scriptCanvas.rect
  local width = canvasRect[3] - canvasRect[1]
  local height = canvasRect[4] - canvasRect[2]

  local padding = 4
  local btnHeight = 12
  local btnWidth = 50
  
  local rootPanel = Panel(padding, padding, width - padding * 2,
                          height - padding * 2)
  local rootLayout = VerticalLayout(padding, Align.TOP, Align.LEFT)
  rootPanel:setLayoutManager(rootLayout)
  GUI.add(rootPanel)

  local topPanel = Panel(0, 0, rootPanel.width, 0)
  rootPanel:add(topPanel)

  local bottomPanel = Panel(0, 0, rootPanel.width, btnHeight)
  local bottomLayout = HorizontalLayout(padding, Align.CENTER)
  bottomPanel:setLayoutManager(bottomLayout)
  local okButton = TextButton(0, 0, btnWidth, btnHeight, "Ok")
  okButton.onClick = function()
    syncControllers()
    console.dismiss()
  end
  bottomPanel:add(okButton)
  local cancelButton = TextButton(0, 0, btnWidth, btnHeight, "Cancel")
  cancelButton.onClick = function()
    console.dismiss()
  end
  bottomPanel:add(cancelButton)
  rootPanel:add(bottomPanel)

  topPanel.height = bottomPanel.y
  rootLayout:layout()

  -- Controller lists
  local selectedController = nil
  local selectedAvailable = nil  
  local labelHeight = 8
  local listWidth = 80
  local listHeight = topPanel.height - labelHeight
  local availableList = List(0, 0,
                             listWidth,
                             listHeight,
                             btnHeight)
  topPanel:add(availableList)
  local availableLabel = Label(availableList.x,
                               topPanel.height - labelHeight, "Available",
                               labelHeight)
  topPanel:add(availableLabel)
  
  local controlWidth = 14
  
  local controllersList = List(listWidth + controlWidth + padding * 2, 0,
                               listWidth,
                               listHeight,
                               btnHeight)
  topPanel:add(controllersList)
  local controllersLabel = Label(controllersList.x,
                               topPanel.height - labelHeight, "Controllers",
                               labelHeight)
  topPanel:add(controllersLabel)

  -- Add/Remove Controller Buttons
  local controlPanel = Panel(listWidth + padding, 0, controlWidth, listHeight)
  local controlLayout = VerticalLayout(padding, Align.CENTER, Align.CENTER)
  controlPanel:setLayoutManager(controlLayout)
  topPanel:add(controlPanel)
  local addCtrlButton = TextButton(0, 0, controlWidth, controlWidth, ">")
  addCtrlButton.onClick = function()
    local controllerButton = availableList:removeItem(selectedAvailable)
    if controllerButton then
      local controllerId = controllerButton.controllerId
      controllerButton = controllersList:emplaceItem(controllerButton.text)
      controllerButton.controllerId = controllerId
      controllerButton:addListener(
        "selected",
        function(t, k, old, new)
          if new then
            selectedController = t
          end
        end
      )
      if controllerButton.selected then
        selectedController = controllerButton
      end
      table.insert(controllers, 1, controllerId)
    end
  end
  controlPanel:add(addCtrlButton)
  local removeCtrlButton = TextButton(0, 0, controlWidth, controlWidth, "<")
  removeCtrlButton.onClick = function()
    local controllerButton = controllersList:removeItem(selectedController)
    if controllerButton then
      local controllerId = controllerButton.controllerId
      controllerButton = availableList:emplaceItem(controllerButton.text)
      controllerButton.controllerId = controllerId
      controllerButton:addListener(
        "selected",
        function(t, k, old, new)
          if new then
            selectedAvailable = t
          end
        end
      )
      if controllerButton.selected then
        selectedAvailable = controllerButton
      end
      for i,controllerId2 in ipairs(controllers) do
        if controllerId2 == controllerId then
          table.remove(controllers, i)
          break
        end
      end
    end
  end
  controlPanel:add(removeCtrlButton)
  
  -- Populate lists
  for i=#controllers,1,-1 do
    local controllerId = controllers[i]
    local controller = world.getProperty(
      "ptforcegateCtrl" .. controllerId)
    if controller then
      local controllerButton = controllersList:emplaceItem(controller.name)
      controllerButton.controllerId = controllerId
      controllerButton:addListener(
        "selected",
        function(t, k, old, new)
          if new then
            selectedController = t
          end
        end
      )
      if controllerButton.selected then
        selectedController = controllerButton
      end
    else
      table.remove(controllers, i)
    end
  end
  local allControllers = world.getProperty("ptforcegateCtrlList")
  if allControllers == nil then
    allControllers = {}
    world.setProperty("ptforcegateCtrlList", allControllers)
  end
  for i=#allControllers,1,-1 do
    local controllerId = allControllers[i]
    local controller = world.getProperty(
      "ptforcegateCtrl" .. controllerId)
    if controller then
      if not contains(controllers, controllerId) then
        local controllerButton = availableList:emplaceItem(controller.name)
        controllerButton.controllerId = controllerId
        controllerButton:addListener(
          "selected",
          function(t, k, old, new)
            if new then
              selectedAvailable = t
            end
          end
        )
        if controllerButton.selected then
          selectedAvailable = controllerButton
        end
      end
    else
      table.remove(allControllers, i)
      world.setProperty("ptforcegateCtrlList", allControllers)
    end
  end
end

function syncControllers()
  world.callScriptedEntity(console.sourceEntity(),
                           "receiveControllers",
                           controllers)
end

function contains(t, v)
  for _,value in pairs(t) do
    if value == v then
      return true
    end
  end
  return false
end

function update(dt)
  GUI.step(dt)
end

function canvasClickEvent(position, button, pressed)
  GUI.clickEvent(position, button, pressed)
end

function canvasKeyEvent(key, isKeyDown)
  GUI.keyEvent(key, isKeyDown)
end

