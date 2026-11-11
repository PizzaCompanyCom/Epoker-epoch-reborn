-- Raid Poker v1.8.0-beta2a: readable suits and non-overlapping seats.
-- Isolated from Draw's Poker Table; no raid messaging or real balance changes.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local T={}
-- Independent visual preferences; the Draw renderer and game rules are untouched.
local defaults={bet=true,turn=true,winner=true,portraits=true,sound=true,timer=true,announcement=true,coinDuration=0.9,glowIntensity=70}
local function prefs()
 if not RaidPokerWotLKDB then return defaults end
 if type(RaidPokerWotLKDB.barrensVisualEffects)~='table' then
  RaidPokerWotLKDB.barrensVisualEffects={bet=true,turn=true,winner=true,portraits=true,sound=true,timer=true,announcement=true,coinDuration=0.9,glowIntensity=70}
 end
 local p=RaidPokerWotLKDB.barrensVisualEffects
 for k,v in pairs(defaults) do if p[k]==nil then p[k]=v end end
 return p
end
local effects={sprites={},clock=0,previous=nil,options=nil,buttons={},lastActionSeat=nil,turnSeconds=0,announcedHand=nil}
local feltArea,coinTarget,seatWidgets
local function playSound(kind)
 if not prefs().sound then return end
 -- Native client sounds only. No message-alert sounds.
 if kind=='coin' then PlaySound('LOOTWINDOWCOINSOUND')
 elseif kind=='win' then PlaySound('LEVELUP') end
end
local function startCoins(fromX,fromY,toX,toY,amount)
 if not prefs().bet or not feltArea or not amount or amount<=0 then return end
 local count=math.min(5,math.max(1,math.floor(amount/100)+1))
 for n=1,count do
  local t=feltArea:CreateTexture(nil,'OVERLAY')
  t:SetTexture(amount>=100 and 'Interface\\MoneyFrame\\UI-GoldIcon' or 'Interface\\MoneyFrame\\UI-SilverIcon')
  t:SetSize(17,17)
  t:SetPoint('CENTER',feltArea,'CENTER',fromX,fromY)
  t:Show()
  effects.sprites[#effects.sprites+1]={tex=t,x=fromX,y=fromY,tx=toX,ty=toY,t=-(n-1)*0.085,duration=math.max(0.4,math.min(1.6,tonumber(prefs().coinDuration) or 0.9))}
 end
 playSound('coin')
end
local function advanceEffects(self,dt)
 effects.clock=effects.clock+dt
 local snapshot=H.GetPublicSnapshot and H.GetPublicSnapshot()
 if snapshot and snapshot.actionSeat~=effects.lastActionSeat then
  effects.lastActionSeat=snapshot.actionSeat
  effects.turnSeconds=0
 end
 if snapshot and snapshot.actionSeat and snapshot.phase~='SHOWDOWN' then effects.turnSeconds=effects.turnSeconds+dt end
 local intensity=math.max(0.2,math.min(1,(tonumber(prefs().glowIntensity) or 70)/100))
 local wave=0.35+0.65*(0.5+0.5*math.sin(effects.clock*4.0))
 if seatWidgets then
  for i,w in ipairs(seatWidgets) do
   if w.actionLayer and w.actionLayer:IsShown() and w.actionUntil and GetTime()>=w.actionUntil then w.actionLayer:Hide() end
   if w.glow and w.glow:IsShown() then w.glow:SetAlpha(wave*intensity) end
   if w.winnerGlow and w.winnerGlow:IsShown() then w.winnerGlow:SetAlpha((0.45+0.55*(0.5+0.5*math.sin(effects.clock*3.0)))*intensity) end
   if w.timerBG then
    local active=snapshot and snapshot.actionSeat==i and snapshot.phase~='SHOWDOWN' and prefs().timer
    if active then
     w.timerBG:Show();w.timerFill:Show()
     local remaining=math.max(0,1-effects.turnSeconds/30)
     w.timerFill:SetWidth(math.max(1,130*remaining))
    else w.timerBG:Hide();w.timerFill:Hide() end
   end
  end
 end
 for i=#effects.sprites,1,-1 do
  local a=effects.sprites[i];a.t=a.t+dt
  local k=math.max(0,math.min(1,a.t/a.duration))
  a.tex:ClearAllPoints();a.tex:SetPoint('CENTER',feltArea,'CENTER',a.x+(a.tx-a.x)*k,a.y+(a.ty-a.y)*k)
  if k>=1 then a.tex:Hide();table.remove(effects.sprites,i) end
 end
end
local function clearCoins()
 for _,a in ipairs(effects.sprites) do a.tex:Hide() end
 effects.sprites={}
end

local f,phase,potText,turnText,boardCards,actionButtons,raiseBox,historyText,optionsText,themeButton,surface,rim,sideText,themeLines,potGold,potSilver,potGoldIcon,potSilverIcon
local personalCards,personalTitle,potStackGold,potStackSilver,winnerPanel,winnerText,phaseFooter
local function money(amount)
 amount=math.max(0,math.floor(tonumber(amount) or 0))
 local g=math.floor(amount/100)
 local s=amount%100
 if g>0 and s>0 then return g..'g '..s..'s' end
 if g>0 then return g..'g' end
 return s..'s'
end
-- Winner category is derived from the evaluated seven-card hand, not from card art.
local handCategories={'HIGH CARD','ONE PAIR','TWO PAIR','THREE OF A KIND','STRAIGHT','FLUSH','FULL HOUSE','FOUR OF A KIND','STRAIGHT FLUSH'}
local function showdownHandLabel(snapshot)
 if snapshot.phase~='SHOWDOWN' then return nil end
 local bestCategory=nil
 for seat,amount in pairs(snapshot.winners or {}) do
  if (tonumber(amount) or 0)>0 then
   local rank=snapshot.winningRanks and snapshot.winningRanks[seat]
   local category=type(rank)=='table' and tonumber(rank[1]) or nil
   if category and (not bestCategory or category>bestCategory) then bestCategory=category end
  end
 end
 if bestCategory then return handCategories[bestCategory+1] end
 -- A fold victory has no poker combination; do not invent one.
 return 'WINNER BY FOLD'
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

local themeIndex=1
local tableArt
-- Independent Poker Table surfaces, NOT the backgrounds of Game Controls.
-- The first four images are the actual decorated poker tables already used
-- by the original Ironforge 5-Card Draw artwork pack.
local tableTextures={'PokerFelt'}
local function savedTheme()
 local db=RaidPokerWotLKDB
 local n=db and tonumber(db.barrensPokerTableTheme) or 1
 -- Migrate previously selected decorative themes to the remaining felt theme.
 if n>=2 and n<=4 then n=1 elseif n>=5 then n=n-3 end
 return math.max(1,math.min(9,math.floor(n)))
end
local themes={
 {'Classic Green Felt',0.06,0.24,0.13},
 {'Solid Black',0.035,0.035,0.04},
 {'Dark Charcoal',0.10,0.11,0.12},
 {'Midnight Blue',0.07,0.11,0.20},
 {'Dark Green',0.05,0.20,0.14},
 {'Burgundy',0.24,0.07,0.12},
 {'Dark Brown',0.20,0.12,0.08},
 {'Royal Blue',0.09,0.13,0.29},
 {'Deep Purple',0.17,0.09,0.23}
}
local function applyTheme()
 themeIndex=math.max(1,math.min(#themes,themeIndex))
 local t=themes[themeIndex]
 if tableArt then
  local key=tableTextures[themeIndex]
  if key then
   tableArt:SetTexture('Interface\\AddOns\\RaidPoker_WotLK\\Backgrounds\\'..key..'.tga')
   tableArt:SetVertexColor(1,1,1,1)
   tableArt:Show()
  else tableArt:Hide() end
 end
 if RaidPokerWotLKDB then RaidPokerWotLKDB.barrensPokerTableTheme=themeIndex end
 if surface then surface:SetVertexColor(t[2],t[3],t[4],1) end
 if rim then rim:SetVertexColor(math.min(1,t[2]+0.15),math.min(1,t[3]+0.10),math.min(1,t[4]+0.06),1) end
 if themeLines then for _,line in ipairs(themeLines) do if themeIndex<=1 then line:Hide() else line:Show() end end end
 if themeButton then themeButton:SetText("Theme: "..t[1]) end
end
local function label(parent,text,size)
 local fs=parent:CreateFontString(nil,'OVERLAY',size or 'GameFontHighlight')
 fs:SetText(text or '');return fs
end
local function button(parent,text,w,h,click)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,h);b:SetText(text);b:SetScript('OnClick',click);return b
end
local function rect(parent,w,h,r,g,b,a)
 local t=parent:CreateTexture(nil,'BACKGROUND');t:SetTexture('Interface\\Buttons\\WHITE8X8');t:SetSize(w,h);t:SetVertexColor(r,g,b,a or 1);return t
end
local function card(parent,w,h)
 local box=CreateFrame('Frame',nil,parent);box:SetSize(w,h)
 local edge=rect(box,w,h,0.75,0.57,0.27,1);edge:SetPoint('CENTER')
 local inner=rect(box,w-4,h-4,0.055,0.11,0.25,1);inner:SetPoint('CENTER')
 local art=box:CreateTexture(nil,'ARTWORK');art:SetPoint('TOPLEFT',box,'TOPLEFT',2,-2);art:SetPoint('BOTTOMRIGHT',box,'BOTTOMRIGHT',-2,2)
 local crest=label(box,'RAID','GameFontNormalSmall');crest:SetPoint('CENTER');crest:SetTextColor(0.96,0.77,0.38)
 local fallback=label(box,'','GameFontNormalSmall');fallback:SetPoint('CENTER');fallback:Hide()
 function box:SetCard(v,hidden)
  if hidden then art:Hide();art:SetTexture(nil);inner:SetVertexColor(0.055,0.11,0.25,1);crest:Show();fallback:Hide();return end
  local rank,suit
  if v then rank,suit=string.match(v,'^(%d+)([SHDC])$') end
  if v and not rank then rank,suit=string.match(v,'^([JQKA])([SHDC])$') end
  if rank and suit then
   local path='Interface\\AddOns\\RaidPoker_WotLK\\Cards\\'..rank..suit..'.tga'
   art:SetTexture(path);art:Show();inner:SetVertexColor(0.97,0.94,0.84,1)
   crest:Hide();fallback:Hide()
  else
   art:Hide();art:SetTexture(nil);inner:SetVertexColor(0.12,0.16,0.18,1);crest:Hide();fallback:Hide()
  end
 end
 box:SetCard(nil,false)
 return box
end
local function makeSeat(parent,i,x,y)
 local seat=CreateFrame('Frame',nil,parent);seat:SetSize(138,79);seat:SetPoint('CENTER',parent,'CENTER',x,y)
 seat:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 seat:SetBackdropColor(0.035,0.035,0.04,0.94);seat:SetBackdropBorderColor(0.43,0.34,0.20,1)
 local bg=rect(seat,132,73,0.07,0.10,0.11,0.35);bg:SetPoint('CENTER')
 local glow=rect(seat,142,83,0.18,0.67,0.29,0.32);glow:SetPoint('CENTER');glow:Hide();glow:SetDrawLayer('BACKGROUND',-1)
 local name=label(seat,'','GameFontNormalSmall');name:SetPoint('TOP',seat,'TOP',0,-5);name:SetWidth(104)
 local status=label(seat,'','GameFontNormalLarge');status:SetPoint('TOP',seat,'TOP',8,-22);status:SetWidth(115);status:SetJustifyH('CENTER')
 local moneyIcon=seat:CreateTexture(nil,'OVERLAY');moneyIcon:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon')
 moneyIcon:SetSize(16,16);moneyIcon:SetPoint('RIGHT',status,'LEFT',2,0)
 local c1=card(seat,23,32);c1:SetPoint('BOTTOM',seat,'BOTTOM',-15,4)
 local c2=card(seat,23,32);c2:SetPoint('BOTTOM',seat,'BOTTOM',15,4)
 local portrait=seat:CreateTexture(nil,'ARTWORK')
 portrait:SetTexture('Interface\\Icons\\INV_Misc_Dice_02')
 portrait:SetTexCoord(0,1,0,1)
 portrait:SetSize(28,28);portrait:SetPoint('TOPLEFT',seat,'TOPLEFT',4,-6)
 local portraitBorder=seat:CreateTexture(nil,'OVERLAY')
 portraitBorder:SetTexture(nil)
 portraitBorder:Hide()
 local winnerGlow=rect(seat,142,83,0.95,0.74,0.18,0.38)
 winnerGlow:SetPoint('CENTER');winnerGlow:SetDrawLayer('BACKGROUND',-1);winnerGlow:Hide()
 local badge=label(seat,'','GameFontNormalSmall');badge:SetPoint('TOPRIGHT',seat,'TOPRIGHT',-4,-4)
 local winnerLabel=label(seat,'','GameFontNormalSmall');winnerLabel:Hide()
 local stateLabel=label(seat,'','GameFontNormalSmall');stateLabel:SetPoint('BOTTOMLEFT',seat,'BOTTOMLEFT',3,4);stateLabel:Hide()
 local actionLayer=CreateFrame('Frame',nil,seat)
 actionLayer:SetAllPoints(seat);actionLayer:SetFrameLevel(seat:GetFrameLevel()+12)
 local actionCover=actionLayer:CreateTexture(nil,'ARTWORK')
 actionCover:SetTexture('Interface\\Buttons\\WHITE8X8')
 actionCover:SetPoint('TOPLEFT',actionLayer,'TOPLEFT',3,-19)
 actionCover:SetPoint('BOTTOMRIGHT',actionLayer,'BOTTOMRIGHT',-3,3)
 actionCover:SetVertexColor(.02,.05,.08,.97)
 local actionLabel=actionLayer:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 actionLabel:SetPoint('CENTER',actionLayer,'CENTER',0,-8)
 if actionLabel.SetFont then actionLabel:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE') end
 actionLabel:SetShadowOffset(1,-1)
 actionLayer:Hide()
 local timerBG=rect(seat,130,3,0.13,0.13,0.13,0.9);timerBG:SetPoint('BOTTOM',seat,'BOTTOM',0,-3);timerBG:Hide()
 local timerFill=rect(seat,130,3,0.20,0.9,0.32,0.95);timerFill:SetPoint('LEFT',timerBG,'LEFT');timerFill:Hide()
 return {frame=seat,bg=bg,glow=glow,winnerGlow=winnerGlow,portrait=portrait,name=name,status=status,moneyIcon=moneyIcon,cards={c1,c2},badge=badge,winnerLabel=winnerLabel,stateLabel=stateLabel,timerBG=timerBG,timerFill=timerFill,actionCover=actionCover,actionLabel=actionLabel,actionLayer=actionLayer}
end
local function feedback(ok,msg)
 if not ok and R.Print then R.Print('Barrens Holdem: '..(msg or 'Invalid action')) end
end

local function arrangePairedWindows(tableFrame, generalFrame, tableScale, generalScale)
 if not tableFrame or not generalFrame or not tableFrame:IsShown() or not generalFrame:IsShown() then return end
 local l1,r1=tableFrame:GetLeft(),tableFrame:GetRight()
 local l2,r2=generalFrame:GetLeft(),generalFrame:GetRight()
 if l1 and r1 and l2 and r2 and (r1<=l2 or r2<=l1) then return end
 local screenW=UIParent:GetWidth()
 local ratio=math.min(1,(screenW-40)/(tableFrame:GetWidth()*tableScale+generalFrame:GetWidth()*generalScale+20))
 local ts=tableScale*ratio;local gs=generalScale*ratio
 tableFrame:SetScale(ts);generalFrame:SetScale(gs)
 local total=tableFrame:GetWidth()*ts+generalFrame:GetWidth()*gs+20
 local left=(screenW-total)/2
 tableFrame:ClearAllPoints();tableFrame:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',left/ts,(UIParent:GetHeight()/2-tableFrame:GetHeight()*ts/2)/ts)
 generalFrame:ClearAllPoints();generalFrame:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',(left+tableFrame:GetWidth()*ts+20)/gs,(UIParent:GetHeight()/2-generalFrame:GetHeight()*gs/2)/gs)
end

local function build()
 if f then return end
 f=CreateFrame('Frame','RaidPokerBarrensTable',UIParent)
 f:SetSize(940,570);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetMovable(true);f:EnableMouse(true)
 f:RegisterForDrag('LeftButton');f:SetClampedToScreen(true)
 f:SetScript('OnDragStart',function(self)self:Raise();self:StartMoving()end)
 f:HookScript('OnMouseDown',function(self)self:Raise()end)
 f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing(); if RaidPokerWotLKDB then RaidPokerWotLKDB.barrensTablePosition={self:GetCenter()} end end)
 if RaidPokerWotLKDB and RaidPokerWotLKDB.barrensTablePosition then local p=RaidPokerWotLKDB.barrensTablePosition; if p[1] and p[2] then f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'BOTTOMLEFT',p[1],p[2]) end end
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=false,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 f:SetBackdropColor(0.055,0.075,0.065,1)
 f:SetBackdropBorderColor(0.65,0.50,0.27,1)
 -- Header title intentionally omitted; controls use this space.
 button(f,'X',30,25,function()f:Hide()end):SetPoint('TOPRIGHT',f,'TOPRIGHT',-15,-13)
 local felt=CreateFrame('Frame',nil,f);felt:SetSize(810,440);felt:SetPoint('TOP',f,'TOP',0,-55)
 feltArea=felt;felt:SetScript('OnUpdate',advanceEffects)
 surface=rect(felt,810,440,0.08,0.26,0.19,1);surface:SetPoint('CENTER')
 tableArt=felt:CreateTexture(nil,'BACKGROUND',0)
 tableArt:SetAllPoints(felt)
 tableArt:SetTexCoord(0,1,0,1)
 themeIndex=savedTheme()
 rim=rect(felt,818,448,0.34,0.24,0.12,0.7);rim:SetPoint('CENTER');rim:SetDrawLayer('BACKGROUND',-2)
 themeLines={}
 for i=1,12 do local line=rect(felt,794,1,0.07,0.04,0.02,0.16);line:SetPoint('TOP',felt,'TOP',0,-12-i*32);themeLines[i]=line end
 -- The community board stays centered. The local player's private cards have
 -- their own row underneath; no opponent's private cards are exposed here.
 phase=label(felt,'','GameFontNormalSmall');phase:Hide()
 turnText=label(felt,'','GameFontHighlight');turnText:SetPoint('CENTER',felt,'CENTER',0,143);turnText:SetWidth(460);turnText:SetJustifyH('CENTER');turnText:SetFont('Fonts\\FRIZQT__.TTF',17,'OUTLINE')
 boardCards={}
 for i=1,5 do local c=card(felt,65,91);c:SetPoint('CENTER',felt,'CENTER',-144+(i-1)*72,32);boardCards[i]=c end
 personalTitle=label(felt,'YOUR HOLE CARDS','GameFontNormalSmall');personalTitle:SetPoint('CENTER',felt,'CENTER',0,-35)
 personalCards={}
 for i=1,2 do local c=card(felt,58,80);c:SetPoint('CENTER',felt,'CENTER',-34+(i-1)*68,-93);personalCards[i]=c end
 -- Single, compact pot panel above the board; gold and silver stacks grow
 -- vertically without extending into the community cards.
 local potPanel=CreateFrame('Frame',nil,felt);potPanel:SetSize(260,50);potPanel:SetPoint('CENTER',felt,'CENTER',0,189)
 coinTarget={0,174}
 local potTitle=label(potPanel,'POT:','GameFontNormalLarge');potTitle:SetPoint('LEFT',potPanel,'LEFT',10,0)
 potText=label(potPanel,'0s','GameFontNormalLarge');potText:SetPoint('LEFT',potTitle,'RIGHT',5,0)
 potGoldIcon=potPanel:CreateTexture(nil,'ARTWORK');potGoldIcon:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon');potGoldIcon:SetSize(15,15);potGoldIcon:SetPoint('LEFT',potPanel,'LEFT',172,0);potGoldIcon:Hide()
 potSilverIcon=potPanel:CreateTexture(nil,'ARTWORK');potSilverIcon:SetTexture('Interface\\MoneyFrame\\UI-SilverIcon');potSilverIcon:SetSize(15,15);potSilverIcon:SetPoint('LEFT',potPanel,'LEFT',211,0);potSilverIcon:Hide()
 potGold=label(potPanel,'','GameFontHighlightSmall');potGold:Hide()
 potSilver=label(potPanel,'','GameFontHighlightSmall');potSilver:Hide()
 potStackGold={};potStackSilver={}
 for i=1,4 do
  local gt=potPanel:CreateTexture(nil,'OVERLAY');gt:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon');gt:SetSize(17,17);gt:SetPoint('BOTTOMLEFT',potPanel,'BOTTOMLEFT',169+(i-1)%2*10,11+math.floor((i-1)/2)*9);gt:Hide();potStackGold[i]=gt
  local st=potPanel:CreateTexture(nil,'OVERLAY');st:SetTexture('Interface\\MoneyFrame\\UI-SilverIcon');st:SetSize(17,17);st:SetPoint('BOTTOMLEFT',potPanel,'BOTTOMLEFT',211+(i-1)%2*10,11+math.floor((i-1)/2)*9);st:Hide();potStackSilver[i]=st
 end
 sideText=label(felt,'','GameFontHighlightSmall');sideText:SetPoint('CENTER',felt,'CENTER',0,-156);sideText:SetWidth(370);sideText:SetJustifyH('CENTER')
 -- Dedicated announcement overlay: above the card frames, not behind them.
 winnerPanel=CreateFrame('Frame',nil,felt);winnerPanel:SetSize(395,65);winnerPanel:SetPoint('CENTER',felt,'CENTER',0,38);winnerPanel:SetFrameLevel(felt:GetFrameLevel()+12)
 local winnerBG=winnerPanel:CreateTexture(nil,'BACKGROUND');winnerBG:SetAllPoints(winnerPanel);winnerBG:SetTexture('Interface\\Buttons\\WHITE8X8');winnerBG:SetVertexColor(0.10,0.055,0.025,0.94)
 winnerText=label(winnerPanel,'','GameFontNormalLarge');winnerText:SetPoint('CENTER');winnerText:SetWidth(380);winnerText:SetJustifyH('CENTER');winnerPanel:Hide()
 phaseFooter=label(f,'','GameFontNormalLarge');phaseFooter:SetPoint('BOTTOM',f,'BOTTOM',0,22);phaseFooter:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE')
 seatWidgets={}
 -- Six seats, three on either side, leaving the board and pot unobstructed.
 -- Preserve the four test players at the outer corners.
 local coords={{-305,-145},{-305,0},{-305,145},{305,-145},{305,0},{305,145}}
 for i=1,6 do seatWidgets[i]=makeSeat(felt,i,coords[i][1],coords[i][2]) end
 -- Theme switch is created inside Settings Table below.
 applyTheme()
 -- Main window is opened independently; no redundant navigation button
 local optionsButton=button(f,'Effects',94,23,function()
  if effects.options then
   if effects.options:IsShown() then effects.options:Hide() else effects.options:Show() end
  end
 end)
 optionsButton:SetPoint('TOPRIGHT',f,'TOPRIGHT',-61,-17)
 optionsButton:SetText('Settings Table')
 optionsButton:SetWidth(130)
 local general=button(f,'Open General',125,25,function()if R.OpenBarrensControls then R.OpenBarrensControls() elseif _G.RaidPokerBarrensGameControls then _G.RaidPokerBarrensGameControls:Show() end
  arrangePairedWindows(f,_G.RaidPokerBarrensGameControls,(RaidPokerWotLKDB and RaidPokerWotLKDB.barrensTableScale) or 1,(RaidPokerWotLKDB and RaidPokerWotLKDB.barrensWindowScale) or 1) end)
 general:SetPoint('TOPRIGHT',f,'TOPRIGHT',-200,-16)
 local closeBots=button(f,'Close Bots',115,25,function()if R.BarrensCloseSoloGame then local ok,err=R.BarrensCloseSoloGame();if not ok and R.Print then R.Print(err or 'Unable to close bots') end end end)
 closeBots:SetPoint('TOPLEFT',f,'TOPLEFT',15,-16)
  local soloBots=button(f,'Solo Bots',115,25,function()
   if R.OpenBarrensSoloDebug then R.OpenBarrensSoloDebug() end
  end)
  soloBots:SetPoint('TOPLEFT',f,'TOPLEFT',140,-16)
 local startGame=button(f,'Start Game',130,25,function()
  local ok,err
  local n=R.HoldemNetwork
  if n and n.active and not n.owner then
   StaticPopup_Show('EPOKER_GM_START_WARNING',n.host or 'Unknown')
   return
  end
  if R.BarrensUnifiedStart then ok,err=R.BarrensUnifiedStart() elseif H.StartPreviewHand then ok,err=H.StartPreviewHand() end
  if ok==false and R.Print then R.Print(err or 'Cannot start game') end
 end)
 startGame:SetPoint('TOPLEFT',f,'TOPLEFT',420,-16)
 local leaveTable=button(f,'Leave Table',115,25,function()
  local n=R.HoldemNetwork
  if n and n.active then
   if n.owner then StaticPopup_Show('EPOKER_HOLDEM_GM_LEAVE_WARNING')
   elseif R.BarrensNetworkLeave then
    -- A live hand must be resolved by the Game Master before a voluntary exit.
    local phase=R.Holdem and R.Holdem.phase or 'LOBBY'
    if phase~='LOBBY' and phase~='SHOWDOWN' then
     if R.Print then R.Print('Finish the current hand before leaving this table.') end
    else R.BarrensNetworkLeave() end
   end
  elseif R.BarrensCloseSoloGame then R.BarrensCloseSoloGame() end
 end)
 leaveTable:SetPoint('TOPLEFT',f,'TOPLEFT',265,-16)
 local function headerIcon(b,texture)
  local t=b:CreateTexture(nil,'OVERLAY')
  t:SetTexture(texture);t:SetSize(16,16);t:SetPoint('LEFT',b,'LEFT',5,0)
  b:SetText('   '..b:GetText())
 end
 headerIcon(soloBots,'Interface\\Icons\\INV_Misc_Dice_02')
 headerIcon(leaveTable,'Interface\\Icons\\Ability_Rogue_FeignDeath')
 headerIcon(closeBots,'Interface\\Icons\\Ability_Rogue_FeignDeath')
 headerIcon(startGame,'Interface\\Icons\\INV_Misc_Coin_01')
 headerIcon(general,'Interface\\Icons\\INV_Misc_Book_09')
 headerIcon(optionsButton,'Interface\\Icons\\Trade_Engineering')
 for _,b in ipairs({optionsButton,general,closeBots,soloBots,leaveTable,startGame}) do
  b:SetFrameLevel(f:GetFrameLevel()+60)
  b:HookScript('OnMouseDown',function()f:Raise()end)
 end
 local op=CreateFrame('Frame',nil,UIParent)
 -- Anchor the settings to UIParent, not the scaled table. Otherwise the slider moves under the mouse while dragging.
	op:SetSize(270,540);op:SetPoint('CENTER',UIParent,'CENTER',590,0)
 op:SetFrameStrata('FULLSCREEN_DIALOG')
 op:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=20,insets={left=6,right=6,top=6,bottom=6}})
 local closeSettings=button(op,'X',26,24,function()op:Hide()end)
 closeSettings:SetPoint('TOPRIGHT',op,'TOPRIGHT',-12,-12)
 local scaleText=label(op,'Table Scale: 100%','GameFontHighlightSmall');scaleText:SetPoint('TOP',op,'TOP',0,-389)
 local scale=CreateFrame('Slider',nil,op,'OptionsSliderTemplate');scale:SetWidth(170);scale:SetHeight(14);scale:SetPoint('TOP',op,'TOP',0,-413);scale:SetMinMaxValues(0.7,1.3);scale:SetValueStep(0.05)
 scale:SetScript('OnValueChanged',function(self,v) v=math.max(0.7,math.min(1.3,math.floor(v*20+0.5)/20));if RaidPokerWotLKDB then RaidPokerWotLKDB.barrensTableScale=v end;f:SetScale(v);scaleText:SetText('Table Scale: '..math.floor(v*100+0.5)..'%') end)
 scale:SetValue((RaidPokerWotLKDB and RaidPokerWotLKDB.barrensTableScale) or 1)
 local opTitle=label(op,'POKER VISUAL EFFECTS','GameFontNormal');opTitle:SetPoint('TOP',op,0,-15)
 themeButton=button(op,'Theme',210,23,function()themeIndex=(themeIndex%#themes)+1;applyTheme()end)
 themeButton:SetPoint('TOP',op,'TOP',0,-483)
 applyTheme()
 local opts={{'bet','Bet Effects'},{'turn','Active Turn Glow'},{'winner','Winner Effects'},{'portraits','Player Portraits'},{'sound','Sound Effects'},{'timer','Turn Timer'},{'announcement','Winner Announcement'}}
 for j,opt in ipairs(opts) do
  local key=opt[1];local b=button(op,'',200,25,function(self)
   local p=prefs();p[key]=not p[key];self:SetText(opt[2]..': '..(p[key] and 'ON' or 'OFF'))
   if key=='bet' and not p[key] then clearCoins() end
   if H.Refresh then H.Refresh() end
  end)
  b:SetPoint('TOP',op,'TOP',0,-27-j*28)
  effects.buttons[key]={button=b,label=opt[2]}
 end
 local durationText=label(op,'Coin Duration: 0.9s','GameFontHighlightSmall');durationText:SetPoint('TOP',op,'TOP',0,-260)
 local duration=CreateFrame('Slider',nil,op,'OptionsSliderTemplate');duration:SetWidth(180);duration:SetHeight(16);duration:SetPoint('TOP',op,'TOP',0,-280);duration:SetMinMaxValues(0.4,1.6);duration:SetValueStep(0.1);duration:SetValue(tonumber(prefs().coinDuration) or 0.9)
 duration:SetScript('OnValueChanged',function(self,v) local rounded=math.floor(v*10+0.5)/6;prefs().coinDuration=rounded;durationText:SetText(string.format('Coin Duration: %.1fs',rounded)) end)
 local glowText=label(op,'Glow Intensity: 70%','GameFontHighlightSmall');glowText:SetPoint('TOP',op,'TOP',0,-314)
 local glowSlider=CreateFrame('Slider',nil,op,'OptionsSliderTemplate');glowSlider:SetWidth(180);glowSlider:SetHeight(16);glowSlider:SetPoint('TOP',op,'TOP',0,-333);glowSlider:SetMinMaxValues(20,100);glowSlider:SetValueStep(10);glowSlider:SetValue(tonumber(prefs().glowIntensity) or 70)
 glowSlider:SetScript('OnValueChanged',function(self,v) local rounded=math.floor(v/6+0.5)*10;prefs().glowIntensity=rounded;glowText:SetText('Glow Intensity: '..rounded..'%') end)
 effects.options=op;op:Hide()
 f:HookScript('OnHide',function()op:Hide()end)
 -- Local preview caption removed from Poker Table.
  -- Visual poker table only: betting and management belong to the main game window.
 f:Hide()
end
local function update()
 if not f then return end
 local s=(R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot()) or H.GetPublicSnapshot()
 if not s then return end
 s.players=s.players or {};s.board=s.board or {};s.winners=s.winners or {};s.log=s.log or {}
 local prev=effects.previous
 if prev and prev.handNumber==s.handNumber then
  for i,p in ipairs(s.players) do
   local old=prev.players[i]
   if old and (p.committed or 0)>(old.committed or 0) then
    local xy=({{-305,-145},{-305,0},{-305,145},{305,-145},{305,0},{305,145}})[i]
    if xy then startCoins(xy[1],xy[2],coinTarget[1],coinTarget[2],p.committed-old.committed) end
   end
  end
  if prev.phase~='SHOWDOWN' and s.phase=='SHOWDOWN' then
   for i,gain in pairs(s.winners or {}) do
    local xy=({{-305,-145},{-305,0},{-305,145},{305,-145},{305,0},{305,145}})[i]
    if xy then startCoins(coinTarget[1],coinTarget[2],xy[1],xy[2],gain) end
   end
   if next(s.winners or {}) then playSound('win') end
  end
 elseif prev and prev.handNumber~=s.handNumber then
  clearCoins()
  for i,p in ipairs(s.players) do
   if (p.committed or 0)>0 then
    local xy=({{-305,-145},{-305,0},{-305,145},{305,-145},{305,0},{305,145}})[i]
    if xy then startCoins(xy[1],xy[2],coinTarget[1],coinTarget[2],p.committed) end
   end
  end
 end
 effects.previous={handNumber=s.handNumber,phase=s.phase,players={},winners=s.winners}
 for i,p in ipairs(s.players) do effects.previous.players[i]={committed=p.committed or 0} end
 for key,v in pairs(effects.buttons) do v.button:SetText(v.label..': '..(prefs()[key] and 'ON' or 'OFF')) end
 phaseFooter:SetText('Hand '..tostring(s.handNumber or 0)..'  |  '..tostring(s.phase or 'LOBBY'))
 local total=paidPot(s)
 potText:SetText(money(total))
 local gold=math.floor(total/100)
 local silver=total%100
 local goldCount=gold>0 and math.min(4,1+math.floor(math.log(gold)/math.log(4))) or 0
 local silverCount=silver>0 and math.min(4,1+math.floor(silver/25)) or 0
 for i=1,4 do
  if i<=goldCount then potStackGold[i]:Show() else potStackGold[i]:Hide() end
  if i<=silverCount then potStackSilver[i]:Show() else potStackSilver[i]:Hide() end
 end
 local parts={}
 if s.phase=='SHOWDOWN' then
  for j,p in ipairs(s.sidePots or {}) do
   parts[#parts+1]=(j==1 and 'Main: ' or ('Side '..(j-1)..': '))..money(p.amount)
  end
 end
 sideText:SetText(table.concat(parts,'\n'))
 if s.phase=='SHOWDOWN' then
  turnText:SetText('SHOWDOWN')
  turnText:SetTextColor(1,0.78,0.18)
 else
  turnText:SetText(s.actionSeat and s.players[s.actionSeat] and ('TURN: '..s.players[s.actionSeat].name) or '')
  turnText:SetTextColor(1,0.95,0.75)
 end
 for i=1,5 do boardCards[i]:SetCard(s.board[i],false) end
 local localSeat=nil
 for i,p in ipairs(s.players) do if p.name==UnitName('player') then localSeat=i;break end end
 local ownHole=localSeat and R.BarrensUnifiedHole and R.BarrensUnifiedHole(localSeat,s) or nil
 local hasOwnCards=ownHole and ownHole[1] and ownHole[2]
 for i=1,2 do
  local value=hasOwnCards and ownHole[i] or nil
  personalCards[i]:SetCard(value and (type(value)=='string' and value or H.CardLabel(value)) or nil,false)
  if hasOwnCards then personalCards[i]:Show() else personalCards[i]:Hide() end
 end
 if hasOwnCards then personalTitle:Show() else personalTitle:Hide() end
 for i,w in ipairs(seatWidgets) do
  local p=s.players[i]
  if p then
   w.frame:Show()
   if prefs().turn and s.actionSeat==i then w.glow:Show() else w.glow:Hide() end
   if prefs().winner and s.phase=='SHOWDOWN' and s.winners and s.winners[i] then w.winnerGlow:Show() else w.winnerGlow:Hide() end
   if prefs().portraits then w.portrait:Show() else w.portrait:Hide() end
   local didWin=prefs().winner and s.phase=='SHOWDOWN' and s.winners and (tonumber(s.winners[i]) or 0)>0
   w.winnerLabel:Hide()
   if p.folded then w.stateLabel:SetText('FOLDED');w.stateLabel:SetTextColor(0.65,0.65,0.65);w.stateLabel:Show();w.bg:SetAlpha(0.45)
   elseif p.allIn then w.stateLabel:SetText('ALL-IN');w.stateLabel:SetTextColor(1,0.75,0.18);w.stateLabel:Show();w.bg:SetAlpha(1)
   else w.stateLabel:Hide();w.bg:SetAlpha(1) end
   local tags=(p.dealer and ' D' or '')..(p.smallBlind and ' SB' or '')..(p.bigBlind and ' BB' or '')
   w.name:SetText(p.name)
   local portraitUnit=nil
   if p.name==UnitName('player') then portraitUnit='player'
   elseif GetNumRaidMembers and GetNumRaidMembers()>0 then
    for ri=1,GetNumRaidMembers() do
     local unit='raid'..ri
     if UnitName(unit)==p.name then portraitUnit=unit;break end
    end
   elseif GetNumPartyMembers and GetNumPartyMembers()>0 then
    for ri=1,GetNumPartyMembers() do
     local unit='party'..ri
     if UnitName(unit)==p.name then portraitUnit=unit;break end
    end
   end
   if portraitUnit and UnitExists(portraitUnit) then
    SetPortraitTexture(w.portrait,portraitUnit)
    w.portrait:SetTexCoord(0,1,0,1)
   else
    w.portrait:SetTexture('Interface\\Icons\\INV_Misc_Dice_02')
    w.portrait:SetTexCoord(0,1,0,1)
   end
   w.badge:SetText(tags)
   local status=(p.folded and ' FOLD' or (p.allIn and ' ALL-IN' or ''))
      -- Keep status inside its own seat, even with a large stack.
   local stack=math.max(0,math.floor(tonumber(p.stack) or 0))
   w.status:SetText(money(stack))
   w.moneyIcon:SetTexture(stack<100 and 'Interface\\MoneyFrame\\UI-SilverIcon' or 'Interface\\MoneyFrame\\UI-GoldIcon')
   w.moneyIcon:Show()
   local action=R.HF19ActionFor and R.HF19ActionFor('HOLDEM',p.name,s.log,s.handNumber)
   if action then
    w.actionLabel:SetText(action);w.actionLabel:SetTextColor(R.HF19ActionColor(action));w.actionUntil=R.HF19ActionExpiry and R.HF19ActionExpiry('HOLDEM',p.name) or (GetTime()+3);w.actionLayer:Show()
   else w.actionLayer:Hide() end
   local hole=R.BarrensUnifiedHole and R.BarrensUnifiedHole(i,s) or nil
   -- Opponents' hole cards are never revealed during an active hand, including solo debug.
   if p.name~=UnitName('player') and s.phase~='SHOWDOWN' then hole=nil end
   for k=1,2 do w.cards[k]:SetCard(hole and hole[k] and (type(hole[k])=='string' and hole[k] or H.CardLabel(hole[k])) or nil,not hole and (p.dealt or (s.phase~='LOBBY' and s.phase~='SHOWDOWN'))) end
  else
   w.frame:Hide();w.moneyIcon:Hide();w.actionLayer:Hide();w.glow:Hide();w.winnerGlow:Hide();w.portrait:Hide();w.winnerLabel:Hide();w.stateLabel:Hide();w.timerBG:Hide();w.timerFill:Hide();w.name:SetText('');w.status:SetText('');w.badge:SetText('')
   for k=1,2 do w.cards[k]:SetCard(nil,false) end
  end
 end
 -- Exactly one winner announcement. Use the actual winning ranks for each
 -- paid winner, and keep multi-winner / split-pot results visible.
 if prefs().announcement and s.phase=='SHOWDOWN' and next(s.winners or {}) then
  local announcements={}
  for i,gain in pairs(s.winners) do
   if (tonumber(gain) or 0)>0 and s.players[i] then
    local rank=s.winningRanks and s.winningRanks[i]
    local category=type(rank)=='table' and tonumber(rank[1]) or nil
    local handName=category and handCategories[category+1] or 'WINNER BY FOLD'
    announcements[#announcements+1]={name=s.players[i].name,gain=tonumber(gain),hand=handName}
   end
  end
  table.sort(announcements,function(a,b)return a.name<b.name end)
  local names,combinations={},{ }
  for _,v in ipairs(announcements) do
   names[#names+1]=v.name..' +'..money(v.gain)
   combinations[#combinations+1]=v.hand
  end
  winnerText:SetText('WINNER: '..table.concat(names,'  |  ')..'\n'..table.concat(combinations,'  |  '))
  winnerPanel:Show()
 else winnerPanel:Hide() end
 local active=s.phase~='LOBBY' and s.phase~='SHOWDOWN' and s.actionSeat
 local lines={}
 for i=math.max(1,#s.log-2),#s.log do if s.log[i] then lines[#lines+1]=s.log[i] end end
 -- The hand history is displayed in Game Controls.

end
-- Public repaint hook: do not require closing and reopening Poker Table.
function R.RefreshBarrensUnifiedTable()
 if f and f:IsShown() then update() end
end
local previousRefresh=H.Refresh
function H.Refresh()
 if previousRefresh then previousRefresh() end
 update()
end
-- Open the existing Poker Table effects panel without creating a second table.
function R.OpenBarrensTableEffects()
 if not f then build() end
 if f then f:Show();f:Raise() end
 if effects.options then effects.options:Show();effects.options:Raise() end
end
-- Clear all cached solo table effects and repaint immediately after Close Solo.
function R.BarrensClearSoloTableVisuals()
 clearCoins()
 effects.previous=nil
 if f then update() end
end
function R.OpenBarrensTable()
 build();update();f:Show();f:Raise()
 local main=_G.RaidPokerBarrensGameControls
 if main and main:IsShown() then arrangePairedWindows(f,main,(RaidPokerWotLKDB and RaidPokerWotLKDB.barrensTableScale) or 1,(RaidPokerWotLKDB and RaidPokerWotLKDB.barrensWindowScale) or 1) end
end

-- Public theme controls for the existing Hold'em Settings window.
function R.SetBarrensPokerTableTheme(index)
 local n=tonumber(index)
 if not n or n<1 or n>#themes then return false end
 themeIndex=math.floor(n)
 if not f then build() end
 applyTheme()
 return true
end
function R.GetBarrensPokerTableThemes()
 local result={}
 for i,t in ipairs(themes) do result[i]=t[1] end
 return result
end
function R.GetBarrensPokerTableTheme() return themeIndex end
