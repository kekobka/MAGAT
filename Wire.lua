---@author kekobka
---@server
local WireComponent = class("WireComponent")
WireComponent.static.Inputs = {}
WireComponent.static.Outputs = {}
local ports = wire.ports
local function accessorFunc(tbl, name, defaultValue, varName)
	local varName = varName or tbl.class.name
	local varName = varName .. "_" .. name

	tbl[varName] = defaultValue
	ports[varName] = defaultValue
	tbl["Get" .. name] = function(self)
		return self[varName]
	end
	tbl["Set" .. name] = function(self, value)
		self[varName] = value
		ports[varName] = value
		return value
	end
end
local function accessorFuncStatic(name, defaultValue)
	WireComponent[name] = defaultValue
	if ports[name] then
		ports[name] = defaultValue
	end
	WireComponent["Get" .. name] = function()
		return WireComponent[name]
	end
	WireComponent["Set" .. name] = function(value)
		WireComponent[name] = value
		ports[name] = value
		return value
	end
end
local function accessorFuncReadOnly(tbl, name, defaultValue, varName)
	local varName = varName or tbl.class.name

	tbl["Get" .. name] = function(self)
		return ports[varName .. "_" .. name]
	end
end
local function accessorFuncReadOnlyStatic(name)
	WireComponent["Get" .. name] = function(self)
		return ports[name]
	end
end
do
	local listeners = {}
	local initialized = false
	function WireComponent.static.InitPorts()
		if initialized then
			return
		end
		wire.adjustPorts(WireComponent.Inputs, WireComponent.Outputs)
		for k, v in next, listeners do
			v:onPortsInit()
		end
		listeners = {}
		initialized = true
	end
	function WireComponent:initPorts()
		wire.adjustPorts(WireComponent.Inputs, WireComponent.Outputs)
		for k, v in next, listeners do
			v:onPortsInit()
		end
	end
	hook.add("DupeFinished", table.address(WireComponent), function()
		WireComponent.InitPorts()
		print("DupeFinished")
	end)
	function WireComponent:listenInit()
		table.insert(listeners, self)
	end
end

do
	local listeners = {}
	hook.add("Input", "PortListener", function(name, value)
		if not isValid(value) then
			return
		end
		local lists = listeners[name]
		if lists then
			local lists = table.copy(lists)
			for k, v in next, lists do
				v(value)
			end
		end
	end)
	function WireComponent.addPortListener(name, func)
		listeners[name] = listeners[name] or {}
		table.insert(listeners[name], func)
	end
	function WireComponent.removePortListener(name, func)
		table.removeByValue(listeners[name], func)
	end
	function WireComponent.addSinglePortListener(name, func)
		listeners[name] = listeners[name] or {}
		local f
		f = function(value)
			func(value)
			table.removeByValue(listeners[name], f)
		end
		table.insert(listeners[name], f)
	end
end

function WireComponent:AddInputs(inputs, replace)
	local tbl = {}
	local name = replace or self.class.name
	for k, v in next, inputs do
		accessorFuncReadOnly(self, k, v, name)
		tbl[name .. "_" .. k] = v
	end
	table.merge(WireComponent.Inputs, tbl)
end

---@param outputs table
function WireComponent:AddOutputs(outputs, replace)
	local tbl = {}
	-- local name = self.class.name
	local name = replace or self.class.name
	for k, v in next, outputs do
		accessorFunc(self, k, v, name)
		tbl[name .. "_" .. k] = type(v)
	end
	table.merge(WireComponent.Outputs, tbl)
end

---@param inputs table
function WireComponent.static.AddInputs(inputs)
	local tbl = {}
	for k, v in next, inputs do
		accessorFuncReadOnlyStatic(k)
		tbl[k] = v
	end
	table.merge(WireComponent.Inputs, tbl)
end

---@param outputs table
function WireComponent.static.AddOutputs(outputs)
	local tbl = {}
	for k, v in next, outputs do
		accessorFuncStatic(k, v)
		tbl[k] = type(v)
	end
	table.merge(WireComponent.Outputs, tbl)
end
--- STUB
function WireComponent:onPortsInit() end

return WireComponent
