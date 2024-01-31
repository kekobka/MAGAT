local Sync = {}

function Sync:included(target)
	local oldnew = target.new

	function target.new(...)
		local obj = oldnew(...)
		local q = table.address(obj)
		hook.add("ClientInitialized", q, function(ply)
			obj:onNetReady(ply)
		end)
		return obj
	end
end
function Sync:onNetReady(ply) end

return Sync
