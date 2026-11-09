-- The Barrens Hold'em beta4c7: adapter for the EXISTING Poker Table 7.0.
-- No duplicate table. Lua 5.1 / WoW 3.3.5a.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local U={mode='SOLO'}
R.HoldemUnified=U
local function network() return R.HoldemNetwork end
local function host() local n=network();return n and n.active and n.owner and n.host==UnitName('player') end
local function mode() return U.mode=='NETWORK' and 'NETWORK' or 'SOLO' end
R.BarrensUnifiedMode=mode
function U.SetMode(m)
 m=string.upper(tostring(m or ''))
 if m~='SOLO' and m~='NETWORK' then return false,'Use SOLO or NETWORK' end
 if H.phase~='LOBBY' and H.phase~='SHOWDOWN' then return false,'Finish the active hand before changing mode' end
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
  if m and m.active then return H.GetPublicSnapshot() end
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
 if mode()=='SOLO' then return H.Action(action,amount) end
 local n=network()
 if not n or not n.active then return false,'Create or join a network lobby first' end
 if n.owner and not host() then return false,'Game Master ownership mismatch' end
 local s=R.BarrensUnifiedSnapshot()
 local p=s.players and s.players[s.actionSeat or 0]
 if not p or p.name~=UnitName('player') then return false,'Wait for your turn' end
 if host() then
  if not R.HoldemMultiplayer or not R.HoldemMultiplayer.active then return false,'No active network hand' end
  return H.Action(action,amount)
 end
 local proto=R.HoldemProtocol
 if not proto or not proto.SendAction then return false,'Network protocol unavailable' end
 local sent,why=proto.SendAction(action,amount)
 if sent==false then return false,why or 'Network action rejected' end
 return true
end
function R.BarrensUnifiedStart()
 if mode()=='SOLO' then return H.StartPreviewHand() end
 local m=R.HoldemMultiplayer
 if not m then return false,'Multiplayer module unavailable' end
 return m.StartHand()
end
function R.BarrensUnifiedReset()
 if mode()=='SOLO' then H.ResetPreview() else
  if R.Print then R.Print('Network hand reset is not available; use Game Master controls.') end
 end
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
