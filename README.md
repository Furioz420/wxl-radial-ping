# wxl-radial-ping

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
This repository contains the WarcraftXL/AzerothCore adaptation.

## License

GPL-3.0-or-later. See `LICENSE`.
