-- Hotfix 33 Fix 12: transparent, permanently attached betting controls.
-- WoW 3.3.5a / Lua 5.1. Main window actions remain authoritative.
local R=RPoker
if not R then return end
local holdemButtons,holdemFields
function R.HF07RegisterHoldemActions(buttons,gold,silver,anteG,anteS,apply)
 holdemButtons=buttons
 holdemFields={raiseG=gold,raiseS=silver,anteG=anteG,anteS=anteS,apply=apply}
end
local labels={'Check','Call','Raise','Fold','All-In','Exchange','Stand Pat'}
local icons={'Interface\\Icons\\INV_Shield_06','Interface\\Icons\\INV_Misc_Coin_01','Interface\\Icons\\Ability_Warrior_Charge','Interface\\Icons\\Ability_Creature_Cursed_02','Interface\\Icons\\INV_Misc_Bag_10','Interface\\Icons\\INV_Misc_Bag_08','Interface\\Icons\\INV_Misc_Note_01'}
local function src(mode,i)
 if mode=='HOLDEM' then return holdemButtons and holdemButtons[i] end
 local ui=R.GameUI
 return ui and ({ui.checkButton,ui.callButton,ui.raiseButton,ui.foldButton,ui.allinButton,ui.exchangeButton,ui.patButton})[i]
end
local function fields(mode)
 if mode=='HOLDEM' then return holdemFields end
 local ui=R.GameUI
 if not ui then return nil end
 return {raiseG=ui.raiseGold,raiseS=ui.raiseSilver,anteG=ui.anteGold,anteS=ui.anteSilver}
end
-- Plain edit boxes: InputBoxTemplate has wide left/right textures that collided at compact widths.
local function edit(parent,x,y)
 local shell=CreateFrame('Frame',nil,parent)
 shell:SetSize(54,22);shell:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y)
 local bg=shell:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints(shell)
 bg:SetTexture('Interface\\Buttons\\WHITE8X8');bg:SetVertexColor(0.15,0.16,0.18,1)
 -- Four thin border textures avoid the wide InputBoxTemplate artwork.
 local borders={}
 local function border(pointA,pointB,w,h)
  local t=shell:CreateTexture(nil,'BORDER')
  t:SetTexture('Interface\\Buttons\\WHITE8X8')
  t:SetVertexColor(0.64,0.52,0.31,1)
  t:SetPoint(pointA,shell,pointA,0,0)
  if pointB then t:SetPoint(pointB,shell,pointB,0,0) end
  if w then t:SetWidth(w) end
  if h then t:SetHeight(h) end
  borders[#borders+1]=t
 end
 border('TOPLEFT','TOPRIGHT',nil,1)
 border('BOTTOMLEFT','BOTTOMRIGHT',nil,1)
 border('TOPLEFT','BOTTOMLEFT',1,nil)
 border('TOPRIGHT','BOTTOMRIGHT',1,nil)
 local function setBorder(r,g,b)
  for _,t in ipairs(borders) do t:SetVertexColor(r,g,b,1) end
 end
 local e=CreateFrame('EditBox',nil,shell)
 e:SetSize(46,18);e:SetPoint('CENTER',shell,'CENTER',0,0)
 e:SetFontObject('ChatFontNormal');e:SetTextColor(1,0.94,0.78)
 e:SetJustifyH('CENTER');e:SetAutoFocus(false);e:SetText('0');e:SetNumeric(true);e:SetMaxLetters(9)
 e:SetScript('OnEditFocusGained',function()setBorder(1,0.82,0.37)end)
 e:SetScript('OnEditFocusLost',function()setBorder(0.64,0.52,0.31)end)
 e:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
 e:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
 return e
end
local function label(parent,text,x,y)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetText(text);return f
end
local function button(parent,text,x,y,w,click,texture)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,23);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(texture and ('   '..text) or text);b:SetScript('OnClick',click)
 if texture then local t=b:CreateTexture(nil,'OVERLAY');t:SetTexture(texture);t:SetSize(17,17);t:SetPoint('LEFT',b,'LEFT',5,0) end
 return b
end
local function build(parent,mode)
 if not parent or parent.HF07BettingPanel then return end
 local p=CreateFrame('Frame',nil,parent)
 p:SetHeight(153)
 p:SetPoint('TOPLEFT',parent,'BOTTOMLEFT',0,0)
 p:SetPoint('TOPRIGHT',parent,'BOTTOMRIGHT',0,0)
 p:SetFrameLevel(parent:GetFrameLevel()+20)
 p:EnableMouse(false)
 -- Matching full-width dark extension; no poker felt or table background.
 local bg=p:CreateTexture(nil,'BACKGROUND')
 bg:SetAllPoints(p);bg:SetTexture('Interface\\Buttons\\WHITE8X8');bg:SetVertexColor(0.055,0.045,0.045,0.90)
 local edge=p:CreateTexture(nil,'BORDER');edge:SetTexture('Interface\\Buttons\\WHITE8X8')
 edge:SetVertexColor(0.52,0.40,0.22,0.9);edge:SetHeight(2);edge:SetPoint('TOPLEFT',p,0,0);edge:SetPoint('TOPRIGHT',p,0,0)
 -- Complete the Poker Table frame around the attached controls without
 -- changing the original table dimensions or its saved scale.
 local function trim(a,b,c,d)
  local t=p:CreateTexture(nil,'BORDER')
  t:SetTexture('Interface\\Buttons\\WHITE8X8')
  t:SetVertexColor(0.45,0.40,0.33,0.95)
  t:SetPoint(a,p,a,0,0);t:SetPoint(b,p,b,0,0)
  if c then t:SetWidth(c) end
  if d then t:SetHeight(d) end
 end
 trim('TOPLEFT','BOTTOMLEFT',2,nil)
 trim('TOPRIGHT','BOTTOMRIGHT',2,nil)
 trim('BOTTOMLEFT','BOTTOMRIGHT',nil,2)

 local width=(mode=='HOLDEM') and 940 or 760
 local margin=16
 local actions=(mode=='DRAW') and {1,2,4,5,6,7} or {1,2,4,5}
 local actionWidth=math.floor((width-2*margin-(#actions-1)*8)/#actions)
 local buttons={}
 for j,i in ipairs(actions) do
  buttons[i]=button(p,labels[i],margin+(j-1)*(actionWidth+8),-10,actionWidth,function()
   local original=src(mode,i)
   if original and original:IsEnabled() then original:Click() end
  end,icons[i])
 end
 local anteX=math.floor(width/2)+8
 label(p,'Raise (Gold / Silver)',margin,-43)
 label(p,'Ante (Gold / Silver)',anteX,-43)
 local rg,rs=edit(p,margin+5,-62),edit(p,margin+75,-62)
 local ag,as=edit(p,anteX+5,-62),edit(p,anteX+75,-62)
 local raise=button(p,'Apply Raise',margin+150,-61,125,function()
  local f=fields(mode)
  if f and f.raiseG and f.raiseS then
   f.raiseG:SetText(rg:GetText());f.raiseS:SetText(rs:GetText())
   p.lastG=rg:GetText();p.lastS=rs:GetText()
  end
  local orig=src(mode,3)
  if orig and orig:IsEnabled() then orig:Click() end
 end,icons[3])
 local apply=button(p,'Apply Ante',anteX+150,-61,125,function()
  if not (R.IsGameMaster and R.IsGameMaster()) then
   if R.Print then R.Print('Only the Game Master can change Ante.') end
   return
  end
  local f=fields(mode)
  if not f or not f.anteG or not f.anteS then return end
  local g,s=tonumber(ag:GetText()),tonumber(as:GetText())
  if not g or not s or g<0 or s<0 or s>99 then return end
  f.anteG:SetText(tostring(g));f.anteS:SetText(tostring(s))
  if mode=='HOLDEM' then
   if f.apply then f.apply:Click() end
  else
   if R.ApplyDrawAnteFromTable then
    local ok,msg=R.ApplyDrawAnteFromTable(g*100+s)
    if R.Print and msg then R.Print(msg) end
   elseif R.Print then
    R.Print('Ante update unavailable: Game.lua Fix 18 is required.')
   end
  end
 end)
 label(p,'BETTING PRESETS - SELECT AMOUNT THEN APPLY RAISE',margin,-99)
 local presets={{'+10s',10},{'+50s',50},{'+100s',100},{'1/4 Pot',-4},{'1/2 Pot',-2},{'Pot',-1}}
 local presetW=math.floor((width-2*margin-5*8)/6)
 for i,v in ipairs(presets) do
  button(p,v[1],margin+(i-1)*(presetW+8),-115,presetW,function()
   local amount=v[2]
   if amount<0 then
    local pot=0
    if mode=='HOLDEM' then
     local snap=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot()
     pot=(snap and tonumber(snap.pot)) or (R.Holdem and tonumber(R.Holdem.pot)) or 0
    else
     local game=R.GetGameState and R.GetGameState()
     pot=(game and tonumber(game.pot)) or 0
    end
    amount=math.max(1,math.floor(pot/math.abs(amount)))
   end
   rg:SetText(tostring(math.floor(amount/100)));rs:SetText(tostring(amount%100))
   local f=fields(mode)
   if f and f.raiseG and f.raiseS then
    f.raiseG:SetText(rg:GetText());f.raiseS:SetText(rs:GetText())
    p.lastG=rg:GetText();p.lastS=rs:GetText()
   end
  end,'Interface\\Icons\\INV_Misc_Coin_01')
 end
 local timer=0
 p:SetScript('OnUpdate',function(self,elapsed)
  timer=timer+(elapsed or 0);if timer<0.2 then return end;timer=0
  for _,i in ipairs(actions) do
   local orig=src(mode,i)
   if orig and orig:IsEnabled() then buttons[i]:Enable() else buttons[i]:Disable() end
  end
  local originalRaise=src(mode,3)
  if originalRaise and originalRaise:IsEnabled() then raise:Enable() else raise:Disable() end
  local isGM=R.IsGameMaster and R.IsGameMaster()
  if isGM then apply:Enable();ag:EnableMouse(true);as:EnableMouse(true)
  else apply:Disable();ag:EnableMouse(false);as:EnableMouse(false) end
  local f=fields(mode)
  if f and f.raiseG and f.raiseS and not rg:HasFocus() and not rs:HasFocus() then
   local g,s=f.raiseG:GetText(),f.raiseS:GetText()
   if self.lastG~=g or self.lastS~=s then
    rg:SetText(g or '0');rs:SetText(s or '0');self.lastG=g;self.lastS=s
   end
  end
 end)
 p.HF07Fields={raiseG=rg,raiseS=rs,anteG=ag,anteS=as}
 parent.HF07BettingPanel=p
end
local function locate()
 build((R.VisualTable and R.VisualTable.frame) or _G.RaidFivePokerVisualTable,'DRAW')
 build(_G.RaidPokerBarrensTable,'HOLDEM')
end
locate()
local watcher=CreateFrame('Frame');local tick=0
watcher:SetScript('OnUpdate',function(self,dt)
 tick=tick+(dt or 0);if tick<0.5 then return end;tick=0;locate()
end)
-- Legacy command now only shows the permanently attached controls.
SLASH_EPOKERBETTING1='/pokerbet'
SlashCmdList.EPOKERBETTING=function(arg)
 locate()
 local mode=(arg or ''):lower():match('^%s*(%S+)')
 local parent=(mode=='holdem') and _G.RaidPokerBarrensTable or ((R.VisualTable and R.VisualTable.frame) or _G.RaidFivePokerVisualTable)
 if parent and parent.HF07BettingPanel then parent.HF07BettingPanel:Show() end
end
