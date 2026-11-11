-- The Barrens Hold'em beta4c3: host-authoritative real-seat management.
-- WotLK 3.3.5a / Lua 5.1. Independent from 5-Card Draw.
local R=RPoker
if not R or not R.Holdem or not R.HoldemNetwork then return end
local H,N=R.Holdem,R.HoldemNetwork
local M={seats={},audit={},initialStack=1000,active=false,hostHand=0}
R.HoldemMultiplayer=M
local frame,roster,summary,amountBox
local function playerName() return UnitName('player') or '' end
local function raidMember(name)
 if not GetNumRaidMembers or GetNumRaidMembers()==0 then return false end
 for i=1,GetNumRaidMembers() do if GetRaidRosterInfo(i)==name then return true end end
 return false
end
local function audit(msg)
 M.audit[#M.audit+1]=date('%H:%M:%S')..' '..msg
 if #M.audit>40 then table.remove(M.audit,1) end
end
local function host()
 return N.active and N.owner and N.host==playerName() and raidMember(playerName())
end
local function waiting() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function eligible(name)
 return type(name)=='string' and #name>0 and N.members[name] and raidMember(name)
end
local function publishSeats()
 if not host() or not waiting() then return end
 -- Publish public seat roster even before the first network hand.
 H.players={}
 for i,seat in ipairs(M.seats) do
  H.players[i]={name=seat.name,stack=seat.stack,street=0,committed=0,folded=false,
   allIn=false,sittingOut=seat.sittingOut,hole={},dealt=false}
 end
 H.phase='LOBBY';H.board={};H.pot=0;H.actionSeat=nil
 if R.HoldemSync and R.HoldemSync.ForceBroadcast then R.HoldemSync.ForceBroadcast() end
 if N.BroadcastTableInfo then N.BroadcastTableInfo() end
end
M.PublishSeats=publishSeats
local function refresh()
 if not frame then return end
 local lines={}
 for i,s in ipairs(M.seats) do
  lines[#lines+1]=i..'. '..s.name..'  '..math.floor(s.stack/100)..'g '..(s.stack%100)..'s'..(s.sittingOut and ' [SITTING OUT]' or (s.stack==0 and ' [BUSTED]' or ' [PLAYING]'))
 end
 roster:SetText(#lines>0 and table.concat(lines,'\n') or 'No assigned seats. Create a network lobby first.')
 summary:SetText('Game Master: '..tostring(N.host or '-')..'  |  '..(host() and 'HOST' or 'READ ONLY')..'  |  '..tostring(H.phase))
end
function M.Assign(name)
 if not host() then return false,'Game Master only' end
 if not waiting() then return false,'Finish the hand first' end
 if not eligible(name) then return false,'Player must join lobby and raid' end
 if name~=playerName() and R.PokerVersionMatches and R.PokerVersionMatches(name)~=true then return false,'Incompatible or unknown addon version: '..name end
 for i,s in ipairs(M.seats) do if s.name==name then return true end end
 if #M.seats>=6 then return false,'Table full (6 seats)' end
 local stack=math.max(0,math.floor(tonumber(M.initialStack) or 0))
 M.seats[#M.seats+1]={name=name,stack=stack,sittingOut=false}
 audit('SEAT '..name..(stack==0 and ' [BUSTED]' or ''))
 publishSeats();refresh();return true
end
function M.Remove(name)
 if not host() or not waiting() then return false,'Game Master / idle hand required' end
 for i,s in ipairs(M.seats) do if s.name==name then table.remove(M.seats,i);audit('REMOVE '..name);publishSeats();refresh();return true end end
 return false,'Player not seated'
end
-- Preserve seat indices until showdown; never splice H.players mid-hand.
function M.Depart(name)
 if not host() then return false,'Game Master only' end
 if waiting() then return M.Remove(name) end
 local found=false
 for _,s in ipairs(M.seats) do
  if s.name==name then s.sittingOut=true;s.departed=true;found=true;break end
 end
 if not found then return false,'Player not seated' end
 if H.ForceFoldDeparting then H.ForceFoldDeparting(name) end
 audit('LEAVE '..name..' (fold, pending seat release)')
 if H.phase=='SHOWDOWN' then M.AfterAction() end
 refresh()
 return true
end
function M.SetStack(name,silver)
 if not host() or not waiting() then return false,'Game Master / idle hand required' end
 silver=tonumber(silver)
 if not silver or silver<0 or silver>100000000 or silver~=math.floor(silver) then return false,'Invalid silver balance' end
 for _,s in ipairs(M.seats) do if s.name==name then
  local previous=s.stack;s.stack=silver
  audit('BALANCE '..name..' '..silver..'s'..(silver==0 and ' [BUSTED]' or (previous==0 and silver>0 and not s.sittingOut and ' [PLAYING]' or '')))
  publishSeats();refresh();return true
 end end
 return false,'Player not seated'
end
function M.SitOut(name,value)
 if not host() or not waiting() then return false,'Game Master / idle hand required' end
 for _,s in ipairs(M.seats) do if s.name==name then s.sittingOut=value and true or false;audit((value and 'SIT OUT ' or 'SIT IN ')..name);publishSeats();refresh();return true end end
 return false,'Player not seated'
end
function M.AutoSeat()
 if not host() then return false,'Game Master only' end
 local names={}
 for name in pairs(N.members) do if eligible(name) then names[#names+1]=name end end
 table.sort(names)
 for _,name in ipairs(names) do if #M.seats<6 then M.Assign(name) end end
 refresh();return true
end
function M.StartHand()
 if not host() then return false,'Game Master only' end
 if not waiting() then return false,'Hand already running' end
 if #M.seats<2 then return false,'At least two seated players required' end
 local funded=0
 for _,s in ipairs(M.seats) do if not s.sittingOut and s.stack>0 and eligible(s.name) then funded=funded+1 end end
 if funded<2 then return false,'At least two active raid members required' end
 -- Reject known incompatible clients; do not silently play with mismatched protocols.
 if R.PokerVersionMatches then
  for _,seat in ipairs(M.seats) do
   if not seat.sittingOut and seat.stack>0 and eligible(seat.name) then
    local match=R.PokerVersionMatches(seat.name)
    if match~=true then return false,'Incompatible or unknown addon version: '..seat.name end
   end
  end
 end
 -- Engine must retain its own stacks and hand count between hands.
 H.players={}
 for i,s in ipairs(M.seats) do
  H.players[i]={name=s.name,stack=s.stack,hole={},committed=0,street=0,folded=false,allIn=false,
   sittingOut=s.sittingOut or not eligible(s.name),dealt=false,done=false,raiseAllowed=true}
 end
 local ok,err=H.StartPreviewHand()
 if not ok then return false,err end
 M.active=true;M.hostHand=H.handNumber
 audit('START HAND '..H.handNumber)
 if R.HoldemProtocol and R.HoldemProtocol.DealPrivateToJoined then R.HoldemProtocol.DealPrivateToJoined() end
 refresh();return true
end
function M.AfterAction()
 if not M.active or not host() then return end
 for i,p in ipairs(H.players) do
  if M.seats[i] and M.seats[i].name==p.name then
   local previous=M.seats[i].stack
   M.seats[i].stack=math.max(0,tonumber(p.stack) or 0)
   -- Zero chips during an all-in never ejects a player from the current hand.
   if H.phase=='SHOWDOWN' and previous>0 and M.seats[i].stack==0 then audit('BUSTED '..p.name) end
  end
 end
 if H.phase=='SHOWDOWN' then
  M.active=false;audit('SHOWDOWN HAND '..H.handNumber)
  local removed=false
  for i=#M.seats,1,-1 do
   if M.seats[i].departed then table.remove(M.seats,i);removed=true end
  end
  if removed then publishSeats() end
 end
 refresh()
end
local function message(ok,why)
 if not ok then R.Print('Barrens Multiplayer: '..tostring(why)) end
end
local function label(x,y,w,text)
 local t=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');t:SetPoint('TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetText(text or '');return t
end
local function button(text,x,y,w,fn)
 local b=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate');b:SetSize(w,24);b:SetPoint('TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',fn);return b
end
local function build()
 if frame then return end
 frame=CreateFrame('Frame','RaidPokerBarrensMultiplayer',UIParent)
 frame:SetSize(540,480);frame:SetPoint('CENTER');frame:SetFrameStrata('DIALOG');frame:SetMovable(true);frame:EnableMouse(true)
 frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true)
 frame:SetScript('OnDragStart',function(self)self:StartMoving()end)
 frame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 frame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 label(20,-20,470,"THE BARRENS HOLD'EM - MULTIPLAYER SEATS")
 summary=label(20,-55,490,'')
 button('Auto Seat Joined',20,-88,138,function()local ok,err=M.AutoSeat();message(ok,err)end)
 button('Start Network Hand',168,-88,170,function()local ok,err=M.StartHand();message(ok,err)end)
 button('Refresh',348,-88,85,refresh)
 button('X',486,-18,30,function()frame:Hide()end)
 roster=label(20,-138,480,'')
 label(20,-365,480,'Balances are virtual Silver. Edit seats between hands only.')
 label(20,-390,480,'Solo Debug and 5-Card Draw remain separate.')
 button('Network Lobby',20,-423,130,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button('Protocol Debug',160,-423,130,function()if R.OpenHoldemProtocolDebug then R.OpenHoldemProtocolDebug()end end)
 button('Sync Viewer',300,-423,120,function()if R.OpenBarrensSyncViewer then R.OpenBarrensSyncViewer()end end)
 frame:Hide()
end
function R.OpenBarrensMultiplayer() build();refresh();frame:Show();frame:Raise() end
local prev=SlashCmdList and SlashCmdList.RAIDFIVEPOKER
if prev then SlashCmdList.RAIDFIVEPOKER=function(input)
 local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
 if cmd=='holdemmulti' or cmd=='holdemseats' then R.OpenBarrensMultiplayer() else prev(input) end
end end
SLASH_BARRNSMULTI1='/holdemmulti'
SlashCmdList.BARRNSMULTI=function()R.OpenBarrensMultiplayer()end
-- Mirror successful engine actions into host-owned balances; never modify Draw balances.
local originalAction=H.Action
H.Action=function(action,amount)
 local ok,err=originalAction(action,amount)
 if ok then M.AfterAction() end
 return ok,err
end
