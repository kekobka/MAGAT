---@name Rigat
---@shared
---@author kekobka
local zero, trace_line, math_clamp = Vector(), trace.line, math.clamp

local EntityCriticalPD = class("EntityCriticalPD")

function EntityCriticalPD:initialize(phys, translationGain, rotationGain)
	if phys.getPhysicsObject then
		self.phys = phys:getPhysicsObject()
	else
		self.phys = phys
	end
	self.masscenter = self.phys:getMassCenter()
	self:refreshMassInertia()
	self:setGain(translationGain, rotationGain)
	self.targetAng = self.phys:getMatrix()
	self.targetPos = self.targetAng * self.phys:getMassCenter()
	self.targetVel = Vector()
	self.targetAngVel = Vector()
	self.posError = Vector()
	self.angError = Vector()
	return self
end

function EntityCriticalPD:setTarget(pos, ang)
	self.targetPos = pos
	self.targetAng = Matrix()
	self.targetAng:setAngles(ang)
end

function EntityCriticalPD:setTargetMatrix(m)
	self.targetPos = m:getTranslation()
	self.targetAng = m
end

function EntityCriticalPD:setTargetPos(pos)
	self.targetPos = pos
end

function EntityCriticalPD:setTargetAng(ang)
	self.targetAng = Matrix()
	self.targetAng:setAngles(ang)
end

function EntityCriticalPD:setTargetVel(vel, angvel)
	self.targetVel = vel
	self.targetAngVel = angvel
end

function EntityCriticalPD:setGain(translationGain, rotationGain)
	self.fk = translationGain * timer.frametime()
	self.fc = math.sqrt(self.fk * timer.frametime()) * 2 -- critical translation damping coefficient
	self.tk = rotationGain * timer.frametime()
	self.tc = math.sqrt(self.tk * timer.frametime()) * 2 -- critical rotation damping coefficient
end

function EntityCriticalPD:refreshMassInertia()
	self.mass = self.phys:getMass()
	self.inertia = self.phys:getInertia()
end

function EntityCriticalPD:massCenter()
	return self.phys:localToWorld(self.masscenter)
end

function EntityCriticalPD:massCenterMatrix()
	local m = self.phys:getMatrix()
	m:setTranslation(m * self.masscenter)
	return m
end

function EntityCriticalPD:getInertiaFromAxis(axis)
	axis = self.phys:worldToLocalVector(axis)
	return self.inertia[1] * axis[1] ^ 2 + self.inertia[2] * axis[2] ^ 2 + self.inertia[3] * axis[3] ^ 2
end

function EntityCriticalPD:simulateForce()
	-- Calculate force
	local x = self.targetPos - self:massCenter()
	local dx = self.targetVel - self.phys:getVelocity()
	local force = x * self.fk + dx * self.fc
	self.posError = force
	self.phys:applyForceCenter(force * self.mass)
end

function EntityCriticalPD:simulateForceCustomError(x, dx)
	-- Calculate force
	local force = x * self.fk + dx * self.fc
	self.phys:applyForceCenter(force * self.mass)
end

function EntityCriticalPD:simulateAngForce()
	-- Calculate torque
	local m = self.phys:getMatrix()
	local axis, ang = (self.targetAng * m:getInverseTR()):getAxisAngle()
	local t = axis * math.deg(ang)
	local dt = self.targetAngVel - self.phys:localToWorldVector(self.phys:getAngleVelocity())

	local torque = t * self.tk + dt * self.tc
	self.angError = torque

	-- Make sure torque isn't null vector or singularity will happen with torque:getNormalized()
	if torque[1] ~= 0 or torque[2] ~= 0 or torque[3] ~= 0 then
		local applytorque = torque * self:getInertiaFromAxis(torque:getNormalized())
		self.phys:applyTorque(applytorque)
	end
end

function EntityCriticalPD:simulateAngForceCustomError(t, dt)
	-- Calculate torque
	local torque = t * self.tk + dt * self.tc

	-- Make sure torque isn't null vector or singularity will happen with torque:getNormalized()
	if torque[1] ~= 0 or torque[2] ~= 0 or torque[3] ~= 0 then
		local applytorque = torque * self:getInertiaFromAxis(torque:getNormalized())
		self.phys:applyTorque(applytorque)
	end
end

function EntityCriticalPD:calcAngForceCustomError(t, dt)
	-- Calculate torque
	local torque = t * self.tk + dt * self.tc

	-- Make sure torque isn't null vector or singularity will happen with torque:getNormalized()
	if torque[1] ~= 0 or torque[2] ~= 0 or torque[3] ~= 0 then
		return torque * self:getInertiaFromAxis(torque:getNormalized())
	end
	return Vector()
end

function EntityCriticalPD:simulate()
	if self.fk ~= 0 then
		self:simulateForce()
	end

	if self.tk ~= 0 then
		self:simulateAngForce()
	end
end

local Gun = class("Gun", Wire)
Gun:include(Sync)

function Gun:onNetReady(ply)
	if not self.selectedAmmo then
		return
	end
end

function Gun:onPortsInit()
	self.ent = Wire["Get" .. self.name]()
	local ent = self.ent
	if not isValid(ent) then
		return
	end
	self:Activate()
	if DEBUG then
	end
end

function Gun:Fire()
	local turret = self.turret
	local ent = self.ent
	local pos = ent:getPos()
	ent:setParent()
	constraint.breakAll(ent)
	ent:setFrozen(false)
	ent:setPos(pos)
	local pos = ent:getPos()
	local hitpos = (Wire.GetHitPos() - pos):getAngle()
	if turret.holding then
		local holding_ent = turret.holding_ent
		if isValid(holding_ent) then
			hitpos = (holding_ent:localToWorld(turret.holding_pos) - pos):getAngle()
		else
			hitpos = (turret.holding_pos - pos):getAngle()
		end
	end
	ent:setAngles(hitpos)

	self.cpd = EntityCriticalPD(ent, 100, 200)
	local body = turret.camera.body
	turret.flying = true
	turret.camera:updateBody(ent)
	Wire.GetSeat():getDriver():setViewEntity(ent)
	local bomb
	for k, v in ipairs(ent:getChildren()) do
		if v.acfIsGun and v:acfIsGun() then
			bomb = v
			break
		end
	end
	ent:addCollisionListener(function()
		if isValid(bomb) then
			bomb:acfFire(1)
		end
		ent:remove()
	end)
	hook.add("Think", table.address(self), function()
		if not isValid(ent) then
			turret.flying = false
			turret.camera:updateBody(body)
			hook.remove("Think", table.address(self))
			table.remove(turret.guns, 1)
			turret.firstgun = turret.guns[1]
			if turret.firstgunt then
				turret.firstgun.isMain = true
			end
			return
		end
		local pos = ent:getPos()
		local hitpos = (Wire.GetHitPos() - pos):getAngle()
		if turret.holding then
			local holding_ent = turret.holding_ent
			if isValid(holding_ent) then
				hitpos = (holding_ent:localToWorld(turret.holding_pos) - pos):getAngle()
			else
				hitpos = (turret.holding_pos - pos):getAngle()
			end
		end

		self.cpd:setTarget(ent:getPos() + ent:getForward() * 700, hitpos)
		self.cpd:simulate()
	end)
end

function Gun:initialize(id, name, firekey, camera, turret)
	self:listenInit()
	self.camera = camera
	self.name = "Rigat_" .. name
	self._name = name
	self.id = id + 1
	self.firekey = firekey
	self.turret = turret
	Wire.AddInputs({[self.name] = "Entity"})
	self.ent = entity(0)
	self.ammotypes = {}
	self.ammotypesEnt = {}
	self.cpd = nil
end
function Gun:IsReloading()
	local this = self.ent
	if not this:acfReady() then
		if this:acfMagSize() == 1 then
			return true
		else
			return this:acfMagRounds() >= 1
		end
	end
end
function Gun:Activate()
end

function Gun:getPos()
	return self.ent:getMassCenterW()
end
function Gun:isValid()
	return isValid(self.ent)
end

local Turret = class("Rigat", Wire)
Turret:include(Sync)

function Turret:onNetReady(ply)
	net.start("InitializeObject")
	net.writeString("Turret")
	net.writeTable({self.id or ""})
	net.send(ply)
end
function Turret:onPortsInit()
	local Vaxis = Wire["GetVAxis" .. self.id]()
	local Haxis = Wire["GetHAxis" .. self.id]()
	if not isValid(Vaxis) or not isValid(Haxis) then
		return
	end
	self.parent = self._base.GetBase and self._base:GetBase() or self._base
	local ang = Angle(0, -90, 0)

	self.HAxisHolo = hologram.create(Haxis:getPos(), ang, "models/sprops/cuboids/height06/size_1/cube_6x6x6.mdl", Vector(0.2, 0.2, 5))
	self.VAxisHolo = hologram.create(Vaxis:getPos(), ang, "models/sprops/cuboids/height06/size_1/cube_6x6x6.mdl", Vector(0.2, 5, 0.2))

	self.VAxisHolo:setParent(self.HAxisHolo)
	self.HAxisHolo:setParent(self.parent)
	Vaxis:setParent(self.VAxisHolo)
	Haxis:setParent(self.HAxisHolo)

	for _, gun in next, self.guns do
		local ent = Wire["Get" .. gun.name]()
		if not isValid(ent) then
			return
		end
		ent:setParent()
		constraint.weld(ent, Vaxis)
		ent:setParent(Vaxis)
		ent:setNocollideAll(true)
	end
	self:Activate()
end
function Turret:initialize(base, camera, id, config)
	self:listenInit()
	self.camera = camera
	id = id or ""
	self.id = id
	print(Color(255, 255, 255), "Module: ", Color(255, 0, 255), "Rigat" .. self.id, Color(0, 255, 0), " Initialized!")
	self.config = config or {depression = 15, elevation = 50, minY = 180, maxY = 180}
	self.firstgun = nil
	self.holding = false
	self._base = base
	self.guns = {}
	self.lasthitpos = zero
	self.lastgunpos = zero
	self.queue = 1
	Wire.AddInputs({["VAxis" .. id] = "Entity", ["HAxis" .. id] = "Entity", ["Base"] = "Entity"})
	Wire.AddOutputs({["HitPos" .. id] = self.lasthitpos, ["GunPos" .. id] = self.lastgunpos})
end
function Turret:Activate()
	timer.create(table.address(self), 120 / 1000, 0, function()
		self:Think()
	end)
	hook.add("KeyPress", "Turret" .. self.id, function(ply, key)

		if not Wire.GetSeat():isValid() then
			return
		end
		if ply ~= Wire.GetSeat():getDriver() then
			return
		end
		if not self.flying then
			if self.firstgun then
				if key == self.firstgun.firekey then
					self.firstgun:Fire()
				end
			end
		end
		if key == IN_KEY.WALK then
			self:Hold()
		end
	end)

end
function Turret:AddGun(name, key, type)
	local GunName = name .. self.id
	self.lastkey = key or self.lastkey

	local gun = Gun(table.count(self.guns), GunName, self.lastkey, self.camera, self)
	if not self.firstgun then
		self.firstgun = gun
		gun.isMain = true
	end
	table.insert(self.guns, gun)

	return gun
end
local min, abs, acos, deg, math_nlerpQuaternion = math.min, math.abs, math.acos, math.deg, math.nlerpQuaternion
local function Quat_Angle(a, b)
	local dot = a:dot(b)
	return dot > 1 and 0 or deg(acos(min(abs(dot), 1)) * 2)
end
local function RotateTowards(from, to)
	local angle = Quat_Angle(from, to)
	if angle == 0 then
		return to
	end
	return math_nlerpQuaternion(from, to, min(1, 10 / angle))
end

local function rotate(holo, ang)
	holo:setAngles(RotateTowards(holo:getQuaternion(), ang:getQuaternion()):getEulerAngle())
end
local test = hologram.create(Vector(), Angle(), "models/sprops/cuboids/height06/size_1/cube_6x6x6.mdl")
function Turret:Think()

	if #self.guns == 0 then
		return
	end
	local EyeVector = Wire.GetEyeVector()
	if EyeVector == zero then
		return
	end
	local EyePos = Wire.GetEyePos()
	local hitpos
	local holding_ent = self.holding_ent
	if self.holding then
		if isValid(holding_ent) then
			hitpos = holding_ent:localToWorld(self.holding_pos)
		else
			hitpos = self.holding_pos
		end
	else
		hitpos = trace_line(EyePos, EyePos + EyeVector * 65565, nil, nil).HitPos
	end
	local gun = self.firstgun
	if not gun:isValid() then
		return
	end
	local gunpos = gun:getPos()
	if self.lasthitpos == hitpos and self.lastgunpos == gunpos then
		return
	end
	self.lasthitpos = hitpos
	self.lastgunpos = gunpos
	Wire["Set" .. "HitPos" .. self.id](self.lasthitpos)
	Wire["Set" .. "GunPos" .. self.id](self.lastgunpos)
	local target = (hitpos - gunpos):getAngle()
	local HAxisHolo = self.HAxisHolo
	local VAxisHolo = self.VAxisHolo
	
	local driver = Wire.GetSeat():getDriver()
	if driver:isValid() then
		net.start("Turret" .. self.id)
		net.writeVector(hitpos)
		net.send(driver, true)
	end
	if self.flying then
		return
	end
	local config = self.config
	local base = self.parent
	local HAxisLocalTarget = base:worldToLocalAngles(target).y

	local VAxisLocalTarget = HAxisHolo:worldToLocalAngles(target).p

	rotate(HAxisHolo, base:localToWorldAngles(Angle(0, math_clamp(HAxisLocalTarget, -config.minY, config.maxY), 0)))
	rotate(VAxisHolo, HAxisHolo:localToWorldAngles(Angle(math_clamp(VAxisLocalTarget, -config.elevation, config.depression), 0, 0)))

end

function Turret:GetBase()
	return self.HAxisHolo
end
function Turret:UnHold(missing)
	self.holding = false
	self.holding_ent = nil
	self.holding_pos = nil
	hook.remove("EntityRemoved", table.address(self))
	if missing then
		print(Color(51, 51, 51), "[TANK] ", Color(255, 255, 255), "TARGET MISSING")
	else
		print(Color(255, 0, 0), "[TANK] ", Color(255, 255, 255), "UNLOCK TARGET")
	end
end
function Turret:Hold()
	if not self.firstgun then
		return
	end
	local EyeVector = Wire.GetEyeVector()
	local EyePos = Wire.GetEyePos()
	local tr = trace.line(EyePos, EyePos + EyeVector * 65665, self.firstgun.ent)
	local ent = tr.Entity
	self.holding = not self.holding
	if not self.holding then
		return self:UnHold()
	end
	if not isValid(ent) then
		self.holding_pos = tr.HitPos
		self.holding_ent = nil
		print(Color(255, 255, 0), "[TANK] ", Color(255, 255, 255), "LOCK POSITION")
	else
		while isValid(ent:getParent()) do
			ent = ent:getParent()
		end
		hook.add("EntityRemoved", table.address(self), function(ent_r)
			if ent_r == ent then
				self:UnHold(true)
			end
		end)
		self.holding_ent = ent
		self.holding_pos = ent:worldToLocal(tr.HitPos)
		local owner = ent:getOwner() or ent
		print(Color(0, 255, 0), "[TANK] ", Color(255, 255, 255), "LOCK TARGET: " .. tostring(owner))
	end
end

return Turret
