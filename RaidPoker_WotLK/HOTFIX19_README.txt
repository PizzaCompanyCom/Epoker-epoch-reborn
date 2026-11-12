EpokerWoW Raid RC1 Hotfix 19 - Single Table & Controls

Install the FULL archive on BOTH clients, replacing the old RaidPoker_WotLK folder. Back up SavedVariables first.

Changes: Join Table quick action, Create/Join controls in both Player Management windows, no-table popup, automatic SOLO->NETWORK reset on join, Holdem network re-discovery, chat /Epoker channel, Auto Announce OFF by default for new settings, timer fixes, 3-second action overlays based on public accepted logs.

LIMITATIONS / TEST REQUIRED:
- WoW 3.3.5a Lua syntax checked; not tested in-game or across two clients.
- Single table is enforced per client based on discovery, not as a distributed atomic lock; simultaneous creation or stale discovery can still produce multiple hosts.
- If discovery has not completed, click Join Table again after a few seconds.
- Existing saved Auto Announce preferences are preserved.
- Reconnect/private-card recovery and full network-state convergence still require two-client validation.
- Draw overlay derives from short activity log; Holdem from public log, so rapid actions may be missed.
- The patch does not guarantee resolution of Grey's Poker Table UI failure until tested in-game.
