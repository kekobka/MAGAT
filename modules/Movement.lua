---@name Movement
---@server
---@author kekobka
---@include ../Wire.lua
local Wire = require("../Wire.lua")

local Movement = class("Movement", Wire)
function Movement:onPortsInit()
    self.Engine = Wire.GetEngine()
    if not isValid(self.Engine) then
        return
    end
    self.Base = Wire.GetBase()
    self.Seat = Wire.GetSeat()
    self:FindCases(self:FindLinks(self.Engine))
    table.insert(self.engines, self.Engine)
    self:Activate()
end
function Movement:initialize()
    self:listenInit()
    print(Color(255, 255, 255), "Module: ", Color(255, 0, 255), "Movement", Color(0, 255, 0), " Initialized!")
    Wire.AddInputs({
        ["Base"] = "Entity",
        ["Engine"] = "Entity",
        ["Seat"] = "Entity"
    })
    self.links = {}
    self.engines = {}
    self.fueltanks = {}
    self.keys = {}
    self.input = {}
end
function Movement:Activate()
    if DEBUG then
        print("DEBUG Movement")
        print("Engines:")
        printTable(self.engines)
        print("Fuel tanks:")
        printTable(self.fueltanks)
    end

    if #self.fueltanks > 0 then
        hook.add("CameraActivated", table.address(self), function(ply)
            local lvl = 0
            for _, tank in next, self.fueltanks do
                lvl = lvl + tank:acfFuelLevel()
            end
            lvl = lvl / #self.fueltanks
            net.start("movement.FuelLevel")
            net.writeFloat(lvl)
            net.send(ply)
            for k, v in next, self.engines do
                v:acfSetActive(true)
            end
            self.active = true
            timer.start(table.address("self"))
        end)
        hook.add("CameraDeactivated", table.address(self), function(ply)
            for k, v in next, self.engines do
                v:acfSetThrottle(0)
            end
            self.active = false
            self.anymove = false
            self.keys = {}
            self.input = {}
            self:KeyPress(ply, 0)
            timer.pause(table.address("self"))
        end)
        timer.create("movement.fuelTank_update", 5, 0, function()
            local driver = self:GetDriver()
            if not driver:isValid() then
                return
            end
            local lvl = 0
            for _, tank in next, self.fueltanks do
                lvl = lvl + tank:acfFuelLevel()
            end
            lvl = lvl / #self.fueltanks
            net.start("movement.FuelLevel")
            net.writeFloat(lvl)
            net.send(driver)
        end)
    end
    self.minPower, self.maxPower = self.Engine:acfPowerband()
    self.midPower = (self.minPower + self.maxPower) / 2
    self.numgears = self.links.gearbox:acfNumGears()
    hook.add("KeyPress", table.address(self), function(ply, key)
        if not self.active then
            return
        end
        if ply ~= Wire.GetSeat():getDriver() then
            return
        end
        self:KeyPress(ply, key, true)
    end)
    hook.add("KeyRelease", table.address(self), function(ply, key)
        if not self.active then
            return
        end
        if ply ~= Wire.GetSeat():getDriver() then
            return
        end
        self:KeyPress(ply, key)
    end)
    timer.create(table.address(self), 250 / 1000, 0, function()
        if self.active then
            self:Think()
        end
    end)
    timer.pause(table.address("self"))
end
function Movement:KeyPress(driver, key, pressed)
    local leftinput, rightinput = self:HandleInput(driver, key, pressed)
    self.input = {
        [true] = leftinput,
        [false] = rightinput
    }
    self.anymove = (leftinput > 0 and true) or (rightinput > 0 and true)
    if self.anymove then
        for k, v in next, self.engines do
            v:acfSetThrottle(100)
        end
    end

    for case, left in next, self.links.cases do
        local i = self.input[left] or 0
        if i == 0 then
            case:acfBrake(50)
            case:acfClutch(1)
        else
            case:acfBrake(0)
            case:acfClutch(0)
            case:acfShift(i)
        end
    end
end

function Movement:Think()
    local input = self.input
    local anymove = self.anymove
    local rpm = self.Engine:acfRPM()

    local clutch = (not anymove or rpm < self.minPower) and 1 or 0
    local gbox = self.links.gearbox

    local gear = gbox:acfGear()

    if not anymove then
        local th = math.remap(self.Engine:acfRPM(), 0, self.midPower, 100, 30)
        for k, v in next, self.engines do
            v:acfSetThrottle(self.active and th or 0)
        end
    end
    if clutch == 0 then
        if gear == 0 then
            gbox:acfShiftUp()
        elseif rpm >= (self.maxPower - 10) and gear < self.numgears - 1 then
            gbox:acfShiftUp()
        end
    else
        gbox:acfShiftDown()
    end
end
function Movement:HandleInput(driver, key, pressed)
    self.keys[key] = pressed
    local horizontal = (self.keys[IN_KEY.MOVERIGHT] and 1 or 0) - (self.keys[IN_KEY.MOVELEFT] and 1 or 0)
    local vertical = (self.keys[IN_KEY.FORWARD] and 1 or 0) - (self.keys[IN_KEY.BACK] and 1 or 0)

    -- no movement
    if vertical == 0 and horizontal == 0 then
        return 0, 0
    end

    -- no steering
    if horizontal == 0 then
        if vertical < 0 then
            local vertical = math.abs(vertical)
            return vertical * 2, vertical
        end
        return vertical, vertical * 2
    end

    -- neutral steering
    if vertical == 0 then
        if horizontal == 1 then
            return 1, 1
        elseif horizontal == -1 then
            return 2, 2
        end
    end

    -- invert reverse steering
    if vertical < 0 then
        local vertical = math.abs(vertical)
        return horizontal > 0 and vertical * 2 or 0, horizontal < 0 and vertical or 0
    end
    return horizontal > 0 and vertical or 0, horizontal < 0 and vertical * 2 or 0

end
function Movement:GetDriver()
    local seat = Wire.GetSeat()
    if seat:isValid() then
        return seat:getDriver()
    end
end
function Movement:FindLinks(ent, linkedto, tbl)
    if tbl and tbl[ent] then
        return true
    end
    if not tbl then
        return {
            [ent] = self:FindLinks(ent, nil, {})
        }
    end
    local links = {}
    for k, wheel in next, ent:acfLinks() do
        if not isValid(wheel) then
            goto ce
        end
        if wheel:acfIsFuel() then
            table.insert(self.fueltanks, wheel)
            goto ce
        end
        if wheel == linkedto then
            goto ce
        end
        if wheel:acfIsEngine() then
            table.insert(self.engines, wheel)
            goto ce
        end
        links[wheel] = self:FindLinks(wheel, ent, tbl)
        ::ce::
    end
    return table.count(links) > 0 and links or false
end

function Movement:FindCases(tbl, case)
    self.links.cases = self.links.cases or {}
    for k, v in next, tbl do
        if not v then
            return true
        else
            local linked = self:FindCases(v, k)
            if linked then
                self.links.gearbox = case
                self.links.cases[k] = self:IsLeft(k)
            end
        end
    end
end
function Movement:IsLeft(ent)
    local dot = Wire.GetBase():worldToLocal(ent:getPos()):dot(Vector(0, -1, 0))
    dot = math.round(dot)

    return dot <= 0
end
function Movement:GetBase()
    return Wire.GetBase()
end

return Movement
