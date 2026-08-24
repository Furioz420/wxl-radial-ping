local _, addon = ...

addon.MESSAGE_PREFIX = "RADIALPING"
addon.SEND_RATE_LIMIT_SECONDS = 1
addon.PING_LIFETIME_SECONDS = 5
addon.PING_FADE_OUT_SECONDS = 0.35

addon.PIN_TOP_CROP = 52
addon.PIN_ATTACH_FROM_BG_TOP = 46

addon.FLIPBOOK_COLUMNS = 6
addon.FLIPBOOK_ROWS = 4
addon.FLIPBOOK_FRAMES = 21
addon.FLIPBOOK_DURATION = 0.7

-- Retail RadialWheelFrameMixin uses 500 squared pixels (about 22.36 px)
-- and places full-size wedge buttons 80 px from the center.
addon.WHEEL_ICON_DISTANCE = 80
addon.WHEEL_DEADZONE_RADIUS = math.sqrt(500)
addon.WHEEL_SCREEN_MARGIN = 20
addon.WHEEL_SECTION_RADIANS = math.pi / 2
addon.WHEEL_FRAME_OVERLAY_ALPHA = 0.55
addon.WHEEL_FRAME_OVERLAY_INSET = 35
addon.WHEEL_WEDGE_OFFSET = 15

local SOUNDS_DIR = "Interface\\WarcraftXL\\RadialPing\\Sounds\\"

addon.PING_TYPES = {
    OnMyWay = {
        label        = "On My Way",
        unitBg       = "Ping_UnitMarker_BG_OnMyWay",
        groundBg     = "Ping_GroundMarker_BG_OnMyWay",
        groundPin    = "Ping_GroundMarker_Pin_OnMyWay",
        iconNormal   = "Ping_Wheel_Icon_OnMyWay",
        iconGlow     = "Ping_Wheel_Icon_OnMyWay_Glow",
        flipbook     = "Ping_Marker_FlipBook_OnMyWay",
        flipbookOffsetX = 1,
        flipbookOffsetY = 13,
        sound = SOUNDS_DIR .. "OnMyWay.ogg",
    },
    Attack = {
        label        = "Attack",
        unitBg       = "Ping_UnitMarker_BG_Attack",
        groundBg     = "Ping_GroundMarker_BG_Attack",
        groundPin    = "Ping_GroundMarker_Pin_Attack",
        iconNormal   = "Ping_Wheel_Icon_Attack",
        iconGlow     = "Ping_Wheel_Icon_Attack_Glow",
        flipbook     = "Ping_Marker_FlipBook_Attack",
        flipbookOffsetX = -12,
        flipbookOffsetY = -10,
        sound = SOUNDS_DIR .. "Attack.ogg",
    },
    Warning = {
        label        = "Warning",
        unitBg       = "Ping_UnitMarker_BG_Warning",
        groundBg     = "Ping_GroundMarker_BG_Warning",
        groundPin    = "Ping_GroundMarker_Pin_Warning",
        iconNormal   = "Ping_Wheel_Icon_Warning",
        iconGlow     = "Ping_Wheel_Icon_Warning_Glow",
        flipbook     = "Ping_Marker_FlipBook_Warning",
        flipbookOffsetX = 1,
        flipbookOffsetY = 5,
        sound = SOUNDS_DIR .. "Warning.ogg",
    },
    Assist = {
        label        = "Assist",
        unitBg       = "Ping_UnitMarker_BG_Assist",
        groundBg     = "Ping_GroundMarker_BG_Assist",
        groundPin    = "Ping_GroundMarker_Pin_Assist",
        iconNormal   = "Ping_Wheel_Icon_Assist",
        iconGlow     = "Ping_Wheel_Icon_Assist_Glow",
        flipbook     = "Ping_Marker_FlipBook_Assist",
        flipbookOffsetX = -15,
        flipbookOffsetY = 8,
        sound = SOUNDS_DIR .. "Assist.ogg",
    },
}

-- Four cardinal slots.  Angles are measured from East (0°), counter-clockwise.
--   N = 90°  → Warning
--   E =  0°  → OnMyWay
--   S = 270° → Assist
--   W = 180° → Attack
-- wedgeRotation rotates the Radial_Wheel_Select_Wedge_Count_4 texture so
-- its "pointing" edge faces the correct quadrant (0° = East/right).
addon.WHEEL_SLOTS = {
    { pingType = "Warning",  angle =  90, wedgeRotation = 270 },  -- North
    { pingType = "OnMyWay",  angle =   0, wedgeRotation =   0 },  -- East
    { pingType = "Assist",   angle = 270, wedgeRotation =  90 },  -- South
    { pingType = "Attack",   angle = 180, wedgeRotation = 180 },  -- West
}

local atlas = addon.atlas
local TEXTURE_PING  = addon.TEXTURE_PING
local TEXTURE_WHEEL = addon.TEXTURE_WHEEL

function addon:ApplyWheelRegion(texture, key)
    local r = atlas[key]
    texture:SetTexture(TEXTURE_WHEEL)
    texture:SetTexCoord(r.left, r.right, r.top, r.bottom)
    texture:SetSize(r.width, r.height)
end

-- Generic apply for atlas entries that use an explicit texture path
-- (e.g. cursor atlas which uses a different sheet from TEXTURE_PING/WHEEL).
function addon:ApplyAtlasRegion(texture, key, texturePath)
    local r = atlas[key]
    texture:SetTexture(texturePath)
    texture:SetTexCoord(r.left, r.right, r.top, r.bottom)
    texture:SetSize(r.width, r.height)
end

function addon:ApplyPingRegion(texture, key, topCrop)
    local r = atlas[key]
    local top = r.top
    local height = r.height
    if topCrop and topCrop > 0 then
        top = r.top + (r.bottom - r.top) * (topCrop / r.height)
        height = r.height - topCrop
    end
    texture:SetTexture(TEXTURE_PING)
    texture:SetTexCoord(r.left, r.right, top, r.bottom)
    texture:SetSize(r.width, height)
end

function addon:ApplyFlipbookFrame(texture, key, frameIndex)
    local r = atlas[key]
    local cols, rows = self.FLIPBOOK_COLUMNS, self.FLIPBOOK_ROWS
    local col = frameIndex % cols
    local row = math.floor(frameIndex / cols)
    local stepX = (r.right - r.left) / cols
    local stepY = (r.bottom - r.top) / rows
    texture:SetTexture(TEXTURE_PING)
    texture:SetTexCoord(
        r.left + stepX * col,
        r.left + stepX * (col + 1),
        r.top  + stepY * row,
        r.top  + stepY * (row + 1)
    )
    texture:SetSize(r.width / cols, r.height / rows)
end

-- Rotated wedge for the 90° selection highlight. Rotation is restricted
-- to multiples of 90° expressed via SetTexCoord (no GPU rotation needed).
function addon:ApplyWedgeRegion(texture, key, rotationDegrees)
    local r = atlas[key]
    local left, right, top, bottom = r.left, r.right, r.top, r.bottom
    local w, h = r.width, r.height

    texture:SetTexture(TEXTURE_WHEEL)
    if rotationDegrees == 0 then
        texture:SetTexCoord(left, right, top, bottom)
        texture:SetSize(w, h)
    elseif rotationDegrees == 90 then
        texture:SetTexCoord(left, bottom, right, bottom, left, top, right, top)
        texture:SetSize(h, w)
    elseif rotationDegrees == 180 then
        texture:SetTexCoord(right, left, bottom, top)
        texture:SetSize(w, h)
    elseif rotationDegrees == 270 then
        texture:SetTexCoord(right, top, left, top, right, bottom, left, bottom)
        texture:SetSize(h, w)
    end
end

function addon:GetCursorUIPosition()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

function addon:PlayPingSound(pingType)
    if not (RadialPingDB and RadialPingDB.soundsEnabled) then return end
    local cfg = self.PING_TYPES[pingType]
    if cfg and cfg.sound then
        PlaySoundFile(cfg.sound)
    end
end
