function init()
  local button = TextButton(100, 100, 100, 14, "Close")
  button.onClick = function()
    console.dismiss()
  end
  GUI.add(button)
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

