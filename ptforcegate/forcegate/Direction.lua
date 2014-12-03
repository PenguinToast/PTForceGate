--- Details
Direction = {
  LEFT = -2,
  RIGHT = 2,
  DOWN = -1,
  UP = 1,
  list = {-2, 2, -1, 1}
}

--- Returns true if the direction is UP or DOWN.
function Direction.isVertical(direction)
  return direction == Direction.UP or direction == Direction.DOWN
end

function Direction.sign(direction)
  if direction < 0 then
    return -1
  elseif direction > 0 then
    return 1
  else
    return 0
  end
end

function Direction.getVector(direction)
  local out = {0, 0}
  if Direction.isVertical(direction) then
    out[2] = Direction.sign(direction)
  else
    out[1] = Direction.sign(direction)
  end
  return out
end

--- Rotate counter-clockwise.
function Direction.rotate(direction)
  if direction == Direction.LEFT then
    return Direction.DOWN
  elseif direction == Direction.RIGHT then
    return Direction.UP
  elseif direction == Direction.DOWN then
    return Direction.LEFT
  else
    return Direction.RIGHT
  end
end

--- Angle in degrees
function Direction.angle(direction)
  if direction == Direction.LEFT then
    return 180
  elseif direction == Direction.RIGHT then
    return 0
  elseif direction == Direction.DOWN then
    return 270
  else
    return 90
  end
end
