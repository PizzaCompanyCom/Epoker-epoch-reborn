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
 local status=label(seat,'','GameFontHighlightSmall');status:SetPoint('TOP',seat,'TOP',0,-22);status:SetWidth(132);status:SetJustifyH('CENTER')
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
 local winnerLabel=label(seat,'WINNER','GameFontNormalSmall');winnerLabel:SetPoint('BOTTOMRIGHT',seat,'BOTTOMRIGHT',-3,4);winnerLabel:SetTextColor(1,0.84,0.23);winnerLabel:Hide()
 local stateLabel=label(seat,'','GameFontNormalSmall');stateLabel:SetPoint('BOTTOMLEFT',seat,'BOTTOMLEFT',3,4);stateLabel:Hide()
 local timerBG=rect(seat,130,3,0.13,0.13,0.13,0.9);timerBG:SetPoint('BOTTOM',seat,'BOTTOM',0,-3);timerBG:Hide()
 local timerFill=rect(seat,130,3,0.20,0.9,0.32,0.95);timerFill:SetPoint('LEFT',timerBG,'LEFT');timerFill:Hide()
 return {frame=seat,bg=bg,glow=glow,winnerGlow=winnerGlow,portrait=portrait,name=name,status=status,cards={c1,c2},badge=badge,winnerLabel=winnerLabel,stateLabel=stateLabel,timerBG=timerBG,timerFill=timerFill}
end
local function feedback(ok,msg)
 if not ok and R.Print then R.Print('Barrens Holdem: '..(msg or 'Invalid action')) end
end
local function build()
 if f then return end
 f=CreateFrame('Frame','RaidPokerBarrensTable',UIParent)
 f:SetSize(940,570);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetMovable(true);f:EnableMouse(true)
 f:RegisterForDrag('LeftButton');f:SetClampedToScreen(true)
 f:SetScript('OnDragStart',function(self)self:StartMoving()end)
 f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing(); if RaidPokerWotLKDB then RaidPokerWotLKDB.barrensTablePosition={self:GetCenter()} end end)
 if RaidPokerWotLKDB and RaidPokerWotLKDB.barrensTablePosition then local p=RaidPokerWotLKDB.barrensTablePosition; if p[1] and p[2] then f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'BOTTOMLEFT',p[1],p[2]) end end
 f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 local title=label(f,"THE BARRENS HOLD'EM",'GameFontNormalLarge');title:SetPoint('TOP',f,'TOP',0,-17)
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
 -- Larger community cards, shifted left to leave room for the pot display.
 phase=label(felt,'','GameFontNormal');phase:SetPoint('TOP',felt,'TOP',-105,-113)
 turnText=label(felt,'','GameFontHighlight');turnText:SetPoint('TOP',felt,'TOP',-105,-140)
 boardCards={}
 for i=1,5 do local c=card(felt,76,106);c:SetPoint('CENTER',felt,'CENTER',-210+(i-1)*84,0);boardCards[i]=c end
 -- Dedicated pot area: native 3.3.5a coin textures, no letter placeholders.
 local potPanel=CreateFrame('Frame',nil,felt);potPanel:SetSize(181,180);potPanel:SetPoint('CENTER',felt,'CENTER',293,0)
 coinTarget={293,0}
 -- Pot is displayed directly on the felt
 -- No opaque pot border
 local potTitle=label(potPanel,'POT','GameFontNormal');potTitle:SetPoint('TOP',potPanel,0,-8)
 potText=label(potPanel,'','GameFontNormalSmall');potText:SetPoint('TOP',potPanel,0,-29);potText:SetWidth(174)
 potGoldIcon=potPanel:CreateTexture(nil,'ARTWORK');potGoldIcon:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon');potGoldIcon:SetSize(18,18);potGoldIcon:SetPoint('TOPLEFT',potPanel,18,-55)
 potGold=label(potPanel,'0','GameFontHighlightSmall');potGold:SetPoint('LEFT',potGoldIcon,'RIGHT',5,0)
 potSilverIcon=potPanel:CreateTexture(nil,'ARTWORK');potSilverIcon:SetTexture('Interface\\MoneyFrame\\UI-SilverIcon');potSilverIcon:SetSize(18,18);potSilverIcon:SetPoint('TOPLEFT',potPanel,95,-55)
 potSilver=label(potPanel,'0','GameFontHighlightSmall');potSilver:SetPoint('LEFT',potSilverIcon,'RIGHT',5,0)
 sideText=label(potPanel,'','GameFontHighlightSmall');sideText:SetPoint('TOP',potPanel,0,-88);sideText:SetWidth(171);sideText:SetJustifyH('CENTER')
 seatWidgets={}
 -- Ten 138px-wide seats at 150px intervals, with no horizontal overlap.
 -- Preserve the four test players at the outer corners.
 local coords={{-300,-154},{-300,154},{300,154},{300,-154},{-150,154},{0,154},{150,154},{-150,-154},{0,-154},{150,-154}}
 for i=1,10 do seatWidgets[i]=makeSeat(felt,i,coords[i][1],coords[i][2]) end
 themeButton=button(f,'Theme',170,25,function()themeIndex=(themeIndex%#themes)+1;applyTheme()end)
 themeButton:SetPoint('TOPRIGHT',f,'TOPRIGHT',-46,-17)
 applyTheme()
 -- Main window is opened independently; no redundant navigation button
 local optionsButton=button(f,'Effects',94,23,function()
  if effects.options then
   if effects.options:IsShown() then effects.options:Hide() else effects.options:Show() end
  end
 end)
 optionsButton:SetPoint('TOPRIGHT',f,'TOPRIGHT',-222,-17)
 local op=CreateFrame('Frame',nil,f)
 op:SetSize(238,385);op:SetPoint('TOPRIGHT',f,'TOPRIGHT',-20,-47)
 op:SetFrameStrata('FULLSCREEN_DIALOG')
 op:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=20,insets={left=6,right=6,top=6,bottom=6}})
 local opTitle=label(op,'POKER VISUAL EFFECTS','GameFontNormal');opTitle:SetPoint('TOP',op,0,-15)
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
 duration:SetScript('OnValueChanged',function(self,v) local rounded=math.floor(v*10+0.5)/10;prefs().coinDuration=rounded;durationText:SetText(string.format('Coin Duration: %.1fs',rounded)) end)
 local glowText=label(op,'Glow Intensity: 70%','GameFontHighlightSmall');glowText:SetPoint('TOP',op,'TOP',0,-314)
 local glowSlider=CreateFrame('Slider',nil,op,'OptionsSliderTemplate');glowSlider:SetWidth(180);glowSlider:SetHeight(16);glowSlider:SetPoint('TOP',op,'TOP',0,-333);glowSlider:SetMinMaxValues(20,100);glowSlider:SetValueStep(10);glowSlider:SetValue(tonumber(prefs().glowIntensity) or 70)
 glowSlider:SetScript('OnValueChanged',function(self,v) local rounded=math.floor(v/10+0.5)*10;prefs().glowIntensity=rounded;glowText:SetText('Glow Intensity: '..rounded..'%') end)
 effects.options=op;op:Hide()
 optionsText=label(f,'LOCAL PREVIEW | SUITS: S Spades, H Hearts, D Diamonds, C Clubs','GameFontHighlightSmall');optionsText:SetPoint('TOP',f,'TOP',0,-527)
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
    local xy=({{-300,-154},{-300,154},{300,154},{300,-154},{-150,154},{0,154},{150,154},{-150,-154},{0,-154},{150,-154}})[i]
    if xy then startCoins(xy[1],xy[2],coinTarget[1],coinTarget[2],p.committed-old.committed) end
   end
  end
  if prev.phase~='SHOWDOWN' and s.phase=='SHOWDOWN' then
   for i,gain in pairs(s.winners or {}) do
    local xy=({{-300,-154},{-300,154},{300,154},{300,-154},{-150,154},{0,154},{150,154},{-150,-154},{0,-154},{150,-154}})[i]
    if xy then startCoins(coinTarget[1],coinTarget[2],xy[1],xy[2],gain) end
   end
   if next(s.winners or {}) then playSound('win') end
  end
 elseif prev and prev.handNumber~=s.handNumber then
  clearCoins()
  for i,p in ipairs(s.players) do
   if (p.committed or 0)>0 then
    local xy=({{-300,-154},{-300,154},{300,154},{300,-154},{-150,154},{0,154},{150,154},{-150,-154},{0,-154},{150,-154}})[i]
    if xy then startCoins(xy[1],xy[2],coinTarget[1],coinTarget[2],p.committed) end
   end
  end
 end
 effects.previous={handNumber=s.handNumber,phase=s.phase,players={},winners=s.winners}
 for i,p in ipairs(s.players) do effects.previous.players[i]={committed=p.committed or 0} end
 for key,v in pairs(effects.buttons) do v.button:SetText(v.label..': '..(prefs()[key] and 'ON' or 'OFF')) end
 phase:SetText('HAND '..s.handNumber..'  •  '..s.phase)
 local total=paidPot(s)
 potText:SetText(s.phase=='SHOWDOWN' and 'LAST POT (PAID)' or 'CURRENT POT')
 potGold:SetText(tostring(math.floor(total/100)))
 potSilver:SetText(tostring(total%100))
 local parts={}
 if s.phase=='SHOWDOWN' then
  for j,p in ipairs(s.sidePots or {}) do
   parts[#parts+1]=(j==1 and 'Main: ' or ('Side '..(j-1)..': '))..money(p.amount)
  end
 end
 sideText:SetText(table.concat(parts,'\n'))
 turnText:SetText(s.actionSeat and ('TURN: '..s.players[s.actionSeat].name) or (s.phase=='SHOWDOWN' and 'SHOWDOWN COMPLETE' or ''))
 for i=1,5 do boardCards[i]:SetCard(s.board[i],false) end
 for i,w in ipairs(seatWidgets) do
  local p=s.players[i]
  if p then
   w.frame:Show()
   if prefs().turn and s.actionSeat==i then w.glow:Show() else w.glow:Hide() end
   if prefs().winner and s.phase=='SHOWDOWN' and s.winners and s.winners[i] then w.winnerGlow:Show() else w.winnerGlow:Hide() end
   if prefs().portraits then w.portrait:Show() else w.portrait:Hide() end
   local didWin=prefs().winner and s.phase=='SHOWDOWN' and s.winners and (tonumber(s.winners[i]) or 0)>0
   if didWin then w.winnerLabel:Show() else w.winnerLabel:Hide() end
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
   w.status:SetText(money(p.stack)..' | Bet '..money(p.street)..status..(s.winners[i] and (' WIN +'..money(s.winners[i])) or ''))
   local hole=(R.BarrensUnifiedHole and R.BarrensUnifiedHole(i,s)) or (not R.BarrensUnifiedSnapshot and H.players[i] and H.players[i].hole)
   for k=1,2 do w.cards[k]:SetCard(hole and hole[k] and (type(hole[k])=='string' and hole[k] or H.CardLabel(hole[k])) or nil,false) end
  else
   w.frame:Hide();w.glow:Hide();w.winnerGlow:Hide();w.portrait:Hide();w.winnerLabel:Hide();w.stateLabel:Hide();w.timerBG:Hide();w.timerFill:Hide();w.name:SetText('');w.status:SetText('');w.badge:SetText('')
   for k=1,2 do w.cards[k]:SetCard(nil,false) end
  end
 end
 if not effects.announcement then
  effects.announcement=label(feltArea,'','GameFontNormalSmall')
  effects.announcement:SetPoint('CENTER',feltArea,'CENTER',-100,-72)
  effects.announcement:SetWidth(470)
 end
 if prefs().announcement and s.phase=='SHOWDOWN' and next(s.winners or {}) then
  local announcements={}
  for i,gain in pairs(s.winners) do
   if tonumber(gain) and gain>0 and s.players[i] then announcements[#announcements+1]=s.players[i].name..' wins '..money(gain) end
  end
  table.sort(announcements)
  effects.announcement:SetText(table.concat(announcements,'  |  '));effects.announcement:Show()
 else effects.announcement:Hide() end
 local active=s.phase~='LOBBY' and s.phase~='SHOWDOWN' and s.actionSeat
 local lines={}
 for i=math.max(1,#s.log-2),#s.log do if s.log[i] then lines[#lines+1]=s.log[i] end end
 -- The hand history is displayed in Game Controls.

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
function R.OpenBarrensTable()
 build();update();f:Show();f:Raise()
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
