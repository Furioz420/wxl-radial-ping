local addon = WXL_RadialPing

-- WXL may install this script before FrameXML has created InterfaceOptionsFrame. Do not return
-- permanently in that state: some clients retain the same Lua context into the world, so there may
-- be no second script execution to create the panel. Poll until both FrameXML and the WXL options
-- registry are ready, and make registration idempotent for contexts that do execute us again.
local function installSettings()
if addon.optionsPanel then
    if WarcraftXL_AddOptionsCategory then
        WarcraftXL_AddOptionsCategory(addon.optionsPanel)
        return true
    end
    return false
end
if not InterfaceOptionsFrame or not WarcraftXL_AddOptionsCategory then return false end

local panel = CreateFrame("Frame", "WarcraftXLRadialPingOptions")
panel.name = "Radial Ping"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Radial Ping")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetWidth(520)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Retail-style world pings relayed to members of your current party or raid.")

local function makeCheck(name, label, anchor, y)
    local button = CreateFrame("CheckButton", name, panel, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, y)
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", button, "RIGHT", 2, 1)
    text:SetText(label)
    return button
end

local enabledCheck = makeCheck("WarcraftXLRadialPingEnabled", "Enable radial pings", subtitle, -14)

local hotkeyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
hotkeyLabel:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 4, -15)

local capture = CreateFrame("Button", "WarcraftXLRadialPingHotkey", panel, "UIPanelButtonTemplate")
capture:SetSize(120, 22)
capture:SetPoint("LEFT", hotkeyLabel, "RIGHT", 12, 0)
capture:SetText("Change hotkey")

local captureFrame = CreateFrame("Frame", nil, UIParent)
captureFrame:EnableKeyboard(true)
captureFrame:Hide()
captureFrame:SetScript("OnKeyDown", function(self, key)
    key = (key or ""):upper()
    if key == "ESCAPE" then
        capture:SetText("Change hotkey")
    elseif #key == 1 or key:match("^F%d+$") or key == "SPACE" or key == "TAB" or
           key == "INSERT" or key == "DELETE" or key == "HOME" or key == "END" or
           key == "PAGEUP" or key == "PAGEDOWN" or key == "UP" or key == "DOWN" or
           key == "LEFT" or key == "RIGHT" or key:match("^NUMPAD%d$") then
        SetCVar("wxlRadialPingKey", key)
        if SetRadialPingHotkeyVK then SetRadialPingHotkeyVK(addon.KeyToVK(key) or 0) end
        hotkeyLabel:SetText("Hotkey: " .. key)
        capture:SetText("Change hotkey")
    else
        capture:SetText("Unsupported key")
    end
    self:Hide()
end)
capture:SetScript("OnClick", function()
    capture:SetText("Press a key...")
    captureFrame:Show()
end)

local modeTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
modeTitle:SetPoint("TOPLEFT", hotkeyLabel, "BOTTOMLEFT", 0, -18)
modeTitle:SetText("Ping mode")

local direct = makeCheck("WarcraftXLRadialPingDirect", "Direct — hold the hotkey to open the wheel", modeTitle, -6)
local relaxed = makeCheck("WarcraftXLRadialPingRelaxed", "Relaxed — show a cursor first, then click to open", direct, -24)
local sounds = makeCheck("WarcraftXLRadialPingSounds", "Enable ping sounds", relaxed, -30)
local chat = makeCheck("WarcraftXLRadialPingChat", "Send a short party/raid chat message", sounds, -24)

local function checked(name) return GetCVar(name) == "1" end
local function sync()
    enabledCheck:SetChecked(checked("wxlRadialPingEnabled"))
    sounds:SetChecked(checked("wxlRadialPingSounds"))
    chat:SetChecked(checked("wxlRadialPingChat"))
    local mode = GetCVar("wxlRadialPingMode")
    direct:SetChecked(mode ~= "relaxed")
    relaxed:SetChecked(mode == "relaxed")
    local key = GetCVar("wxlRadialPingKey")
    hotkeyLabel:SetText("Hotkey: " .. ((key and key ~= "") and key or "Not bound"))
end

enabledCheck:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    SetCVar("wxlRadialPingEnabled", value)
    if SetRadialPingInputEnabled then SetRadialPingInputEnabled(value == "1" and 1 or 0) end
end)
sounds:SetScript("OnClick", function(self) SetCVar("wxlRadialPingSounds", self:GetChecked() and "1" or "0") end)
chat:SetScript("OnClick", function(self) SetCVar("wxlRadialPingChat", self:GetChecked() and "1" or "0") end)
direct:SetScript("OnClick", function() SetCVar("wxlRadialPingMode", "direct") sync() end)
relaxed:SetScript("OnClick", function() SetCVar("wxlRadialPingMode", "relaxed") sync() end)
panel:SetScript("OnShow", sync)

WarcraftXL_AddOptionsCategory(panel)
addon.optionsPanel = panel
return true
end

if not installSettings() then
    local loader = CreateFrame("Frame")
    local elapsed = 0
    loader:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        if installSettings() then
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
end
