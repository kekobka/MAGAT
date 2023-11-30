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
    self.Engine:acfSetActive(true)
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
        end)
        timer.create("movement.fuelTank_update", 5, 0, function()
            local driver = self:GetDriver()
            if not isValid(driver) then
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
    hook.add("Think", table.address(self), function()
        local driver = self:GetDriver()
        if not isValid(driver) then
            self.Engine:acfSetThrottle(0)
            for k, v in next, self.engines do
                v:acfSetThrottle(0)
            end
            return
        end
        local leftinput, rightinput = self:HandleInput(driver)
        local input = {
            [true] = leftinput,
            [false] = rightinput
        }
        local anymove = (leftinput > 0 and true) or (rightinput > 0 and true)
        local min, max = self.Engine:acfPowerband()
        local midPower = (min + max) / 2
        if not anymove then
            self.Engine:acfSetThrottle(self.Engine:acfRPM() < midPower and 100 or 0)
        else
            self.Engine:acfSetThrottle(100)
        end
        for k, v in next, self.engines do
            v:acfSetThrottle(self.Engine:acfGetThrottle())
        end
        local clutch = (not anymove or self.Engine:acfRPM() < min) and 1 or 0
        local cases = self.links.cases
        local gbox = self.links.gearbox
        gbox:acfClutch(0)
        local gear = gbox:acfGear()
        local rpm = self.Engine:acfRPM()

        if clutch == 0 then
            if gear == 0 then
                gbox:acfShiftUp()
            end
            if rpm >= (max - 1) and gear < gbox:acfNumGears() - 1 then
                gbox:acfShiftUp()
            end
            -- if self.Engine:acfRPM() >= (midPower + max) / 2 then
            --     gbox:acfShift(math.min(gbox:acfNumGears() - 1, gbox:acfGear() + 1))
            -- end
        else
            gbox:acfShiftDown()
        end
        for gbox, left in next, cases do
            local i = input[left]
            if i == 0 then
                gbox:acfBrake(50)
                gbox:acfClutch(1)
            else
                gbox:acfBrake(0)
                gbox:acfClutch(0)
                gbox:acfShift(i)
            end
        end
    end)
end
function Movement:HandleInput(driver)
    local horizontal = (driver:keyDown(IN_KEY.MOVERIGHT) and 1 or 0) - (driver:keyDown(IN_KEY.MOVELEFT) and 1 or 0)
    local vertical = (driver:keyDown(IN_KEY.FORWARD) and 1 or 0) - (driver:keyDown(IN_KEY.BACK) and 1 or 0)

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
    if isValid(seat) then
        local d = seat:getDriver()
        return isValid(d) and d
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
            wheel:acfSetActive(true)
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
