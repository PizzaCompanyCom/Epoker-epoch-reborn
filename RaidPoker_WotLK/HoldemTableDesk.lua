-- The Barrens Hold'em - beta4e9: unified table workflow
-- WoW 3.3.5a / Lua 5.1. Reuses existing game modules; does not alter the deck.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local W,summary,seatLabels,selection,controls,selected,amount
local selectedSeat=1
local function say(message) if R.Print then R.Print('Holdem Desk: '..message) end end
local function net() return R.HoldemNetwork end
local function multi() return R.HoldemMultiplayer end
local function isGM()
 local n=net()
 return n and n.active and n.owner and n.host==UnitName('player')
end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function active()
 return isGM() and idle() and R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK'
end
local function seat() local m=multi();return m and m.seats and m.seats[selectedSeat] end
local function money(v)
 v=math.max(0,math.floor(tonumber(v) or 0))
 return math.floor(v/100)..'g '..(v%100)..'s'
end
local function text(parent,x,y,w,value,style)
 local f=parent:CreateFontString(nil,'OVERLAY',style or 'GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',parent,x,y);f:SetWidth(w);f:SetJustifyH('LEFT');f:SetText(value or '')
 return f
end
local function button(parent,label,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,25);b:SetPoint('TOPLEFT',parent,x,y);b:SetText(label);b:SetScript('OnClick',fn)
 return b
end
local function open(name,...)
 local f=R[name]
 if type(f)=='function' then f(...) else say(name..' unavailable') end
end
local function invoke(name,...)
 if not active() then say('Game Master controls require an idle network table');return end
 local m=multi()
 if not m or type(m[name])~='function' then say(name..' unavailable');return end
 local ok,err=m[name](...)
 if ok==false then say(tostring(err or 'Action refused')) end
 if R.RefreshBarrensTableDesk then R.RefreshBarrensTableDesk() end
end
local function confirm(message,fn)
 StaticPopupDialogs['RAIDPOKER_BARRENS_DESK_CONFIRM']={
  text=message,button1='Confirm',button2='Cancel',timeout=0,
  whileDead=true,hideOnEscape=true,preferredIndex=3,
  OnAccept=function()fn()end
 }
 StaticPopup_Show('RAIDPOKER_BARRENS_DESK_CONFIRM')
end
function R.RefreshBarrensTableDesk()
 if not W then return end
 local n=net();local m=multi()
 local count=0;local ready=0
 for i=1,10 do
  local p=m and m.seats and m.seats[i]
  if p and p.name then
   count=count+1
   if not p.sittingOut and (tonumber(p.stack) or 0)>0 then ready=ready+1 end
  end
  local status=p and (p.sittingOut and 'OUT' or ((tonumber(p.stack) or 0)<=0 and 'BUSTED' or 'IN')) or ''
  seatLabels[i]:SetText((i==selectedSeat and '> ' or '  ')..i..'. '..(p and (p.name..'   '..money(p.stack)..'   '..status) or '[Empty]'))
 end
 summary:SetText('MODE: '..tostring(R.BarrensUnifiedMode and R.BarrensUnifiedMode() or 'SOLO')
  ..'    |    GM: '..tostring(n and n.host or '-')
  ..'    |    PHASE: '..tostring(H.phase or '-')
  ..'\nSEATED: '..count..'/10    |    READY: '..ready
  ..'    |    '..(active() and '|cff66ff66GM CONTROLS ENABLED|r' or '|cffffaa55GM CONTROLS LOCKED|r'))
 local p=seat()
 selection:SetText(p and ('SELECTED: '..p.name..' / '..money(p.stack)) or 'SELECTED: Empty seat')
 for _,b in ipairs(controls) do if active() then b:Enable() else b:Disable() end end
end
local function build()
 if W then return end
 W=CreateFrame('Frame','RaidPokerBarrensTableDesk',UIParent)
 W:SetSize(760,705);W:SetPoint('CENTER',UIParent,'CENTER',0,0)
 W:SetFrameStrata('FULLSCREEN_DIALOG');W:SetFrameLevel(500)
 W:SetMovable(true);W:EnableMouse(true);W:SetClampedToScreen(true)
 W:RegisterForDrag('LeftButton')
 W:SetScript('OnDragStart',function(self)self:StartMoving()end)
 W:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 W:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 text(W,20,-18,650,"THE BARRENS HOLD'EM - TABLE OPERATIONS",'GameFontNormalLarge')
 local close=button(W,'X',715,-12,27,function()W:Hide()end)
 close:SetFrameLevel(W:GetFrameLevel()+30)
 close:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Close Table Operations');GameTooltip:Show()end)
 close:SetScript('OnLeave',function()GameTooltip:Hide()end)
 -- Separate drag handle remains enabled for all players, regardless of GM status.
 local drag=CreateFrame('Button',nil,W)
 drag:SetPoint('TOPLEFT',W,'TOPLEFT',16,-10)
 drag:SetSize(660,30)
 drag:SetFrameLevel(W:GetFrameLevel()+5)
 drag:RegisterForDrag('LeftButton')
 drag:SetScript('OnDragStart',function()W:StartMoving()end)
 drag:SetScript('OnDragStop',function()W:StopMovingOrSizing()end)
 drag:SetScript('OnMouseUp',function(_,button)if button=='RightButton' then W:Hide()end end)
 -- The header drag area does not overlap the close button.
 if UISpecialFrames then table.insert(UISpecialFrames,'RaidPokerBarrensTableDesk') end
 summary=text(W,20,-56,710,'','GameFontHighlight')
 text(W,20,-113,300,'PLAYER SEATS','GameFontNormal')
 text(W,370,-113,350,'GAME MASTER ACTIONS','GameFontNormal')
 seatLabels={};controls={}
 for i=1,10 do
  local index=i
  local b=button(W,'',20,-138-(i-1)*30,325,function()selectedSeat=index;R.RefreshBarrensTableDesk()end)
  seatLabels[i]=b:GetFontString()
 end
 selection=text(W,20,-449,710,'','GameFontNormal')
 local function gm(label,x,y,w,fn)
  local b=button(W,label,x,y,w,fn);controls[#controls+1]=b;return b
 end
 gm('Auto Seat Joined',370,-138,170,function()invoke('AutoSeat')end)
 gm('Start Network Hand',552,-138,182,function()
  if R.HoldemPreflight and R.HoldemPreflight.Start then
   local ok,err=R.HoldemPreflight.Start()
   if ok==false then say(tostring(err or 'Preflight refused')) end
  else open('OpenBarrensPreflight') end
 end)
 gm('Sit Out',370,-173,170,function()local p=seat();if p then invoke('SitOut',p.name,true)end end)
 gm('Sit In',552,-173,182,function()local p=seat();if p then invoke('SitOut',p.name,false)end end)
 gm('Remove Player',370,-208,170,function()
  local p=seat()
  if p then local name=p.name;confirm('Remove '..name..' from the Holdem table?',function()invoke('Remove',name)end) end
 end)
 text(W,370,-255,340,'SET BALANCE (SILVER)','GameFontNormalSmall')
 amount=CreateFrame('EditBox',nil,W)
 amount:SetSize(170,26);amount:SetPoint('TOPLEFT',W,370,-277)
 amount:SetAutoFocus(false);amount:SetNumeric(true);amount:SetMaxLetters(9)
 amount:SetFontObject('ChatFontNormal');amount:SetTextInsets(8,8,0,0)
 amount:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 amount:SetBackdropColor(.05,.05,.05,.9);amount:SetText('1000')
 gm('Apply Balance',552,-277,182,function()
  local p=seat();if not p then return end
  local name=p.name;local value=tonumber(amount:GetText())
  if not value or value<0 then say('Enter a non-negative balance');return end
  confirm('Set '..name..' balance to '..money(value)..'?',function()invoke('SetStack',name,value)end)
 end)
 text(W,370,-336,350,'TABLE WORKFLOW','GameFontNormal')
 button(W,'Hand Preflight',370,-359,170,function()open('OpenBarrensPreflight')end)
 button(W,'Player Management',552,-359,182,function()open('OpenBarrensManagement')end)
 button(W,'Network Lobby',370,-392,170,function()open('OpenBarrensNetworkLobby')end)
 button(W,'Multiplayer Seats',552,-392,182,function()open('OpenBarrensMultiplayer')end)
 button(W,'GM Transfer',370,-425,170,function()open('OpenBarrensGMTransfer')end)
 button(W,'Session Recovery',552,-425,182,function()open('OpenBarrensSessionRecovery')end)
 text(W,20,-494,700,'EXISTING WINDOWS AND VISUAL CONTROLS','GameFontNormal')
 button(W,'Main Game Window',20,-521,170,function()open('OpenBarrensControls')end)
 button(W,'Poker Table',201,-521,170,function()open('OpenBarrensTable')end)
 button(W,'Settings / Themes',382,-521,170,function()open('OpenBarrensSettings')end)
 button(W,'Table Effects',563,-521,170,function()open('OpenBarrensTableEffects')end)
 button(W,'Betting Activity',20,-555,170,function()open('OpenBarrensBettingActivity')end)
 button(W,'Hand History',201,-555,170,function()open('OpenBarrensHandHistory')end)
 button(W,'Rules / Help',382,-555,170,function()open('OpenBarrensGuide','HELP')end)
 button(W,'Force Seat Sync',563,-555,170,function()
  if not active() then say('Only the idle Game Master can sync seats');return end
  local bridge=R.HoldemAdminBridge
  if bridge and bridge.BroadcastSeats then
   local ok,err=bridge.BroadcastSeats()
   if ok==false then say(tostring(err or 'Sync refused'))end
  else say('Seat sync module unavailable')end
 end)
 button(W,'Refresh',20,-600,170,R.RefreshBarrensTableDesk)
 text(W,201,-606,520,'No hidden cards or deck state are sent by these controls.','GameFontHighlightSmall')
 local auditText=text(W,20,-643,710,'','GameFontHighlightSmall')
 local priorRefresh=R.RefreshBarrensTableDesk
 R.RefreshBarrensTableDesk=function()
  priorRefresh()
  local history=R.HoldemIntegration and R.HoldemIntegration.events or {}
  local recent={}
  for i=math.max(1,#history-2),#history do if history[i] then recent[#recent+1]=history[i] end end
  auditText:SetText('RECENT GM ACTIVITY: '..(#recent>0 and table.concat(recent,'  |  ') or 'No actions yet'))
 end
 W:SetScript('OnShow',R.RefreshBarrensTableDesk)
 W:Hide()
end
function R.OpenBarrensTableDesk()
 build()
 if W:IsShown() then W:Hide();return end
 R.RefreshBarrensTableDesk();W:Show();W:Raise()
end
function R.CloseBarrensTableDesk() if W then W:Hide() end end
SLASH_BARRTABLEDESK1='/holdemdesk'
SlashCmdList.BARRTABLEDESK=function(arg)
 if arg and string.lower(arg)=='close' then R.CloseBarrensTableDesk()
 else R.OpenBarrensTableDesk() end
end
local tick=CreateFrame('Frame');local elapsed=0
tick:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt
 if elapsed>=2 then elapsed=0;if W and W:IsShown() then R.RefreshBarrensTableDesk()end end
end)
