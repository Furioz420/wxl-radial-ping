# WXL Radial Ping

MASSIVE THANKS TO ITHORGRIM FOR THE CLIENT RELATED FUNCTIONS IN WXL.

MASSIVE THANKS TO DUSKHAVEN AND THE AFFILIATED DEVS LIKE TESTER FOR THE BASE ADDON FOR RADIAL PING.

I just did some refining and adjustments to it and reworked it to work with wxl & ac.

Native WarcraftXL port of the former `RadialPing` addon.

- Client settings are archived custom CVars and appear under Interface > WXL > Radial Ping.
- The default hotkey is `G`; it can be changed in that panel.
- CMSG `0x0520` sends pings and SMSG `0x0104` relays them.
- The native opcode integration is under `scripts/wxl-opcodes/server/azerothcore`.
- The server validates and rate-limits each ping, then relays it only to online members of the
  sender's party/raid on the same map.
- Client files required by an MPQ/open patch are under `assets/` with their exact virtual paths.

Install `wxl_radial_ping.cpp`, and install the WXL opcode
registry/integration files. Register the feature loader:
`AddSC_wxl_radial_ping()`
