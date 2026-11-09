-- The Barrens Hold'em beta4e2: seat inspector and session readiness.
-- Read-only UI. Existing 5-Card Draw, Hold'em engine and protocol are untouched.
local R=RPoker
if not R or not R.Holdem then return end
local f,lines,selected
local function money(v)
 v=math.max(0,math.floor(tonumber(v) or 0))
 return math.floor(v/100)..'g '..(v%100)..'s'
end
local function snap()
 return (R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot()) or
  (R.Holdem.GetPublicSnapshot and R.Holdem.GetPublicSnapshot()) or {}
end
local function records()
 return RaidPokerWotLKDB and RaidPokerWotLKDB.barrensRecords or {}
end
local function button(parent,label,x,y,w,cb)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,23);b:SetPoint('TOPLEFT',parent,x,y);b:SetText(label);b:SetScript('OnClick',cb)
 return b
end
local function text(parent,x,y,w)
 local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,x,y);t:SetWidth(w);t:SetJustifyH('LEFT');return t
end
local function refresh()
 if not f or not f:IsShown() then return end
 local s=snap();local p=s.players and s.players[selected or 1]
 local m=R.HoldemMultiplayer
 local real=m and m.seats and m.seats[selected or 1]
 local name=(p and p.name) or (real and real.name)
 local r=name and (records().players or {})[name] or nil
 local out={'SEAT '..tostring(selected or 1)..'  |  '..tostring(name or 'EMPTY'),' '}
 if name then
  out[#out+1]='Balance: '..money((p and p.stack) or (real and real.stack))
  out[#out+1]='Current bet: '..money(p and (p.street or p.bet or 0))
  out[#out+1]='Committed: '..money(p and p.committed)
  out[#out+1]='Status: '..(p and p.folded and 'FOLDED' or (p and p.allIn and 'ALL-IN' or ((real and real.sittingOut) or (p and p.sittingOut)) and 'SITTING OUT' or 'ACTIVE'))
  out[#out+1]=' '
  out[#out+1]='LOCAL CUMULATIVE RECORD'
  out[#out+1]='Hands: '..tostring(r and r.hands or 0)
  out[#out+1]='Wins: '..tostring(r and r.wins or 0)
  out[#out+1]='Folds: '..tostring(r and r.folds or 0)
  out[#out+1]='Payouts: '..money(r and r.payout)
 else
  out[#out+1]='No player assigned to this seat.'
 end
 out[#out+1]=' '
 out[#out+1]='Private opponent cards are never displayed here.'
 lines:SetText(table.concat(out,'\n'))
end
function R.OpenBarrensSeatInspector(seat)
 if not f then
  f=CreateFrame('Frame','RaidPokerBarrensSeatInspector',UIParent)
  f:SetSize(440,465);f:SetPoint('CENTER',UIParent,'CENTER',440,0)
  f:SetFrameStrata('DIALOG');f:SetMovable(true);f:EnableMouse(true)
  f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function(self)self:StartMoving()end)
  f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
  local heading=text(f,18,-20,360);heading:SetText("THE BARRENS HOLD'EM - SEAT INSPECTOR")
  button(f,'X',395,-12,30,function()f:Hide()end)
  for i=1,10 do
   local seatIndex=i
   local x=18+((i-1)%5)*82
   local y=-56-math.floor((i-1)/5)*31
   button(f,tostring(i),x,y,75,function()selected=seatIndex;refresh()end)
  end
  lines=text(f,22,-143,395)
  button(f,'Refresh',18,-414,90,refresh)
  button(f,'Player Mgmt',120,-414,130,function()if R.OpenBarrensManagement then R.OpenBarrensManagement()end end)
  button(f,'Operations',260,-414,140,function()if R.OpenBarrensOperations then R.OpenBarrensOperations()end end)
 end
 selected=math.max(1,math.min(10,tonumber(seat) or selected or 1))
 f:Show();f:Raise();refresh()
end
SLASH_BARRENSINSPECT1='/holdeminspect'
SlashCmdList.BARRENSINSPECT=function(msg)R.OpenBarrensSeatInspector(tonumber(msg))end
