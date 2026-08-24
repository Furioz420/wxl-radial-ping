local _, addon = ...

local WHEEL_BG_KEY    = "Radial_Wheel_BG"
local WHEEL_FRAME_KEY = "Radial_Wheel_Frame_Count_4"
local WHEEL_WEDGE_KEY = "Radial_Wheel_Select_Wedge_Count_4"
local WHEEL_CLOSE_KEY = "Radial_Wheel_Icon_Close"
local WHEEL_CLOSE_HL_KEY = "Radial_Wheel_Select_Close"
-- SetCursor resolves cursor assets from Interface\\Cursor. The patch supplies this
-- cursor there; addon texture paths (especially with a .blp suffix) are not accepted
-- reliably by the 3.3.5 cursor API and were being retried every frame.
local CURSORPIN          = "Interface\\Cursor\\PingUiPin"
local TWEEN_IN_DURATION  = 0.20
local TWEEN_OUT_DURATION = 0.13

local WHEEL_SIZE = addon.atlas[WHEEL_BG_KEY].width
local WHEEL_HALF = WHEEL_SIZE / 2
local DEADZONE_SQ = addon.WHEEL_DEADZONE_RADIUS * addon.WHEEL_DEADZONE_RADIUS

local SLOT_ICON_OFFSETS = {}
local SLOT_WEDGE_ANCHORS = {}
do
    local OFFSET = addon.WHEEL_WEDGE_OFFSET
    local WEDGE_ANCHORS = {
        [0]   = { point = "LEFT",   x =  OFFSET, y =       0 },
        [90]  = { point = "TOP",    x =       0, y = -OFFSET },
        [180] = { point = "RIGHT",  x = -OFFSET, y =       0 },
        [270] = { point = "BOTTOM", x =       0, y =  OFFSET },
    }
    for index, slot in ipairs(addon.WHEEL_SLOTS) do
        local rad = math.rad(slot.angle)
        SLOT_ICON_OFFSETS[index] = {
            x = math.floor(math.cos(rad) * addon.WHEEL_ICON_DISTANCE + 0.5),
            y = math.floor(math.sin(rad) * addon.WHEEL_ICON_DISTANCE + 0.5),
        }
        SLOT_WEDGE_ANCHORS[index] = WEDGE_ANCHORS[slot.wedgeRotation]
    end
end

local wheel
local wheelPin

function addon:IsWheelOpen()
    return wheel and wheel:IsShown() and wheel.tweenState ~= "out"
end

local function unitGuidParts(token)
    if not UnitGUID then return false end
    local guid = UnitGUID(token)
    local hex = guid and guid:match("^0[xX](%x+)$")
    if not hex then return nil, nil end
    if #hex < 16 then hex = string.rep("0", 16 - #hex) .. hex end
    local high = tonumber(hex:sub(1, 8), 16)
    local low = tonumber(hex:sub(9, 16), 16)
    return low, high
end

local function unitTokenMatchesGuid(token, guidLow, guidHigh)
    local low, high = unitGuidParts(token)
    return low == guidLow and high == guidHigh
end

local function findAttachedUnitName(guidLow, guidHigh)
    local tokens = { "mouseover", "target", "focus" }
    for _, token in ipairs(tokens) do
        if unitTokenMatchesGuid(token, guidLow, guidHigh) then
            return UnitName(token)
        end
    end
    return "creature"
end

function addon:ResolveCursorAnchor()
    local worldX, worldY, worldZ, guidLow, guidHigh =
        self:GetMouseWorldPosition()

    -- The Wrath world picker can pass through friendly player models and
    -- report the floor behind them. The native mouseover token is exact, so
    -- prefer its GUID and resolved world position when one is present.
    local mouseoverLow, mouseoverHigh = unitGuidParts("mouseover")
    if mouseoverLow and mouseoverHigh and
       (mouseoverLow ~= 0 or mouseoverHigh ~= 0) then
        local mouseoverX, mouseoverY, mouseoverZ =
            self:GetUnitWorldPosition(mouseoverLow, mouseoverHigh)
        if mouseoverX then
            return mouseoverX, mouseoverY, mouseoverZ,
                mouseoverLow, mouseoverHigh,
                UnitName("mouseover") or
                    findAttachedUnitName(mouseoverLow, mouseoverHigh)
        end
    end

    if guidLow and guidHigh and (guidLow ~= 0 or guidHigh ~= 0) then
        local unitX, unitY, unitZ = self:GetUnitWorldPosition(guidLow, guidHigh)
        if unitX then
            return unitX, unitY, unitZ, guidLow, guidHigh,
                findAttachedUnitName(guidLow, guidHigh)
        end
    end

    return worldX, worldY, worldZ
end

function addon:PingAtCursor(pingType)
    if not self.PING_TYPES[pingType] then return end
    if self:IsWheelOpen() then self:CloseWheel(false) end

    local x, y, z, guidLow, guidHigh, unitName = self:ResolveCursorAnchor()
    if x == nil or y == nil or z == nil then return end
    self:SendPing(pingType, x, y, z, guidLow, guidHigh, unitName)
end

local function slotFromCursorDelta(dx, dy)
    if dx * dx + dy * dy < DEADZONE_SQ then return nil end
    local angle = math.atan2(dy, dx)
    local clockwiseFromNorth = math.pi / 2 - angle
    local twoPi = math.pi * 2
    -- Center each selection sector on its displayed icon. The old calculation
    -- started a sector at North, so moving a fraction left of the top icon
    -- jumped all the way to the West slot and made the wheel feel reluctant.
    local normalized = ((clockwiseFromNorth + addon.WHEEL_SECTION_RADIANS / 2) % twoPi + twoPi) % twoPi
    local count = #addon.WHEEL_SLOTS
    return math.floor(normalized / addon.WHEEL_SECTION_RADIANS) % count + 1
end

local function setSelection(frame, slotIndex)
    if frame.selectedSlot == slotIndex then return end
    frame.selectedSlot = slotIndex

    if slotIndex == nil then
        frame.selectionWedge:Hide()
        frame.closeHighlight:Show()
        frame.closeIcon:SetAlpha(1)
    else
        local slot = addon.WHEEL_SLOTS[slotIndex]
        local anchor = SLOT_WEDGE_ANCHORS[slotIndex]
        addon:ApplyWedgeRegion(frame.selectionWedge, WHEEL_WEDGE_KEY, slot.wedgeRotation)
        frame.selectionWedge:ClearAllPoints()
        frame.selectionWedge:SetPoint(anchor.point, frame, "CENTER", anchor.x, anchor.y)
        frame.selectionWedge:Show()
        frame.closeHighlight:Hide()
        frame.closeIcon:SetAlpha(0.7)
    end

    for i, slot in ipairs(addon.WHEEL_SLOTS) do
        local cfg = addon.PING_TYPES[slot.pingType]
        local icon = frame.icons[i]
        local selected = (i == slotIndex)
        addon:ApplyPingRegion(icon, selected and cfg.iconGlow or cfg.iconNormal)
        icon:SetAlpha(selected and 1 or 0.8)
    end
end

local function onUpdate(frame)
    local now = GetTime()

    -- Close tween: shrink + fade out from center, then hide
    if frame.tweenState == "out" then
        local t = math.min((now - frame.tweenStartTime) / TWEEN_OUT_DURATION, 1)
        local ease = t * t  -- ease-in quad
        frame:SetAlpha(1 - ease)
        if t >= 1 then
            frame:SetScript("OnUpdate", nil)
            frame:SetAlpha(1)
            frame:Hide()
            frame.tweenState = nil
        end
        return
    end

    -- Retail fades the wheel chrome in but keeps the selection geometry at its
    -- final scale, so cursor motion is represented immediately.
    if frame.tweenState == "in" then
        local t = math.min((now - frame.tweenStartTime) / TWEEN_IN_DURATION, 1)
        local ease = 1 - (1 - t) * (1 - t)  -- ease-out quad
        frame:SetAlpha(ease)
        if t >= 1 then
            frame:SetAlpha(1)
            frame.tweenState = nil
        end
    end

    local cursorX, cursorY = addon:GetCursorUIPosition()
    local dx = cursorX - frame.cursorOriginX
    local dy = cursorY - frame.cursorOriginY
    local inDeadzone = (dx * dx + dy * dy) < DEADZONE_SQ
    setSelection(frame, inDeadzone and nil or slotFromCursorDelta(dx, dy))

    -- Pointer arrow: visible outside deadzone, rotates to face cursor
    if inDeadzone then
        frame.pointer:Hide()
    else
        local angle = math.atan2(dy, dx)
        frame.pointer:SetRotation(angle)
        frame.pointer:Show()
    end

    -- Click-to-commit: left mouse released while a slot is highlighted fires the ping
    if IsMouseButtonDown("LeftButton") then
        frame.clickArmed = true
    elseif frame.clickArmed then
        frame.clickArmed = false
        if frame.selectedSlot then
            addon:CloseWheel(true)
            return
        end
    end
end

local function applyAtlasRegionRotatedRadians(texture, texturePath, region, rotationRadians, width, height)
    if width == nil then width = region.width end
    if height == nil then height = region.height end
    texture:SetTexture(texturePath)
    local centerX = (region.left + region.right) / 2
    local centerY = (region.top + region.bottom) / 2
    local halfWidth  = (region.right - region.left) / 2
    local halfHeight = (region.bottom - region.top) / 2
    local cos = math.cos(rotationRadians)
    local sin = math.sin(rotationRadians)
    local function rotateOffset(ox, oy)
        return {centerX + ox * cos - oy * sin, centerY + ox * sin + oy * cos}
    end
    local ulx, uly = unpack(rotateOffset(-halfWidth, -halfHeight))
    local llx, lly = unpack(rotateOffset(-halfWidth,  halfHeight))
    local urx, ury = unpack(rotateOffset( halfWidth, -halfHeight))
    local lrx, lry = unpack(rotateOffset( halfWidth,  halfHeight))
    texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    texture:SetSize(width, height)
    return texture
end

local function createWheel()
    -- Pin: a zero-size anchor placed at the click spot.
    -- Parenting the wheel to it and anchoring CENTER→CENTER means
    -- SetScale on the wheel grows/shrinks from the pin's center outward.
    wheelPin = CreateFrame("Frame", nil, UIParent)
    wheelPin:SetSize(1, 1)
    wheelPin:EnableMouse(false)
    wheelPin:EnableKeyboard(false)

    local frame = CreateFrame("Frame", nil, wheelPin)
    frame:SetSize(WHEEL_SIZE, WHEEL_SIZE)
    frame:SetPoint("CENTER", wheelPin, "CENTER", 0, 0)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(20)
    frame:EnableMouse(false)
    frame:EnableKeyboard(false)

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetPoint("CENTER")
    addon:ApplyWheelRegion(frame.background, WHEEL_BG_KEY)

    frame.selectionWedge = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.selectionWedge:SetBlendMode("ADD")
    addon:ApplyWheelRegion(frame.selectionWedge, WHEEL_WEDGE_KEY)
    frame.selectionWedge:Hide()

    frame.frameTexture = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    frame.frameTexture:SetPoint("CENTER")
    addon:ApplyWheelRegion(frame.frameTexture, WHEEL_FRAME_KEY)

    frame.closeHighlight = frame:CreateTexture(nil, "OVERLAY", nil, 4)
    frame.closeHighlight:SetPoint("CENTER")
    frame.closeHighlight:SetBlendMode("ADD")
    addon:ApplyWheelRegion(frame.closeHighlight, WHEEL_CLOSE_HL_KEY)
    frame.closeHighlight:Hide()

    frame.closeIcon = frame:CreateTexture(nil, "OVERLAY", nil, 5)
    frame.closeIcon:SetPoint("CENTER")
    addon:ApplyWheelRegion(frame.closeIcon, WHEEL_CLOSE_KEY)
    frame.closeIcon:SetAlpha(0.85)

    frame.pointer = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.pointer:SetPoint("CENTER")
    frame.pointer:SetBlendMode("ADD")
    frame.pointer:SetTexture(addon.TEXTURE_WHEEL_POINTER)
    local pR = addon.atlas["Radial_Wheel_Select_Pointer"]
    frame.pointer:SetSize(pR.width, pR.height)
    frame.pointer:Hide()

    frame.icons = {}
    frame.labels = {}
    for i, slot in ipairs(addon.WHEEL_SLOTS) do
        local cfg = addon.PING_TYPES[slot.pingType]
        local off = SLOT_ICON_OFFSETS[i]
        local icon = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetPoint("CENTER", frame, "CENTER", off.x, off.y)
        addon:ApplyPingRegion(icon, cfg.iconNormal)
        icon:SetAlpha(0.8)
        frame.icons[i] = icon

        -- Retail treats the label as part of each wedge. Apart from matching the
        -- visual layout, it makes fast mouse sweeps much easier to read than an
        -- icon-only wheel.
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetText(cfg.label)
        label:SetTextColor(1, 1, 1)
        label:SetShadowColor(0, 0, 0, 0.9)
        label:SetShadowOffset(1, -1)
        if slot.angle == 90 then
            label:SetPoint("BOTTOM", icon, "TOP", 0, 8)
        elseif slot.angle == 180 then
            label:SetPoint("RIGHT", icon, "LEFT", -4, 0)
        elseif slot.angle == 270 then
            label:SetPoint("TOP", icon, "BOTTOM", 0, -8)
        else
            label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        end
        frame.labels[i] = label
    end

    frame:Hide()
    return frame
end

function addon:OpenWheel(worldX, worldY, worldZ)
    if not wheel then wheel = createWheel() end
    if wheel:IsShown() and wheel.tweenState ~= "out" then return end

    wheel.wasMouselooking = IsMouselooking()
    if wheel.wasMouselooking then MouselookStop() end

    wheel.anchorGuidLow, wheel.anchorGuidHigh, wheel.anchorUnitName = nil, nil, nil
    if worldX then
        wheel.anchorWorldX, wheel.anchorWorldY, wheel.anchorWorldZ = worldX, worldY, worldZ
    else
        wheel.anchorWorldX, wheel.anchorWorldY, wheel.anchorWorldZ,
            wheel.anchorGuidLow, wheel.anchorGuidHigh, wheel.anchorUnitName =
            self:ResolveCursorAnchor()
    end

    local x, y = self:GetCursorUIPosition()

    -- Native projection and marker anchors share WorldFrame coordinates. Do not
    -- derive a global correction from the clicked model surface: that correction
    -- becomes invalid when the camera moves or the pin follows a unit.
    addon.WORLD_PROJECTION_OFFSET_X = 0
    addon.WORLD_PROJECTION_OFFSET_Y = 0

    -- Save unclamped cursor origin — this is the reference for delta/selection.
    -- anchorX/Y is clamped (for wheel placement); using it for delta gives wrong
    -- directions when the wheel was pushed away from the cursor by clamping.
    wheel.cursorOriginX, wheel.cursorOriginY = x, y
    local margin = self.WHEEL_SCREEN_MARGIN
    x = math.min(math.max(x, WHEEL_HALF + margin), UIParent:GetWidth()  - WHEEL_HALF - margin)
    y = math.min(math.max(y, WHEEL_HALF + margin), UIParent:GetHeight() - WHEEL_HALF - margin)
    wheel.anchorX, wheel.anchorY = x, y

    wheelPin:ClearAllPoints()
    wheelPin:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    wheel:SetScale(1)
    wheel:SetAlpha(0)
    wheel.tweenState = "in"
    wheel.tweenStartTime = GetTime()
    wheel:Show()
    wheel:SetScript("OnUpdate", onUpdate)
    SetCursor(CURSORPIN)

    setSelection(wheel, nil)
end

function addon:CloseWheel(commitSelection)
    if not wheel or not wheel:IsShown() then return end
    if wheel.tweenState == "out" then return end

    local slot = (commitSelection and wheel.selectedSlot) and addon.WHEEL_SLOTS[wheel.selectedSlot] or nil
    local restartMouselook = wheel.wasMouselooking

    -- Commit immediately
    wheel.wasMouselooking = false
    setSelection(wheel, nil)
    SetCursor(nil)

    if slot then
        self:SendPing(slot.pingType, wheel.anchorWorldX, wheel.anchorWorldY, wheel.anchorWorldZ,
            wheel.anchorGuidLow, wheel.anchorGuidHigh, wheel.anchorUnitName)
    end
    if restartMouselook then MouselookStart() end

    -- Start close tween; OnUpdate will hide the frame when done
    wheel.tweenState = "out"
    wheel.tweenStartTime = GetTime()
    wheel:SetScript("OnUpdate", onUpdate)
end
