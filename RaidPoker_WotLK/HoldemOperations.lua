-- Barrens Hold'em beta4e1: advanced operations console.
-- Read-only table diagnostics, persistent GM audit, hand review, player ledger.
-- Does not modify engine, protocol, or 5-Card Draw. WoW 3.3.5a / Lua 5.1.
local R=RPoker
if not R or not R.Holdem or not R.BarrensRecords then return end
local O={}
R.BarrensOperations=O
local function db()
 RaidPokerWotLKDB=RaidPokerWotLKDB or {}
 local d=RaidPokerWotLKDB
 d.barrensOperations=d.barrensOperations or {audit={},settings={}}
 return d.barrensOperations
end
local function money(v)
 v=math.max(0,math.floor(tonumber(v) or 0))
 return math.floor(v/100)..'g '..(v%100)..'s'
end
local function mode() return R.BarrensUnifiedMode and R.BarrensUnifiedMode() or 'SOLO' end
local function snap() return R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot() or R.Holdem.GetPublicSnapshot() end
local function actor() return UnitName('player') or 'Unknown' end
local function audit(action,subject,details)
 local d=db();local a=d.audit
 a[#a+1]={when=date and date('%Y-%m-%d %H:%M:%S') or '',by=actor(),mode=mode(),action=action,subject=subject or '',details=details or ''}
 while #a>120 do table.remove(a,1) end
 if O.Refresh then O.Refresh() end
end
O.Audit=audit
local M=R.HoldemMultiplayer
if M and not M._barrensOperationsWrapped then
 M._barrensOperationsWrapped=true
 local function wrap(method,describe)
  local original=M[method]
  if type(original)~='function' then return end
  M[method]=function(...)
   local ok,why=original(...)
   if ok then local subject,details=describe(...);audit(method,subject,details) end
   return ok,why
  end
 end
 wrap('Assign',function(name)return name,'Seat assigned'end)
 wrap('Remove',function(name)return name,'Seat removed'end)
 wrap('SetStack',function(name,silver)return name,'New balance: '..money(silver)end)
 wrap('SitOut',function(name,value)return name,value and 'Sitting out' or 'Playing'end)
 wrap('StartHand',function()return 'Table','Network hand started'end)
end
local window,body,header,footer,exportBox
local page='OVERVIEW';local handOffset=0;local playerOffset=0;local auditOffset=0
local function label(parent,text,x,y,width,style)
 local t=parent:CreateFontString(nil,'OVERLAY',style or 'GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(text or '')
 return t
end
local function button(parent,text,x,y,w,callback)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,24);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',callback)
 return b
end
local function records()
 RaidPokerWotLKDB=RaidPokerWotLKDB or {}
 return RaidPokerWotLKDB.barrensRecords or {hands={},players={}}
end
local function sortedPlayers()
 local a={}
 for name,p in pairs(records().players or {}) do a[#a+1]={name=name,p=p} end
 table.sort(a,function(x,y)
  if (x.p.wins or 0)==(y.p.wins or 0) then return x.name<y.name end
  return (x.p.wins or 0)>(y.p.wins or 0)
 end)
 return a
end
local function publicPlayers(s)
 local a={}
 for i=1,10 do
  local p=s.players and s.players[i]
  if p and p.name and p.name~='' then
   local state=p.sittingOut and 'SIT OUT' or (p.folded and 'FOLD' or (p.allIn and 'ALL-IN' or 'PLAYING'))
   a[#a+1]=string.format('%2d. %-18s %-12s  %s',i,p.name:sub(1,18),money(p.stack),state)
  end
 end
 return a
end
local function linesForPage()
 local s=snap() or {};local r=records();local n=R.HoldemNetwork
 local lines={}
 if page=='OVERVIEW' then
  lines[#lines+1]='MODE: '..mode()..'     PHASE: '..tostring(s.phase or 'LOBBY')..'     HAND: '..tostring(s.handNumber or 0)
  lines[#lines+1]='GAME MASTER: '..tostring(n and n.host or '-')..'    NETWORK: '..(n and n.active and 'CONNECTED' or 'OFFLINE')
  lines[#lines+1]='POT: '..money(s.pot)..'    CURRENT BET: '..money(s.currentBet)..'    ACTION SEAT: '..tostring(s.actionSeat or '-')
  lines[#lines+1]=''
  lines[#lines+1]='SEATS / BALANCES / STATUS'
  local ps=publicPlayers(s)
  for _,line in ipairs(ps) do lines[#lines+1]=line end
  if #ps==0 then lines[#lines+1]='No players in the current snapshot.' end
  lines[#lines+1]=''
  lines[#lines+1]='Recorded hands: '..#(r.hands or {})..'    Recorded players: '..#sortedPlayers()
 elseif page=='PLAYERS' then
  lines[#lines+1]='CUMULATIVE LOCAL STATISTICS  |  WINS / HANDS / FOLDS / PAYOUT'
  lines[#lines+1]=''
  local a=sortedPlayers()
  for i=playerOffset+1,math.min(#a,playerOffset+15) do
   local x=a[i]
   lines[#lines+1]=string.format('%-17s  %3d / %3d    Fold %3d   %s',x.name:sub(1,17),x.p.wins or 0,x.p.hands or 0,x.p.folds or 0,money(x.p.payout))
  end
  if #a==0 then lines[#lines+1]='No player records yet.' end
  lines[#lines+1]=''
  lines[#lines+1]='Showing '..(math.min(#a,playerOffset+1))..'-'..math.min(#a,playerOffset+15)..' of '..#a
 elseif page=='HANDS' then
  local hands=r.hands or {}
  lines[#lines+1]='RECENT HANDS (NEWEST FIRST)  |  LOCAL OBSERVATIONS'
  lines[#lines+1]=''
  for i=#hands-handOffset,math.max(1,#hands-handOffset-13),-1 do
   local h=hands[i]
   if h then
    local wins={}
    for _,w in ipairs(h.winners or {}) do wins[#wins+1]=tostring(w.name)..' +'..money(w.amount) end
    lines[#lines+1]='#'..tostring(h.id)..'  '..tostring(h.mode)..'  Hand '..tostring(h.number)..'  '..tostring(h.phase)
    lines[#lines+1]='  Pot '..money(h.pot)..'  '..(#wins>0 and table.concat(wins,', ') or 'No payout recorded')
   end
  end
  if #hands==0 then lines[#lines+1]='No recorded hands yet.' end
  lines[#lines+1]=''
  lines[#lines+1]='Showing up to 7 hands; use Prev / Next.'
 elseif page=='AUDIT' then
  local a=db().audit
  lines[#lines+1]='GAME MASTER ACTION HISTORY  |  LAST 120 ACTIONS'
  lines[#lines+1]=''
  for i=#a-auditOffset,math.max(1,#a-auditOffset-15),-1 do
   local x=a[i]
   if x then lines[#lines+1]=x.when..'  '..x.action..'  '..x.subject
    lines[#lines+1]='  '..x.details end
  end
  if #a==0 then lines[#lines+1]='No administrative actions recorded yet.' end
 elseif page=='SESSION' then
  lines[#lines+1]='SESSION CONTROL / READINESS CHECK'
  lines[#lines+1]=''
  local n=R.HoldemNetwork;local m=R.HoldemMultiplayer
  local owner=n and n.active and n.owner and n.host==actor()
  lines[#lines+1]='Role: '..(owner and 'GAME MASTER' or 'PLAYER / READ ONLY')
  lines[#lines+1]='Lobby: '..(n and n.active and 'ACTIVE' or 'NOT CREATED')..'  Host: '..tostring(n and n.host or '-')
  lines[#lines+1]='Phase: '..tostring(s.phase or 'LOBBY')..'  Hand: '..tostring(s.handNumber or 0)
  lines[#lines+1]=''
  local assigned,playing,busted,sitting=0,0,0,0
  for i=1,10 do
   local p=(m and m.seats and m.seats[i]) or (s.players and s.players[i])
   if p and p.name and p.name~='' then
    assigned=assigned+1
    if p.sittingOut then sitting=sitting+1
    elseif (tonumber(p.stack) or 0)<=0 then busted=busted+1
    else playing=playing+1 end
   end
  end
  lines[#lines+1]='Seats: '..assigned..'/10  Playing: '..playing..'  Sitting Out: '..sitting..'  Busted: '..busted
  lines[#lines+1]=''
  lines[#lines+1]='READINESS'
  lines[#lines+1]=(n and n.active and '[OK]' or '[WAIT]')..' Network lobby established'
  lines[#lines+1]=(assigned>=2 and '[OK]' or '[WAIT]')..' At least two assigned seats'
  lines[#lines+1]=(playing>=2 and '[OK]' or '[WAIT]')..' At least two funded active players'
  lines[#lines+1]=(owner and '[OK]' or '[INFO]')..' Host authority for administrative actions'
  lines[#lines+1]=''
  lines[#lines+1]='Use Player Mgmt for Sit In/Out, balances, removals and start hand.'
  lines[#lines+1]='This page never changes a live hand or sends private cards.'
 elseif page=='DIAGNOSTICS' then
  lines[#lines+1]='NETWORK / PROTOCOL DIAGNOSTICS (READ ONLY)'
  lines[#lines+1]=''
  lines[#lines+1]='Mode: '..mode()..'  Network active: '..tostring(n and n.active or false)
  lines[#lines+1]='Host: '..tostring(n and n.host or '-')..'  Local owner: '..tostring(n and n.owner or false)
  lines[#lines+1]='Session: '..tostring(n and n.session or '-')
  local members=0
  if n and n.members then for _ in pairs(n.members) do members=members+1 end end
  lines[#lines+1]='Lobby members: '..members
  lines[#lines+1]='Multiplayer module: '..tostring(R.HoldemMultiplayer~=nil)
  lines[#lines+1]='Private-card protocol: '..tostring(R.HoldemProtocol~=nil)
  lines[#lines+1]='Public state sync: '..tostring(R.HoldemSync~=nil)
  lines[#lines+1]='Game phase: '..tostring(s.phase)..'  Hand: '..tostring(s.handNumber)
  lines[#lines+1]=''
  lines[#lines+1]='This panel does not expose private cards or the shuffled deck.'
 end
 return lines
end
function O.Refresh()
 if not window or not window:IsShown() then return end
 header:SetText('THE BARRENS HOLD\'EM - '..page)
 local lines=linesForPage()
 body:SetText(table.concat(lines,'\n'))
 footer:SetText('Local records are not network-synchronized. No character gold is transferred.')
end
local function changePage(p)
 page=p;handOffset=0;playerOffset=0;auditOffset=0;O.Refresh()
end
local function navigate(delta)
 if page=='HANDS' then handOffset=math.max(0,math.min(math.max(0,#(records().hands or {})-1),handOffset+delta*7))
 elseif page=='PLAYERS' then playerOffset=math.max(0,math.min(math.max(0,#sortedPlayers()-1),playerOffset+delta*15))
 elseif page=='AUDIT' then auditOffset=math.max(0,math.min(math.max(0,#db().audit-1),auditOffset+delta*8)) end
 O.Refresh()
end
local function exportCurrent()
 if not exportBox then
  local e=CreateFrame('Frame','RaidPokerBarrensExport',UIParent)
  e:SetSize(620,480);e:SetPoint('CENTER');e:SetFrameStrata('FULLSCREEN_DIALOG')
  e:SetMovable(true);e:EnableMouse(true);e:RegisterForDrag('LeftButton')
  e:SetScript('OnDragStart',function(self)self:StartMoving()end)
  e:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  e:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
  label(e,'COPY CURRENT PAGE - CTRL+C',18,-18,500,'GameFontNormalLarge')
  button(e,'X',570,-12,30,function()e:Hide()end)
  local scroll=CreateFrame('ScrollFrame',nil,e,'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT',e,'TOPLEFT',20,-55);scroll:SetPoint('BOTTOMRIGHT',e,'BOTTOMRIGHT',-38,18)
  local edit=CreateFrame('EditBox',nil,scroll)
  edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject('ChatFontNormal');edit:SetWidth(530)
  edit:SetScript('OnEscapePressed',function()e:Hide()end)
  scroll:SetScrollChild(edit)
  exportBox={frame=e,edit=edit}
 end
 exportBox.edit:SetText(table.concat(linesForPage(),'\n'))
 exportBox.frame:Show();exportBox.edit:SetFocus();exportBox.edit:HighlightText()
end
local function build()
 if window then return end
 window=CreateFrame('Frame','RaidPokerBarrensOperations',UIParent)
 window:SetSize(690,585);window:SetPoint('CENTER');window:SetFrameStrata('DIALOG')
 window:SetMovable(true);window:EnableMouse(true);window:SetClampedToScreen(true)
 window:RegisterForDrag('LeftButton')
 window:SetScript('OnDragStart',function(self)self:StartMoving()end)
 window:SetScript('OnDragStop',function(self)
  self:StopMovingOrSizing()
  local x,y=self:GetCenter()
  if x and y then db().position={x,y} end
 end)
 local pos=db().position
 if pos and pos[1] and pos[2] then
  window:ClearAllPoints();window:SetPoint('CENTER',UIParent,'BOTTOMLEFT',pos[1],pos[2])
 end
 window:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 header=label(window,'',18,-18,600,'GameFontNormalLarge')
 button(window,'X',646,-13,28,function()window:Hide()end)
 local tabs={{'Overview','OVERVIEW'},{'Players','PLAYERS'},{'Hands','HANDS'},{'GM Audit','AUDIT'},{'Session','SESSION'},{'Diagnostics','DIAGNOSTICS'}}
 for i,t in ipairs(tabs) do button(window,t[1],16+(i-1)*110,-52,105,function()changePage(t[2])end) end
 body=label(window,'',23,-96,640,'GameFontHighlightSmall');body:SetHeight(365);body:SetJustifyV('TOP')
 button(window,'Prev',20,-476,80,function()navigate(-1)end)
 button(window,'Next',106,-476,80,function()navigate(1)end)
 button(window,'Copy Page',197,-476,105,exportCurrent)
 button(window,'Player Mgmt',313,-476,112,function()if R.OpenBarrensManagement then R.OpenBarrensManagement() end end)
 button(window,'Network Lobby',433,-476,112,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button(window,'Poker Table',553,-476,112,function()if R.OpenBarrensTable then R.OpenBarrensTable()end end)
 footer=label(window,'',23,-522,640,'GameFontHighlightSmall')
 window:Hide()
end
function O.Open(p)build();page=p or 'OVERVIEW';window:Show();window:Raise();O.Refresh()end
function R.OpenBarrensOperations()O.Open('OVERVIEW')end
function R.OpenBarrensSession()O.Open('SESSION')end
-- Extend existing records buttons without changing their data collector.
function R.OpenBarrensStatistics()O.Open('PLAYERS')end
function R.OpenBarrensHandHistory()O.Open('HANDS')end
R.OpenBarrensHistory=R.OpenBarrensHandHistory
SLASH_BARRENSOPS1='/holdemops'
SlashCmdList.BARRENSOPS=function(input)
 local arg=string.lower((input or ''):match('^%s*(.-)%s*$'))
 if arg=='stats' then O.Open('PLAYERS') elseif arg=='hands' then O.Open('HANDS')
 elseif arg=='audit' then O.Open('AUDIT') elseif arg=='debug' then O.Open('DIAGNOSTICS') elseif arg=='session' then O.Open('SESSION')
 else O.Open('OVERVIEW') end
end
local ticker=CreateFrame('Frame');local elapsed=0
 ticker:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt;if elapsed>=1.5 then elapsed=0;O.Refresh()end
 end)
