-- The Barrens Hold'em beta4c1: PUBLIC, READ-ONLY raid state mirror.
-- Does NOT transmit hole cards, deck, private state, balances in Draw or real money.
-- This is a staged network transport test, NOT multiplayer betting.
local R=RPoker
if not R then return end
local N=R.HoldemNetwork
local H=R.Holdem
if not N or not H then return end
local PREFIX='RPBH4C'
local S={revision=0,received=0,remote=nil,hostLast=0,remoteSession=nil,remoteHost=nil}
R.HoldemSync=S
local win,headline,boardLabel,seatLabel,foot
local function me() return UnitName('player') or '' end
local function inRaid() return GetNumRaidMembers and GetNumRaidMembers()>0 end
local function raidMember(name)
 if not inRaid() then return false end
 for i=1,GetNumRaidMembers() do if GetRaidRosterInfo(i)==name then return true end end
 return false
end
local function safe(s)
 return tostring(s or ''):gsub('[|,;\r\n]',''):sub(1,30)
end
local function send(msg)
 if N.owner and N.active and inRaid() and N.session then
  SendAddonMessage(PREFIX,msg,'RAID')
 end
end
local function fmt(n)
 n=math.max(0,math.floor(tonumber(n) or 0))
 if n<100 then return n..'s' end
 return math.floor(n/100)..'g '..(n%100)..'s'
end
local function refresh()
 if not win then return end
 local state=(N.owner and N.active) and H or S.remote
 local mode=(N.owner and N.active) and 'HOST / LOCAL ENGINE' or 'REMOTE / READ ONLY'
 headline:SetText('Network: '..(N.active and 'CONNECTED' or 'OFFLINE')..'  |  '..mode)
 if not N.active or not state then
  boardLabel:SetText('No synchronized state. Join a Hold\'em network table and wait for the host.')
  seatLabel:SetText('');return
 end
 local board={}
 for i=1,5 do
  local c=state.board and state.board[i]
  if type(c)=='table' then c=H.CardLabel(c) end
  board[#board+1]=c or '--'
 end
 boardLabel:SetText('Hand '..tostring(state.handNumber or 0)..'  |  '..safe(state.phase)..'  |  Pot: '..fmt(state.pot)..'\nCommunity: '..table.concat(board,'   '))
 local lines={}
 for i,p in ipairs(state.players or {}) do
  local flags=(p.folded and ' FOLD') or (p.allIn and ' ALL-IN') or ''
  local turn=(state.actionSeat==i and '  < TURN' or '')
  lines[#lines+1]=i..'. '..safe(p.name)..'  Stack '..fmt(p.stack)..'  Bet '..fmt(p.street)..flags..turn
 end
 seatLabel:SetText(table.concat(lines,'\n'))
end
local function label(parent,x,y,w,font)
 local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetJustifyH('LEFT')
 return f
end
local function build()
 if win then return end
 win=CreateFrame('Frame','RaidPokerBarrensSyncViewer',UIParent)
 win:SetWidth(460);win:SetHeight(430);win:SetPoint('CENTER',UIParent,'CENTER',0,0)
 win:SetFrameStrata('DIALOG');win:SetMovable(true);win:EnableMouse(true)
 win:RegisterForDrag('LeftButton');win:SetClampedToScreen(true)
 win:SetScript('OnDragStart',function(self)self:StartMoving()end)
 win:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 win:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 label(win,20,-22,385,'GameFontNormalLarge'):SetText("THE BARRENS HOLD'EM - SYNC VIEWER")
 local close=CreateFrame('Button',nil,win,'UIPanelButtonTemplate')
 close:SetWidth(26);close:SetHeight(23);close:SetPoint('TOPRIGHT',win,'TOPRIGHT',-14,-14)
 close:SetText('X');close:SetScript('OnClick',function()win:Hide()end)
 headline=label(win,20,-56,425)
 boardLabel=label(win,20,-92,420,'GameFontNormal')
 seatLabel=label(win,20,-150,420,'GameFontHighlightSmall')
 foot=label(win,20,-385,425)
 foot:SetText('Public state only. No hole cards or private deck data are sent.\nBetting remains LOCAL in beta4c1.')
 win:Hide()
end
function R.OpenBarrensSyncViewer()
 build();refresh();win:Show();win:Raise()
end
local function broadcast()
 if not (N.owner and N.active and inRaid() and N.session) then return end
 S.revision=S.revision+1
 local rev=tostring(S.revision)
 local session=safe(N.session)
 local board={}
 for i=1,5 do board[i]=H.board[i] and H.CardLabel(H.board[i]) or '-' end
 send('H|'..session..'|'..rev..'|'..safe(H.phase)..'|'..tostring(H.handNumber or 0)..'|'..tostring(H.pot or 0)..'|'..tostring(H.actionSeat or 0)..'|'..table.concat(board,',')..'|'..tostring(H.currentBet or 0)..'|'..tostring(H.minRaise or 0)..'|'..tostring(H.ante or 0))
 for i,p in ipairs(H.players or {}) do
  local flags=(p.folded and 'F' or '-')..(p.allIn and 'A' or '-')..(p.sittingOut and 'S' or '-')
  send('P|'..session..'|'..rev..'|'..i..'|'..safe(p.name)..'|'..tostring(p.stack or 0)..'|'..tostring(p.street or 0)..'|'..flags)
 end
 send('E|'..session..'|'..rev..'|'..tostring(#(H.players or {})))
 local payouts={}
 for seat,amount in pairs(H.winners or {}) do
  if tonumber(seat) and tonumber(amount) and amount>0 then payouts[#payouts+1]=tostring(seat)..':'..tostring(amount) end
 end
 table.sort(payouts)
 send('W|'..session..'|'..rev..'|'..(#payouts>0 and table.concat(payouts,',') or '-'))
end
S.ForceBroadcast=function() if not N.owner or not N.active then return false end;broadcast();return true end
-- A remote client may request a fresh public snapshot after a missed packet.
S.Request=function()
 if not N.active or N.owner or not N.session or not N.host or not raidMember(N.host) then return false end
 SendAddonMessage(PREFIX,'Q|'..safe(N.session),'WHISPER',N.host)
 return true
end
local function boundedNumber(v,limit)
 local n=tonumber(v)
 if not n or n<0 or n>limit or n~=math.floor(n) then return nil end
 return n
end
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('CHAT_MSG_ADDON')
events:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
  return
 end
 local prefix,msg,channel,sender=...
 if prefix~=PREFIX or type(msg)~='string' or #msg>240 then return end
 if channel=='WHISPER' and N.owner and N.active and raidMember(sender) and N.members[sender] and msg=='Q|'..safe(N.session) then
  broadcast();return
 end
 if channel~='RAID' or not N.active or N.owner or sender~=N.host or not raidMember(sender) then return end
 local parts={}
 for part in (msg..'|'):gmatch('(.-)|') do parts[#parts+1]=part end
 local kind,session,rev=parts[1],parts[2],boundedNumber(parts[3],1000000000)
 if not rev or session~=safe(N.session) then return end
 -- A newly joined table starts its revision counter at 1. Never carry the
 -- previous host/session revision or public snapshot into the new lobby.
 if S.remoteSession~=session or S.remoteHost~=sender then
  S.remoteSession=session;S.remoteHost=sender
  S.received=0;S.pending=nil;S.pendingByRevision={};S.remote=nil
 end
 if kind=='H' and (#parts==10 or #parts==11) then
  local hand=boundedNumber(parts[5],1000000)
  local pot=boundedNumber(parts[6],100000000)
  local turn=boundedNumber(parts[7],10)
  local currentBet=boundedNumber(parts[9],100000000)
  local minRaise=boundedNumber(parts[10],100000000)
  local ante=boundedNumber(parts[11] or '0',100000000)
  local allowed={LOBBY=true,PREFLOP=true,FLOP=true,TURN=true,RIVER=true,SHOWDOWN=true}
  if not hand or not pot or not turn or not currentBet or not minRaise or not ante or not allowed[parts[4]] then return end
  -- Ignore completed/older revisions, and never replace a newer
  -- incomplete snapshot with a delayed header from an older revision.
  if rev<=S.received then return end
  local board={}
  for c in (parts[8]..','):gmatch('(.-),') do
   if #board>=5 then return end
   if c~='-' and not c:match('^(10|[2-9JQKA])[SHDC]$') then return end
   board[#board+1]=c
  end
  if #board~=5 then return end
  S.pendingByRevision=S.pendingByRevision or {}
  S.pendingByRevision[rev]={revision=rev,phase=parts[4],handNumber=hand,pot=pot,actionSeat=turn,currentBet=currentBet,minRaise=minRaise,ante=ante,board=board,players={},winners={}}
  S.pending=S.pendingByRevision[rev]
  for old in pairs(S.pendingByRevision) do if old<rev-4 then S.pendingByRevision[old]=nil end end
 elseif kind=='P' and #parts==8 and S.pendingByRevision and S.pendingByRevision[rev] and rev>S.received then
  local pending=S.pendingByRevision[rev]
  local i=boundedNumber(parts[4],6)
  local stack=boundedNumber(parts[6],100000000)
  local bet=boundedNumber(parts[7],100000000)
  if not i or i<1 or not stack or not bet or #parts[5]>30 or not parts[8]:match('^[F%-][A%-][S%-]$') then return end
  pending.players[i]={name=parts[5],stack=stack,street=bet,folded=parts[8]:sub(1,1)=='F',allIn=parts[8]:sub(2,2)=='A',sittingOut=parts[8]:sub(3,3)=='S'}
 elseif kind=='W' and #parts==4 and S.remote and S.received==rev then
  local winners={}
  if parts[4]~='-' then
   for pair in (parts[4]..','):gmatch('(.-),') do
    local seat,amount=pair:match('^(%d+):(%d+)$')
    local i=boundedNumber(seat,6);local value=boundedNumber(amount,100000000)
    if not i or i<1 or not value then return end
    winners[i]=value
   end
  end
  S.remote.winners=winners
 elseif kind=='E' and #parts==4 and S.pendingByRevision and S.pendingByRevision[rev] and rev>S.received then
  local pending=S.pendingByRevision[rev]
  local count=boundedNumber(parts[4],6)
  if count==nil then return end
  for i=1,count do if not pending.players[i] then return end end
  -- Reject extra seat entries: they must not leak into the next snapshot.
  for i=count+1,6 do if pending.players[i] then return end end
  S.remote=pending;S.received=rev;S.pending=nil
  for old in pairs(S.pendingByRevision) do if old<=rev then S.pendingByRevision[old]=nil end end
  refresh()
  if R.RefreshBarrensUnifiedTable then R.RefreshBarrensUnifiedTable() end
  if R.RefreshBarrensUnifiedControls then R.RefreshBarrensUnifiedControls() end
 end
end)
local timer=CreateFrame('Frame')
local elapsed=0
timer:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt
 -- Clear stale client-side state when leaving the lobby. A new session
 -- will establish its own revision sequence on the next host snapshot.
 if not N.active and (S.remote or S.pending or S.remoteSession) then
  S.remote=nil;S.pending=nil;S.pendingByRevision={};S.received=0;S.remoteSession=nil;S.remoteHost=nil
  refresh()
 end
 if elapsed>=1.5 then
  elapsed=0;broadcast()
  if N.active and not N.owner then
   -- Request a fresh state if an interrupted packet burst left our turn stale.
   S.requestElapsed=(S.requestElapsed or 0)+1.5
   if S.requestElapsed>=4.5 then S.requestElapsed=0;S.Request() end
  else S.requestElapsed=0 end
  if win and win:IsShown() then refresh() end
 end end
end)
local old=SlashCmdList.RAIDFIVEPOKER
if old then
 SlashCmdList.RAIDFIVEPOKER=function(input)
  local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
  if cmd=='holdemsync' or cmd=='barrenssync' then R.OpenBarrensSyncViewer()
  else old(input) end
 end
end
