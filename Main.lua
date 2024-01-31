---@name MAGAT
--- Modular Integrated General Armored Technology
---@author kekobka
--- @includedir modules

DEBUG = true
if SERVER then
	---@include https://github.com/kekobka/MAGAT/raw/main/Wire.lua as Wire.lua
	Wire = require("Wire.lua")
	---@include https://github.com/kekobka/MAGAT/raw/main/Sync.lua as Sync.lua
	Sync = require("Sync.lua")
end

---@include https://github.com/kekobka/MAGAT/raw/main/modules/Camera.lua as Camera
---@include https://github.com/kekobka/MAGAT/raw/main/modules/Hud.lua as Hud
---@include https://github.com/kekobka/MAGAT/raw/main/modules/Movement.lua as Movement
---@include https://github.com/kekobka/MAGAT/raw/main/modules/Turret.lua as Turret

modules = {
	Camera = require("Camera"),
	Hud = require("Hud"),
	Movement = require("Movement"),
	Turret = require("Turret"),
}

if SERVER then
	local Base = modules.Movement()
	local Camera = modules.Camera()

	local turretConfig = {
		depression = 11,
		elevation = 90,
		minY = 180,
		maxY = 180,
	}

	local turretConfigSecond = {
		depression = 15,
		elevation = 25,
		minY = 0,
		maxY = 0,
	}

	local turret = modules.Turret(Base, Camera, nil, turretConfig)

	-- turret:AddGun(name? = "", fire key? = lastkey, enum STYPES? = STYPES.CANNON)
	turret:AddGun("Main", IN_KEY.ATTACK)
	turret:AddGun("Turret", IN_KEY.ATTACK2, STYPES.MACHINEGUN)

	Wire.AddInputs({
		Seat = "Entity",
		Base = "Entity",
	})
	Wire.AddOutputs({
		Driver = entity(0),
	})

	Wire.InitPorts()
end
-- STYPES.CANNON
-- STYPES.AUTOCANNON
-- STYPES.MACHINEGUN
