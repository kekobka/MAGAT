---@name Camera
---@shared
---@author kekobka
local Camera

local CAMERA_OFFSET = Vector(0, 0, 150)
local CAMERA_OFFSETSCOPE = Vector(0, 0, 150)
local CAMERA_DISTANCE = 300

ISDRIVER = false
CAMERA_ZOOMED = false

if SERVER then
	Camera = class("Camera", Wire)
	Wire.AddOutputs({
		EyeVector = Vector(0, 0, 0),
		EyePos = Vector(),
	})
	function Camera:onPortsInit()
		local base = Wire.GetBase()
		if not isValid(base) then
			return
		end
		self:setBody(base)
		self:setSeat(Wire.GetSeat())
	end
	function Camera:initialize(body, seat)
		self:listenInit()
		local function set_driver(ply, vehicle, role)
			if vehicle ~= self.seat then
				return
			end
			enableHud(ply, role ~= nil and true or false)
			self.user = role ~= nil and ply or nil
			if self.user ~= nil then
				hook.run("CameraActivated", self.user)
				net.start("Base")
				net.writeEntity(Wire.GetBase())
				net.send(self.user)
			else
				hook.run("CameraDeactivated", ply)
			end
		end

		hook.add("PlayerEnteredVehicle", "Camera", set_driver)
		hook.add("PlayerLeaveVehicle", "Camera", set_driver)
	end

	function Camera:onMoved(fn)
		net.receive("eye", function(len, pl)
			self.eye = net.readVector()
			fn(self.eye, self.body:localToWorld(self.offset))
			Wire.SetEyeVector(self.eye)
			self._eye = self.eye
		end)
	end
	function Camera:setBody(body)
		self.body = body
		self.offset = CAMERA_OFFSET
		self.eye = self.body:getRight()
		self._eye = self.eye
		self.pos = self.body:localToWorld(self.offset)
		self.user = nil

		net.receive("eye", function(len, pl)
			self.eye = net.readVector()
			self.offset = net.readVector()
			Wire.SetEyePos(self.body:localToWorld(self.offset))
			Wire.SetEyeVector(self.eye)
			self._eye = self.eye
		end)
		net.receive("initCAMERA", function(len, pl)
			net.start("initCAMERA")
			net.writeEntity(self.body)
			net.send(pl)
		end)
		timer.create("Camera", 0.015, 0, function()
			Wire.SetEyePos(self.body:localToWorld(self.offset))
		end)
	end
	function Camera:setSeat(seat)
		self.seat = seat
	end
else
	Camera = class("Camera")
	function Camera:initialize(body)
		print(Color(255, 255, 255), "Module: ", Color(255, 0, 255), "Camera", Color(0, 255, 0), " Initialized!")
		self.body = body
		self.offset = CAMERA_OFFSET
		self.matrix = Matrix()
		self.dist = CAMERA_DISTANCE
		self.forward = self.body:getForward()
		self.eye = self.forward
		self.zoom = 15
	end
	function Camera:start()
		ISDRIVER = true
		self.zoom = 15
		self.forward = self.body:getForward()
		self.yaw = math.deg(math.atan2(self.forward[2], self.forward[1]))
		self.pitch = math.deg(math.asin(self.forward[3] / math.sqrt(self.forward[2] ^ 2 + self.forward[1] ^ 2)))

		hook.add("mousemoved", "camera", function(x, y)
			local scale = timer.frametime()
			local zoom = (CAMERA_ZOOMED and self.zoom or 1)
			self.yaw = (self.yaw - x * scale * 2 / zoom) % 360
			self.pitch = math.clamp(self.pitch + y * scale / zoom, -89, 89)
			self.forward = Angle(self.pitch, self.yaw, 0):getForward()
			net.start("eye")
			net.writeVector(self.forward)
			net.writeVector(self.offset)
			net.send()
		end)
		local lastdist = CAMERA_DISTANCE
		hook.add("mouseWheeled", "camera", function(v)
			if CAMERA_ZOOMED then
				self.zoom = math.clamp(self.zoom + v, 2, 90)
				if self.zoom == 1 then
					CAMERA_ZOOMED = false
					self.offset = CAMERA_OFFSET
					self.dist = lastdist
					self.zoom = 1
				end
				return
			end
			self.dist = math.clamp(self.dist - v * 9, 200, 500)
		end)
		local zoomed = false
		hook.add("inputpressed", "camera", function(v)
			if v == KEY.SHIFT then
				zoomed = not zoomed
				if zoomed then
					self.offset = CAMERA_OFFSETSCOPE
					CAMERA_ZOOMED = true
					lastdist = self.dist
					self.dist = 0
				else
					self.offset = CAMERA_OFFSET
					CAMERA_ZOOMED = false
					lastdist, self.dist = self.dist, lastdist
				end
			elseif v == KEY.N and player() == owner() then
				concmd("flir_toggle")
			end
		end)
		hook.add("calcview", "camera", function(tbl)
			local up = self.body:getUp()
			up = (up - self.forward * self.forward:dot(up)):getNormalized()
			local right = (self.forward):cross(up)
			self.matrix:setForward(self.forward)
			self.pos = self.body:localToWorld(self.offset) - self.matrix:getForward() * self.dist
			return {
				origin = self.pos,
				angles = self.matrix:getAngles(),
				fov = 90 / (CAMERA_ZOOMED and self.zoom or 1),
			}
		end)
	end

	function Camera:stop()
		ISDRIVER = false
		CAMERA_ZOOMED = false
		self.dist = CAMERA_DISTANCE
		hook.remove("mousemoved", "camera")
		hook.remove("mouseWheeled", "camera")
		hook.remove("inputpressed", "camera")
		hook.remove("calcview", "camera")
	end
	net.start("initCAMERA")
	net.send()
	net.receive("initCAMERA", function()
		local mycamera = Camera:new(net.readEntity())
		hook.add("hudconnected", "camera", function()
			mycamera:start()
		end)
		hook.add("huddisconnected", "camera", function()
			mycamera:stop()
		end)
	end)
end

return Camera
