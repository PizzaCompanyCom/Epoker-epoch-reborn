-- Barrens Hold'em: dialog layering, WoW 3.3.5a / Lua 5.1.
-- Loaded after all other Hold'em modules. Does not change 5-Card Draw.
local names = {
 'RaidPokerBarrensControlCenter',
 'RaidPokerBarrensPreflight',
 'RaidPokerBarrensTableDesk',
 'RaidPokerBarrensGMTransfer',
 'RaidPokerBarrensSessionRecovery',
 'RaidPokerBarrensTableThemePicker',
 'RaidPokerBarrensManagement',
 'RaidPokerBarrensMultiplayer',
 'RaidPokerBarrensNetworkLobby',
 'RaidPokerHoldemProtocolDebug',
 'RaidPokerBarrensSyncViewer',
 'RaidPokerBarrensSoloDebug',
 'RaidPokerBarrensNetworkTable',
 'RaidPokerBarrensVisualNetwork',
 'RaidPokerBarrensOperations',
 'RaidPokerBarrensExport',
 'RaidPokerBarrensRecordsWindow',
 'RaidPokerBarrensSeatInspector',
 'RaidPokerBarrensStatistics',
 'RaidPokerBarrensBettingActivity',
 'RaidPokerBarrensThemeSettings',
 'RaidPokerBarrensGuide',
}
local registered = {}
local function elevate(f)
 if not f then return end
 -- Both primary windows stay on DIALOG. Auxiliary windows sit above them.
 f:SetFrameStrata('FULLSCREEN_DIALOG')
 if f.Raise then f:Raise() end
end
local function register(name)
 if registered[name] then return end
 local f = _G[name]
 if not f or not f.HookScript then return end
 registered[name] = true
 f:HookScript('OnShow', function(self) elevate(self) end)
 if f:IsShown() then elevate(f) end
end
local watcher = CreateFrame('Frame')
local elapsed = 0
watcher:SetScript('OnUpdate', function(self, dt)
 elapsed = elapsed + dt
 if elapsed < 1 then return end
 elapsed = 0
 for i=1,#names do register(names[i]) end
end)
-- Register already constructed windows immediately as well.
for i=1,#names do register(names[i]) end
