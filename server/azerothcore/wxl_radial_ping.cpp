/* WarcraftXL radial ping relay for AzerothCore. */

#include "Group.h"
#include "GroupReference.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Timer.h"
#include "Unit.h"
#include "WorldPacket.h"
#include "WorldSession.h"

#include <cmath>
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>

namespace
{
    constexpr uint16 WXL_CMSG_RADIAL_PING = 0x0521;
    constexpr uint16 WXL_SMSG_RADIAL_PING = 0x0522;
    constexpr std::size_t WXL_FIXED_REQUEST_SIZE = 37;
    constexpr std::size_t WXL_MAX_UNIT_NAME = 64;
    constexpr uint32 WXL_RATE_LIMIT_MS = 1000;

    std::mutex g_rateMutex;
    std::unordered_map<WorldSession*, uint32> g_lastPing;

    bool ReadSizedString(ByteBuffer& payload, std::string& value, std::size_t maxLength)
    {
        if (payload.rpos() + sizeof(uint32) > payload.size())
            return false;
        uint32 length = 0;
        payload >> length;
        if (length > maxLength || payload.rpos() + length > payload.size())
            return false;
        value.resize(length);
        if (length)
            payload.read(reinterpret_cast<uint8*>(&value[0]), length);
        return true;
    }

    void AppendSizedString(ByteBuffer& payload, std::string const& value)
    {
        payload << uint32(value.size());
        if (!value.empty())
            payload.append(reinterpret_cast<uint8 const*>(value.data()), value.size());
    }

    bool PassRateLimit(WorldSession* session)
    {
        uint32 const now = getMSTime();
        std::lock_guard<std::mutex> lock(g_rateMutex);
        uint32& previous = g_lastPing[session];
        if (previous && getMSTimeDiff(previous, now) < WXL_RATE_LIMIT_MS)
            return false;
        previous = now;
        return true;
    }

    void HandleRadialPing(WorldSession* session, WorldPacket& payload)
    {
        Player* sender = session ? session->GetPlayer() : nullptr;
        if (!sender || !sender->IsInWorld() || payload.size() < WXL_FIXED_REQUEST_SIZE ||
            payload.size() > WXL_FIXED_REQUEST_SIZE + WXL_MAX_UNIT_NAME || !PassRateLimit(session))
            return;

        uint8 type = 0;
        double x = 0.0, y = 0.0, z = 0.0;
        uint32 guidLow = 0, guidHigh = 0;
        std::string unitName;
        payload >> type >> x >> y >> z >> guidLow >> guidHigh;
        if (type > 3 || !std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z) ||
            std::abs(x) > 1000000.0 || std::abs(y) > 1000000.0 || std::abs(z) > 1000000.0 ||
            !ReadSizedString(payload, unitName, WXL_MAX_UNIT_NAME) || payload.rpos() != payload.size())
            return;

        for (char& character : unitName)
            if (static_cast<unsigned char>(character) < 0x20 || character == ':')
                character = ' ';

        // Cursor/terrain coordinates originate at the client because the server has no camera.
        // Unit pings are different: resolve their GUID against the sender's current map and replace
        // the guessed hit point with the authoritative object origin. Clients retain the GUID and
        // follow the live unit locally between packets.
        uint64 const rawGuid = uint64(guidLow) | (uint64(guidHigh) << 32);
        if (rawGuid)
        {
            ObjectGuid const guid(rawGuid);
            Unit* unit = guid.IsUnit() ? ObjectAccessor::GetUnit(*sender, guid) : nullptr;
            if (unit && unit->IsInWorld() && unit->GetMapId() == sender->GetMapId())
            {
                x = unit->GetPositionX();
                y = unit->GetPositionY();
                z = unit->GetPositionZ();
                unitName = unit->GetName();
                if (unitName.size() > WXL_MAX_UNIT_NAME)
                    unitName.resize(WXL_MAX_UNIT_NAME);
            }
            else
            {
                // Never let a forged/stale GUID turn a fixed ground ping into a client attachment.
                guidLow = 0;
                guidHigh = 0;
                unitName.clear();
            }
        }

        Group* group = sender->GetGroup();
        if (!group)
            return;

        std::string const senderName = sender->GetName();
        WorldPacket response(WXL_SMSG_RADIAL_PING, 41 + unitName.size() + senderName.size());
        response << type << x << y << z << guidLow << guidHigh;
        AppendSizedString(response, unitName);
        AppendSizedString(response, senderName);

        for (GroupReference* itr = group->GetFirstMember(); itr; itr = itr->next())
        {
            Player* member = itr->GetSource();
            if (!member || !member->IsInWorld() ||
                member->GetMapId() != sender->GetMapId() || !member->GetSession())
                continue;
            member->GetSession()->SendPacket(&response);
        }
    }

    class wxl_radial_ping_player_script final : public PlayerScript
    {
    public:
        wxl_radial_ping_player_script()
            : PlayerScript("wxl_radial_ping_player_script", {PLAYERHOOK_ON_LOGOUT}) { }

        void OnPlayerLogout(Player* player) override
        {
            WorldSession* session = player ? player->GetSession() : nullptr;
            if (!session)
                return;
            std::lock_guard<std::mutex> lock(g_rateMutex);
            g_lastPing.erase(session);
        }
    };

    class wxl_radial_ping_server_script final : public ServerScript
    {
    public:
        wxl_radial_ping_server_script()
            : ServerScript("wxl_radial_ping_server_script", {SERVERHOOK_CAN_PACKET_RECEIVE}) { }

        bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override
        {
            if (packet.GetOpcode() != WXL_CMSG_RADIAL_PING)
                return true;
            HandleRadialPing(session, packet);
            return false;
        }
    };
}

void AddSC_wxl_radial_ping()
{
    new wxl_radial_ping_server_script();
    new wxl_radial_ping_player_script();
}
