function init()
  states = console.configParameter("states")
  
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
