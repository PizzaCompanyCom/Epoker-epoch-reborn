-- The Barrens Hold'em: persistent local hand records and cumulative statistics.
-- WoW 3.3.5a / Lua 5.1. Read-only observer: never changes cards, bets or network state.
local R=RPoker
if not R or not R.Holdem then return end
local M={}
R.BarrensRecords=M
local function store()
 RaidPokerWotLKDB=RaidPokerWotLKDB or {}
 local d=RaidPokerWotLKDB
 d.barrensRecords=d.barrensRecords or {hands={},players={},sequence=0}
 return d.barrensRecords
end
local function money(n)
 n=math.max(0,math.floor(tonumber(n) or 0))
 return tostring(math.floor(n/100))..'g '..tostring(n%100)..'s'
end
local function snapshot()
 if R.BarrensUnifiedSnapshot then return R.BarrensUnifiedSnapshot() end
 return R.Holdem.GetPublicSnapshot and R.Holdem.GetPublicSnapshot()
end
local function mode()
 return R.BarrensUnifiedMode and R.BarrensUnifiedMode() or 'SOLO'
end
local function playerRecord(name)
 local d=store()
 if not name or name=='' then return nil end
 if not d.players[name] then d.players[name]={hands=0,wins=0,payout=0,folds=0,allins=0} end
 return d.players[name]
end
local observed={}
local function readState()
 local s=snapshot()
 if not s or not s.players then return end
 local m=mode()
 if observed.mode~=m or (observed.number and (tonumber(s.handNumber) or 0)<observed.number) then
  observed={mode=m}
 end
 local number=tonumber(s.handNumber) or 0
 if number<=0 then observed.number=number;return end
 if observed.number~=number then
  observed.number=number
  observed.logSeen={}
  observed.finished=false
  observed.members={}
  local d=store()
  d.sequence=(d.sequence or 0)+1
  observed.id=d.sequence
  local entry={id=observed.id,mode=m,number=number,phase=s.phase or '',events={},players={},winners={},pot=0,date=date and date('%Y-%m-%d %H:%M') or ''}
  d.hands[#d.hands+1]=entry
  while #d.hands>60 do table.remove(d.hands,1) end
 end
 local d=store()
 local entry
 for i=#d.hands,1,-1 do if d.hands[i].id==observed.id then entry=d.hands[i];break end end
 if not entry then return end
 entry.phase=s.phase or entry.phase
 for seat,p in pairs(s.players) do
  if type(seat)=='number' and type(p)=='table' and p.name and p.name~='' then
   entry.players[seat]=p.name
   if not observed.members[p.name] then
    observed.members[p.name]=true
    local pr=playerRecord(p.name);pr.hands=pr.hands+1
   end
  end
 end
 -- Snapshot logs may be capped at 30 lines. Match the longest overlap to avoid repeats.
 local lines=s.log or {}
 local old=observed.logSeen or {}
 local overlap=0
 for n=math.min(#old,#lines),1,-1 do
  local matches=true
  for j=1,n do if old[#old-n+j]~=lines[j] then matches=false;break end end
  if matches then overlap=n;break end
 end
 for i=overlap+1,#lines do
  local event=tostring(lines[i])
  entry.events[#entry.events+1]=event
  while #entry.events>100 do table.remove(entry.events,1) end
  local who=event:match('^(.-) folds$')
  if who then local pr=playerRecord(who);if pr then pr.folds=pr.folds+1 end end
 end
 observed.logSeen={}
 for i=1,#lines do observed.logSeen[i]=lines[i] end
 if s.phase=='SHOWDOWN' and not observed.finished then
  observed.finished=true
  local paid=0
  for seat,amount in pairs(s.winners or {}) do
   local name=entry.players[seat]
   local gain=tonumber(amount) or 0
   if name and gain>0 then
    entry.winners[#entry.winners+1]={name=name,amount=gain}
    local pr=playerRecord(name);pr.wins=pr.wins+1;pr.payout=pr.payout+gain
    paid=paid+gain
   end
  end
  entry.pot=paid
 end
end
M.Observe=readState
local panel,body,heading,selected
local function label(parent,value,x,y)
 local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(510);t:SetJustifyH('LEFT');t:SetText(value or '')
 return t
end
local function button(parent,title,x,y,w,click)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w or 100,23);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(title);b:SetScript('OnClick',click)
 return b
end
local function render()
 if not panel or not panel:IsShown() then return end
 local d=store()
 if selected=='STATS' then
  heading:SetText('CUMULATIVE PLAYER STATISTICS - LOCAL RECORDS')
  local a={}
  for name,p in pairs(d.players) do a[#a+1]={name=name,p=p} end
  table.sort(a,function(x,y) return x.p.wins==y.p.wins and x.name<y.name or x.p.wins>y.p.wins end)
  local lines={'PLAYER                  HANDS    WINS    FOLDS    PAYOUT'}
  for i=1,math.min(17,#a) do
   local v=a[i]
   lines[#lines+1]=string.format('%-22s %4d      %4d      %4d     %s',v.name:sub(1,22),v.p.hands or 0,v.p.wins or 0,v.p.folds or 0,money(v.p.payout))
  end
  if #a==0 then lines[#lines+1]='No completed or observed hands yet.' end
  body:SetText(table.concat(lines,'\n'))
 elseif selected=='HANDS' then
  heading:SetText('HAND HISTORY - LAST 60 OBSERVED HANDS')
  local lines={}
  for i=#d.hands,math.max(1,#d.hands-16),-1 do
   local h=d.hands[i]
   local winners={}
   for _,w in ipairs(h.winners or {}) do winners[#winners+1]=w.name..' +'..money(w.amount) end
   lines[#lines+1]='#'..h.id..'  '..h.mode..'  Hand '..h.number..'  '..h.phase..'  '..money(h.pot)..'  '..table.concat(winners,', ')
  end
  if #lines==0 then lines[1]='No recorded hands yet.' end
  body:SetText(table.concat(lines,'\n'))
 else
  heading:SetText('BETTING ACTIVITY - MOST RECENT HAND')
  local h=d.hands[#d.hands]
  local lines={}
  if h then
   lines[1]='#'..h.id..'  '..h.mode..'  Hand '..h.number..'  '..h.phase
   for i=math.max(1,#h.events-17),#h.events do lines[#lines+1]=h.events[i] end
  else lines[1]='No betting actions recorded yet.' end
  body:SetText(table.concat(lines,'\n'))
 end
end
local function open(tab)
 selected=tab or 'HANDS'
 if not panel then
  panel=CreateFrame('Frame','RaidPokerBarrensRecordsWindow',UIParent)
  panel:SetSize(590,505);panel:SetPoint('CENTER');panel:SetFrameStrata('DIALOG')
  panel:SetMovable(true);panel:EnableMouse(true);panel:RegisterForDrag('LeftButton')
  panel:SetScript('OnDragStart',function(self)self:StartMoving()end)
  panel:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  panel:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
  local title=label(panel,"THE BARRENS HOLD'EM - RECORDS",20,-19)
  title:SetFontObject('GameFontNormalLarge')
  button(panel,'X',550,-10,26,function()panel:Hide()end)
  button(panel,'Activity',20,-50,120,function()selected='ACTIVITY';render()end)
  button(panel,'Hand History',150,-50,120,function()selected='HANDS';render()end)
  button(panel,'Statistics',280,-50,120,function()selected='STATS';render()end)
  button(panel,'Player Mgmt',410,-50,150,function()if R.OpenBarrensManagement then R.OpenBarrensManagement() end end)
  heading=label(panel,'',20,-91);heading:SetTextColor(1,0.78,0.25)
  body=label(panel,'',20,-120);body:SetWidth(545);body:SetHeight(350);body:SetJustifyV('TOP')
  panel:Hide()
 end
 panel:Show();panel:Raise();render()
end
function R.OpenBarrensBettingActivity() open('ACTIVITY') end
function R.OpenBarrensStatistics() open('STATS') end
function R.OpenBarrensHandHistory() open('HANDS') end
R.OpenBarrensHistory=R.OpenBarrensHandHistory
function R.RefreshBarrensStatistics() render() end
local timer=CreateFrame('Frame')
local elapsed=0
timer:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt
 if elapsed>=1 then elapsed=0;readState();render() end
end)
SLASH_BARRENSRECORDS1='/holdemhistory'
SlashCmdList.BARRENSRECORDS=function()open('HANDS')end
