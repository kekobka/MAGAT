---@name Hud
---@client
---@author kekobka
local OverlayPath = "https://i.imgur.com/yS9nSt2.png" -- "egpextras/textures/tank/overlays/border_circular.png" -- "https://i.imgur.com/8mZQOKL.png"
local ScopePath = "https://i.imgur.com/eRVcanH.png" -- "egpextras/textures/tank/sights/1g46/range_table.png"

local GunPath = "https://i.imgur.com/YM7hhoR.png" -- "egpextras/textures/tank/sights/togs/reticle_high.png"
local TablePath = "https://i.imgur.com/pHArIuR.png" -- "egpextras/textures/tank/sights/togs/reticle_low.png"
local GunScopePath = "https://i.imgur.com/9nmya14.png" -- "egpextras/textures/tank/sights/1g42/reticle.png"

local Hud = class("Hud")
if CLIENT then
    local base = entity(0)
    local ammotypes = {}
    local usingAmmo = ""
    local nextUsingAmmo = ""
    local ammmotypesCount = 0
    local reloadProgress = 1
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
    local ammotypesdata = {
        ["APFSDS"] = "https://i.imgur.com/CHm4uLw.png",
        ["APDS"] = "https://i.imgur.com/ieWcP7i.png",
        ["APHECBC"] = "https://i.imgur.com/xBB6ugU.png",
        ["APHE"] = "https://i.imgur.com/frWfH8a.png",
        ["APCBC"] = "https://i.imgur.com/ugYBTRP.png",
        ["APC"] = "https://i.imgur.com/4qjXNsQ.png",
        ["APBC"] = "https://i.imgur.com/cNE3tB2.png",
        ["AP"] = "https://i.imgur.com/ZQ5AfgC.png",
        ["APCR"] = "https://i.imgur.com/tIAgMFu.png",
        ["GLATGM"] = "https://i.imgur.com/zJJvQ4H.png",
        ["THEATFS"] = "https://i.imgur.com/jZGs8Wa.png",
        ["HEATFS"] = "https://i.imgur.com/gvKLiE4.png",
        ["THEAT"] = "https://i.imgur.com/jZGs8Wa.png",
        ["HEAT"] = "https://i.imgur.com/M2RAqcx.png",
        ["HEFS"] = "https://i.imgur.com/OKZLDuw.png",
        ["HESH"] = "https://i.imgur.com/RTDacUT.png",
        ["HE"] = "https://i.imgur.com/AYJw6b9.png",
        ["FL"] = "https://i.imgur.com/E0NdKgw.png",
        ["SM"] = "https://i.imgur.com/NwLC7Fh.png"
    }

    local function getMaterial(url)
        return render.createMaterial(url, function(_, _, _, _, w)
            w(0, 0, 1024, 1024)
        end)
    end

    net.receive("Base", function()
        base = net.readEntity()
    end)
    local fuellvl = 1
    net.receive("movement.FuelLevel", function()
        fuellvl = net.readFloat()
    end)
    net.receive("Gun_ammo_types", function()
        local usedAmmoTypes = net.readTable()
        usingAmmo = net.readString()
        nextUsingAmmo = net.readString()
        reloadProgress = net.readFloat()
        ammotypes = {}
        for t, count in next, usedAmmoTypes do
            local type = ammotypesdata[t]
            if type then
                local a = isstring(type) and getMaterial(type) or type
                ammotypesdata[t] = a
                table.insert(ammotypes, {
                    name = t,
                    mat = a,
                    count = count
                })
            end
        end
        table.sort(ammotypes, function(a, b)
            return ammoPriority[a.name] < ammoPriority[b.name]
        end)
        ammmotypesCount = table.count(ammotypes)
    end)

    net.receive("Gun_ammo_types_update", function()
        local type = net.readString()
        local newcount = net.readFloat()
        for _, v in next, ammotypes do
            if v.name == type then
                v.count = newcount
                return
            end
        end
    end)

    net.receive("Gun_update", function()
        usingAmmo = net.readString()
    end)
    net.receive("Gun_update_reloading", function()
        reloadProgress = net.readFloat()
        usingAmmo = net.readString()
    end)

    local overlayMat = getMaterial(OverlayPath)
    local scopeMat = getMaterial(ScopePath)
    local gunMat = getMaterial(GunPath)
    local tableMat = getMaterial(TablePath)
    local gunScopePath = getMaterial(GunScopePath)
    local target = Vector()
    net.receive("Turret", function()
        local t = net.readVector()
        if t then
            target = t
        end
    end)
    local fontRoboto16 = render.createFont("Roboto", 16, 500, true, false, true, false, 0, false, 0)
    local fontRoboto48 = render.createFont("Roboto", 96, 500, true, false, true, false, 0, false, 0)
    local fontIcons = render.createFont("Segoe MDL2 Assets", 96, 500, true, false, false, false, false, true)
    local hide = {
        ["CHudHealth"] = false,
        ["CHudBattery"] = false,
        ["CHudCrosshair"] = false,
        ["NetGraph"] = false
    }
    hook.add("hudshoulddraw", "Hud", function(s)
        return hide[s]
    end)
    local speed, lerp, plerp, lasttarget = 0, math.lerpVector, Vector()
    hook.add("drawhud", "Hud", function()
        local w, h = render.getResolution()
        local scale = 1440 / h
        plerp = lerp(0.1, plerp, target)
        local d = plerp:toScreen()
        render.setRGBA(255, 255, 255, 150)
        if CAMERA_ZOOMED then
            render.setMaterial(scopeMat)
            local s = 1024 * scale
            render.drawTexturedRectFast(w / 2 - s / 2, h / 2 - s / 2, s, s)

            -- pointer
            if d.visible then
                render.setMaterial(gunScopePath)
                render.setRGBA(255, 255, 255, 200)
                local s = 1024 * scale
                render.drawTexturedRectFast(d.x - s / 2, d.y - s / 2, s, s)
            end
            render.setRGBA(255, 255, 255, 255)
            render.setMaterial(overlayMat)
            local s = 6000 * scale
            render.drawTexturedRectFast(0, 0, w, h)
        else
            render.setMaterial(tableMat)
            local s = 512 * scale
            render.drawTexturedRectFast(w / 2 - s / 2, h / 2 - s / 2, s, s)

            -- pointer
            if d.visible then
                render.setMaterial(gunMat)
                render.setRGBA(255, 255, 255, 200)
                render.drawTexturedRectFast(d.x - s / 2, d.y - s / 2, s, s)
            end
        end

        local cX, cY = w / 2, h - 128
        render.setRGBA(255, 255, 255, 255)
        render.setFont(fontRoboto16)
        for i, data in next, ammotypes do
            render.setMaterial(data.mat)
            local x = (i - 1) - (ammmotypesCount - 1) / 2
            if nextUsingAmmo == data.name then
                render.setRGBA(255, 255, 0, 255)
                render.drawRectFast(cX - 29 + x * 60, cY - 2, 58, 58)
                render.setRGBA(255, 255, 255, 255)
            end
            if usingAmmo == data.name then
                render.setRGBA(0, 255, 0, 255)
                render.drawRectFast(cX - 29 + x * 60, cY - 2, 58, reloadProgress * 58)
                render.setRGBA(255, 255, 255, 255)
            end
            render.drawTexturedRectFast(cX - 27 + x * 60, cY, 54, 54)
            render.drawSimpleText(cX + x * 60, cY, data.name, 1, 2)
            render.drawSimpleText(cX + x * 60, cY + 54, data.count, 1)
        end

        speed = speed * 0.95 + math.floor(base:getVelocity():getLength() * 1.905 / 100000 * 3600) * 0.05

        render.setFont(fontRoboto48)
        local spd = tostring(math.min(math.floor(speed), 999))
        local str = string.rep("0", 3 - #tostring(spd)) .. spd
        render.setRGBA(51, 51, 51, 255)

        for k = 1, 3 do
            local num = string.sub(str, k, k)
            if num ~= "0" then
                render.setRGBA(255, 255, 255, 250)
            end
            render.drawSimpleText(w - 300 + k * 46, cY, num)
        end

        render.setRGBA(255, 255, 255, 255)
        render.setFont(fontIcons)
        local lvl = math.round(fuellvl * 10)
        if lvl == 10 then
            render.drawSimpleText(w - 250, cY - 60, string.utf8char(0xE83F))
        else
            local gb = 255 - ((5 - lvl) * 255)
            render.setRGBA(255, gb, gb, 255)
            render.drawSimpleText(w - 250, cY - 60, string.utf8char(0xE850 + lvl))
        end
    end)

    hook.add("inputReleased", "HUD.Input", function(key)
        local type = key - 1
        if ammotypes[type] then
            nextUsingAmmo = ammotypes[type].name
            net.start("gun_ammo_change")
            net.writeString(nextUsingAmmo)
            net.send()
        end
    end)
end
return Hud
