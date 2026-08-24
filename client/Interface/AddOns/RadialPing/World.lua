local _, addon = ...

local activePings = {}
local lastSendTime = 0

local FRAME_WIDTH  = addon.atlas.Ping_UnitMarker_BG_OnMyWay.width
local PIN_HEIGHT   = addon.atlas.Ping_GroundMarker_Pin_OnMyWay.height
local BG_HEIGHT    = addon.atlas.Ping_UnitMarker_BG_OnMyWay.height
local STEM_VISIBLE = PIN_HEIGHT - addon.PIN_TOP_CROP
local STEM_BELOW   = STEM_VISIBLE - (BG_HEIGHT - addon.PIN_ATTACH_FROM_BG_TOP)
local FRAME_HEIGHT = BG_HEIGHT + STEM_BELOW

local STROKE_ROTATION_SPEED = -math.pi * 0.6  -- radians/sec, anti-clockwise
local RISE_DURATION         = 0.33             -- seconds for bubble to travel from ground to top
local STROKE_SCALE          = 1.50             -- >1 makes the ring larger than the raw BLP size
local SCREEN_EDGE_MARGIN    = 8
local CLAMPED_SIZE          = addon.atlas.Ping_OVMarker_Pointer_OnMyWay.width

-- ── Minimap blip ────────────────────────────────────────────────────────────
-- Approximate visible radius (yards) at each Minimap zoom level (outdoor zones).
-- Source: established WotLK addon community values.
local MINIMAP_ZOOM_RADIUS = { [0]=933, [1]=600, [2]=433, [3]=333, [4]=233, [5]=166 }
local MINIMAP_BLIP_W = 16
local MINIMAP_BLIP_H = 20

local function createMinimapBlip()
    local blip = CreateFrame("Frame", nil, Minimap)
    blip:SetSize(MINIMAP_BLIP_W, MINIMAP_BLIP_H)
    blip:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    blip.tex = blip:CreateTexture(nil, "OVERLAY")
    blip.tex:SetAllPoints(blip)
    blip:Hide()
    return blip
end

local function updateMinimapBlip(frame)
    local blip = frame.mmBlip
    if not blip then return end

    local remaining = frame.expiresAt - GetTime()
    if remaining <= 0 then blip:Hide(); return end

    if not UnitPosition then blip:Hide(); return end
    local mapY, mapX = UnitPosition("player")
    if not mapX or not mapY then blip:Hide(); return end

    local zoom       = Minimap:GetZoom() or 0
    local yardRadius = MINIMAP_ZOOM_RADIUS[zoom] or 333
    local mmRadius   = Minimap:GetWidth() / 2   -- pixels
    local ypp        = yardRadius / mmRadius     -- yards per pixel

    local dx = (frame.posX - mapX) / ypp
    local dy = (frame.posY - mapY) / ypp

    -- Clamp to the minimap circle edge
    local dist   = math.sqrt(dx * dx + dy * dy)
    local clampR = mmRadius - MINIMAP_BLIP_H / 2
    if dist > clampR then
        local scale = clampR / dist
        dx = dx * scale
        dy = dy * scale
    end

    local alpha = (remaining < addon.PING_FADE_OUT_SECONDS)
        and (remaining / addon.PING_FADE_OUT_SECONDS) or 1

    blip:ClearAllPoints()
    blip:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
    blip:SetAlpha(alpha)
    blip:Show()
end

local function easeOut(t)
    return 1 - (1 - t) * (1 - t)
end

local function applyStrokeRotation(texture, radians)
    texture:SetRotation(radians)
end

-- Texture:SetRotation() rebuilds coordinates against the complete texture.
-- That is correct for the standalone stroke BLPs, but clamped pointers are
-- regions inside UIPingSystem2x: rotating them that way exposes the full atlas.
-- Rotate the four corners inside the selected atlas rectangle instead.
local function applyAtlasRotation(texture, region, radians)
    local centerX = (region.left + region.right) * 0.5
    local centerY = (region.top + region.bottom) * 0.5
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    local function rotate(x, y)
        local dx = x - centerX
        local dy = y - centerY
        return centerX + dx * cosine - dy * sine,
               centerY + dx * sine + dy * cosine
    end

    local ulX, ulY = rotate(region.left, region.top)
    local llX, llY = rotate(region.left, region.bottom)
    local urX, urY = rotate(region.right, region.top)
    local lrX, lrY = rotate(region.right, region.bottom)
    texture:SetTexCoord(ulX, ulY, llX, llY, urX, urY, lrX, lrY)
end

local function applyStyle(frame, pingType)
    local cfg = addon.PING_TYPES[pingType]
    frame.pingType = pingType
    frame.lastFlipbookFrame = nil

    if frame.isWorldPoint then
        frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
        frame.bg:ClearAllPoints()
        frame.bg:SetPoint("TOP", frame, "TOP", 0, 0)
        addon:ApplyPingRegion(frame.bg, cfg.groundBg)
        addon:ApplyPingRegion(frame.pin, cfg.groundPin, addon.PIN_TOP_CROP)
        frame.pin:Show()
    else
        frame:SetSize(FRAME_WIDTH, BG_HEIGHT)
        frame.bg:ClearAllPoints()
        frame.bg:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
        addon:ApplyPingRegion(frame.bg, cfg.unitBg)
        frame.pin:Hide()
    end

    frame.flipbook:ClearAllPoints()
    frame.flipbook:SetPoint("CENTER", frame.bg, "CENTER", cfg.flipbookOffsetX, cfg.flipbookOffsetY)
    addon:ApplyFlipbookFrame(frame.flipbook, cfg.flipbook, 0)

    -- Stroke ring: individual BLP per type, full texture
    frame.stroke:SetTexture(addon.STROKE_TEXTURE[pingType])
    frame.stroke:SetTexCoord(0, 1, 0, 1)
    local strokeAtlas = addon.atlas["Ping_GroundMarker_Stroke_" .. pingType]
                     or addon.atlas["Ping_GroundMarker_Stroke_Warning"]
    frame.stroke:SetSize(strokeAtlas.width * STROKE_SCALE, strokeAtlas.height * STROKE_SCALE)
    frame.stroke:ClearAllPoints()
    frame.stroke:SetPoint("CENTER", frame.bg, "CENTER", 0, 4)
    frame.strokeAngle = 0
    applyStrokeRotation(frame.stroke, 0)

    addon:ApplyPingRegion(frame.clampedBg, "Ping_OVMarker_Pointer_BG")
    frame.clampedPointerRegion = addon.atlas["Ping_OVMarker_Pointer_" .. pingType]
    addon:ApplyPingRegion(frame.clampedPointer, "Ping_OVMarker_Pointer_" .. pingType)

    -- Minimap pin icon
    local r = addon.atlas["Ping_MapPin_" .. pingType]
    if r then
        frame.mmBlip.tex:SetTexture(addon.TEXTURE_PING)
        frame.mmBlip.tex:SetTexCoord(r.left, r.right, r.top, r.bottom)
        frame.mmBlip:SetSize(r.width, r.height)
    end
end

local function setClampedState(frame, clamped, rawX, rawY, projectionRoot)
    if clamped then
        frame.bg:Hide()
        frame.pin:Hide()
        frame.flipbook:Hide()
        frame.stroke:Hide()
        frame.clampedBg:Show()
        frame.clampedPointer:Show()

        local centerX = projectionRoot:GetWidth() / 2
        local centerY = projectionRoot:GetHeight() / 2
        local dx = rawX - centerX
        local dy = rawY - centerY
        if dx ~= 0 or dy ~= 0 then
            -- The retail clamped marker points back toward the actual world pin.
            applyAtlasRotation(
                frame.clampedPointer, frame.clampedPointerRegion,
                math.atan2(dy, dx) - math.pi / 2)
        end
    else
        frame.clampedBg:Hide()
        frame.clampedPointer:Hide()
        frame.bg:Show()
        if frame.isWorldPoint then
            frame.pin:Show()
            if frame.riseComplete then
                frame.flipbook:Show()
                frame.stroke:Show()
            else
                frame.flipbook:Hide()
                frame.stroke:Hide()
            end
        else
            frame.pin:Hide()
            frame.flipbook:Show()
            if frame.riseComplete then
                frame.stroke:Show()
            else
                frame.stroke:Hide()
            end
        end
    end
    frame.isClamped = clamped
end

local function updatePosition(frame)
    if frame.unitGuidLow and frame.unitGuidHigh then
        local unitX, unitY, unitZ = addon:GetUnitWorldPosition(
            frame.unitGuidLow, frame.unitGuidHigh)
        if unitX and unitY and unitZ then
            frame.posX = unitX
            frame.posY = unitY
            frame.posZ = unitZ
        end
    end

    local rawX, rawY, _, visible = addon:ConvertWorldToScreen(
        frame.posX, frame.posY, frame.posZ)
    local projectionRoot = WorldFrame or UIParent
    if rawX == nil or rawY == nil then
        -- During camera transitions the native projection can briefly be unavailable.
        -- Keep the last edge/screen position instead of making a remote ping disappear.
        rawX, rawY = frame.lastRawX, frame.lastRawY
        if rawX == nil or rawY == nil then
            rawX = projectionRoot:GetWidth() / 2
            rawY = SCREEN_EDGE_MARGIN
        end
    end
    frame.lastRawX, frame.lastRawY = rawX, rawY
    if not frame:IsShown() then frame:Show() end
    frame:ClearAllPoints()
    local screenX = rawX
    local screenY = rawY

    -- Keep clipped pings on the nearest WorldFrame edge so group/raid pings remain
    -- visible even when their world point is outside the current camera view.
    local halfClamp = CLAMPED_SIZE / 2
    local minX = halfClamp + SCREEN_EDGE_MARGIN
    local maxX = math.max(minX, projectionRoot:GetWidth() - halfClamp - SCREEN_EDGE_MARGIN)
    local minY = halfClamp + SCREEN_EDGE_MARGIN
    local maxY = math.max(minY, projectionRoot:GetHeight() - halfClamp - SCREEN_EDGE_MARGIN)
    local clamped = visible == 0 or screenX < minX or screenX > maxX or screenY < minY or screenY > maxY
    if clamped then
        screenX = math.min(math.max(screenX, minX), maxX)
        screenY = math.min(math.max(screenY, minY), maxY)
    end

    setClampedState(frame, clamped, rawX, rawY, projectionRoot)
    if clamped then
        frame:SetPoint("CENTER", projectionRoot, "BOTTOMLEFT", screenX, screenY)
    else
        frame:SetPoint("BOTTOM", projectionRoot, "BOTTOMLEFT", screenX, screenY)
    end
    return true
end

-- Returns true once bubble has reached its final position.
local function updateRise(frame)
    local elapsed = GetTime() - frame.spawnedAt
    if not frame.isWorldPoint then
        local duration = 0.23
        local t = math.min(elapsed / duration, 1)
        frame.bg:ClearAllPoints()
        frame.bg:SetPoint("BOTTOM", frame, "BOTTOM", 0, (1 - easeOut(t)) * 40)
        if t >= 1 and not frame.riseComplete then
            frame.riseComplete = true
            frame.settleTime = GetTime()
            frame.bg:ClearAllPoints()
            frame.bg:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
            frame.stroke:Show()
        end
        return t >= 1
    end

    if elapsed >= RISE_DURATION then
        if not frame.riseComplete then
            frame.riseComplete = true
            frame.settleTime = GetTime()
            frame.bg:ClearAllPoints()
            frame.bg:SetPoint("TOP", frame, "TOP", 0, 0)
            addon:ApplyPingRegion(frame.pin, addon.PING_TYPES[frame.pingType].groundPin, addon.PIN_TOP_CROP)
            frame.flipbook:Show()
            frame.stroke:Show()
        end
        return true
    end
    local t = easeOut(elapsed / RISE_DURATION)
    -- Bubble rises: starts at ground (offset -STEM_BELOW), ends at final pos (offset 0)
    frame.bg:ClearAllPoints()
    frame.bg:SetPoint("TOP", frame, "TOP", 0, -(1 - t) * STEM_BELOW)
    -- Stem grows from the attachment point downward as bubble rises
    local stemT = math.max(t, 0.001)
    local r = addon.atlas[addon.PING_TYPES[frame.pingType].groundPin]
    local topCoord = r.top + (r.bottom - r.top) * (addon.PIN_TOP_CROP / r.height)
    frame.pin:SetTexCoord(r.left, r.right, topCoord, topCoord + (r.bottom - topCoord) * stemT)
    frame.pin:SetSize(r.width, math.max(STEM_VISIBLE * stemT, 1))
    return false
end

local function updateFlipbook(frame)
    local elapsed = GetTime() - (frame.settleTime or frame.spawnedAt)
    local progress = math.min(math.max(elapsed / addon.FLIPBOOK_DURATION, 0), 1)
    local frameIndex = math.min(math.floor(progress * addon.FLIPBOOK_FRAMES), addon.FLIPBOOK_FRAMES - 1)
    if frame.lastFlipbookFrame == frameIndex then return end
    frame.lastFlipbookFrame = frameIndex
    addon:ApplyFlipbookFrame(frame.flipbook, addon.PING_TYPES[frame.pingType].flipbook, frameIndex)
end

local function onUpdate(frame)
    local now    = GetTime()
    local remaining = frame.expiresAt - now
    if remaining <= 0 then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        if frame.mmBlip then frame.mmBlip:Hide() end
        return
    end
    if updatePosition(frame) then
        local settled = updateRise(frame)
        if settled then
            updateFlipbook(frame)
            frame.strokeAngle = frame.strokeAngle + STROKE_ROTATION_SPEED * frame.lastElapsed
            applyStrokeRotation(frame.stroke, frame.strokeAngle)
        end
        -- Rise/flipbook updates intentionally keep progressing while the world
        -- anchor is off screen, but the retail clamped pointer must remain the
        -- only visible representation until the anchor re-enters the viewport.
        if frame.isClamped then
            frame.bg:Hide()
            frame.pin:Hide()
            frame.flipbook:Hide()
            frame.stroke:Hide()
        end
        if remaining < addon.PING_FADE_OUT_SECONDS then
            frame:SetAlpha(remaining / addon.PING_FADE_OUT_SECONDS)
        else
            frame:SetAlpha(1)
        end
    end
    frame.lastElapsed = now - (frame.lastUpdateTime or now)
    frame.lastUpdateTime = now
    updateMinimapBlip(frame)
end

local function createFrame()
    -- Native world projection returns coordinates in WorldFrame space. Keep the
    -- visual receiver in that same hierarchy so UIParent scaling, widescreen
    -- offsets, and camera viewport changes cannot introduce a second transform.
    -- This is the same anchoring contract used by the QuestMarker distance label.
    local projectionRoot = WorldFrame or UIParent
    local frame = CreateFrame("Frame", nil, projectionRoot)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    -- World pins should be occluded by normal interface panels instead of
    -- floating over bags, the PVE frame, or other full-screen UI.
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)
    frame:EnableMouse(false)

    frame.bg = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.bg:SetPoint("TOP", frame, "TOP", 0, 0)

    frame.pin = frame:CreateTexture(nil, "ARTWORK", nil, 0)
    frame.pin:SetPoint("TOP", frame.bg, "TOP", 0, -addon.PIN_ATTACH_FROM_BG_TOP)
    frame.pin:SetAlpha(0.95)

    frame.flipbook = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    frame.flipbook:Hide()

    frame.stroke = frame:CreateTexture(nil, "OVERLAY", nil, 3)
    frame.stroke:SetPoint("CENTER", frame.bg, "CENTER", 0, 0)
    frame.stroke:SetBlendMode("ADD")
    frame.stroke._strokeKey = "Ping_GroundMarker_Stroke_OnMyWay"  -- default, overwritten in applyStyle

    frame.clampedBg = frame:CreateTexture(nil, "ARTWORK", nil, 4)
    frame.clampedBg:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.clampedBg:Hide()

    frame.clampedPointer = frame:CreateTexture(nil, "OVERLAY", nil, 5)
    frame.clampedPointer:SetPoint("CENTER", frame.clampedBg, "CENTER", 0, 0)
    frame.clampedPointer:Hide()

    frame.mmBlip = createMinimapBlip()

    frame:Hide()
    return frame
end

function addon:ApplyPing(sender, pingType, x, y, z, guidLow, guidHigh, unitName)
    if not self.PING_TYPES[pingType] then return end

    local frame = activePings[sender]
    if not frame then
        frame = createFrame()
        activePings[sender] = frame
    end

    frame.unitGuidLow = tonumber(guidLow)
    frame.unitGuidHigh = tonumber(guidHigh)
    frame.unitName = unitName
    if not frame.unitGuidLow or not frame.unitGuidHigh or
       (frame.unitGuidLow == 0 and frame.unitGuidHigh == 0) then
        frame.unitGuidLow, frame.unitGuidHigh, frame.unitName = nil, nil, nil
    end
    frame.isWorldPoint = frame.unitGuidLow == nil

    applyStyle(frame, pingType)
    frame.bg:ClearAllPoints()
    if frame.isWorldPoint then
        -- Retail ground pins grow a stem from the picked world point.
        frame.bg:SetPoint("TOP", frame, "TOP", 0, -STEM_BELOW)
        frame.pin:SetSize(frame.pin:GetWidth(), 1)
        frame.flipbook:Hide()
    else
        -- Retail unit pins are compact bubbles attached above the model; they
        -- do not carry the ground stem that made our old unit marker look displaced.
        frame.bg:SetPoint("BOTTOM", frame, "BOTTOM", 0, 40)
        frame.pin:Hide()
        frame.flipbook:Show()
    end
    frame.stroke:Hide()
    frame.riseComplete = false
    frame.settleTime   = nil
    frame.posX, frame.posY, frame.posZ = x, y, z
    frame.lastRawX, frame.lastRawY = nil, nil
    frame.isClamped = false

    local now = GetTime()
    frame.spawnedAt      = now
    frame.expiresAt      = now + self.PING_LIFETIME_SECONDS
    frame.lastUpdateTime = now
    frame.lastElapsed    = 0
    frame.strokeAngle    = 0
    frame:SetAlpha(1)
    frame:Show()
    frame:SetScript("OnUpdate", onUpdate)
    onUpdate(frame)

    self:PlayPingSound(pingType)
end

function addon:SendPing(pingType, x, y, z, guidLow, guidHigh, unitName)
    local now = GetTime()
    if now - lastSendTime < self.SEND_RATE_LIMIT_SECONDS then return end
    lastSendTime = now

    if x == nil or y == nil or z == nil then
        x, y, z, guidLow, guidHigh = self:GetMouseWorldPosition()
    end
    if x == nil or y == nil or z == nil then return end

    local channel = (GetNumRaidMembers() > 0 and "RAID")
        or (GetNumPartyMembers() > 0 and "PARTY")
        or nil
    local safeUnitName = unitName and unitName:gsub("[:\r\n]", " ") or ""
    if #safeUnitName > 64 then safeUnitName = safeUnitName:sub(1, 64) end

    if not channel then
        self:ApplyPing(UnitName("player"), pingType, x, y, z,
            guidLow, guidHigh, safeUnitName ~= "" and safeUnitName or nil)
        return
    end

    local bridge = wxlwow and wxlwow.radial_ping
    local pingCodes = { OnMyWay = 0, Attack = 1, Warning = 2, Assist = 3 }
    local pingCode = pingCodes[pingType]
    local sent = bridge and type(bridge.send_server) == "function" and
        pingCode ~= nil and bridge.send_server(pingCode, x, y, z,
            tonumber(guidLow) or 0, tonumber(guidHigh) or 0, safeUnitName)

    -- Render the sender's marker immediately.  The server packet remains the
    -- authority for every other party member, but it is an acknowledgement
    -- path for the sender rather than a prerequisite for local feedback.  A
    -- realm that accepts the CMSG without echoing it (or echoes it one frame
    -- later) must not make the ping appear to do nothing.
    self:ApplyPing(UnitName("player"), pingType, x, y, z,
        guidLow, guidHigh, safeUnitName ~= "" and safeUnitName or nil)

    if RadialPingDB and RadialPingDB.chatEnabled then
        if guidLow and guidHigh then
            local playerName = UnitName("player") or "Someone"
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cff66ccff[Map Ping]|r %s says move to %s",
                playerName, safeUnitName ~= "" and safeUnitName or "creature"))
        else
            local label = (self.PING_TYPES[pingType] and self.PING_TYPES[pingType].label) or pingType
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Map Ping]|r " .. label)
        end
    end
end

local function pullServerPings()
    local bridge = wxlwow and wxlwow.radial_ping
    if not bridge or type(bridge.pop_server) ~= "function" then return end
    local pingNames = { [0] = "OnMyWay", [1] = "Attack", [2] = "Warning", [3] = "Assist" }
    while true do
        local pingCode, x, y, z, guidLow, guidHigh, unitName, sender = bridge.pop_server()
        if pingCode == nil then break end
        local pingType = pingNames[tonumber(pingCode)]
        if pingType and x and y and z then
            addon:ApplyPing(sender and sender ~= "" and sender or "Party member",
                pingType, x, y, z, tonumber(guidLow), tonumber(guidHigh),
                unitName and unitName ~= "" and unitName or nil)
        end
    end
end

local bridge = wxlwow and wxlwow.radial_ping
if bridge then
    bridge._NativeChanged = pullServerPings
    pullServerPings()
end
