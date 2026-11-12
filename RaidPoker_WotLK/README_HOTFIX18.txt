EpokerWoW Raid 1.8.0 RC1 - Hotfix 18 (Multiplayer Safety & Raid Visibility)

INSTALL: Replace Interface/AddOns/RaidPoker_WotLK with the full folder in this archive. Back up your previous folder and SavedVariables. ALL RAID PLAYERS MUST INSTALL THIS SAME VERSION. Restart WoW.

CHANGES
- Both modes: Player Management shows addon-detected raid members not seated at the table.
- Both modes: available tables highlighted; Hold'em has selectable open-table entries.
- Both modes: Close Solo button with dice icon below Poker Table.
- Both modes: joining or creating a real table clears a previous Solo Debug session.
- Hold'em: network lobby automatically switches to NETWORK and clears local bots/preview.
- Hold'em: Solo Debug actions blocked during multiplayer.
- Hold'em: only own private cards displayed; opponent seats show face-down cards.
- Hold'em: host seating updates are mirrored to clients, including idle lobby with 0 or 1 seat.
- Hold'em: public sync includes sitting-out flag, current bet, minimum raise and payouts.
- Hold'em: lobby membership refreshed on join; stale private cards and session state cleared.
- Hold'em: open-table status and occupied seats broadcast on discovery.
- Addon TOC version bumped to 1.8.0-RC1-HF18.

LIMITATIONS / TESTING
- Lua syntax checked, ZIP CRC checked; no live WoW 3.3.5a or two-client test.
- The host necessarily stores all hole cards in the game engine; only its own cards should render.
- Network packet delivery, ordering and multi-client state convergence require testing.
- Do not use real stakes until card privacy and synchronization are verified with two clients.
