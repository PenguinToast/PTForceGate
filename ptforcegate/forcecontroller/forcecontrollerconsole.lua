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
  local buttonPanel = Panel(height - padding - stateHeight,
                           (width - (stateWidth * numStates + padding
                                       * (numStates - 1))) / 2)
  GUI.add(statePanel)
  local stateX = 0
  for state,control in pairs(states) do
    local stateButton = TextRadioButton(stateX, 0, stateWidth, stateHeight,
                                        control.stateName)
    local statePanel = Panel(padding, padding)
    statePanel.width = width - padding * 2
    statePanel.height = height - padding * 3 - stateHeight
    -- Add components for each state
    -- TODO
    statePanel:bind("visible", Binding(stateButton, "selected"))
    GUI.add(statePanel)
    buttonPanel:add(stateButton)
    stateX = stateX + stateWidth + padding
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
