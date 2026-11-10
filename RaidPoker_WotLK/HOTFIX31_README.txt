EpokerWoW Raid RC1 - Hotfix 31: Five-Card Exchange Notification

For World of Warcraft 3.3.5a / TrinityCore.
Based on Hotfix 30 FULL.

Ironforge 5-Card Poker only:
- Gold notification inside the main Poker Table card area, above cards.
- Shows only when the local player has the active DRAW turn.
- Gold border flashes for the first 2 seconds, then remains steady.
- Plays the existing 'Your turn' sound once per draw turn, respecting Poker Sound Options.
- Hides after Exchange / Stand Pat / timeout / phase change.
- No extra countdown. Existing turn timer and auto-Stand-Pat behavior unchanged.
- No separate popup and no new network messages.

Install FULL: extract RaidPoker_WotLK into Interface/AddOns, replacing previous folder.
Install PATCH: copy Game.lua to Interface/AddOns/RaidPoker_WotLK over Hotfix 30.
Both raid participants should run the same version.
