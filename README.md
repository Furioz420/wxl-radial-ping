# wxl-radial-ping

[Build compatibility and release gate](BUILDING.md)

Retail-style party and raid pings for WarcraftXL ABI 1.1.

The native extension provides cursor-to-world picking, interpolated model-position tracking,
world-to-UI projection, and the ping-specific `C_Ping` bridge. The addon owns the wheel and
presentation; the server validates and relays pings to eligible group members on the same map.

## Protocol

- `0x0521`: client radial-ping request;
- `0x0522`: server radial-ping relay.

The current AzerothCore reference is in `server/azerothcore/wxl_radial_ping.cpp`. It rate-limits
requests, validates positions and unit GUIDs, and relays accepted pings only to online members of
the sender's group on the same map.

## Client data

The addon is under `client/Interface/AddOns/RadialPing`. Interface textures remain under `assets/`
with their client virtual paths. These files are reviewed and deployed through the client-data
pipeline; they are not part of the Hub extension ZIP.

The Hub release contains only:

- `wxl-radial-ping.dll`;
- `wxl-radial-ping.cfg`.

## Requirements

- WarcraftXL Core ABI 1.1 with FrameScript and network services;
- `wxl-runtime` 1.1.0 or newer;
- the matching server and client-data prerequisites above.

Set `WXL_RADIAL_PING=0` in `wxl-radial-ping.cfg` to disable the native extension.

## Attribution

The client engine bindings and WarcraftXL integration build on work by the WarcraftXL contributors.
The base Radial Ping addon work is credited to Duskhaven and its contributors, including Tester.
This repository contains the WarcraftXL/AzerothCore adaptation. Furioz is credited for the local v1.1 integration commits; preserve original addon and asset notices.

## License

GPL-3.0-or-later. See `LICENSE`.

## Integration and release checks

Build the Win32 DLL against the matching core and Runtime 1.1 APIs. The repository release workflow packages the DLL and config only; server relay code and interface art/Lua are separate client/server deployments. The integrated Eunoia client has a built-in `FrameXML/FrameNew/WarcraftXL/RadialPing` path, while this repository still documents its addon payload. Select one UI loading route and retire the duplicate addon before a coordinated release.

With the matching server installed, send a party ping and verify the wheel, world projection, relay, and rate-limit behavior. Test a different map and an ineligible recipient as negative cases; inspect client and server logs. Keep prior DLL/config, server integration, and client assets for rollback. The build pins the core revision in [BUILDING.md](BUILDING.md); publish a release tag only after the client/server route passes.
