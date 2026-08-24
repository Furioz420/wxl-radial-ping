// Native world-pick and projection bridge for the Radial Ping FrameScript addon.
// Copyright (C) 2026 WarcraftXL. GPLv3.

#include "ExtensionApi.hpp"

#include "game/Binding.hpp"
#include "game/Pick.hpp"
#include "game/Script.hpp"
#include "game/World.hpp"
#include "offsets/engine/Lua.hpp"
#include "offsets/game/Unit.hpp"
#include "offsets/game/World.hpp"

#include <windows.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <deque>
#include <mutex>
#include <span>
#include <string>
#include <vector>

namespace
{
    namespace luaoff = wxl::offsets::engine::lua;
    namespace script = wxl::game::script;
    namespace world = wxl::game::world;
    namespace worldoff = wxl::offsets::game::world;

    constexpr uint16_t kCmsgRadialPing = 0x0521;
    constexpr uint16_t kSmsgRadialPing = 0x0522;
    constexpr size_t kUnitScaleField = 0x98;
    constexpr size_t kUnitNameHeightField = 0xAC;

    float UnitOverheadHeight(void* unit)
    {
        if (!unit) return 0.0f;
        const auto* bytes = static_cast<const uint8_t*>(unit);
        const float scale = *reinterpret_cast<const float*>(bytes + kUnitScaleField);
        const float height = *reinterpret_cast<const float*>(bytes + kUnitNameHeightField);
        if (!(scale > 0.0f && scale < 100.0f && height > 0.0f && height < 100.0f))
            return 0.0f;
        return height * scale * 1.25f;
    }

    bool ProjectToUi(const float position[3], float& screenX, float& screenY,
                     bool& visible, float& ddcWidth, float& ddcHeight)
    {
        void* worldFrame = *reinterpret_cast<void**>(worldoff::kWorldFrame);
        if (!worldFrame) return false;
        float projected[3]{};
        uint32_t clipFlags = 0;
        const int onScreen = wxl::game::Native<worldoff::GetScreenCoordinatesFn>(
            worldoff::kGetScreenCoordinates)(
                worldFrame, nullptr, position, projected, &clipFlags);
        screenX = projected[0];
        screenY = projected[1];
        ddcWidth = *reinterpret_cast<const float*>(worldoff::kDdcWidth);
        ddcHeight = *reinterpret_cast<const float*>(worldoff::kDdcHeight);
        if (!(ddcWidth > 0.0f) || !(ddcHeight > 0.0f)) return false;
        visible = onScreen != 0;
        return true;
    }

    constexpr std::size_t kFixedRequestSize = 37;
    constexpr std::size_t kFixedResponseSize = 41;
    constexpr std::size_t kMaxUnitName = 64;
    constexpr std::size_t kMaxSenderName = 64;

    struct PingUpdate
    {
        uint8_t type = 0;
        double x = 0.0;
        double y = 0.0;
        double z = 0.0;
        uint32_t guidLow = 0;
        uint32_t guidHigh = 0;
        std::string unitName;
        std::string senderName;
    };

    std::mutex g_pingMutex;
    std::deque<PingUpdate> g_pingUpdates;

    template <typename T>
    void Append(std::vector<uint8_t>& payload, const T& value)
    {
        const auto* bytes = reinterpret_cast<const uint8_t*>(&value);
        payload.insert(payload.end(), bytes, bytes + sizeof(T));
    }

    void AppendString(std::vector<uint8_t>& payload, const std::string& value)
    {
        const uint32_t size = static_cast<uint32_t>(value.size());
        Append(payload, size);
        payload.insert(payload.end(), value.begin(), value.end());
    }

    template <typename T>
    bool Read(std::span<const uint8_t> payload, std::size_t& cursor, T& value)
    {
        if (cursor > payload.size() || sizeof(T) > payload.size() - cursor)
            return false;
        std::memcpy(&value, payload.data() + cursor, sizeof(T));
        cursor += sizeof(T);
        return true;
    }

    bool ReadString(std::span<const uint8_t> payload, std::size_t& cursor,
                    std::string& value, std::size_t maximum)
    {
        uint32_t size = 0;
        if (!Read(payload, cursor, size) || size > maximum ||
            cursor > payload.size() || size > payload.size() - cursor)
            return false;
        value.assign(reinterpret_cast<const char*>(payload.data() + cursor), size);
        cursor += size;
        return true;
    }

    void __cdecl OnServerPing(const uint8_t* bytes, uint32_t size, void*)
    {
        const std::span<const uint8_t> payload(bytes, size);
        PingUpdate update;
        std::size_t cursor = 0;
        if (payload.size() < kFixedResponseSize ||
            !Read(payload, cursor, update.type) || update.type > 3 ||
            !Read(payload, cursor, update.x) ||
            !Read(payload, cursor, update.y) ||
            !Read(payload, cursor, update.z) ||
            !Read(payload, cursor, update.guidLow) ||
            !Read(payload, cursor, update.guidHigh) ||
            !ReadString(payload, cursor, update.unitName, kMaxUnitName) ||
            !ReadString(payload, cursor, update.senderName, kMaxSenderName) ||
            cursor != payload.size() ||
            !std::isfinite(update.x) || !std::isfinite(update.y) ||
            !std::isfinite(update.z))
        {
            WLOG_WARN("rejected malformed radial-ping response (%u bytes)", size);
            return;
        }

        {
            const std::lock_guard lock(g_pingMutex);
            if (g_pingUpdates.size() >= 32) g_pingUpdates.pop_front();
            g_pingUpdates.push_back(std::move(update));
        }
        wxl_radial_ping::FrameScript()->Execute(
            "if wxlwow and wxlwow.radial_ping and "
            "wxlwow.radial_ping._NativeChanged then "
            "wxlwow.radial_ping._NativeChanged() end",
            "radial-ping-update");
    }

    int __cdecl LuaSendServerPing(void* state)
    {
        if (script::ArgCount(state) < 6)
        {
            script::PushBoolean(state, false);
            return 1;
        }

        const uint8_t type = static_cast<uint8_t>(script::ToNumber(state, 1));
        const double x = script::ToNumber(state, 2);
        const double y = script::ToNumber(state, 3);
        const double z = script::ToNumber(state, 4);
        const uint32_t guidLow = static_cast<uint32_t>(script::ToNumber(state, 5));
        const uint32_t guidHigh = static_cast<uint32_t>(script::ToNumber(state, 6));
        const char* rawName = script::ArgCount(state) >= 7
            ? script::ToString(state, 7) : nullptr;
        std::string unitName = rawName ? rawName : "";
        if (unitName.size() > kMaxUnitName) unitName.resize(kMaxUnitName);
        for (char& character : unitName)
            if (static_cast<unsigned char>(character) < 0x20 || character == ':')
                character = ' ';

        if (type > 3 || !std::isfinite(x) || !std::isfinite(y) ||
            !std::isfinite(z))
        {
            script::PushBoolean(state, false);
            return 1;
        }

        std::vector<uint8_t> payload;
        payload.reserve(kFixedRequestSize + unitName.size());
        Append(payload, type);
        Append(payload, x);
        Append(payload, y);
        Append(payload, z);
        Append(payload, guidLow);
        Append(payload, guidHigh);
        AppendString(payload, unitName);
        const bool sent = wxl_radial_ping::Network()->Send(
            kCmsgRadialPing, payload.data(),
            static_cast<uint32_t>(payload.size())) != 0;
        script::PushBoolean(state, sent);
        return 1;
    }

    int __cdecl LuaPopServerPing(void* state)
    {
        PingUpdate update;
        {
            const std::lock_guard lock(g_pingMutex);
            if (g_pingUpdates.empty()) return 0;
            update = std::move(g_pingUpdates.front());
            g_pingUpdates.pop_front();
        }
        script::PushNumber(state, update.type);
        script::PushNumber(state, update.x);
        script::PushNumber(state, update.y);
        script::PushNumber(state, update.z);
        script::PushNumber(state, update.guidLow);
        script::PushNumber(state, update.guidHigh);
        script::PushString(state, update.unitName.c_str());
        script::PushString(state, update.senderName.c_str());
        return 8;
    }

    void PushNil(void* state)
    {
        wxl::game::Native<luaoff::LuaPushNilFn>(luaoff::kLuaPushNil)(state);
    }

    void PushNumber(void* state, double value)
    {
        wxl::game::Native<luaoff::LuaPushNumberFn>(luaoff::kLuaPushNumber)(state, value);
    }

    int __cdecl LuaPickCursor(void* state)
    {
        world::WorldHit hit{};
        bool picked = false;
        __try
        {
            picked = world::PickCursor(hit) != 0;
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
            picked = false;
        }

        if (!picked)
        {
            PushNil(state);
            return 1;
        }

        PushNumber(state, hit.pos.x);
        PushNumber(state, hit.pos.y);
        PushNumber(state, hit.pos.z);

        uint32_t guidLow = static_cast<uint32_t>(
            reinterpret_cast<uintptr_t>(hit.objLo));
        uint32_t guidHigh = static_cast<uint32_t>(
            reinterpret_cast<uintptr_t>(hit.objHi));
        const uint64_t guid = static_cast<uint64_t>(guidLow) |
            (static_cast<uint64_t>(guidHigh) << 32);

        // Terrain and doodad handles are not unit GUIDs. Only publish an attachment GUID when the
        // client resolves it as a unit/player; otherwise the addon keeps a fixed ground position.
        bool unitGuid = false;
        __try
        {
            unitGuid = guid && world::ResolveObject(
                guid, world::kTypeMaskUnit | world::kTypeMaskPlayer);
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
            unitGuid = false;
        }
        if (!unitGuid)
        {
            guidLow = 0;
            guidHigh = 0;
        }
        PushNumber(state, guidLow);
        PushNumber(state, guidHigh);
        return 5;
    }

    int __cdecl LuaUnitPosition(void* state)
    {
        const auto toNumber = wxl::game::Native<luaoff::LuaToNumberFn>(
            luaoff::kLuaToNumber);
        const uint32_t guidLow = static_cast<uint32_t>(toNumber(state, 1));
        const uint32_t guidHigh = static_cast<uint32_t>(toNumber(state, 2));
        const uint64_t guid = static_cast<uint64_t>(guidLow) |
            (static_cast<uint64_t>(guidHigh) << 32);

        float position[3] = {};
        bool found = false;
        __try
        {
            void* unit = world::ResolveObject(
                guid, world::kTypeMaskUnit | world::kTypeMaskPlayer);
            if (unit)
            {
                float base[3] = {};
                float name[3] = {};
                world::UnitPosition(unit, base);
                world::NamePosition(unit, name);
                const float dx = name[0] - base[0];
                const float dy = name[1] - base[1];
                const float dz = name[2] - base[2];
                const bool validName = std::isfinite(name[0]) &&
                    std::isfinite(name[1]) && std::isfinite(name[2]) &&
                    dx * dx + dy * dy < 4.0f && dz > 0.1f && dz < 100.0f;
                if (validName)
                {
                    position[0] = name[0];
                    position[1] = name[1];
                    position[2] = name[2];
                }
                else
                {
                    position[0] = base[0];
                    position[1] = base[1];
                    position[2] = base[2] + UnitOverheadHeight(unit);
                }
                found = std::isfinite(position[0]) &&
                    std::isfinite(position[1]) && std::isfinite(position[2]);
            }
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
            found = false;
        }

        if (!found)
        {
            PushNil(state);
            return 1;
        }

        PushNumber(state, position[0]);
        PushNumber(state, position[1]);
        PushNumber(state, position[2]);
        return 3;
    }

    int __cdecl LuaWorldToScreen(void* state)
    {
        const auto toNumber = wxl::game::Native<luaoff::LuaToNumberFn>(
            luaoff::kLuaToNumber);
        const float position[3] = {
            static_cast<float>(toNumber(state, 1)),
            static_cast<float>(toNumber(state, 2)),
            static_cast<float>(toNumber(state, 3)),
        };

        float screenX = 0.0f;
        float screenY = 0.0f;
        float ddcWidth = 0.0f;
        float ddcHeight = 0.0f;
        bool visible = false;
        bool projected = false;
        __try
        {
            projected = ProjectToUi(
                position, screenX, screenY, visible, ddcWidth, ddcHeight);
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
            projected = false;
        }

        if (!projected)
        {
            PushNil(state);
            return 1;
        }

        PushNumber(state, screenX);
        PushNumber(state, screenY);
        wxl::game::Native<luaoff::LuaPushBooleanFn>(
            luaoff::kLuaPushBoolean)(state, visible ? 1 : 0);
        PushNumber(state, ddcWidth);
        PushNumber(state, ddcHeight);

        return 5;
    }

    constexpr char kBootstrap[] = R"lua(
do
    wxlwow = wxlwow or {}
    wxlwow.radial_ping = wxlwow.radial_ping or {}
    local RP = wxlwow.radial_ping

    if _WXLWOW_RADIAL_PICK_CURSOR then
        RP.pick_cursor = _WXLWOW_RADIAL_PICK_CURSOR
        _WXLWOW_RADIAL_PICK_CURSOR = nil
    end
    if _WXLWOW_RADIAL_WORLD_TO_SCREEN then
        RP.world_to_screen = _WXLWOW_RADIAL_WORLD_TO_SCREEN
        _WXLWOW_RADIAL_WORLD_TO_SCREEN = nil
    end
    if _WXLWOW_RADIAL_UNIT_POSITION then
        RP.unit_position = _WXLWOW_RADIAL_UNIT_POSITION
        _WXLWOW_RADIAL_UNIT_POSITION = nil
    end
    if _WXLWOW_RADIAL_SEND_SERVER then
        RP.send_server = _WXLWOW_RADIAL_SEND_SERVER
        _WXLWOW_RADIAL_SEND_SERVER = nil
    end
    if _WXLWOW_RADIAL_POP_SERVER then
        RP.pop_server = _WXLWOW_RADIAL_POP_SERVER
        _WXLWOW_RADIAL_POP_SERVER = nil
    end

    -- Ping API adapter. The shared retail-UI extension owns general-purpose
    -- compatibility; this domain module owns the C_Ping/C_PingSecure contract.
    Enum = Enum or {}
    Enum.PingMode = Enum.PingMode or { KeyDown = 0, ClickDrag = 1 }
    Enum.PingSubjectType = Enum.PingSubjectType or {
        Assist = 0, Attack = 1, OnMyWay = 2, Warning = 3,
    }
    Enum.PingResult = Enum.PingResult or {
        Success = 0, FailedGeneric = 1, FailedSpamming = 2,
        FailedDisabledByLeader = 3, FailedDisabledBySettings = 4,
        FailedOutOfPingArea = 5, FailedSquelched = 6,
        FailedUnspecified = 7, FailedSilent = 8,
    }
    Enum.PingSetTargetState = Enum.PingSetTargetState or {
        Ok = 0, Failed = 1, Pending = 2,
    }
    Enum.PingTargetOption = Enum.PingTargetOption or { All = 0, Environment = 1 }

    local subjectNames = {
        [Enum.PingSubjectType.Assist] = "Assist",
        [Enum.PingSubjectType.Attack] = "Attack",
        [Enum.PingSubjectType.OnMyWay] = "OnMyWay",
        [Enum.PingSubjectType.Warning] = "Warning",
    }
    RP.secure = RP.secure or { callbacks = {} }
    local Secure = RP.secure
    local function result(ok, pingType)
        return { result = ok and Enum.PingResult.Success or Enum.PingResult.FailedGeneric,
                 type = pingType }
    end
    local function sendPicked(pingType)
        local hit = Secure.hit
        local addon = RP.addon
        if not hit or not addon or type(addon.SendPing) ~= "function" then
            return result(false, pingType)
        end
        addon:SendPing(subjectNames[pingType] or "Warning",
            hit.x, hit.y, hit.z, hit.guidLow, hit.guidHigh, hit.unitName)
        Secure.hit = nil
        return result(true, pingType)
    end

    C_Ping = C_Ping or {}
    if type(C_Ping.GetCooldownInfo) ~= "function" then
        function C_Ping.GetCooldownInfo() return nil end
    end
    if type(C_Ping.GetDefaultPingOptions) ~= "function" then
        function C_Ping.GetDefaultPingOptions()
            return {
                { type=Enum.PingSubjectType.Attack, uiTextureKitID="Attack", orderIndex=1 },
                { type=Enum.PingSubjectType.Warning, uiTextureKitID="Warning", orderIndex=2 },
                { type=Enum.PingSubjectType.OnMyWay, uiTextureKitID="OnMyWay", orderIndex=3 },
                { type=Enum.PingSubjectType.Assist, uiTextureKitID="Assist", orderIndex=4 },
            }
        end
    end
    if type(C_Ping.GetTextureKitForType) ~= "function" then
        function C_Ping.GetTextureKitForType(pingType)
            return subjectNames[pingType] or "Warning"
        end
    end
    if type(C_Ping.TogglePingListener) ~= "function" then
        function C_Ping.TogglePingListener(enabled)
            local callback = Secure.callbacks.toggleListener
            if callback then callback(enabled and true or false)
            elseif enabled and type(RadialPing_OnBinding) == "function" then
                RadialPing_OnBinding()
            end
        end
    end
    if type(C_Ping.SendMacroPing) ~= "function" then
        function C_Ping.SendMacroPing(info)
            local callback = Secure.callbacks.sendMacro
            if callback then return callback(info) end
            if RP.pick_cursor then
                local x, y, z, guidLow, guidHigh = RP.pick_cursor()
                if x then
                    Secure.hit = { x=x, y=y, z=z, guidLow=guidLow, guidHigh=guidHigh }
                    return sendPicked(info and info.type or Enum.PingSubjectType.Warning)
                end
            end
            return result(false, info and info.type)
        end
    end

    C_PingSecure = C_PingSecure or {}
    local function callbackSetter(key)
        return function(callback) Secure.callbacks[key] = callback end
    end
    C_PingSecure.SetPendingPingOffScreenCallback = C_PingSecure.SetPendingPingOffScreenCallback or callbackSetter("offscreen")
    C_PingSecure.SetPingCooldownStartedCallback = C_PingSecure.SetPingCooldownStartedCallback or callbackSetter("cooldown")
    C_PingSecure.SetPingPinFrameAddedCallback = C_PingSecure.SetPingPinFrameAddedCallback or callbackSetter("pinAdded")
    C_PingSecure.SetPingPinFrameRemovedCallback = C_PingSecure.SetPingPinFrameRemovedCallback or callbackSetter("pinRemoved")
    C_PingSecure.SetPingPinFrameScreenClampStateUpdatedCallback = C_PingSecure.SetPingPinFrameScreenClampStateUpdatedCallback or callbackSetter("pinClamp")
    C_PingSecure.SetPingRadialWheelCreatedCallback = C_PingSecure.SetPingRadialWheelCreatedCallback or callbackSetter("wheelCreated")
    C_PingSecure.SetSendMacroPingCallback = C_PingSecure.SetSendMacroPingCallback or callbackSetter("sendMacro")
    C_PingSecure.SetTogglePingListenerCallback = C_PingSecure.SetTogglePingListenerCallback or callbackSetter("toggleListener")
    if type(C_PingSecure.CreateFrame) ~= "function" then
        function C_PingSecure.CreateFrame()
            local callback = Secure.callbacks.wheelCreated
            if callback then callback(WorldFrame or UIParent) end
            return true
        end
    end
    if type(C_PingSecure.ClearHitTestPingInfo) ~= "function" then
        function C_PingSecure.ClearHitTestPingInfo() Secure.hit = nil end
    end
    if type(C_PingSecure.SetHitTestPingTarget) ~= "function" then
        function C_PingSecure.SetHitTestPingTarget()
            if not RP.pick_cursor then return Enum.PingSetTargetState.Failed end
            local x, y, z, guidLow, guidHigh = RP.pick_cursor()
            if not x then return Enum.PingSetTargetState.Failed end
            Secure.hit = { x=x, y=y, z=z, guidLow=guidLow, guidHigh=guidHigh }
            return Enum.PingSetTargetState.Ok
        end
    end
    if type(C_PingSecure.SendHitTestPing) ~= "function" then
        function C_PingSecure.SendHitTestPing(pingType) return sendPicked(pingType) end
    end
    if type(C_PingSecure.SetHitTestTargetAndSendPing) ~= "function" then
        function C_PingSecure.SetHitTestTargetAndSendPing()
            local state = C_PingSecure.SetHitTestPingTarget()
            if state ~= Enum.PingSetTargetState.Ok then return result(false) end
            return sendPicked(Enum.PingSubjectType.Warning)
        end
    end
    if type(C_PingSecure.GetTargetPingReceiver) ~= "function" then
        function C_PingSecure.GetTargetPingReceiver() return nil end
    end
    if type(C_PingSecure.DisplayError) ~= "function" then
        function C_PingSecure.DisplayError(message)
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage(message or "Unable to ping that target", 1, 0.1, 0.1)
            end
        end
    end
    local function unsupportedPing() return result(false) end
    C_PingSecure.SendPlayerItemPing = C_PingSecure.SendPlayerItemPing or unsupportedPing
    C_PingSecure.SendPlayerSpellCategoryPing = C_PingSecure.SendPlayerSpellCategoryPing or unsupportedPing
    C_PingSecure.SendPlayerSpellPing = C_PingSecure.SendPlayerSpellPing or unsupportedPing
    C_PingSecure.SendUnitPing = C_PingSecure.SendUnitPing or unsupportedPing
end
)lua";
}

namespace wxl_radial_ping
{
    bool InstallRadialPing()
    {
        const WXL_FrameScriptApi* api = FrameScript();
        if (!api) return false;

        bool ok = true;
        ok &= api->RegisterFunction("_WXLWOW_RADIAL_PICK_CURSOR", &LuaPickCursor) != 0;
        ok &= api->RegisterFunction("_WXLWOW_RADIAL_WORLD_TO_SCREEN", &LuaWorldToScreen) != 0;
        ok &= api->RegisterFunction("_WXLWOW_RADIAL_UNIT_POSITION", &LuaUnitPosition) != 0;
        ok &= api->RegisterFunction("_WXLWOW_RADIAL_SEND_SERVER", &LuaSendServerPing) != 0;
        ok &= api->RegisterFunction("_WXLWOW_RADIAL_POP_SERVER", &LuaPopServerPing) != 0;
        ok &= Network()->RegisterClientOpcode(
            kCmsgRadialPing, "CMSG_WXL_RADIAL_PING") != 0;
        ok &= Network()->RegisterServerOpcode(
            kSmsgRadialPing, "SMSG_WXL_RADIAL_PING",
            &OnServerPing, nullptr) != 0;
        ok &= api->RegisterScript("radial-ping", kBootstrap) != 0;
        if (ok)
            WLOG_INFO("native cursor pick, authoritative ping transport, unit tracking, and world projection bridge registered");
        return ok;
    }
}
