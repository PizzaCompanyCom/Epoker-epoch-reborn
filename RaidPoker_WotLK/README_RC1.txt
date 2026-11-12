Raid Poker WotLK v1.8.0 RC1 - Full Installation
=================================================
Target: World of Warcraft 3.3.5a / TrinityCore (Interface 30300)
Status: RELEASE CANDIDATE FOR IN-GAME TESTING, not verified stable.

INSTALL:
1. Back up the old Interface/AddOns/RaidPoker_WotLK folder and its SavedVariables.
2. Remove the old RaidPoker_WotLK addon folder to avoid stale Lua files.
3. Extract this ZIP into World of Warcraft/Interface/AddOns/.
4. Confirm RaidPoker_WotLK/RaidPoker_WotLK.toc exists and restart the client.

INCLUDED:
- Complete 5-Card Draw addon and its existing card and background artwork.
- The Barrens Hold'em: solo mode, network modules, lobby, Game Master,
  player management, preflight, seat management, session recovery,
  consolidated Table Operations, Poker Table and theme settings.
- All previously delivered beta4e5 through beta4e10 Lua overlays.
- RC1 fix: restored 8 Lua modules absent from the old full archive,
  and removed a stray trailing 'end' in HoldemNetworkTable.lua.
- TOC version set to 1.8.0-RC1.

COMMANDS:
 /holdemdesk       Integrated Table Operations
 /holdempreflight  Network hand preflight
 /holdemrecover    Session recovery
 /holdemtransfer   Game Master transfer
 /holdemtable      Network table

VALIDATION:
 - Every .lua file passes Lua syntax parsing (Lua 5.1-compatible syntax check).
 - All Lua entries in the TOC are present.
 - ZIP integrity tested.
NOT VALIDATED:
 - Two-client network gameplay, live WoW API behavior, addon sync correctness,
   hand completion and GM migration under disconnects.
 - Some existing modules may still have runtime or integration errors.
This archive is a candidate for testing, NOT a guaranteed stable release.
