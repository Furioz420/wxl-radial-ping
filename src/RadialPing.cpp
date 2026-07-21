// WarcraftXL radial ping client module.
// Copyright (C) 2026 WarcraftXL. GPLv3 (see repository license).

#include "RadialPingLua.hpp"

#include "events/Event.hpp"
#include "runtime/LuaBindings.hpp"
#include "runtime/ModuleInstall.hpp"
#include "wxl-client-extensions/src/Network.hpp"

#include <windows.h>

#include <atomic>
#include <cstdio>
#include <string>

namespace wxl::scripts::radialping
{
    namespace
    {
        std::atomic<uint32_t> g_hotkeyVk{0};
        std::atomic<bool> g_hotkeyDown{false};
        std::atomic<bool> g_inputEnabled{true};
        bool g_captureDecision = false; // main UI thread only, set synchronously from ExecuteCurrent

        int __cdecl SetHotkeyVk(void* state)
        {
            uint32_t vk = 0;
            if (wxl::runtime::lua::GetTop(state) >= 1 &&
                wxl::runtime::lua::IsNumber(state, 1))
            {
                const double value = wxl::runtime::lua::ToNumber(state, 1);
                if (value >= 0.0 && value <= 255.0)
                    vk = static_cast<uint32_t>(value);
            }
            g_hotkeyVk.store(vk, std::memory_order_relaxed);
            return 0;
        }

        int __cdecl SetInputEnabled(void* state)
        {
            const bool enabled = wxl::runtime::lua::GetTop(state) >= 1 &&
                wxl::runtime::lua::ToNumber(state, 1) != 0.0;
            g_inputEnabled.store(enabled, std::memory_order_relaxed);
            return 0;
        }

        int __cdecl SetInputCapture(void* state)
        {
            g_captureDecision = wxl::runtime::lua::GetTop(state) >= 1 &&
                wxl::runtime::lua::ToNumber(state, 1) != 0.0;
            return 0;
        }

        void OnInput(void*, const void* rawArgs)
        {
            auto const* args = static_cast<wxl::events::InputArgs const*>(rawArgs);
            if (!args || !args->handled)
                return;

            const bool down = args->message == WM_KEYDOWN || args->message == WM_SYSKEYDOWN;
            const bool up = args->message == WM_KEYUP || args->message == WM_SYSKEYUP;
            if (!down && !up)
                return;

            const uint32_t configured = g_hotkeyVk.load(std::memory_order_relaxed);
            if (!configured || !g_inputEnabled.load(std::memory_order_relaxed) ||
                static_cast<uint32_t>(args->wparam) != configured)
                return;

            if (down)
            {
                if (g_hotkeyDown.load(std::memory_order_relaxed))
                {
                    *args->handled = true;
                    return;
                }
                g_captureDecision = false;
                wxl::runtime::lua::ExecuteCurrent("wxl-radial-ping-key-down",
                    "if (not GetCurrentKeyBoardFocus or not GetCurrentKeyBoardFocus()) and "
                    "RadialPing_OnBinding then SetRadialPingInputCapture(1); "
                    "RadialPing_OnBinding('down') end");
                if (g_captureDecision)
                    g_hotkeyDown.store(true, std::memory_order_relaxed);
            }
            else if (g_hotkeyDown.exchange(false, std::memory_order_relaxed))
            {
                g_captureDecision = true;
                wxl::runtime::lua::ExecuteCurrent("wxl-radial-ping-key-up",
                    "if RadialPing_OnBinding then RadialPing_OnBinding('up') end");
            }

            if (g_captureDecision)
                *args->handled = true;
        }

        void InstallModule()
        {
            using namespace wxl::runtime;
            lua::RegisterCVar("wxlRadialPingEnabled", "1");
            lua::RegisterCVar("wxlRadialPingSounds", "1");
            lua::RegisterCVar("wxlRadialPingChat", "0");
            lua::RegisterCVar("wxlRadialPingMode", "direct");
            lua::RegisterCVar("wxlRadialPingKey", "G");
            lua::RegisterFunction("SetRadialPingHotkeyVK", &SetHotkeyVk);
            lua::RegisterFunction("SetRadialPingInputEnabled", &SetInputEnabled);
            lua::RegisterFunction("SetRadialPingInputCapture", &SetInputCapture);

            std::string source;
            for (std::size_t index = 0; index < generated::kLuaChunkCount; ++index)
                source += generated::kLuaChunks[index];
            lua::RegisterScript("wxl-radial-ping", source.c_str());
            wxl::events::Subscribe(wxl::events::Event::OnInput, &OnInput, nullptr);
        }

        struct Registrar
        {
            Registrar()
            {
                client_extensions::network::RegisterClientOpcode(
                    0x0520, "CMSG_WXL_RADIAL_PING");
                client_extensions::network::RegisterServerOpcode(
                    0x0104, "SMSG_WXL_RADIAL_PING");
                wxl::runtime::modules::Register("wxl-radial-ping", &InstallModule);
            }
        } g_registrar;
    }
}
