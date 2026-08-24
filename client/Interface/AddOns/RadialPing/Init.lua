local _, addon = ...

wxlwow = wxlwow or {}
wxlwow.radial_ping = wxlwow.radial_ping or {}
wxlwow.radial_ping.addon = addon

local DEFAULTS = { soundsEnabled = true, chatEnabled = false, pingMode = "direct" }

function addon:GetMouseWorldPosition()
    local bridge = wxlwow and wxlwow.radial_ping
    if not bridge or type(bridge.pick_cursor) ~= "function" then return nil end
    return bridge.pick_cursor()
end

function addon:ConvertWorldToScreen(x, y, z)
    local bridge = wxlwow and wxlwow.radial_ping
    if not bridge or type(bridge.world_to_screen) ~= "function" then return nil end
    local screenX, screenY, visible, ddcWidth, ddcHeight = bridge.world_to_screen(x, y, z)
    if screenX == nil or screenY == nil then return nil end

    -- Native projection is in bottom-left DDC pixels. Convert each axis against
    -- the live WorldFrame so UI scale and widescreen aspect are both respected.
    local root = WorldFrame or UIParent
    local rootWidth = root and root:GetWidth() or 0
    local rootHeight = root and root:GetHeight() or 0
    if not ddcWidth or not ddcHeight or ddcWidth <= 0 or ddcHeight <= 0 or
       rootWidth <= 0 or rootHeight <= 0 then
        return nil
    end
    local rawX, rawY = screenX, screenY
    screenX = rawX * rootWidth / ddcWidth
    screenY = rawY * rootHeight / ddcHeight
    return screenX, screenY, 0, visible and 1 or 0,
        rawX, rawY, ddcWidth, ddcHeight
end

function addon:GetUnitWorldPosition(guidLow, guidHigh)
    local bridge = wxlwow and wxlwow.radial_ping
    if not bridge or type(bridge.unit_position) ~= "function" then return nil end
    return bridge.unit_position(guidLow, guidHigh)
end

local function applyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= "RadialPing" then return end
    RadialPingDB = RadialPingDB or {}
    applyDefaults(RadialPingDB, DEFAULTS)
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(addon.MESSAGE_PREFIX)
    end
    loader:UnregisterAllEvents()
end)

BINDING_HEADER_RADIALPING = "Radial Ping"
BINDING_NAME_RADIALPING_OPEN = "Open ping wheel"
BINDING_NAME_RADIALPING_WARNING = "Ping: Warning at cursor"
BINDING_NAME_RADIALPING_ATTACK = "Ping: Attack at cursor"
BINDING_NAME_RADIALPING_ON_MY_WAY = "Ping: On My Way at cursor"
BINDING_NAME_RADIALPING_ASSIST = "Ping: Assist at cursor"

-- Relaxed mode poller: shows the ping cursor and waits for a left-click.
local relaxedPoller = CreateFrame("Frame")
relaxedPoller:Hide()
relaxedPoller:SetScript("OnUpdate", function(self)
    SetCursor("Interface\\Cursor\\PingUiPin")
    if IsMouseButtonDown("LeftButton") then
        self:Hide()
        addon:OpenWheel()
    end
end)

function RadialPing_OnBinding()
    local mode = RadialPingDB and RadialPingDB.pingMode or "direct"
    if mode == "relaxed" then
        if addon:IsWheelOpen() then
            addon:CloseWheel(false)
        elseif relaxedPoller:IsShown() then
            relaxedPoller:Hide()
            SetCursor(nil)
        else
            relaxedPoller:Show()
        end
    else
        if addon:IsWheelOpen() then
            addon:CloseWheel(false)
        else
            addon:OpenWheel()
        end
    end
end

function RadialPing_DirectBinding(pingType)
    addon:PingAtCursor(pingType)
end

SLASH_RADIALPING1 = "/radialping"
SLASH_RADIALPING2 = "/rping"
SlashCmdList.RADIALPING = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "config" or msg == "options" or msg == "" then
        if addon.optionsPanel and InterfaceOptionsFrame_OpenToCategory then
            -- WoW requires two calls to reliably navigate to the right panel.
            InterfaceOptionsFrame_OpenToCategory(addon.optionsPanel)
            InterfaceOptionsFrame_OpenToCategory(addon.optionsPanel)
        end
    elseif msg == "sound on" or msg == "sounds on" then
        RadialPingDB.soundsEnabled = true
        print("|cff66ccffRadialPing|r: sounds enabled.")
    elseif msg == "sound off" or msg == "sounds off" then
        RadialPingDB.soundsEnabled = false
        print("|cff66ccffRadialPing|r: sounds disabled.")
    elseif msg == "mode direct" then
        RadialPingDB.pingMode = "direct"
        print("|cff66ccffRadialPing|r: mode set to |cffffffffDirect|r (tap the binding to open or cancel the wheel).")
    elseif msg == "mode relaxed" then
        RadialPingDB.pingMode = "relaxed"
        print("|cff66ccffRadialPing|r: mode set to |cffffffffRelaxed|r (crystal cursor, click to open wheel).")
    elseif msg == "debug projection" or msg == "debug" then
        local cursorX, cursorY = addon:GetCursorUIPosition()
        local worldX, worldY, worldZ = addon:GetMouseWorldPosition()
        if not worldX then
            print("|cff66ccffRadialPing|r: projection debug could not pick the world under the cursor.")
            return
        end
        local projectedX, projectedY, _, visible, rawX, rawY, ddcWidth, ddcHeight =
            addon:ConvertWorldToScreen(worldX, worldY, worldZ)
        local root = WorldFrame or UIParent
        print(string.format(
            "|cff66ccffRadialPing|r: cursor=%.1f,%.1f ui=%.1f,%.1f raw=%.1f,%.1f ddc=%.1fx%.1f root=%.1fx%.1f visible=%s",
            cursorX or -1, cursorY or -1, projectedX or -1, projectedY or -1,
            rawX or -1, rawY or -1, ddcWidth or -1, ddcHeight or -1,
            root:GetWidth() or -1, root:GetHeight() or -1, tostring(visible == 1)))
    else
        print("|cff66ccffRadialPing|r commands:")
        print("  /rping               -- open settings panel")
        print("  /rping sound on/off  -- toggle ping sounds")
        print("  /rping mode direct   -- tap to open, move, then left-click to ping")
        print("  /rping mode relaxed  -- crystal cursor, left-click to open wheel")
        print("  /rping debug projection -- compare cursor and native world projection")
        print("Bind a key under Key Bindings -> Radial Ping.")
    end
end
