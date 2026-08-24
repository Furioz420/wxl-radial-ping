#include "ExtensionApi.hpp"

const WXL_PluginInfo* __cdecl WXL_Query(void)
{
    static const WXL_PluginInfo info{
        sizeof(WXL_PluginInfo), WXL_API_VERSION, "wxl-radial-ping", 1, WXL_CLIENT_BUILD,
    };
    return &info;
}

int __cdecl WXL_Load(const WXL_Api* api)
{
    if (!api || api->apiVersion != WXL_API_VERSION) return 0;
    wxl_radial_ping::g_api = api;

    if (!wxl_radial_ping::ConfigBool("WXL_RADIAL_PING", true))
    {
        api->Log(WXL_LOG_INFO, "wxl-radial-ping", "extension disabled by configuration");
        return 1;
    }
    if (!wxl_radial_ping::FrameScript())
    {
        api->Log(WXL_LOG_ERROR, "wxl-radial-ping", "required wxl.framescript v1 is unavailable");
        return 0;
    }
    if (!wxl_radial_ping::Network())
    {
        api->Log(WXL_LOG_ERROR, "wxl-radial-ping", "required wxl.network v1 is unavailable");
        return 0;
    }
    return wxl_radial_ping::InstallRadialPing() ? 1 : 0;
}
