---@name MAGAT
--- Modular Integrated General Armored Technology
---@author kekobka
---@includedir modules

DEBUG = false

local modules = {}
for k, v in next, requiredir("modules") do
    modules[v.name] = v
end

if SERVER then
    ---@include Wire.lua
    local Wire = require("Wire.lua")

    local Base = modules.Movement()
    local Camera = modules.Camera()

    local turretConfig = {
        depression = 15,
        elevation = 50,
        minY = 180,
        maxY = 180
    }

    local turret = modules.Turret(Base, Camera, nil, turretConfig)
    turret:AddGun("Main", IN_KEY.ATTACK)
    -- turret:AddGun("Turret", IN_KEY.ATTACK2)
    
    -- local turret = modules.Turret(turret, 2, turretConfig)
    -- turret:AddGun("MachineGun", IN_KEY.ATTACK2)
    Wire.AddInputs({
        Seat = "Entity",
        Base = "Entity"
    })
    Wire.AddOutputs({
        Driver = entity(0)
    })

    Wire.InitPorts()
    -- local oldprinthud = print
    -- function print(...)
    --     local a = Wire.GetSeat()
    --     if isValid(a) and isValid(a:getDriver()) then
    --         printHud(a:getDriver(), ...)
    --     else
    --         oldprinthud(...)
    --     end
    -- end
end
