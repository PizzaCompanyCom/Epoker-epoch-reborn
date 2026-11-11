-- Raid Poker v1.8.0-beta3: isolated Hold'em game control panel.
-- Shares Draw visual assets, not Draw's state or network handlers.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local function money(amount)
 amount=math.max(0,math.floor(tonumber(amount) or 0))
 local g=math.floor(amount/100)
 local s=amount%100
 if g>0 and s>0 then return g..'g '..s..'s' end
 if g>0 then return g..'g' end
 return s..'s'
end
local function paidPot(snapshot)
 if snapshot.phase~='SHOWDOWN' then return snapshot.pot or 0 end
 local sum=0
 for _,pot in ipairs(snapshot.sidePots or {}) do sum=sum+(tonumber(pot.amount) or 0) end
 if sum>0 then return sum end
 -- Older preview snapshots may omit side pots; reconstruct from payout logs.
 for _,line in ipairs(snapshot.log or {}) do
  local amount=string.match(line,'Pot %d+:%s*(%d+)s paid')
  if amount then sum=sum+tonumber(amount) end
 end
 return sum
end

local frame,phaseText,potText,turnText,handCards,boardCards,buttons,raiseBox,statusText,historyText,startButton,resetButton
local currentBetText,toCallText,balanceText,timerText,turnTimerBar,anteGold,anteSilver,stackGold,stackSilver,raiseGold,raiseSilver
local themeArt,themeTint
local function txt(parent,value,font)
 local x=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontNormal');x:SetText(value or '');return x
end
local function panel(parent,w,h,r,g,b)
 local t=parent:CreateTexture(nil,'BACKGROUND');t:SetTexture('Interface\\Buttons\\WHITE8X8');t:SetVertexColor(r,g,b,1);t:SetSize(w,h);return t
end
local function button(parent,label,w,h,callback)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,h);b:SetText(label);b:SetScript('OnClick',callback);return b
end
-- UI-only elements inspired by the established 5-Card Draw main window.
local function iconButton(parent,label,texture,w,h,callback)
 local b=button(parent,'   '..label,w,h,callback)
 if texture then
  local icon=b:CreateTexture(nil,'ARTWORK')
  icon:SetTexture(texture);icon:SetSize(20,20);icon:SetPoint('LEFT',b,'LEFT',7,0)
  if label=='Leave Table' then icon:SetVertexColor(0.45,0.85,1,1) end
  -- Keep the icon visible even when the button is disabled.
  icon:SetDrawLayer('OVERLAY', 7)
  local labelRegion=b:GetFontString()
  if labelRegion then
   labelRegion:ClearAllPoints()
   labelRegion:SetPoint('LEFT',b,'LEFT',30,0)
   labelRegion:SetPoint('RIGHT',b,'RIGHT',-4,0)
   labelRegion:SetJustifyH('CENTER')
  end
 end
 return b
end
local function line(parent,w,h,r,g,b,x,y)
 local t=panel(parent,w,h,r,g,b);t:SetPoint('TOP',parent,x,y);return t
end
local function card(parent,w,h)
 local f=CreateFrame('Frame',nil,parent);f:SetSize(w,h)
 local edge=panel(f,w,h,0.72,0.53,0.25);edge:SetPoint('CENTER')
 local bg=panel(f,w-4,h-4,0.055,0.11,0.25);bg:SetPoint('CENTER')
 local art=f:CreateTexture(nil,'ARTWORK');art:SetPoint('TOPLEFT',f,2,-2);art:SetPoint('BOTTOMRIGHT',f,-2,2)
 local crest=txt(f,'RAID POKER','GameFontNormalSmall');crest:SetPoint('CENTER');crest:SetTextColor(0.95,0.77,0.40)
 function f:SetCard(v,hidden)
  if hidden then art:Hide();art:SetTexture(nil);crest:Show();bg:SetVertexColor(0.055,0.11,0.25,1);return end
  local rank,suit
  if v then rank,suit=string.match(v,'^(%d+)([SHDC])$') end
  if v and not rank then rank,suit=string.match(v,'^([JQKA])([SHDC])$') end
  if rank and suit then
   art:SetTexture('Interface\\AddOns\\RaidPoker_WotLK\\Cards\\'..rank..suit..'.tga');art:Show();crest:Hide()
  else art:SetTexture(nil);art:Hide();crest:Hide();bg:SetVertexColor(0.10,0.18,0.20,1) end
 end
 f:SetCard(nil,true);return f
end
local function performAction(action,amount)
 if R.BarrensUnifiedAction then return R.BarrensUnifiedAction(action,amount) end
 return H.Action(action,amount)
end
local function message(ok,reason)
 if not ok and R.Print then R.Print('Barrens Holdem: '..(reason or 'Invalid action')) end
end
local backgrounds={'ClassicDark','Tavern','Alliance','Horde','PokerFelt','Ironforge','BootyBayTavern','PirateShip'}
local backgroundNames={'Classic Dark','Tavern','Alliance','Horde','Poker Felt','Ironforge','Booty Bay Tavern','Pirate Ship'}
local function db()
 RaidPokerWotLKDB=RaidPokerWotLKDB or {}
 RaidPokerWotLKDB.barrensTheme=RaidPokerWotLKDB.barrensTheme or 1
 return RaidPokerWotLKDB
end
function R.RefreshBarrensBackground()
 if not themeArt then return end
 local d=db();local n=math.max(1,math.min(8,tonumber(d.barrensTheme) or 1))
 themeArt:SetTexture('Interface\\AddOns\\RaidPoker_WotLK\\Backgrounds\\'..backgrounds[n]..'.tga')
 themeArt:SetAlpha(tonumber(d.barrensThemeOpacity) or 0.85)
 if themeTint then
  local darkness=1-(tonumber(d.barrensThemeBrightness) or 0.85)
  themeTint:SetVertexColor(0,0,0,math.max(0,math.min(0.8,darkness)))
 end
end
local settingsFrame,themePicker,tableThemePicker,scaleSlider,opacitySlider
local function applyWindowScale()
 if frame then frame:SetScale(tonumber(db().barrensWindowScale) or 1) end
end
function R.OpenBarrensSettings()
 if not settingsFrame then
  local f=CreateFrame('Frame','RaidPokerBarrensThemeSettings',UIParent)
  settingsFrame=f;f:SetSize(360,690);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG')
  f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function(self)self:StartMoving()end)
  f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,tile=true,tileSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local title=txt(f,'EPOKERWOW RAID - SETTINGS','GameFontNormalLarge');title:SetPoint('TOP',0,-25)
  button(f,'X',23,21,function()f:Hide()end):SetPoint('TOPRIGHT',-10,-10)
  local function heading(text,y)
   local t=txt(f,text,'GameFontNormalSmall');t:SetPoint('TOP',0,y);return t
  end
  local function slider(text,y,min,max,step,key,initial,callback)
   heading(text,y)
   local sl=CreateFrame('Slider',nil,f,'OptionsSliderTemplate')
   sl:SetSize(185,15);sl:SetPoint('TOP',0,y-23)
   sl:SetMinMaxValues(min,max);sl:SetValueStep(step)
   sl:SetScript('OnValueChanged',function(self,v)
    db()[key]=v
    if callback then callback() end
   end)
   sl:SetValue(tonumber(db()[key]) or initial)
   return sl
  end
  scaleSlider=slider('Window Scale',-63,0.7,1.3,0.05,'barrensWindowScale',1,applyWindowScale)
  button(f,'Reset Layout',128,22,function()
   db().barrensWindowScale=1;scaleSlider:SetValue(1)
   if frame then frame:ClearAllPoints();frame:SetPoint('CENTER',UIParent,'CENTER',0,0) end
   db().barrensControlsPosition=nil
  end):SetPoint('TOP',0,-108)
  opacitySlider=slider('Game Window Background Opacity',-146,0.15,1,0.05,'barrensThemeOpacity',0.85,R.RefreshBarrensBackground)
  heading('APPEARANCE & AUDIO',-213)
  button(f,'Background Themes',175,23,function()
   themePicker:Show();themePicker:Raise()
  end):SetPoint('TOP',0,-247)
  button(f,'Table Surface Themes',175,23,function()
   if tableThemePicker then tableThemePicker:Show();tableThemePicker:Raise() end
  end):SetPoint('TOP',0,-291)
  button(f,'Sound Options',175,23,function()
   if R.OpenBarrensTableEffects then R.OpenBarrensTableEffects() end
  end):SetPoint('TOP',0,-335)
  button(f,'Protocol Debug',175,23,function()
   if R.OpenHoldemProtocolDebug then R.OpenHoldemProtocolDebug() end
  end):SetPoint('TOP',0,-379)
  button(f,'5-Card Draw Settings',175,23,function()
   f:Hide()
   if R.SettingsFrame then R.SettingsFrame:Show();R.SettingsFrame:Raise() end
  end):SetPoint('TOP',0,-423)
   heading('EpokerWoW Raid - Version: '..(GetAddOnMetadata('RaidPoker_WotLK','Version') or 'Unknown'),-623)
  heading('Changes are saved automatically.',-652)
  themePicker=CreateFrame('Frame',nil,UIParent)
  themePicker:SetSize(285,353);themePicker:SetPoint('LEFT',f,'RIGHT',8,0)
  themePicker:SetFrameStrata('FULLSCREEN_DIALOG')
  themePicker:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,tile=true,tileSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local label=txt(themePicker,'BACKGROUND THEMES','GameFontNormal');label:SetPoint('TOP',0,-20)
  button(themePicker,'X',22,20,function()themePicker:Hide()end):SetPoint('TOPRIGHT',-9,-9)
  for i,name in ipairs(backgroundNames) do
   local index=i
   local b=button(themePicker,name,225,25,function()
    db().barrensTheme=index;R.RefreshBarrensBackground()
    -- Keep the theme chooser open for browsing multiple backgrounds.
   end)
   b:SetPoint('TOP',0,-45-(i-1)*35)
  end
  local hint=txt(themePicker,'Select themes freely; close with X.','GameFontNormalSmall')
  hint:SetPoint('BOTTOM',0,13)
  themePicker:Hide()
  tableThemePicker=CreateFrame('Frame','RaidPokerBarrensTableThemePicker',UIParent)
  tableThemePicker:SetSize(320,425)
  tableThemePicker:SetPoint('LEFT',f,'RIGHT',8,0)
  tableThemePicker:SetFrameStrata('FULLSCREEN_DIALOG')
  tableThemePicker:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,tile=true,tileSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local surfaceTitle=txt(tableThemePicker,'POKER TABLE SURFACES','GameFontNormal')
  surfaceTitle:SetPoint('TOP',0,-22)
  button(tableThemePicker,'X',22,20,function()tableThemePicker:Hide()end):SetPoint('TOPRIGHT',-9,-9)
  local names={'Classic Green Felt','Solid Black','Dark Charcoal','Midnight Blue','Dark Green','Burgundy','Dark Brown','Royal Blue','Deep Purple'}
  for i,name in ipairs(names) do
   local idx=i
   local b=button(tableThemePicker,name,255,25,function()
    if R.SetBarrensPokerTableTheme then R.SetBarrensPokerTableTheme(idx) end
   end)
   b:SetPoint('TOP',0,-43-(i-1)*37)
  end
  local surfaceHint=txt(tableThemePicker,'Felt table and solid-color surfaces.','GameFontHighlightSmall')
  surfaceHint:SetPoint('BOTTOM',0,15)
  tableThemePicker:Hide()
  f:SetScript('OnHide',function()themePicker:Hide();tableThemePicker:Hide()end)
  f:Hide()
 end
 if settingsFrame:IsShown() then settingsFrame:Hide() else settingsFrame:Show();settingsFrame:Raise() end
end
local guideFrame,guideText
function R.OpenBarrensGuide(kind)
 if not guideFrame then
  local f=CreateFrame('Frame','RaidPokerBarrensGuide',UIParent);guideFrame=f
  f:SetSize(645,520);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG')
  f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function(self)self:StartMoving()end)
  f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,tile=true,tileSize=32,insets={left=8,right=8,top=8,bottom=8}})
  button(f,'X',28,24,function()f:Hide()end):SetPoint('TOPRIGHT',-12,-12)
  guideText=txt(f,'','GameFontHighlight');guideText:SetPoint('TOPLEFT',24,-28);guideText:SetWidth(585);guideText:SetJustifyH('LEFT');guideText:SetJustifyV('TOP')
  f:Hide()
 end
 local content={
 HELP="Poker Help - Texas Hold'em\\n1. Click Join Table, If there are no active tables, click Player Management, click Create Table.\\n2. Each player receives 2 private cards.\\n3. Betting rounds: Pre-Flop, Flop, Turn and River.\\n4. On your turn, choose CHECK, CALL, BET, RAISE, FOLD or ALL-IN.\\n5. Make the best 5-card hand using your cards and the 5 community cards.\\n6. Game Master manages the table, balances and player seating.\\n\\nTurn Timer: When time expires, the game automatically CHECKS if possible, otherwise FOLDS, then advances to the next player.",
 RULES="TEXAS HOLD'EM RULES\\n\\nEach player gets TWO private hole cards. Community cards are revealed as Flop (3), Turn (1) and River (1). Betting occurs before the flop and after each reveal.\\n\\nMake the strongest FIVE-card combination using zero, one or both hole cards. Check only when no call is owed. Call matches the current bet; Raise increases it; Fold gives up the hand; All-In commits the remaining stack.\\n\\nAt showdown the strongest eligible hand wins. Tied eligible hands split their pot; side pots are resolved among eligible players. Virtual balances only.",
 RANKINGS="POKER HAND RANKINGS - BEST TO WORST\\n\\n1. ROYAL FLUSH: A-K-Q-J-10, all the same suit.\\n2. STRAIGHT FLUSH: five consecutive ranks of one suit.\\n3. FOUR OF A KIND: four cards of the same rank.\\n4. FULL HOUSE: three of one rank plus a pair.\\n5. FLUSH: five cards of one suit, not consecutive.\\n6. STRAIGHT: five consecutive ranks, mixed suits.\\n7. THREE OF A KIND: three cards of one rank.\\n8. TWO PAIR: two separate pairs plus a fifth card.\\n9. ONE PAIR: two equal ranks plus three kickers.\\n10. HIGH CARD: no combination; compare highest cards.\\n\\nAce can be high (10-J-Q-K-A) or low (A-2-3-4-5). Compare combination ranks first, then kickers. Exact ties split the eligible pot."
 }
 guideText:SetText((content[kind] or content.HELP):gsub('\\n','\n'))
 if guideFrame:IsShown() and guideFrame.currentKind==kind then guideFrame:Hide() else guideFrame.currentKind=kind;guideFrame:Show();guideFrame:Raise() end
end

local activityFrame,activityRows
function R.OpenBarrensBettingActivity()
 if not activityFrame then
  activityFrame=CreateFrame('Frame','RaidPokerBarrensBettingActivity',UIParent)
  activityFrame:SetSize(390,340);activityFrame:SetPoint('CENTER',UIParent,'CENTER',400,0)
  activityFrame:SetFrameStrata('FULLSCREEN_DIALOG')
  activityFrame:SetMovable(true);activityFrame:EnableMouse(true)
  activityFrame:RegisterForDrag('LeftButton')
  activityFrame:SetScript('OnDragStart',function(self)self:StartMoving()end)
  activityFrame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  activityFrame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
  local title=txt(activityFrame,'THE BARRENS HOLD\'EM - BETTING ACTIVITY','GameFontNormalLarge')
  title:SetPoint('TOP',activityFrame,0,-20)
  button(activityFrame,'X',26,24,function()activityFrame:Hide()end):SetPoint('TOPRIGHT',activityFrame,-12,-12)
  activityRows={}
  for i=1,11 do
   local row=txt(activityFrame,'','GameFontHighlightSmall')
   row:SetPoint('TOPLEFT',activityFrame,20,-52-(i-1)*24)
   row:SetWidth(350);row:SetJustifyH('LEFT')
   activityRows[i]=row
  end
 end
 if activityFrame:IsShown() then activityFrame:Hide() else activityFrame:Show() end
end
local function refreshActivity(snapshot)
 if not activityFrame or not activityFrame:IsShown() then return end
 local lines=snapshot.log or {}
 for i=1,11 do
  local idx=#lines-11+i
  activityRows[i]:SetText(idx>0 and tostring(lines[idx]) or '')
 end
end


local statsFrame,statsRows
function R.OpenBarrensStatistics()
 if not statsFrame then
  statsFrame=CreateFrame('Frame','RaidPokerBarrensStatistics',UIParent)
  statsFrame:SetSize(570,390);statsFrame:SetPoint('CENTER',UIParent,'CENTER',-420,0)
  statsFrame:SetFrameStrata('DIALOG');statsFrame:SetMovable(true);statsFrame:EnableMouse(true)
  statsFrame:RegisterForDrag('LeftButton')
  statsFrame:SetScript('OnDragStart',function(self)self:StartMoving()end)
  statsFrame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  statsFrame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
  local heading=txt(statsFrame,"THE BARRENS HOLD'EM - STATISTICS",'GameFontNormalLarge');heading:SetPoint('TOP',statsFrame,0,-19)
  button(statsFrame,'X',27,23,function()statsFrame:Hide()end):SetPoint('TOPRIGHT',statsFrame,-12,-12)
  statsRows={}
  local xs={20,74,254,354,456};local widths={48,170,94,94,90}
  local headers={'SEAT','PLAYER','STACK','BET','STATUS'}
  for c=1,5 do
   local head=txt(statsFrame,headers[c],'GameFontNormalSmall')
   head:SetPoint('TOPLEFT',statsFrame,xs[c],-79);head:SetWidth(widths[c])
  end
  statsRows[1]=txt(statsFrame,'','GameFontHighlightSmall');statsRows[1]:SetPoint('TOPLEFT',statsFrame,20,-51);statsRows[1]:SetWidth(530)
  statsRows[2]=txt(statsFrame,'','GameFontHighlightSmall');statsRows[2]:Hide()
  for i=1,6 do
   local y=-104-(i-1)*24
   local bg=statsFrame:CreateTexture(nil,'BACKGROUND');bg:SetTexture('Interface\\Buttons\\WHITE8X8')
   bg:SetPoint('TOPLEFT',statsFrame,16,y+3);bg:SetSize(537,23)
   bg:SetVertexColor(.24,.25,.27,i%2==0 and .22 or .10)
   local row={}
   for c=1,5 do
    local cell=txt(statsFrame,'','GameFontHighlightSmall')
    cell:SetPoint('TOPLEFT',statsFrame,xs[c],y);cell:SetWidth(widths[c]);cell:SetJustifyH('LEFT')
    row[c]=cell
   end
   statsRows[i+2]=row
  end
 end
 if statsFrame:IsShown() then statsFrame:Hide() else statsFrame:Show() end
 if statsFrame:IsShown() then R.RefreshBarrensStatistics() end
end
function R.RefreshBarrensStatistics()
 if not statsFrame or not statsFrame:IsShown() then return end
 local s=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot() or H.GetPublicSnapshot()
 if not s then return end
 statsRows[1]:SetText('Hand: '..tostring(s.handNumber or 0)..'   Phase: '..tostring(s.phase or 'LOBBY')..'   Pot: '..money(paidPot(s)))
 for i=1,6 do
  local p=s.players and s.players[i]
  local cells=statsRows[i+2]
  local state=p and (p.folded and 'Folded' or (p.allIn and 'All-In' or 'Playing')) or ''
  local values={tostring(i),p and tostring(p.name or '?'):sub(1,19) or 'Empty',p and money(p.stack or p.balance or 0) or '',p and money(p.street or p.bet or 0) or '',state}
  for c=1,5 do cells[c]:SetText(values[c]) end
 end
end

local function build()
 if frame then return end
 frame=CreateFrame('Frame','RaidPokerBarrensGameControls',UIParent)
 frame:SetSize(790,815);frame:SetPoint('CENTER',UIParent,'CENTER',0,0)
 frame:SetFrameStrata('DIALOG');frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true)
 frame:HookScript('OnMouseDown',function(self)self:Raise()end)
 frame:SetScript('OnDragStart',function(self)self:StartMoving()end)
 frame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing(); if RaidPokerWotLKDB then RaidPokerWotLKDB.barrensControlsPosition={self:GetCenter()} end end)
 if RaidPokerWotLKDB and RaidPokerWotLKDB.barrensControlsPosition then local p=RaidPokerWotLKDB.barrensControlsPosition; if p[1] and p[2] then frame:ClearAllPoints();frame:SetPoint('CENTER',UIParent,'BOTTOMLEFT',p[1],p[2]) end end
 frame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
  frame:SetBackdropColor(0.065,0.045,0.025,0.98)
  frame:SetBackdropBorderColor(0.65,0.45,0.21,1)
 -- The large decorative title is intentionally omitted to match 5-Card Draw.
 -- Poker Table navigation is in the primary row.
 local pokerButton=frame
 local closeSoloButton=iconButton(frame,'Close Bots','Interface\\Icons\\INV_Misc_Dice_02',130,26,function()
  if R.BarrensCloseSoloGame then local ok,err=R.BarrensCloseSoloGame();if not ok and R.Print then R.Print(err) end end
 end)
 closeSoloButton:SetPoint('TOPLEFT',frame,15,-12)
 closeSoloButton:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Close Bots / Solo Debug');GameTooltip:AddLine('Clears local bots and preview cards. Does not close a network table.',1,1,1,true);GameTooltip:Show()end)
 closeSoloButton:SetScript('OnLeave',function()GameTooltip:Hide()end)

 local toolbar={
  {'Force Synchronization','Interface\\Icons\\Spell_Nature_EarthBind',function()
    if R.HoldemSync and R.HoldemSync.ForceBroadcast then
     local ok=R.HoldemSync.ForceBroadcast()
     if R.Print then R.Print(ok and 'Holdem: public state broadcast.' or 'Holdem: only the active host can broadcast.') end
    elseif R.OpenBarrensSyncViewer then R.OpenBarrensSyncViewer() end
  end},
  {'Reconnect / Recovery','Interface\\Icons\\INV_Misc_PocketWatch_01',function()if R.OpenBarrensSessionRecovery then R.OpenBarrensSessionRecovery() end end},
  {'Help: Game Master / Player','Interface\\Icons\\INV_Misc_QuestionMark',function()R.OpenBarrensGuide('HELP')end},
  {'Rules: Texas Holdem','Interface\\Icons\\INV_Misc_Book_11',function()R.OpenBarrensGuide('RULES')end},
  {'Rankings','Interface\\Icons\\INV_Misc_Note_01',function()R.OpenBarrensGuide('RANKINGS')end},
  {'Solo Debug Controls','Interface\\Icons\\INV_Misc_Dice_02',function()if R.OpenBarrensSoloDebug then R.OpenBarrensSoloDebug()end end},
  {'Settings','Interface\\Icons\\INV_Misc_Gear_01',function()R.OpenBarrensSettings()end},
 }
 local x=frame:GetWidth()-15-28-#toolbar*36-8
 for _,entry in ipairs(toolbar) do
  -- Same icon-only button construction as the working 5-Card Draw toolbar.
  -- UIPanelButtonTemplate normal/pushed textures were covering these icons.
  local b=CreateFrame('Button',nil,frame);b:SetSize(32,30);b:SetFrameLevel(frame:GetFrameLevel()+12)
  b:SetPoint('TOPLEFT',frame,x,-10);x=x+36
  local icon=b:CreateTexture(nil,'OVERLAY');icon:SetTexture(entry[2]);icon:SetAllPoints(b)
  b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
  b:SetScript('OnClick',entry[3]);b:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(entry[1]);GameTooltip:Show()end)
  b:SetScript('OnLeave',function()GameTooltip:Hide()end)
 end
 button(frame,'X',25,25,function()frame:Hide()end):SetPoint('TOPRIGHT',frame,-13,-12)
 -- The gold divider under the old title is intentionally omitted.
 -- Native procedural timber trim, compatible with the 3.3.5a renderer.
 -- A single full-window background, matching the 5-Card Draw theme system.
 themeArt=frame:CreateTexture(nil,'BACKGROUND',nil,1)
 themeArt:SetPoint('TOPLEFT',frame,15,-91)
 themeArt:SetPoint('BOTTOMRIGHT',frame,-15,17)
 themeTint=frame:CreateTexture(nil,'BACKGROUND',nil,2)
 themeTint:SetAllPoints(themeArt)
 local felt=CreateFrame('Frame',nil,frame);felt:SetSize(746,254);felt:SetPoint('TOP',frame,0,-100)
 themeTint:SetTexture('Interface\\Buttons\\WHITE8X8')
 themeTint:SetVertexColor(0,0,0,0.1)
 R.RefreshBarrensBackground()
 local inner=CreateFrame('Frame',nil,felt)
 inner:SetPoint('TOPLEFT',felt,8,-8);inner:SetPoint('BOTTOMRIGHT',felt,-8,8)
 inner:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=14,insets={left=2,right=2,top=2,bottom=2}})
 inner:SetBackdropColor(0,0.035,0.025,0.66)
 inner:SetBackdropBorderColor(0.45,0.38,0.19,0.9)
 -- HF23: remove the obsolete gold divider; the turn timer is the only horizontal indicator here.

 handCards={}
 for i=1,2 do local c=card(felt,91,133);c:SetPoint('TOP',felt,(i==1 and -55 or 55),-14);handCards[i]=c end
 boardCards={}
 for i=1,5 do local c=card(felt,49,71);c:SetPoint('TOP',felt,(i-3)*62,-161);boardCards[i]=c end
 -- Dedicated countdown strip replaces the decorative yellow divider during a turn.
 turnTimerBar=CreateFrame('StatusBar',nil,frame)
 turnTimerBar:SetSize(705,15);turnTimerBar:SetPoint('TOP',frame,0,-349)
 turnTimerBar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')
 turnTimerBar:SetStatusBarColor(0.25,0.85,0.35,1)
 turnTimerBar:SetMinMaxValues(0,1);turnTimerBar:SetValue(0);turnTimerBar:Hide()
 timerText=txt(frame,'Waiting for players','GameFontNormalSmall')
 timerText:SetPoint('TOP',frame,0,-368)
 timerText:SetTextColor(1,0.85,0.3)
 local infoBackdrop=CreateFrame('Frame',nil,frame);infoBackdrop:SetSize(746,48);infoBackdrop:SetPoint('TOP',frame,0,-377)
 infoBackdrop:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});infoBackdrop:SetBackdropColor(0,0,0,0)
 phaseText=txt(frame,'','GameFontNormalSmall');phaseText:SetPoint('TOPLEFT',frame,25,-385);phaseText:Hide()
 potText=txt(frame,'POT: 0s','GameFontNormal');potText:SetPoint('TOPLEFT',frame,25,-405)
 currentBetText=txt(frame,'CURRENT BET: 0s','GameFontNormal');currentBetText:SetPoint('TOPLEFT',frame,185,-405)
 toCallText=txt(frame,'TO CALL: 0s','GameFontNormal');toCallText:SetPoint('TOPLEFT',frame,370,-405)
 balanceText=txt(frame,'YOUR BALANCE: 0s','GameFontNormal');balanceText:SetPoint('TOPLEFT',frame,540,-405)
  -- Emphasized financial HUD: slightly larger, bold, with existing color coding.
  local hudFont='Fonts\\FRIZQT__.TTF'
  for _,label in ipairs({potText,currentBetText,toCallText,balanceText}) do
   label:SetFont(hudFont,14,'OUTLINE')
  end
 potText:SetTextColor(1,0.78,0.19);currentBetText:SetTextColor(1,0.49,0.16);toCallText:SetTextColor(0.39,0.77,1);balanceText:SetTextColor(0.52,0.95,0.59)
 turnText=txt(frame,'','GameFontNormalSmall');turnText:SetPoint('TOPRIGHT',frame,-26,-385)
 -- Reuse the familiar Draw-style primary table controls, with Hold'em handlers.
 local function joinTable()
  local n=R.HoldemNetwork
  if not n or not n.JoinSingle then
   if R.Print then R.Print('Holdem network is unavailable.') end
   return
  end
  local ok,why=n.JoinSingle()
  if not ok and why~='No active table' and R.Print then R.Print(why or 'Unable to join table.') end
 end
 local function leaveTable()
  if R.BarrensNetworkLeave then R.BarrensNetworkLeave()
  elseif R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby() end
 end
 local primary={
  {'Join Table','Interface\\Icons\\INV_Misc_GroupLooking',joinTable},
  {'Poker Table','Interface\\Icons\\INV_Misc_Coin_01',function()local f=_G.RaidPokerBarrensTable;if f and f:IsShown() then f:Hide() elseif R.OpenBarrensTable then R.OpenBarrensTable() end end},
  {'Start Game','Interface\\Icons\\INV_Gauntlets_05',function()if R.BarrensUnifiedStart then message(R.BarrensUnifiedStart()) else message(H.StartPreviewHand()) end end},
  {'Leader','Interface\\Icons\\INV_Misc_Head_Human_01',function()if R.OpenBarrensLeaderControls then R.OpenBarrensLeaderControls() end end},
  {'Leave Table','Interface\\Buttons\\UI-MinusButton-Up',leaveTable},
 }
 local primaryButtons={}
 for i,v in ipairs(primary) do
  local b=iconButton(frame,v[1],v[2],136,33,v[3])
  b:SetPoint('TOPLEFT',frame,26+(i-1)*148,-432)
  if i==1 then for j=1,b:GetNumRegions() do local region=select(j,b:GetRegions());if region and region.GetTexture and region:GetTexture()=='Interface\\Buttons\\UI-PlusButton-Up' then region:ClearAllPoints();region:SetPoint('LEFT',b,'LEFT',9,0) end end end
  primaryButtons[i]=b
 end
 startButton=primaryButtons[3]
 -- Reset remains available in Solo Debug, without occupying the primary row.
 resetButton=button(frame,'Reset',75,22,function()if R.BarrensUnifiedReset then R.BarrensUnifiedReset() else H.ResetPreview() end end)
 resetButton:SetPoint('TOPRIGHT',frame,-18,-760);resetButton:Hide() -- Reset remains in Solo Debug
 local function numberBox(x,y,initial)
  local e=CreateFrame('EditBox',nil,frame)
  e:SetSize(52,22);e:SetPoint('TOPLEFT',frame,x,y)
  e:SetAutoFocus(false);e:SetNumeric(true);e:SetMaxLetters(7)
  e:SetFontObject('ChatFontNormal');e:SetTextColor(1,1,1)
  e:SetTextInsets(6,6,0,0);e:SetJustifyH('LEFT')
  e:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
  e:SetBackdropColor(0.025,0.035,0.035,0.95)
  e:SetBackdropBorderColor(0.65,0.53,0.28,1)
  e:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
  e:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
  e:SetText(tostring(initial or 0));return e
 end
 raiseGold=numberBox(45,-555,0);raiseSilver=numberBox(116,-555,10)
 raiseBox=raiseSilver
 anteGold=numberBox(278,-555,0);anteSilver=numberBox(349,-555,10)
 stackGold=numberBox(509,-555,10);stackSilver=numberBox(580,-555,0)
 local function fieldLabel(text,x)
  local t=txt(frame,text,'GameFontHighlightSmall');t:SetPoint('TOPLEFT',frame,x,-540)
 end
 fieldLabel('Raise (Gold / Silver)',26);fieldLabel('Ante (Gold / Silver) - Game Master Only',258);fieldLabel('Starting Stack (G / S)',489)
 -- Keep the Ante inputs synchronized with the latest public table state.
 local lastAnte=nil
 local anteTicker=CreateFrame('Frame',nil,frame)
 local anteElapsed=0
 anteTicker:SetScript('OnUpdate',function(self,dt)
  anteElapsed=anteElapsed+dt;if anteElapsed<0.5 then return end;anteElapsed=0
  local snap=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot()
  local ante=snap and snap.ante
  if ante==nil and R.Holdem then ante=R.Holdem.ante end
  if ante~=nil and ante~=lastAnte and not anteGold:HasFocus() and not anteSilver:HasFocus() then
   lastAnte=ante;anteGold:SetText(tostring(math.floor(ante/100)));anteSilver:SetText(tostring(ante%100))
  end
 end)
local apply=button(frame,'Apply',90,31,function()
  local ante=anteGold:GetNumber()*100+anteSilver:GetNumber()
  local stack=stackGold:GetNumber()*100+stackSilver:GetNumber()
  -- Settings are forwarded only to an existing GM configuration API; never mutate the engine directly.
  if R.BarrensApplyTableSettings then message(R.BarrensApplyTableSettings(ante,stack))
  elseif R.Print then R.Print('Holdem: configure ante and starting stack using Player Management / Game Master.') end
 end);apply:SetPoint('TOPLEFT',frame,655,-552)
 local applyGear=apply:CreateTexture(nil,'OVERLAY')
 applyGear:SetTexture('Interface\\Icons\\INV_Misc_Gear_01')
 applyGear:SetSize(19,19);applyGear:SetPoint('LEFT',apply,'LEFT',7,0)
 local applyText=apply:GetFontString()
 if applyText then
  applyText:ClearAllPoints()
  applyText:SetPoint('LEFT',apply,'LEFT',29,0)
  applyText:SetPoint('RIGHT',apply,'RIGHT',-3,0)
  applyText:SetJustifyH('CENTER')
 end
 buttons={}
 local names={'Check','Call','Raise','Fold','All-In'}
 local acts={'CHECK','CALL','RAISE','FOLD','ALLIN'}
 for i=1,5 do
  local act=acts[i]
  local actionIcons={'Interface\\Icons\\INV_Shield_06','Interface\\Icons\\INV_Misc_Coin_01','Interface\\Icons\\Ability_Warrior_Charge','Interface\\Icons\\Ability_Creature_Cursed_02','Interface\\Icons\\INV_Misc_Bag_10'}
  local b=iconButton(frame,names[i],actionIcons[i],134,34,function()local amount=raiseGold:GetNumber()*100+raiseSilver:GetNumber();local ok,why=performAction(act,act=='RAISE' and amount or 0);message(ok,why);if ok and R.AnnounceLocalPokerAction then R.AnnounceLocalPokerAction('HOLDEM',act,amount)end end)
  b:SetPoint('TOPLEFT',frame,26+(i-1)*148,-479);buttons[i]=b
  if i==1 then for j=1,b:GetNumRegions() do local region=select(j,b:GetRegions());if region and region.GetTexture and region:GetTexture()=='Interface\\Icons\\INV_Shield_05' then region:ClearAllPoints();region:SetPoint('LEFT',b,'LEFT',9,0) end end end
 end
 if R.HF07RegisterHoldemActions then R.HF07RegisterHoldemActions(buttons,raiseGold,raiseSilver,anteGold,anteSilver,apply) end
 local presets=CreateFrame('Frame',nil,frame);presets:SetSize(746,88);presets:SetPoint('TOP',frame,0,-602)
 presets:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 presets:SetBackdropColor(0,0.035,0.025,0.66);presets:SetBackdropBorderColor(0.45,0.38,0.19,0.9)
 local presetsTitle=txt(presets,'BETTING PRESETS - CHOOSE AMOUNT THEN PRESS RAISE','GameFontNormalSmall');presetsTitle:SetPoint('TOPLEFT',presets,12,-10)
 local function setRaise(amount)
  amount=math.max(0,math.floor(tonumber(amount) or 0));raiseGold:SetText(tostring(math.floor(amount/100)));raiseSilver:SetText(tostring(amount%100))
 end
 local amounts={{'+10s',10},{'+50s',50},{'+100s',100}}
 for i,v in ipairs(amounts) do
  button(presets,v[1],111,25,function()setRaise(v[2])end):SetPoint('TOPLEFT',presets,12+(i-1)*121,-42)
 end
 button(presets,'1/4 Pot',111,25,function()local snap=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot();setRaise(math.max(1,math.floor(((snap and snap.pot) or H.pot or 0)/4)))end):SetPoint('TOPLEFT',presets,375,-42)
 button(presets,'1/2 Pot',111,25,function()local snap=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot();setRaise(math.max(1,math.floor(((snap and snap.pot) or H.pot or 0)/2)))end):SetPoint('TOPLEFT',presets,496,-42)
 button(presets,'Pot',111,25,function()local snap=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot();setRaise(math.max(1,(snap and snap.pot) or H.pot or 0))end):SetPoint('TOPLEFT',presets,617,-42)
 -- Removed obsolete LOCAL PREVIEW caption; state remains available in Solo Debug.
 historyText=txt(frame,'','GameFontHighlightSmall');historyText:SetPoint('TOPLEFT',frame,27,-723);historyText:SetWidth(725);historyText:SetHeight(17);historyText:SetJustifyH('LEFT')
 -- One aligned bottom row, following the 5-Card Draw layout.
 local activityButton=iconButton(frame,'Betting Activity','Interface\\Icons\\INV_Misc_Note_01',170,34,function()local w=_G.RaidPokerBarrensBettingActivity;if w and w:IsShown() then w:Hide() else R.OpenBarrensBettingActivity() end end)
 activityButton:SetPoint('BOTTOMLEFT',frame,216,76)
 local playerButton=iconButton(frame,'Player Management','Interface\\Icons\\INV_Misc_Head_Human_01',170,34,function()local f=_G.RaidPokerBarrensManagement;if f and f:IsShown() then f:Hide() elseif R.OpenBarrensManagement then R.OpenBarrensManagement() end end)
 playerButton:SetPoint('BOTTOMLEFT',frame,406,76)
 local statsButton=iconButton(frame,'Statistics','Interface\\Icons\\INV_Misc_Book_11',170,34,function()local w=_G.RaidPokerBarrensStatistics;if w and w:IsShown() then w:Hide() else R.OpenBarrensStatistics() end end)
 statsButton:SetPoint('BOTTOMLEFT',frame,596,76)
 local emotesButton=iconButton(frame,'Emotes','Interface\\Icons\\INV_Misc_Head_Human_02',170,34,function()if R.ToggleEmotesAnnouncements then R.ToggleEmotesAnnouncements('HOLDEM') elseif R.Print then R.Print('Emotes module not loaded; check addon files.')end end)
 emotesButton:SetPoint('BOTTOMLEFT',frame,26,76)
 -- History is available in the primary controls row. No duplicate button.
 applyWindowScale()
 frame:Hide()
end
local function refresh()
 if not frame then return end
 local s=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot() or H.GetPublicSnapshot()
 if not s then return end
 s.players=s.players or {};s.board=s.board or {};s.log=s.log or {}
 refreshActivity(s)
 -- Phase is available through game state; the redundant phase label is hidden.
 local shownPot=paidPot(s)
 potText:SetText((s.phase=='SHOWDOWN' and 'LAST POT (PAID): ' or 'POT: ')..money(shownPot))
 turnText:SetText(s.actionSeat and ('TURN: '..(s.players[s.actionSeat] and s.players[s.actionSeat].name or '?')) or '')
 currentBetText:SetText('CURRENT BET: '..money(s.currentBet or 0))
 local mySeat
 for seat,p in ipairs(s.players) do if p.name==UnitName('player') then mySeat=seat;break end end
 local me=mySeat and s.players[mySeat]
 local myBet=me and (tonumber(me.bet) or tonumber(me.streetBet) or 0) or 0
 toCallText:SetText('TO CALL: '..money(math.max(0,(tonumber(s.currentBet) or 0)-myBet)))
 balanceText:SetText('YOUR BALANCE: '..money(me and (me.stack or me.balance or 0) or 0))
 timerText:SetText(R.GetBarrensTurnTimerText and R.GetBarrensTurnTimerText(s) or (s.phase=='LOBBY' and 'Waiting for players' or ('Hand in progress  |  '..(s.phase or ''))))
 if turnTimerBar and R.GetBarrensTurnTimerProgress then
  local progress,active=R.GetBarrensTurnTimerProgress(s)
  if active then
   turnTimerBar:SetValue(progress);turnTimerBar:Show()
   if progress<0.25 then turnTimerBar:SetStatusBarColor(0.9,0.18,0.15,1)
   elseif progress<0.5 then turnTimerBar:SetStatusBarColor(0.95,0.65,0.12,1)
   else turnTimerBar:SetStatusBarColor(0.2,0.85,0.35,1) end
  else turnTimerBar:Hide() end
 end
 -- Local preview: seat 1 is the test user's hand. Never reuse this exposure in network play.
 local hole
 if R.BarrensUnifiedHole then
  for seat,p in ipairs(s.players) do if p.name==UnitName('player') then hole=R.BarrensUnifiedHole(seat,s);break end end
 else local p=H.players[1];hole=p and p.hole end
 for i=1,2 do local c=hole and hole[i];handCards[i]:SetCard(type(c)=='table' and H.CardLabel(c) or c,not c) end
 for i=1,5 do boardCards[i]:SetCard(s.board[i],false) end
 local network=R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK'
 local n=R.HoldemNetwork
 local myTurn=s.actionSeat and s.players[s.actionSeat] and s.players[s.actionSeat].name==UnitName('player')
 local active=s.phase~='LOBBY' and s.phase~='SHOWDOWN' and s.actionSeat and (not network or myTurn)
 for _,b in ipairs(buttons) do if active then b:Enable() else b:Disable() end end
 local canStart=not network or (n and n.active and n.owner and n.host==UnitName('player'))
 if canStart then startButton:Enable() else startButton:Disable() end
 if network then resetButton:Disable() else resetButton:Enable() end
 -- Redundant SOLO DEBUG / HAND STATUS line intentionally removed.
 local lines={};for i=math.max(1,#s.log-1),#s.log do if s.log[i] then lines[#lines+1]=s.log[i] end end
 historyText:SetText(table.concat(lines,'  |  '))
 if R.RefreshBarrensStatistics then R.RefreshBarrensStatistics() end
end
local prior=H.Refresh
function H.Refresh()
 if prior then prior() end
 refresh()
end
function R.RefreshBarrensUnifiedControls() if frame and frame:IsShown() then refresh() end end
function R.OpenBarrensControls()
 build();refresh();if frame:IsShown() then frame:Hide() else frame:Show();frame:SetFrameStrata('DIALOG');frame:Raise() end
end
