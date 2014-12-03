function init(args)
  self.dead = false

  -- Data doesn't attack people
  entity.setDamageOnTouch(false)
  entity.setAggressive(false)
  
  self.forceRegion = {0,0,0,0}
  self.force = {0,0}
  self.timeout = 0.5
  self.timer = self.timeout
end

function update(dt)
  local self = self
  self.timer = self.timer - dt
  if self.timer <= 0 then
    -- Kill self
    kill()
  else
    entity.setForceRegion(self.forceRegion, self.force)
  end
  --world.logInfo("Monster %s applied force %s to region %s", entity.id(), self.forceToApply, self.regionToApply)
end

--- Sets the force region for this monster to apply, and refreshes the timeout
-- timer.
function setForceToApply(region, force)
  local self = self
  self.forceRegion = region
  self.force = force
  self.timer = self.timeout
end

function isForceMonster()
  return true
end

function damage(args)
  -- This monster should not die outside of scripts.
end

--- Kills this monster
function kill()
  self.dead = true
end

function shouldDie()
  return self.dead
end
