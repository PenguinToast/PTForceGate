function init()
  states = Binding.proxy(console.configParameter("states"))
  local states = states
  local numStates = #states
  local guiConfig = console.configParameter("gui")
  local canvasRect = guiConfig.scriptCanvas.rect
  local width = canvasRect[3] - canvasRect[1]
  local height = canvasRect[4] - canvasRect[2]
  
  padding = 4
  stateHeight = 12
  local stateWidth = 70
  local rootPanel = Panel(padding, padding, width - padding * 2,
                          height - padding * 2)
  local rootLayout = VerticalLayout(padding, Align.TOP)
  rootPanel:setLayoutManager(rootLayout)
  GUI.add(rootPanel)

  -- Controller name
  local namePanel = Panel(0, 0, rootPanel.width, stateHeight + 2)
  local nameLayout = HorizontalLayout(padding, Align.CENTER, Align.CENTER)
  namePanel:setLayoutManager(nameLayout)
  local nameLabel = Label(0, 0, "Name:", stateHeight)
  namePanel:add(nameLabel)
  local nameField = TextField(0, 0, 90, stateHeight + 2)
  nameField.text = states[1].name
  nameField:addListener(
    "text",
    function(t, k, old, new)
      for state,control in pairs(states) do
        control.name = new
      end
    end
  )
  namePanel:add(nameField)
  rootPanel:add(namePanel)

  -- State buttons
  local buttonPanel = Panel(0, 0, rootPanel.width, stateHeight)
  local buttonLayout = HorizontalLayout(padding, Align.CENTER)
  buttonPanel:setLayoutManager(buttonLayout)
  local buttonLabel = Label(0, 0, "Controller States:", stateHeight)
  buttonPanel:add(buttonLabel)
  rootPanel:add(buttonPanel)
  
  local statePanelContainer = Panel(0, 0, rootPanel.width)
  rootPanel:add(statePanelContainer)

  local confirmationPanel = Panel(0, 0, rootPanel.width, stateHeight)
  local confirmationLayout = HorizontalLayout(padding, Align.CENTER)
  confirmationPanel:setLayoutManager(confirmationLayout)
  local okButton = TextButton(0, 0, stateWidth, stateHeight, "Ok")
  okButton.onClick = function()
    syncStates()
    console.dismiss()
  end
  confirmationPanel:add(okButton)
  local cancelButton = TextButton(0, 0, stateWidth, stateHeight, "Cancel")
  cancelButton.onClick = function()
    console.dismiss()
  end
  confirmationPanel:add(cancelButton)
  rootPanel:add(confirmationPanel)
  
  statePanelContainer.height = rootPanel.children[#rootPanel.children].y
  rootLayout:layout()
  local options = {
    {forceDirectionOption, "Left Gate Force", {Direction.LEFT}},
    {forceDirectionOption, "Right Gate Force", {Direction.RIGHT}},
    {forceDirectionOption, "Top Gate Force", {Direction.UP}},
    {forceDirectionOption, "Bottom Gate Force", {Direction.DOWN}},
    {forceActiveOption, "Left Gate Active", {Direction.LEFT}},
    {forceActiveOption, "Right Gate Active", {Direction.RIGHT}},
    {forceActiveOption, "Top Gate Active", {Direction.UP}},
    {forceActiveOption, "Bottom Gate Active", {Direction.DOWN}}
  }
  for state,control in pairs(states) do
    local stateButton = TextRadioButton(0, 0, stateWidth, stateHeight,
                                        control.stateName)
    buttonPanel:add(stateButton)
    local statePanel = Panel(0, 0, statePanelContainer.width,
                             statePanelContainer.height)
    -- Add components for each state
    -- List of configurable options
    local optionsList = List(0, 0, 110, statePanel.height, stateHeight,
                             CheckTextRadioButton)
    local stateBorder = Rectangle(optionsList.width, 0,
                                  statePanel.width - optionsList.width,
                                  statePanel.height,
                                  "#121212", 1)
    statePanel:add(stateBorder)
    for _,option in ipairs(options) do
      local optionCheckBox = optionsList:emplaceItem(option[2])
      optionCheckBox.checkBox:addListener(
        "selected",
        function(t, k, old, new)
          if new then
            optionCheckBox:select()
          end
        end
      )
      local optionPanel = Panel(optionsList.width + padding, padding,
                                statePanel.width - optionsList.width - padding,
                                statePanel.height - padding * 2)
      optionPanel:bind("visible", Binding(optionCheckBox, "selected"))
      option[1](optionCheckBox.checkBox, optionPanel, state, unpack(option[3]))
      statePanel:add(optionPanel)
    end
    statePanel:add(optionsList)
    
    statePanel:bind("visible", Binding(stateButton, "selected"))
    statePanelContainer:add(statePanel)
  end
end

function directionToString(direction)
  if direction == Direction.LEFT then
    return "Left"
  elseif direction == Direction.RIGHT then
    return "Right"
  elseif direction == Direction.DOWN then
    return "Bottom"
  else -- direction == Direction.UP
    return "Top"
  end
end

function forceDirectionOption(checkBox, panel, state, direction)
  direction = tostring(direction)
  local layout = HorizontalLayout(padding, Align.LEFT, Align.TOP)
  panel:setLayoutManager(layout)
  local directionField = TextField(0, 0, 40, stateHeight, "Degrees")
  panel:add(directionField)
  local label = Label(0, 0,
                      directionToString(tonumber(direction))
                        .. " Gate Direction",
                      stateHeight)
  panel:add(label)
  if states[state][direction].forceDirection ~= nil then
    checkBox.selected = true
    local forceDir = states[state][direction].forceDirection
    directionField.text = string.format("%.1f",
      math.deg(math.atan2(forceDir[2], forceDir[1])))
  end
  checkBox:addListener(
    "selected",
    function(t, k, old, new)
      if new then -- selected
        local ang = math.rad(tonumber(directionField.text) or 0)
        local forceDir = {math.cos(ang), math.sin(ang)}
        states[state][direction].forceDirection = forceDir
      else -- deselected
        states[state][direction].forceDirection = nil
      end
    end
  )
  directionField.filter = "^%-?%d*%.?%d*$"
  directionField:addListener(
    "text",
    function(t, k, old, new)
      if checkBox.selected then
        local ang = math.rad(tonumber(new) or 0)
        local forceDir = {math.cos(ang), math.sin(ang)}
        states[state][direction].forceDirection = forceDir
      end
    end
  )
end

function forceActiveOption(checkBox, panel, state, direction)
  direction = tostring(direction)
  local layout = HorizontalLayout(padding, Align.LEFT, Align.TOP)
  panel:setLayoutManager(layout)
  local activeCheck = CheckBox(0, 0, stateHeight)
  panel:add(activeCheck)
  local label = Label(0, 0,
                      directionToString(tonumber(direction)) .. " Gate Active",
                      stateHeight)
  panel:add(label)
  if states[state][direction].active ~= nil then
    checkBox.selected = true
    activeCheck.selected = states[state][direction].active
  end
  checkBox:addListener(
    "selected",
    function(t, k, old, new)
      if new then -- selected
        states[state][direction].active = activeCheck.selected
      else -- deselected
        states[state][direction].active = nil
      end
    end
  )
  activeCheck:addListener(
    "selected",
    function(t, k, old, new)
      if checkBox.selected then
        states[state][direction].active = t.selected
      end
    end
  )
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
                           states._instance)
end
