CheckTextRadioButton = class(RadioButton)
CheckTextRadioButton.hoverColor = "#1F1F1F"
CheckTextRadioButton.pressedColor = "#454545"
CheckTextRadioButton.checkColor = "#343434"
--- The text of the button.
CheckTextRadioButton.text = nil
--- The padding between the text and the button edge.
CheckTextRadioButton.textPadding = 2

function CheckTextRadioButton:_init(x, y, width, height, text)
  RadioButton._init(self, x, y, 0)
  self.width = width
  self.height = height

  local padding = self.textPadding
  local contentPane = Panel(padding, 0, width - padding * 2, height)
  local contentLayout = HorizontalLayout(padding, Align.LEFT, Align.CENTER)
  contentPane:setLayoutManager(contentLayout)
  self:add(contentPane)

  local fontSize = height - padding * 2
  local checkBox = CheckBox(0, 0, fontSize)
  self.checkBox = checkBox
  contentPane:add(checkBox)
  
  local label = Label(0, 0, text, fontSize, fontColor)
  self.label = label
  contentPane:add(label)

  self.text = text
  self:addListener(
    "text",
    function(t, k, old, new)
      t.label.text = new
      contentLayout:layout()
    end
  )
end

function CheckTextRadioButton:drawCheck(dt)
  local startX = self.x + self.offset[1]
  local startY = self.y + self.offset[2]
  local w = self.width
  local h = self.height
  local checkRect = {startX + 1, startY + 1,
                     startX + w - 1, startY + h - 1}
  PtUtil.fillRect(checkRect, self.checkColor)
end

