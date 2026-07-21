local addon = WXL_RadialPing

local function enabled()
    return GetCVar("wxlRadialPingEnabled") == "1"
end

local relaxedPoller = CreateFrame("Frame")
relaxedPoller:Hide()
relaxedPoller:SetScript("OnUpdate", function(self)
    if not enabled() then self:Hide() SetCursor(nil) return end
    SetCursor("Interface\\Cursor\\PingUiPin")
    if IsMouseButtonDown("LeftButton") then
        self:Hide()
        addon:OpenWheel()
    end
end)

function RadialPing_OnBinding(keystate)
    if not enabled() then return end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus then return end
    local mode = GetCVar("wxlRadialPingMode")
    if mode == "relaxed" then
        if keystate == "down" then
            relaxedPoller:Show()
        elseif relaxedPoller:IsShown() then
            relaxedPoller:Hide()
            SetCursor(nil)
        else
            addon:CloseWheel(true)
        end
    elseif keystate == "down" then
        addon:OpenWheel()
    else
        addon:CloseWheel(true)
    end
end

local function keyToVK(key)
    key = (key or ""):upper()
    if #key == 1 then return string.byte(key) end
    local named = {
        SPACE = 0x20, TAB = 0x09, INSERT = 0x2D, DELETE = 0x2E,
        HOME = 0x24, END = 0x23, PAGEUP = 0x21, PAGEDOWN = 0x22,
        UP = 0x26, DOWN = 0x28, LEFT = 0x25, RIGHT = 0x27,
        NUMPAD0 = 0x60, NUMPAD1 = 0x61, NUMPAD2 = 0x62, NUMPAD3 = 0x63,
        NUMPAD4 = 0x64, NUMPAD5 = 0x65, NUMPAD6 = 0x66, NUMPAD7 = 0x67,
        NUMPAD8 = 0x68, NUMPAD9 = 0x69,
    }
    local fn = tonumber(key:match("^F(%d+)$"))
    if fn and fn >= 1 and fn <= 12 then return 0x6F + fn end
    return named[key]
end
addon.KeyToVK = keyToVK

if SetRadialPingHotkeyVK then
    SetRadialPingHotkeyVK(keyToVK(GetCVar("wxlRadialPingKey")) or 0)
end
if SetRadialPingInputEnabled then
    SetRadialPingInputEnabled(enabled() and 1 or 0)
end

SLASH_RADIALPING1 = "/radialping"
SLASH_RADIALPING2 = "/rping"
SlashCmdList = SlashCmdList or {}
SlashCmdList.RADIALPING = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "config" or msg == "options" then
        if addon.optionsPanel and WarcraftXL_OpenToCategory then
            WarcraftXL_OpenToCategory(addon.optionsPanel)
        end
    elseif msg == "on" or msg == "off" then
        SetCVar("wxlRadialPingEnabled", msg == "on" and "1" or "0")
        if SetRadialPingInputEnabled then SetRadialPingInputEnabled(msg == "on" and 1 or 0) end
        print("|cff66ccffWarcraftXL Radial Ping|r: " .. (msg == "on" and "enabled" or "disabled"))
    elseif msg == "mode direct" or msg == "mode relaxed" then
        SetCVar("wxlRadialPingMode", msg:match("mode (%a+)$"))
        print("|cff66ccffWarcraftXL Radial Ping|r: " .. msg)
    else
        print("|cff66ccffWarcraftXL Radial Ping|r: /rping, /rping on|off, /rping mode direct|relaxed")
    end
end
