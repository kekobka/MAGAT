---@name Hud
---@shared
---@author kekobka
local Hud = class("Hud")
if CLIENT then
    STYPES = {
        CANNON = 0,
        AUTOCANNON = 1,
        MACHINEGUN = 2
    }
    local STYPES_t = {
        [0] = "",
        [1] = "ac/",
        [2] = "mg/"
    }
    local OverlayPath = "https://raw.githubusercontent.com/kekobka/MAGAT/main/content/overlay.png"
    local ScopePath = "https://raw.githubusercontent.com/kekobka/MAGAT/main/content/table.png"

    local FullpoinerPath = "https://raw.githubusercontent.com/kekobka/MAGAT/main/content/fullpointer.png"
    local TablePath = "https://raw.githubusercontent.com/kekobka/MAGAT/main/content/fulltable.png"
    local GunPath = "https://raw.githubusercontent.com/kekobka/MAGAT/main/content/pointer.png"

    local activegun = 1
    local fontRoboto16 = render.createFont("Roboto", 16, 500, true, false, true, false, 0, false, 0)
    local fontRoboto48 = render.createFont("Roboto", 96, 500, true, false, true, false, 0, false, 0)
    local fontIcons = render.createFont("Segoe MDL2 Assets", 96, 500, true, false, false, false, false, true)
    local base = entity(0)
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
        ["APFSDS"] = true,
        ["APDS"] = true,
        ["APHECBC"] = true,
        ["APHE"] = true,
        ["APCBC"] = true,
        ["APC"] = true,
        ["APBC"] = true,
        ["AP"] = true,
        ["APCR"] = true,
        ["GLATGM"] = true,
        ["THEATFS"] = true,
        ["HEATFS"] = true,
        ["THEAT"] = true,
        ["HEAT"] = true,
        ["HEFS"] = true,
        ["HESH"] = true,
        ["HE"] = true,
        ["FL"] = true,
        ["SM"] = true
    }

    local _materials = {}
    local function getMaterial(url)
        if _materials[url] then
            return _materials[url]
        end
        _materials[url] = render.createMaterial(url, function(_, _, _, _, w)
            w(0, 0, 1024, 1024)
        end)
        return _materials[url]
    end

    local overlayMat = getMaterial(OverlayPath)
    local scopeMat = getMaterial(ScopePath)
    local gunMat = getMaterial(FullpoinerPath)
    local tableMat = getMaterial(TablePath)
    local gunScopePath = getMaterial(GunPath)

    local iobjects = {}
    objects = objects or {}
    local guns = {}
    local gunsCount = 0
    table.merge(objects, {
        ["Turret"] = function(name)
            local target, lerp, plerp = Vector(), math.lerpVector, Vector()
            net.receive("Turret" .. name, function()
                local t = net.readVector()
                if t then
                    target = t
                end
            end)
            return function(w, h, scale)
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
            end
        end,
        ["Gun"] = function(name)

            local gundata = {
                name = name,
                usingAmmo = "",
                nextUsingAmmo = "",
                reloadProgress = 1,
                ammotypes = {},
                ammmotypesCount = 0,
                fireRate = 0
            }
            net.receive("Gun_update" .. name, function()
                gundata.usingAmmo = net.readString()
            end)
            net.receive("Gun_update_firerate" .. name, function()
                gundata.fireRate = net.readFloat() / 58
            end)
            net.receive("Gun_ammo_types_update" .. name, function()
                local type = net.readString()
                local newcount = net.readFloat()
                for _, v in next, gundata.ammotypes do
                    if v.name == type then
                        v.count = newcount
                        return
                    end
                end
            end)
            net.receive("Gun_update_reloading" .. name, function()
                gundata.reloadProgress = net.readFloat()
                gundata.usingAmmo = net.readString()
                local unloadtime = net.readFloat()
                if unloadtime > 0 then
                    gundata.reloadProgress = gundata.reloadProgress - unloadtime * gundata.fireRate
                    print(gundata.reloadProgress)
                end
            end)
            net.receive("Gun_ammo_types" .. name, function()
                local usedAmmoTypes = net.readTable()
                gundata.usingAmmo = net.readString()
                gundata.nextUsingAmmo = net.readString()
                gundata.reloadProgress = net.readFloat()
                gundata.type = net.readUInt(2)
                local adder = STYPES_t[gundata.type]
                gundata.ammotypes = {}
                for t, count in next, usedAmmoTypes do

                    local type = ammotypesdata[t] and "https://raw.githubusercontent.com/kekobka/MAGAT/main/content/shelltypes/" .. adder .. t .. ".png" or ""
                    if type then
                        local a = isstring(type) and getMaterial(type) or type
                        ammotypesdata[t] = a
                        table.insert(gundata.ammotypes, {
                            name = t,
                            mat = a,
                            count = count
                        })
                    end
                end
                table.sort(gundata.ammotypes, function(a, b)
                    return ammoPriority[a.name] < ammoPriority[b.name]
                end)
                gundata.ammmotypesCount = table.count(gundata.ammotypes)
            end)
            local index = table.insert(guns, gundata)
            local ammmotypesCount = gundata.ammmotypesCount
            -- guns
            return function(w, h, scale, dt)
                gunsCount = #guns
                local isactive = activegun == index
                local cX, cY = w / 2, h - 128
                cX = cX + 81 * (gundata.ammmotypesCount * (index - 1) - (gunsCount - 1))

                render.setRGBA(255, 255, 255, 255)
                render.setFont(fontRoboto16)
                for i, data in next, gundata.ammotypes do
                    render.setMaterial(data.mat)
                    local x = (i - 1) - (gundata.ammmotypesCount - 1) / 2
                    if gundata.nextUsingAmmo == data.name then
                        render.setRGBA(255, 255, 0, 255)
                        render.drawRectFast(cX - 29 + x * 60, cY - 2, 58, 58)
                        render.setRGBA(255, 255, 255, 255)
                    end
                    if gundata.usingAmmo == data.name then
                        render.setRGBA(0, 255, 0, 255)
                        render.drawRectFast(cX - 29 + x * 60, cY - 2, 58, math.max(gundata.reloadProgress, 0) * 58)
                        render.setRGBA(255, 255, 255, 255)
                    end
                    render.drawTexturedRectFast(cX - 27 + x * 60, cY, 54, 54)
                    render.drawSimpleText(cX + x * 60, cY - 16, data.name, 1, 2)
                    render.drawSimpleText(cX + x * 60, cY + 54, data.count, 1)
                end
                if isactive then
                    local min = (#gundata.ammotypes - 1) - (gundata.ammmotypesCount - 1) / 2
                    render.setRGBA(0, 255, 0, 255)
                    render.drawRectFast(cX - min * 120, cY + 80, min * 120 * 2, 3)
                end
                gundata.reloadProgress = math.min(1, gundata.reloadProgress + gundata.fireRate * dt)
            end
        end
    })
    net.receive("InitializeObject", function()
        table.insert(iobjects, objects[net.readString()](unpack(net.readTable())))
    end)

    net.receive("Base", function()
        base = net.readEntity()
    end)
    local fuellvl = 1
    net.receive("movement.FuelLevel", function()
        fuellvl = net.readFloat()
    end)

    local target = Vector()
    net.receive("Turret", function()
        local t = net.readVector()
        if t then
            target = t
        end
    end)

    local hide = {
        ["CHudHealth"] = false,
        ["CHudBattery"] = false,
        ["CHudCrosshair"] = false,
        ["NetGraph"] = false
    }
    hook.add("hudshoulddraw", "Hud", function(s)
        return hide[s]
    end)
    local speed = 0
    local lastframe, timer_realtime = 0, timer.realtime
    hook.add("drawhud", "Hud", function()
        local w, h = render.getResolution()
        local scale = 1440 / h
        lastframe = timer_realtime() - lastframe
        for _, v in next, iobjects do
            v(w, h, scale, lastframe)
        end
        lastframe = timer_realtime()
        render.setRGBA(255, 255, 255, 150)
        if CAMERA_ZOOMED then
            render.setMaterial(scopeMat)
            local s = 1024 * scale
            render.drawTexturedRectFast(w / 2 - s / 2, h / 2 - s / 2, s, s)

            render.setRGBA(255, 255, 255, 255)
            render.setMaterial(overlayMat)
            local s = 6000 * scale
            render.drawTexturedRectFast(0, 0, w, h)
        else
            render.setMaterial(tableMat)
            local s = 512 * scale
            render.drawTexturedRectFast(w / 2 - s / 2, h / 2 - s / 2, s, s)
        end

        speed = speed * 0.95 + math.floor(base:getVelocity():getLength() * 1.905 / 100000 * 3600) * 0.05
        local cY = h - 128
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
        if not ISDRIVER then
            return
        end
        local type = key - 1
        if input.isKeyDown(KEY.CTRL) then
            local gun = guns[type]
            if gun then
                printHud("Gun changing ammo: ", gun.name)
                activegun = type
            end
            return
        end
        if not activegun then
            return
        end
        local gun = guns[activegun]
        local type = key - 1
        if gun.ammotypes[type] then
            gun.nextUsingAmmo = gun.ammotypes[type].name
            net.start("gun_ammo_change" .. gun.name)
            net.writeString(gun.nextUsingAmmo)
            net.send()
        end
    end)

end
return Hud
