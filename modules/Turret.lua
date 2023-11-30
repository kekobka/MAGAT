---@name Turret
---@server
---@author kekobka
---@include ../Wire.lua
local zero, trace_line, math_clamp = Vector(), trace.line, math.clamp
local Wire = require("../Wire.lua")
local Gun = class("Gun", Wire)
local ammoPriority = {
    ["APFSDS"] = 1,
    ["APDS"] = 2,
    ["APHECBC"] = 3,
    ["APHE"] = 4,
    ["APCBC"] = 5,
    ["APC"] = 6,
    ["APBC"] = 7,
    ["AP"] = 8,
    ["APCR"] = 9,
    ["GLATGM"] = 10,
    ["THEATFS"] = 11,
    ["HEATFS"] = 12,
    ["THEAT"] = 13,
    ["HEAT"] = 14,
    ["HEFS"] = 15,
    ["HESH"] = 16,
    ["HE"] = 17,
    ["FL"] = 18,
    ["SM"] = 19
}
function Gun:onPortsInit()
    self.ent = Wire["Get" .. self.name]()
    local ent = self.ent
    -- ent:getWirelink()["Fuse Time"] = 0
    -- ent:setParent(Wire.GetVAxis())
    self.selectedAmmo = ent:acfAmmoType()
    ent:setNocollideAll(true)
    hook.add("KeyPress", self.name, function(ply, key)
        if ply ~= Wire.GetSeat():getDriver() then
            return
        end
        self:KeyPress(ply, key, true)
    end)
    hook.add("KeyRelease", self.name, function(ply, key)
        if ply ~= Wire.GetSeat():getDriver() then
            return
        end
        if key == self.firekey then
            ent:acfFire(0)
        end
    end)
    self:GetAmmoTypes()
    if self.isMain then
        net.receive("gun_ammo_change", function(_, ply)
            if ply ~= Wire.GetSeat():getDriver() then
                return
            end
            local newAmmo = net.readString()
            self:SelectAmmo(newAmmo)
        end)
    end
    self:Activate()
    self.crew = self.ent:acfGetCrew()
    if DEBUG then
        print("DEBUG " .. self.name)
        print("Ammo boxes:")
        printTable(self.ammotypesEnt)
        print("Crew:")
        printTable(self.crew)
    end
end
function Gun:KeyPress(ply, key, pressed)
    if pressed then
        local ent = self.ent
        if key == self.firekey then
            net.start("Gun_ammo_types_update")
            local type = ent:acfAmmoType()
            net.writeString(type)
            local count = self:GetAmmo(type)
            ent:acfFire(1)
            if count then
                net.writeFloat(count)
                self.ammotypes[type] = count
            end
            net.send(ply)
        elseif key == IN_KEY.RELOAD then
            ent:acfReload()
        end
    end
end
function Gun:initialize(name, firekey, camera)
    self:listenInit()
    self.camera = camera
    self.name = "Gun_" .. name
    self.firekey = firekey
    Wire.AddInputs({
        [self.name] = "Entity"
    })
    self.ent = entity(0)
    self.ammotypes = {}
    self.ammotypesEnt = {}

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
    local ent = self.ent
    if self.isMain then
        timer.create(table.address(self), 0.1, 0, function()
            local ply = Wire.GetSeat():getDriver()
            if not isValid(ply) then
                return
            end

            if self:IsReloading() then
                self.reloading = true
                net.start("Gun_update_reloading")
                net.writeFloat(ent:acfReloadProgress())
                net.writeString(ent:acfAmmoType())
                net.send(ply)
            elseif self.reloading then
                self.reloading = false
                net.start("Gun_update")
                net.writeString(ent:acfAmmoType())
                net.send(ply)
                self:onReloaded()
            end
        end)
    end
    local tbl = table.getKeys(self.ammotypesEnt)
    table.sort(tbl, function(a, b)
        return ammoPriority[a] < ammoPriority[b]
    end)
    self:SelectAmmo(tbl[1])
end
--- STUB
function Gun:onReloaded()
end

function Gun:SelectAmmo(ammoName)
    if self.selectedAmmo == ammoName then
        if ammoName == self.ent:acfAmmoType() then
            return
        end
        self.ent:acfUnload()
        self.ent:acfReload()
    end
    self.selectedAmmo = ammoName
    if not self.ammotypesEnt[ammoName] then
        return
    end
    for type, crates in next, self.ammotypesEnt do
        for k, crate in next, crates do
            crate:acfSetActive(type == self.selectedAmmo)
        end
    end
end
function Gun:GetAmmoTypes()

    for k, crate in next, self.ent:acfLinks() do
        if crate:acfIsAmmo() then
            local type = crate:acfAmmoType()
            local count = self.ammotypes[type] or 0
            self.ammotypesEnt[type] = self.ammotypesEnt[type] or {}

            self.ammotypes[type] = count + crate:acfRounds()
            table.insert(self.ammotypesEnt[type], crate)
        end
    end

    if self.isMain then
        hook.add("CameraActivated", table.address(self), function(ply)
            if not self.selectedAmmo then
                return
            end
            net.start("Gun_ammo_types")
            net.writeTable(self.ammotypes)
            net.writeString(self.ent:acfAmmoType())
            net.writeString(self.selectedAmmo)
            net.writeFloat(self.ent:acfReloadProgress())
            net.send(ply)
        end)
    end
end
function Gun:GetAmmo(type)
    local ammo = 0
    local ents = self.ammotypesEnt[type]
    if not ents then
        return
    end
    for k, crate in next, ents do
        ammo = ammo + crate:acfRounds()
    end
    return ammo
end
-- function Gun:GetPredict(target)
--     local Distance = target:getDistance(self:getPos()) * game.getTickInterval()

--     local MuzzleVelocity = self.ent:acfMuzzleVel() * 0.74
--     local Ang = math.asin(((Distance * ((physenv.getGravity() * game.getTickInterval()).z)) / MuzzleVelocity ^ 2) / 2)
--     local Pos = 1.7 * math.tan(Ang) * Distance

--     return target - Vector(0, 0, Pos / game.getTickInterval()) - self:getPos()
-- end

local Feet_to_Meters = 3.280839895
function Gun:GetPredict(target, enttarget)
    if not self.ent:isValid() then
        return
    end
    local vel = self.ent:acfMuzzleVel()
    local start = self:getPos()

    if vel == 0 then
        return target, zero
    end
    local dist = start:getDistance(target)
    local T = dist * 1.27 / 39.3701 / vel
    local drifttarg = isValid(enttarget) and (enttarget:getVelocity() * T) or Vector()
    local Drift = (Wire.GetBase():getVelocity() * T) - drifttarg

    local Drop = (0.45 * 9.8 * T ^ 2) * 39.3701
    local traverse = Vector(0, 0, Drop) - Drift
    -- local fps = vel * Feet_to_Meters
    -- self.ent:getWirelink()["Fuse Time"] = (dist + Drop) / 39.3701 * Feet_to_Meters / fps
    return target + traverse, traverse
end
function Gun:getPos()
    return self.ent:getMassCenterW()
end

local Turret = class("Turret", Wire)

function Turret:onPortsInit()
    local Vaxis = Wire["GetVAxis" .. self.id]()
    local Haxis = Wire["GetHAxis" .. self.id]()
    if isValid(Vaxis) and isValid(Haxis) then
        local ang = Angle(0, -90, 0)

        self.HAxisHolo = hologram.create(Haxis:getPos(), ang, "models/sprops/cuboids/height06/size_1/cube_6x6x6.mdl", Vector(.2, .2, 5))
        self.VAxisHolo = hologram.create(Vaxis:getPos(), ang, "models/sprops/cuboids/height06/size_1/cube_6x6x6.mdl", Vector(.2, 5, .2))

        self.VAxisHolo:setParent(self.HAxisHolo)
        self.HAxisHolo:setParent(self.parent)
        Vaxis:setParent(self.VAxisHolo)
        Haxis:setParent(self.HAxisHolo)
    end
    for gun, getter in next, self.guns do
        local ent = Wire[getter]()
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
    print(Color(255, 255, 255), "Module: ", Color(255, 0, 255), "Turret" .. self.id, Color(0, 255, 0), " Initialized!")
    self.config = config or {
        depression = 15,
        elevation = 50,
        minY = 180,
        maxY = 180
    }
    self.firstgun = nil
    self.holding = false
    self.parent = base.GetBase and base:GetBase() or base
    self.guns = {}
    self.lasthitpos = zero
    self.lastgunpos = zero
    Wire.AddInputs({
        ["VAxis" .. id] = "Entity",
        ["HAxis" .. id] = "Entity",
        ["Base"] = "Entity"
    })
end
function Turret:Activate()
    timer.create(table.address(self), 120 / 1000, 0, function()
        -- hook.add("Think", table.address(self), function()
        self:Think()
    end)
    hook.add("KeyPress", "Turret" .. self.id, function(ply, key)
        if not Wire.GetSeat():isValid() then
            return
        end
        if ply ~= Wire.GetSeat():getDriver() then
            return
        end
        if key == IN_KEY.WALK then
            self:Hold()
        end
    end)
end
function Turret:AddGun(name, key)
    local GunName = name .. self.id
    local gun = Gun(name .. self.id, key, self.camera)
    if not self.firstgun then
        self.firstgun = gun
        gun.isMain = true
    end
    self.guns[gun] = "GetGun_" .. name .. self.id
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
        hitpos = trace_line(EyePos, EyePos + EyeVector * 65565, nil, nil, COLLISION_GROUP.PROJECTILE).HitPos
    end
    local gun = self.firstgun
    local gunpos = gun:getPos()
    if self.lasthitpos == hitpos and self.lastgunpos == gunpos then
        return
    end
    local Target, Reverse = gun:GetPredict(hitpos, holding_ent)
    self.lasthitpos = hitpos
    self.lastgunpos = gunpos
    local target = (Target - gunpos):getAngle()
    local HAxisHolo = self.HAxisHolo
    local VAxisHolo = self.VAxisHolo

    local config = self.config
    local base = self.parent
    local HAxisLocalTarget = base:worldToLocalAngles(target).y

    local VAxisLocalTarget = HAxisHolo:worldToLocalAngles(target).p

    rotate(HAxisHolo, base:localToWorldAngles(Angle(0, math_clamp(HAxisLocalTarget, -config.minY, config.maxY), 0)))
    rotate(VAxisHolo, HAxisHolo:localToWorldAngles(Angle(math_clamp(VAxisLocalTarget, -config.elevation, config.depression), 0, 0))) -- VAxisHolo:getAngles():rotateAroundAxis(HAxisHolo:getRight(), -VAxisLocalTarget))

    local driver = Wire.GetSeat():getDriver()
    if driver:isValid() then
        local dist = hitpos:getDistance(gunpos)
        local hitpos_gun = trace_line(gunpos, gunpos + gun.ent:getForward() * dist - Reverse, nil, nil, COLLISION_GROUP.PROJECTILE).HitPos
        local target, reverse = gun:GetPredict(hitpos_gun)
        net.start("Turret" .. self.id)
        net.writeVector(target - reverse)
        net.send(driver, true)
    end
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
