--- Details
Direction = {
  LEFT = 4,
  RIGHT = 2,
  DOWN = 3,
  UP = 1,
  list = {1, 2, 3, 4}
}

--- Gets the opposite direction.
function Direction.flip(direction)
  if direction == Direction.LEFT then
    return Direction.RIGHT
  elseif direction == Direction.RIGHT then
    return Direction.LEFT
  elseif direction == Direction.DOWN then
    return Direction.UP
  else
    return Direction.DOWN
  end
end

--- Returns true if the direction is UP or DOWN.
function Direction.isVertical(direction)
  return direction == Direction.UP or direction == Direction.DOWN
end

--- Returns 1 for up and right, and -1 for down and left.
function Direction.sign(direction)
  if direction == Direction.LEFT or direction == Direction.DOWN then
    return -1
  else
    return 1
  end
end

--- Get a unit vector in the specified direction.
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

--- Angle in radians
function Direction.angle(direction)
  if direction == Direction.LEFT then
    return math.pi
  elseif direction == Direction.RIGHT then
    return 0
  elseif direction == Direction.DOWN then
    return 3 * math.pi / 2
  else
    return math.pi / 2
  end
end
