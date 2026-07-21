local addon = WXL_RadialPing

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

local function applyStyle(frame, pingType)
    local cfg = addon.PING_TYPES[pingType]
    frame.pingType = pingType
    frame.lastFlipbookFrame = nil

    addon:ApplyPingRegion(frame.bg, cfg.markerBg)
    addon:ApplyPingRegion(frame.pin, cfg.markerPin, addon.PIN_TOP_CROP)

    frame.flipbook:ClearAllPoints()
    frame.flipbook:SetPoint("CENTER", frame.bg, "CENTER", cfg.flipbookOffsetX, cfg.flipbookOffsetY)
    addon:ApplyFlipbookFrame(frame.flipbook, cfg.flipbook, 0)

    -- Stroke ring: individual BLP per type, full texture
    frame.stroke:SetTexture(addon.STROKE_TEXTURE[pingType])
    frame.stroke:SetTexCoord(0, 1, 0, 1)
    local strokeAtlas = addon.atlas["Ping_GroundMarker_Stroke_" .. pingType]
                     or addon.atlas["Ping_GroundMarker_Stroke_Warning"]
    frame.stroke:SetSize(strokeAtlas.width * STROKE_SCALE, strokeAtlas.height * STROKE_SCALE)
    frame.stroke:SetPoint("CENTER", frame.bg, "CENTER", 0, 4)
    frame.strokeAngle = 0
    applyStrokeRotation(frame.stroke, 0)

    -- Minimap pin icon
    local r = addon.atlas["Ping_MapPin_" .. pingType]
    if r then
        frame.mmBlip.tex:SetTexture(addon.TEXTURE_PING)
        frame.mmBlip.tex:SetTexCoord(r.left, r.right, r.top, r.bottom)
        frame.mmBlip:SetSize(r.width, r.height)
    end
end

local function updatePosition(frame)
    if frame.unitGuidLow and frame.unitGuidHigh and GetUnitPosition then
        local unitX, unitY, unitZ = GetUnitPosition(frame.unitGuidLow, frame.unitGuidHigh)
        if unitX and unitY and unitZ then
            frame.posX, frame.posY, frame.posZ = unitX, unitY, unitZ
        end
    end

    local rawX, rawY, _, visible = ConvertCoordsToScreenSpace(
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
    -- ConvertCoordsToScreenSpace is relative to CGWorldFrame. WorldFrame can have a
    -- non-zero inset inside UIParent, so using UIParent as the anchor root introduces
    -- a constant diagonal offset even when the projection itself is correct.
    local offsetX = addon.WORLD_PROJECTION_OFFSET_X or 0
    local offsetY = addon.WORLD_PROJECTION_OFFSET_Y or 0
    local screenX = rawX + offsetX
    local screenY = rawY + offsetY

    -- Keep clipped pings on the nearest WorldFrame edge so group/raid pings remain
    -- visible even when their world point is outside the current camera view.
    local minX = FRAME_WIDTH / 2 + SCREEN_EDGE_MARGIN
    local maxX = math.max(minX, projectionRoot:GetWidth() - FRAME_WIDTH / 2 - SCREEN_EDGE_MARGIN)
    local minY = SCREEN_EDGE_MARGIN
    local maxY = math.max(minY, projectionRoot:GetHeight() - FRAME_HEIGHT - SCREEN_EDGE_MARGIN)
    if visible == 0 or screenX < minX or screenX > maxX or screenY < minY or screenY > maxY then
        screenX = math.min(math.max(screenX, minX), maxX)
        screenY = math.min(math.max(screenY, minY), maxY)
    end

    frame:SetPoint("BOTTOM", projectionRoot, "BOTTOMLEFT", screenX, screenY)
    return true
end

-- Returns true once bubble has reached its final position.
local function updateRise(frame)
    local elapsed = GetTime() - frame.spawnedAt
    if elapsed >= RISE_DURATION then
        if not frame.riseComplete then
            frame.riseComplete = true
            frame.settleTime = GetTime()
            frame.bg:ClearAllPoints()
            frame.bg:SetPoint("TOP", frame, "TOP", 0, 0)
            addon:ApplyPingRegion(frame.pin, addon.PING_TYPES[frame.pingType].markerPin, addon.PIN_TOP_CROP)
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
    local r = addon.atlas[addon.PING_TYPES[frame.pingType].markerPin]
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
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetFrameLevel(10)
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

    applyStyle(frame, pingType)
    -- Reset to spawn state: bubble at ground, stem collapsed, animated parts hidden
    frame.bg:ClearAllPoints()
    frame.bg:SetPoint("TOP", frame, "TOP", 0, -STEM_BELOW)
    frame.pin:SetSize(frame.pin:GetWidth(), 1)
    frame.flipbook:Hide()
    frame.stroke:Hide()
    frame.riseComplete = false
    frame.settleTime   = nil
    frame.posX, frame.posY, frame.posZ = x, y, z
    frame.lastRawX, frame.lastRawY = nil, nil
    frame.unitGuidLow = tonumber(guidLow)
    frame.unitGuidHigh = tonumber(guidHigh)
    frame.unitName = unitName
    if not frame.unitGuidLow or not frame.unitGuidHigh or
       (frame.unitGuidLow == 0 and frame.unitGuidHigh == 0) then
        frame.unitGuidLow, frame.unitGuidHigh, frame.unitName = nil, nil, nil
    end

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
    if GetCVar("wxlRadialPingEnabled") ~= "1" then return end
    local now = GetTime()
    if now - lastSendTime < self.SEND_RATE_LIMIT_SECONDS then return end
    lastSendTime = now

    if x == nil or y == nil or z == nil then
        x, y, z, guidLow, guidHigh = GetMouseWorldPosition()
    end
    if x == nil or y == nil or z == nil then return end

    self:ApplyPing(UnitName("player"), pingType, x, y, z, guidLow, guidHigh, unitName)

    local channel = (GetNumRaidMembers() > 0 and "RAID")
        or (GetNumPartyMembers() > 0 and "PARTY")
        or nil
    if not channel then return end

    local safeUnitName = unitName and unitName:gsub("[:\r\n]", " ") or ""
    if #safeUnitName > 64 then safeUnitName = safeUnitName:sub(1, 64) end
    local pingCodes = { OnMyWay = 0, Attack = 1, Warning = 2, Assist = 3 }
    local pingCode = pingCodes[pingType]
    if pingCode == nil or not CreateWXLPacket then return end
    local packet = CreateWXLPacket(self.CMSG_OPCODE, 37 + #safeUnitName)
    if not packet then return end
    packet:WriteUInt8(pingCode)
    packet:WriteDouble(x):WriteDouble(y):WriteDouble(z)
    packet:WriteUInt32(tonumber(guidLow) or 0):WriteUInt32(tonumber(guidHigh) or 0)
    packet:WriteString(safeUnitName):Send()

    if GetCVar("wxlRadialPingChat") == "1" then
        if guidLow and guidHigh then
            local playerName = UnitName("player") or "Someone"
            SendChatMessage(string.format("[Map Ping] %s says move to creature %s",
                playerName, safeUnitName ~= "" and safeUnitName or "creature"), channel)
        else
            local label = (self.PING_TYPES[pingType] and self.PING_TYPES[pingType].label) or pingType
            SendChatMessage("[Map Ping] " .. label, channel)
        end
    end
end

if OnWXLPacket then
    OnWXLPacket(addon.SMSG_OPCODE, function(reader)
        local names = { [0] = "OnMyWay", [1] = "Attack", [2] = "Warning", [3] = "Assist" }
        local pingType = names[reader:ReadUInt8()]
        local x, y, z = reader:ReadDouble(), reader:ReadDouble(), reader:ReadDouble()
        local guidLow, guidHigh = reader:ReadUInt32(), reader:ReadUInt32()
        local unitName, sender = reader:ReadString(), reader:ReadString()
        if pingType and x and y and z then
            addon:ApplyPing(sender ~= "" and sender or "Party member", pingType, x, y, z,
                guidLow, guidHigh, unitName ~= "" and unitName or nil)
        end
    end)
end
