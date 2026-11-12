-- Raid 5-Card Poker WotLK 0.3.0: visual enhancements, no replacement of the game engine.
local R=RPoker
local H={}
R.EnhancementFrames={}
local function label(parent,x,y,w,template,value)
 local t=parent:CreateFontString(nil,'OVERLAY',template or 'GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT')
 if value then t:SetText(value) end
 return t
end
local function pane(parent,x,y,w,h)
 local f=CreateFrame('Frame',nil,parent)
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetHeight(h)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 R.RegisterBackground(f,0.025,0.065,0.055,0.9)
 return f
end
local function action(parent,name,x,y,w,cb)
 return R.Button(parent,name,w,23,x,y,cb)
end
local oldBuild=R.BuildGame
function R.BuildGame(main)
 oldBuild(main)
 local ui=R.GameUI
 if not ui then return end
 -- Player seating: fixed, separate cells prevent long names from overlapping.
 for i=1,6 do
  local c=math.floor((i-1)/5);local r=(i-1)%5
  local row=ui.rows[i]
  row:ClearAllPoints()
  row:SetPoint('TOPLEFT',ui.table,'TOPLEFT',20+c*355,-38-r*30)
  row:SetWidth(325)
  local seat=pane(ui.table,10+c*355,-31-r*30,345,27)
  seat:SetFrameLevel(ui.table:GetFrameLevel()+1)
  row:SetParent(seat)
  row:ClearAllPoints();row:SetPoint('TOPLEFT',seat,'TOPLEFT',10,-7)
  row:SetWidth(322);row:SetDrawLayer('OVERLAY')
  H['seat'..i]=seat
 end
 -- Bigger cards and selection borders, without moving the existing game controls.
 for i=1,5 do
  local b=ui.cards[i]
  b:SetHeight(146)
  b:SetWidth(100)
  b:ClearAllPoints();b:SetPoint('TOPLEFT',b:GetParent(),'TOPLEFT',20+(i-1)*126,-35)
  b.cardArt:SetDrawLayer('ARTWORK')
  local edge=b:CreateTexture(nil,'OVERLAY')
  edge:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
  edge:SetBlendMode('ADD');edge:SetAllPoints(b);edge:Hide()
  H['selected'..i]=edge
 end
 -- Movable independent betting activity window, hidden until opened from the main toolbar.
 H.activity=CreateFrame('Frame','RaidPokerBettingActivity',UIParent)
 H.activity:SetWidth(350);H.activity:SetHeight(320)
 H.activity:SetFrameStrata('FULLSCREEN_DIALOG')
 H.activity:SetMovable(true);H.activity:SetClampedToScreen(true);H.activity:EnableMouse(true)
 H.activity:SetPoint('CENTER',UIParent,'CENTER',RaidPokerWotLKDB.activityX or 380,RaidPokerWotLKDB.activityY or 0)
 H.activity:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=28,insets={left=10,right=10,top=10,bottom=10}})
 R.RegisterBackground(H.activity,0.04,0.05,0.04,1)
 table.insert(R.EnhancementFrames,H.activity)
 label(H.activity,22,-20,270,'GameFontNormalLarge','BETTING ACTIVITY')
 action(H.activity,'X',308,-15,25,function() H.activity:Hide() end)
 local drag=CreateFrame('Frame',nil,H.activity)
 drag:SetPoint('TOPLEFT',H.activity,'TOPLEFT',16,-12)
 drag:SetWidth(275);drag:SetHeight(31);drag:EnableMouse(true);drag:RegisterForDrag('LeftButton')
 drag:SetScript('OnDragStart',function()H.activity:StartMoving()end)
 drag:SetScript('OnDragStop',function()
  H.activity:StopMovingOrSizing()
  local x,y=H.activity:GetCenter();local ux,uy=UIParent:GetCenter()
  if x and ux then RaidPokerWotLKDB.activityX=x-ux;RaidPokerWotLKDB.activityY=y-uy end
 end)
 H.activityRows={}
 for i=1,11 do H.activityRows[i]=label(H.activity,23,-56-(i-1)*22,300,'GameFontHighlightSmall') end
 H.activity:Hide()
 R.ToggleBettingActivity=function()
  if H.activity:IsShown() then H.activity:Hide()
  else H.activity:Show();H.activity:Raise() end
 end
 action(main,'Betting Activity',272,-674,155,function()R.ToggleBettingActivity()end)
 action(main,'Emotes',92,-674,155,function()if R.ToggleEmotesAnnouncements then R.ToggleEmotesAnnouncements('DRAW')else R.Print('Emotes module not loaded; check addon files.')end end)
 -- Thin horizontal turn countdown immediately below the cards, using original color thresholds.
 H.turnPanel=CreateFrame('Frame',nil,main)
 H.turnPanel:SetPoint('TOPLEFT',main,'TOPLEFT',23,-307)
 H.turnPanel:SetWidth(733);H.turnPanel:SetHeight(20)
 H.bar=CreateFrame('StatusBar',nil,H.turnPanel)
 H.bar:SetAllPoints(H.turnPanel)
 H.bar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')
 H.bar:SetMinMaxValues(0,1);H.bar:SetValue(0);H.bar:SetStatusBarColor(0.4,0.6,0.4)
 H.barBG=H.bar:CreateTexture(nil,'BACKGROUND');H.barBG:SetAllPoints(H.bar)
 H.barBG:SetTexture(0.13,0.13,0.13,0.85)
 H.turnName=H.bar:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 H.turnName:SetPoint('CENTER',H.bar,'CENTER',-25,0)
 H.turnName:SetText('Waiting for players')
 H.timerText=H.bar:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 H.timerText:SetPoint('RIGHT',H.bar,'RIGHT',-10,0)
 -- Betting presets are input helpers only; Raise still submits the actual action.
 H.presets=pane(main,22,-565,735,100)
 label(H.presets,13,-8,680,'GameFontNormal','BETTING PRESETS - CHOOSE AMOUNT, THEN PRESS RAISE')
 local presets={{'+10s',10},{'+50s',50},{'+100s',100},{'1/4 Pot',0.25},{'1/2 Pot',0.5},{'Pot',1}}
 for i,item in ipairs(presets) do
  local preset=item
  action(H.presets,preset[1],13+(i-1)*117,-34,110,function()
   local g=R.G;local p=nil
   for _,entry in ipairs(g.players or {}) do if entry.name==UnitName('player') then p=entry;break end end
   local owed=p and math.max(0,(g.bet or 0)-(p.paid or 0)) or 0
   local current=R.ReadMoney(ui.raiseGold,ui.raiseSilver) or 0
   local v
   if preset[2]>=1 then v=current+preset[2] else v=owed+math.max(1,math.floor((g.pot or 0)*preset[2]+0.5)) end
   if p then v=math.min(v,p.balance or v) end
   R.SetMoneyBoxes(ui.raiseGold,ui.raiseSilver,math.max(0,math.floor(v)))
  end)
 end
 -- Removed redundant Betting Presets help line (v1.7.24).
 -- A dedicated diagnostics panel: never visible or actionable during real raid play.
 -- Dedicated movable Solo Debug window, separate from the poker gameplay layout.
 H.debug=CreateFrame('Frame','RaidFivePokerSoloDebug',UIParent)
 H.debug:SetWidth(303);H.debug:SetHeight(247)
 H.debug:SetFrameStrata('FULLSCREEN_DIALOG')
 H.debug:SetMovable(true);H.debug:SetClampedToScreen(true);H.debug:EnableMouse(true)
 H.debug:SetPoint('CENTER',UIParent,'CENTER',(RaidPokerWotLKDB.debugX or 440),(RaidPokerWotLKDB.debugY or -80))
 R.Backdrop(H.debug)
 table.insert(R.EnhancementFrames,H.debug)
 local debugDrag=CreateFrame('Frame',nil,H.debug)
 debugDrag:SetPoint('TOPLEFT',H.debug,'TOPLEFT',12,-9)
 debugDrag:SetPoint('TOPRIGHT',H.debug,'TOPRIGHT',-40,-9)
 debugDrag:SetHeight(30);debugDrag:SetFrameLevel(H.debug:GetFrameLevel()+8);debugDrag:EnableMouse(true);debugDrag:RegisterForDrag('LeftButton')
 debugDrag:SetScript('OnDragStart',function(self)
  if IsMouseButtonDown('LeftButton') then H.debug:StartMoving() end
 end)
 debugDrag:SetScript('OnDragStop',function()
  H.debug:StopMovingOrSizing()
  local x,y=H.debug:GetCenter();local ux,uy=UIParent:GetCenter()
  if x and ux then RaidPokerWotLKDB.debugX=x-ux;RaidPokerWotLKDB.debugY=y-uy end
 end)
 local debugClose=action(H.debug,'X',269,-9,25,function()H.debug:Hide()end)
 debugClose:SetFrameLevel(debugDrag:GetFrameLevel()+1)
 label(H.debug,12,-12,280,'GameFontNormal','SOLO DEBUG CONTROLS')
 H.debugStatus=label(H.debug,12,-45,280,'GameFontHighlightSmall','Debug mode is OFF')
 action(H.debug,'New Hand',12,-75,130,function()R.DebugNewHand()end)
 action(H.debug,'Next Bot',156,-75,130,function()R.DebugNextBot()end)
 action(H.debug,'Showdown',12,-107,130,function()R.DebugForceShowdown()end)
 action(H.debug,'+500s',156,-107,130,function()R.DebugCredit()end)
 action(H.debug,'1 Bot',12,-139,85,function()R.SoloStart(1)end)
 action(H.debug,'3 Bots',107,-139,85,function()R.SoloStart(3)end)
 action(H.debug,'Debug Off',202,-139,85,function()R.SoloStop()end)
 label(H.debug,12,-188,275,'GameFontHighlightSmall','Debug controls work only in Solo Debug Mode.')
 -- Winner popup: informational, auto-shown once for each new result.
 H.popup=CreateFrame('Frame','RaidFivePokerWinnerPopup',UIParent)
 H.popup:SetWidth(460);H.popup:SetHeight(170);H.popup:SetPoint('CENTER',UIParent,'CENTER',0,210)
 H.popup:SetFrameStrata('FULLSCREEN_DIALOG');R.Backdrop(H.popup)
 table.insert(R.EnhancementFrames,H.popup)
 local title=label(H.popup,30,-20,390,'GameFontNormalLarge','HAND COMPLETE')
 title:SetJustifyH('CENTER')
 H.winner=label(H.popup,25,-61,410,'GameFontHighlight','')
 H.winner:SetJustifyH('CENTER');H.winner:SetHeight(65)
 action(H.popup,'Close',185,-127,90,function()H.popup:Hide()end)
 H.popup:Hide()
 R.HideWinnerPopup=function() H.popup:Hide() end
 H.lastResult=''
 H.debug:Hide()
 R.ToggleDebugPanel=function()
  if H.debug:IsShown() then H.debug:Hide()
  else
   if R.Main and not R.Main:IsShown() then R.Main:Show() end
   H.debug:Show();H.debug:Raise()
  end
 end
 local priorHide=main:GetScript('OnHide')
 main:SetScript('OnHide',function(self)if priorHide then priorHide(self) end H.popup:Hide();H.debug:Hide() end)
end
local oldRefresh=R.Refresh
function R.Refresh()
 oldRefresh()
 local g=R.G
 if not H.activity then return end
 for i=1,11 do
  local s=(g.log or {})[i] or ''
  H.activityRows[i]:SetText(string.sub(s,1,45))
  if string.find(s,'WINNER') then H.activityRows[i]:SetTextColor(0.35,1,0.45)
  elseif string.find(s,'raises') or string.find(s,'RAISE') then H.activityRows[i]:SetTextColor(1,0.78,0.3)
  elseif string.find(s,'folds') or string.find(s,'FOLD') then H.activityRows[i]:SetTextColor(1,0.42,0.42)
  else H.activityRows[i]:SetTextColor(0.88,0.88,0.88) end
  local p=(g.players or {})[i]
  if p then
   local status=p.fold and 'FOLD' or p.allin and 'ALL-IN' or p.inhand and (p.done and 'ACTED' or 'IN HAND') or 'WAITING'
   local turn=(g.turn==p.name and ' > ' or '   ')
   local name=string.sub(p.name or '?',1,15)
   R.GameUI.rows[i]:SetText(turn..name..'  '..(p.balance or 0)..'s  '..status)
   if g.turn==p.name then H['seat'..i]:SetBackdropColor(0.12,0.25,0.12,0.95)
   else H['seat'..i]:SetBackdropColor(0.025,0.065,0.055,0.7) end
  end
 end
 for i=1,5 do
  H['selected'..i]:Hide() -- v0.9.1: raised card alone indicates selection
 end
 H.debugStatus:SetText(g.solo and ('ACTIVE - '..#g.players..' players | '..g.phase) or 'Debug mode is OFF')
 if g.winner and g.winner~='' and g.phase=='SHOWDOWN' then
  local id=tostring(g.round)..':'..g.winner
  if H.lastResult~=id then
   H.lastResult=id;H.winner:SetText(string.sub(g.winner,1,210));if R.Main and R.Main:IsShown() and (not RaidPokerWotLKDB or RaidPokerWotLKDB.showWinnerPopup==true) then H.popup:Show() end
  end
 elseif g.phase=='BET1' then H.popup:Hide() end
end
local clock=CreateFrame('Frame')
local acc=0
clock:SetScript('OnUpdate',function(self,dt)
 acc=acc+dt;if acc<0.12 then return end;acc=0
 if not H.bar then return end
 local g=R.G
 local timer=tonumber(g.timer) or 30
 if g.turn=='' or timer<=0 then H.bar:SetValue(0);H.timerText:SetText('');H.turnName:SetText('Waiting for players');return end
 local isHost=(g.host==UnitName('player'))
 local deadline=isHost and g.deadline or g.clientDeadline
 local remain=math.max(0,(deadline or 0)-GetTime())
 H.bar:SetValue(math.min(1,remain/timer))
 H.timerText:SetText(math.ceil(remain)..'s')
 H.turnName:SetText(g.turn==UnitName('player') and 'YOUR TURN' or (g.turn.."'s turn"))
 if g.turn~=UnitName('player') then H.bar:SetStatusBarColor(0.52,0.55,0.6)
 elseif remain<timer*0.25 then H.bar:SetStatusBarColor(0.9,0.18,0.15)
 elseif remain<timer*0.5 then H.bar:SetStatusBarColor(0.95,0.73,0.1)
 else H.bar:SetStatusBarColor(0.12,0.85,0.3) end
end)
