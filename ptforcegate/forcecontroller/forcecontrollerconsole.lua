function init()
  states = console.configParameter("states")
  local states = states
  local numStates = #states
  local guiConfig = console.configParameter("gui")
  local canvasRect = guiConfig.scriptCanvas.rect
  local width = canvasRect[3] - canvasRect[1]
  local height = canvasRect[4] - canvasRect[2]
  
  local padding = 5
  local stateHeight = 12
  local stateWidth = 70
  local rootPanel = Panel(padding, padding, width - padding * 2,
                          height - padding * 2)
  local rootLayout = VerticalLayout(padding, Align.TOP)
  rootPanel:setLayoutManager(rootLayout)
  GUI.add(rootPanel)

  -- Controller name
  local namePanel = Panel(0, 0, rootPanel.width, stateHeight)
  local nameLayout = HorizontalLayout(padding, Align.CENTER)
  namePanel:setLayoutManager(nameLayout)
  local nameLabel = Label(0, 0, "Name:", stateHeight)
  namePanel:add(nameLabel)
  local nameField = TextField(0, 0, 90, stateHeight)
  nameField.text = states[1].name
  namePanel:add(nameField)
  rootPanel:add(namePanel)

  -- State buttons
  local buttonPanel = Panel(0, 0, rootPanel.width, stateHeight)
  local buttonLayout = HorizontalLayout(padding, Align.CENTER)
  buttonPanel:setLayoutManager(buttonLayout)
  rootPanel:add(buttonPanel)
  
  local statePanelContainer = Panel(0, 0, rootPanel.width)
  rootPanel:add(statePanelContainer)
  statePanelContainer.height = statePanelContainer.y
  rootLayout:layout()
  for state,control in pairs(states) do
    local stateButton = TextRadioButton(0, 0, stateWidth, stateHeight,
                                        control.stateName)
    buttonPanel:add(stateButton)
    local statePanel = Panel(0, 0, statePanelContainer.width,
                             statePanelContainer.height)
    -- Add components for each state
    -- TODO
    
    
    statePanel:bind("visible", Binding(stateButton, "selected"))
    statePanelContainer:add(statePanel)
  end
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

function syncStates()
  world.callScriptedEntity(console.sourceEntity(),
                           "receiveConsoleStates",
                           states)
end
