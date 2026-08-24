local _, addon = ...

-- ---------------------------------------------------------------------------
-- Interface Options panels (Interface Options -> WarcraftXL -> Radial Ping)
-- ---------------------------------------------------------------------------

local rootPanel = _G.WarcraftXLOptionsPanel
if not rootPanel then
    rootPanel = CreateFrame("Frame", "WarcraftXLOptionsPanel")
    rootPanel.name = "WarcraftXL"
    local rootTitle = rootPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    rootTitle:SetPoint("TOPLEFT", 16, -16)
    rootTitle:SetText("WarcraftXL")
    local rootSubtitle = rootPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rootSubtitle:SetPoint("TOPLEFT", rootTitle, "BOTTOMLEFT", 0, -6)
    rootSubtitle:SetWidth(430)
    rootSubtitle:SetJustifyH("LEFT")
    rootSubtitle:SetText("Client feature settings and interface extensions.")
    local radialStatus = rootPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    radialStatus:SetPoint("TOPLEFT", rootSubtitle, "BOTTOMLEFT", 0, -24)
    radialStatus:SetText("Radial Ping|cff20ff20  Available|r")
    local questStatus = rootPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    questStatus:SetPoint("TOPLEFT", radialStatus, "BOTTOMLEFT", 0, -12)
    questStatus:SetText("Quest Marker|cff20ff20  Available|r")
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(rootPanel)
    end
end

local panel = CreateFrame("Frame", "RadialPingOptionsPanel")
panel.name = "Radial Ping"
panel.parent = "WarcraftXL"

-- Title
local titleFS = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
titleFS:SetPoint("TOPLEFT", 16, -16)
titleFS:SetText("Radial Ping")

local subtitleFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitleFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -4)
subtitleFS:SetText("Radial ping wheel for parties and raids")

-- ── Hotkey ──────────────────────────────────────────────────────────────────

local hotkeyLabelFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hotkeyLabelFS:SetPoint("TOPLEFT", subtitleFS, "BOTTOMLEFT", 0, -12)
hotkeyLabelFS:SetTextColor(0.65, 0.65, 0.65)
hotkeyLabelFS:SetText("Hotkey: Not bound")

local hotkeyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
hotkeyBtn:SetSize(90, 22)
hotkeyBtn:SetPoint("LEFT", hotkeyLabelFS, "RIGHT", 10, 0)
hotkeyBtn:SetText("Set Hotkey")
hotkeyBtn:SetScript("OnClick", function()
    KeyBindingFrame_LoadUI()
    if KeyBindingFrame then
        -- Hide settings first so the game doesn't close it permanently
        InterfaceOptionsFrame:Hide()
        KeyBindingFrame:HookScript("OnHide", function()
            InterfaceOptionsFrame:Show()
            InterfaceOptionsFrame_OpenToCategory(addon.optionsPanel)
        end)
        KeyBindingFrame:Show()
    end
end)

-- ── Mode ────────────────────────────────────────────────────────────────────

local modeHeaderFS = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
modeHeaderFS:SetPoint("TOPLEFT", hotkeyLabelFS, "BOTTOMLEFT", 0, -16)
modeHeaderFS:SetText("Ping Mode")

-- Direct
local directBtn = CreateFrame("CheckButton", "RadialPingOptDirect", panel, "UICheckButtonTemplate")
directBtn:SetPoint("TOPLEFT", modeHeaderFS, "BOTTOMLEFT", 0, -8)

local directLabelFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
directLabelFS:SetPoint("LEFT", directBtn, "RIGHT", 0, 1)
directLabelFS:SetText("Direct")

local directDescFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
directDescFS:SetPoint("TOPLEFT", directLabelFS, "BOTTOMLEFT", 0, -3)
directDescFS:SetWidth(350)
directDescFS:SetJustifyH("LEFT")
directDescFS:SetTextColor(0.65, 0.65, 0.65)
directDescFS:SetText("Hold hotkey shows Ping Wheel.\nNavigate the wheel and click or release hotkey fires the ping.")

-- Relaxed
local relaxedBtn = CreateFrame("CheckButton", "RadialPingOptRelaxed", panel, "UICheckButtonTemplate")
relaxedBtn:SetPoint("CENTER", directBtn, "CENTER", 0, -60)

local relaxedLabelFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
relaxedLabelFS:SetPoint("LEFT", relaxedBtn, "RIGHT", 0, 1)
relaxedLabelFS:SetText("Relaxed")

local relaxedDescFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
relaxedDescFS:SetPoint("TOPLEFT", relaxedLabelFS, "BOTTOMLEFT", 0, -3)
relaxedDescFS:SetWidth(350)
relaxedDescFS:SetJustifyH("LEFT")
relaxedDescFS:SetTextColor(0.65, 0.65, 0.65)
relaxedDescFS:SetText("Hold hotkey shows Ping Cursor.\nNavigate mouse and click once to show the Ping Wheel.\nNavigate the wheel and click again or release hotkey fires the ping.")

-- Divider
local divider = panel:CreateTexture(nil, "ARTWORK")
divider:SetTexture(0.4, 0.4, 0.4, 0.5)
divider:SetSize(380, 1)
divider:SetPoint("TOPLEFT", relaxedDescFS, "BOTTOMLEFT", -32, -10)

-- ── Sounds ──────────────────────────────────────────────────────────────────

local soundsBtn = CreateFrame("CheckButton", "RadialPingOptSounds", panel, "UICheckButtonTemplate")
soundsBtn:SetPoint("CENTER", relaxedBtn, "CENTER", 0, -75)

local soundsLabelFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
soundsLabelFS:SetPoint("LEFT", soundsBtn, "RIGHT", 0, 1)
soundsLabelFS:SetText("Enable ping sounds")

-- ── Chat ────────────────────────────────────────────────────────────────────

local chatBtn = CreateFrame("CheckButton", "RadialPingOptChat", panel, "UICheckButtonTemplate")
chatBtn:SetPoint("CENTER", soundsBtn, "CENTER", 0, -30)

local chatLabelFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
chatLabelFS:SetPoint("LEFT", chatBtn, "RIGHT", 0, 1)
chatLabelFS:SetText("Send chat message on ping")

local chatDescFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
chatDescFS:SetPoint("TOPLEFT", chatLabelFS, "BOTTOMLEFT", 0, -3)
chatDescFS:SetWidth(325)
chatDescFS:SetJustifyH("LEFT")
chatDescFS:SetTextColor(0.65, 0.65, 0.65)
chatDescFS:SetText("Posts a [RadialPing] message to party or raid chat when you send a ping.")

-- ── Logic ───────────────────────────────────────────────────────────────────

local function syncPanel()
    if not RadialPingDB then return end
    local mode = RadialPingDB.pingMode or "direct"
    directBtn:SetChecked(mode == "direct")
    relaxedBtn:SetChecked(mode == "relaxed")
    soundsBtn:SetChecked(not not RadialPingDB.soundsEnabled)
    chatBtn:SetChecked(not not RadialPingDB.chatEnabled)
    local key = GetBindingKey("RADIALPING_OPEN")
    if key then
        hotkeyLabelFS:SetText("Hotkey: " .. GetBindingText(key, "KEY_"))
    else
        hotkeyLabelFS:SetText("Hotkey: Not bound")
    end
end

directBtn:SetScript("OnClick", function()
    if RadialPingDB then RadialPingDB.pingMode = "direct" end
    syncPanel()
end)

relaxedBtn:SetScript("OnClick", function()
    if RadialPingDB then RadialPingDB.pingMode = "relaxed" end
    syncPanel()
end)

soundsBtn:SetScript("OnClick", function(self)
    if RadialPingDB then
        RadialPingDB.soundsEnabled = self:GetChecked() and true or false
    end
end)

chatBtn:SetScript("OnClick", function(self)
    if RadialPingDB then
        RadialPingDB.chatEnabled = self:GetChecked() and true or false
    end
end)

panel:SetScript("OnShow", syncPanel)

if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

addon.optionsPanel = panel
