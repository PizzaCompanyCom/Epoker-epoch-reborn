-- The Barrens Hold'em beta4c7: adapter for the EXISTING Poker Table 7.0.
-- No duplicate table. Lua 5.1 / WoW 3.3.5a.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local U={mode='SOLO'}
-- Network mode is selected automatically by the lobby. Preview bots are never network seats.
R.HoldemUnified=U
local function network() return R.HoldemNetwork end
local function host() local n=network();return n and n.active and n.owner and n.host==UnitName('player') end
local function mode() return U.mode=='NETWORK' and 'NETWORK' or 'SOLO' end
R.BarrensUnifiedMode=mode
function U.SetMode(m)
 m=string.upper(tostring(m or ''))
 if m~='SOLO' and m~='NETWORK' then return false,'Use SOLO or NETWORK' end
 if m=='SOLO' and H.phase~='LOBBY' and H.phase~='SHOWDOWN' then return false,'Finish the active hand before changing mode' end
 if m=='NETWORK' and U.mode~='NETWORK' then
  if R.HoldemSoloDebug and R.HoldemSoloDebug.StopForNetwork then R.HoldemSoloDebug.StopForNetwork() end
  -- Do not leave preview bots or an unfinished solo hand in the network engine.
  H.phase='LOBBY';H.players={};H.board={};H.deck={};H.pot=0;H.actionSeat=nil
  H.winners={};H.sidePots={};H.handNumber=0;H.log={}
  if R.HoldemMultiplayer then R.HoldemMultiplayer.active=false;R.HoldemMultiplayer.seats={} end
  if R.HoldemProtocol then R.HoldemProtocol.privateCards={};R.HoldemProtocol.privateHand=nil end
 end
 U.mode=m
 if R.Print then R.Print('Barrens Table 7.0 mode: '..m) end
 U.Refresh()
 return true
end
function R.BarrensUnifiedSnapshot()
 if mode()=='SOLO' then return H.GetPublicSnapshot() end
 local n=network()
 if not n or not n.active then return {handNumber=0,phase='LOBBY',players={},board={},pot=0,winners={},log={}} end
 if host() then
  local m=R.HoldemMultiplayer
  if m and (m.active or #m.seats>0) then return H.GetPublicSnapshot() end
  return {handNumber=0,phase='LOBBY',players={},board={},pot=0,winners={},log={}}
 end
 local s=R.HoldemSync and R.HoldemSync.remote
 if not s then return {handNumber=0,phase='LOBBY',players={},board={},pot=0,winners={},log={}} end
 -- Never enrich public remote state with host private cards.
 return s
end
function R.BarrensUnifiedHole(seat,s)
 if mode()=='SOLO' then return H.players[seat] and H.players[seat].hole end
 local n=network()
 if not n or not n.active then return nil end
 local p=s and s.players and s.players[seat]
 if not p or p.name~=UnitName('player') then return nil end
 if host() then return H.players[seat] and H.players[seat].hole end
 local proto=R.HoldemProtocol
 if proto and proto.privateHand==s.handNumber then return proto.privateCards end
 return nil
end
function R.BarrensUnifiedAction(action,amount)
 -- The UI always supplies the raise field, even for Check/Call/Fold/All-In.
 -- The multiplayer protocol requires zero for every non-raise action.
 if action~='RAISE' then amount=0 end
 if mode()=='SOLO' then return H.Action(action,amount) end
 local n=network()
 if not n or not n.active then return false,'Create or join a network lobby first' end
 if n.owner and not host() then return false,'Game Master ownership mismatch' end
 local s=R.BarrensUnifiedSnapshot()
 local p=s.players and s.players[s.actionSeat or 0]
 if not p or p.name~=UnitName('player') then return false,'Wait for your turn' end
 if host() then
  if not R.HoldemMultiplayer or not R.HoldemMultiplayer.active then return false,'No active network hand' end
  local ok,why=H.Action(action,amount)
  if ok and R.HoldemSync and R.HoldemSync.ForceBroadcast then R.HoldemSync.ForceBroadcast() end
  return ok,why
 end
 local proto=R.HoldemProtocol
 if not proto or not proto.SendAction then return false,'Network protocol unavailable' end
 local sent,why=proto.SendAction(action,amount)
 if sent==false then return false,why or 'Network action rejected' end
 return true
end
function R.BarrensUnifiedStart()
 if mode()=='SOLO' then
  if not (R.HoldemSoloDebug and R.HoldemSoloDebug.active) then return false,'Open Solo Debug to start a local game.' end
  return H.StartPreviewHand()
 end
 local m=R.HoldemMultiplayer
 if not m then return false,'Multiplayer module unavailable' end
 return m.StartHand()
end
function R.BarrensUnifiedReset()
 if mode()=='SOLO' then H.ResetPreview() else
  if R.Print then R.Print('Network hand reset is not available; use Game Master controls.') end
 end
end
function R.BarrensCloseSoloGame()
 if mode()~='SOLO' then return false,'Leave the multiplayer table before closing Solo Debug' end
 if R.HoldemSoloDebug then R.HoldemSoloDebug.auto=false;R.HoldemSoloDebug.active=false end
 H.phase='LOBBY';H.players={};H.board={};H.deck={};H.pot=0;H.actionSeat=nil
 H.handNumber=0;H.dealer=0;H.smallBlindSeat=nil;H.bigBlindSeat=nil
 H.currentBet=0;H.minRaise=H.bigBlind or 10
 H.winners={};H.sidePots={};H.log={}
 if R.BarrensClearSoloTableVisuals then R.BarrensClearSoloTableVisuals() end
 U.Refresh()
 return true
end
function U.Refresh()
 if R.RefreshBarrensUnifiedTable then R.RefreshBarrensUnifiedTable() end
 if R.RefreshBarrensUnifiedControls then R.RefreshBarrensUnifiedControls() end
end
-- A read-only refresh ticker: existing renderer handles its own animation.
local tick=CreateFrame('Frame')
local elapsed=0
tick:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt
 if elapsed>=0.5 then elapsed=0;U.Refresh() end
end)
SLASH_BARRNUNIFIED1='/holdemunified'
SlashCmdList.BARRNUNIFIED=function(input)
 local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
 if cmd=='network' or cmd=='multi' then U.SetMode('NETWORK')
 elseif cmd=='solo' or cmd=='debug' then U.SetMode('SOLO')
 else if R.Print then R.Print('Usage: /holdemunified network OR /holdemunified solo') end end
 if R.OpenBarrensTable then R.OpenBarrensTable() end
end
