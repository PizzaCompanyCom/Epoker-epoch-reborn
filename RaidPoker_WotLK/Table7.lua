-- Poker Table 7.0: presentation-only layer for WoW 3.3.5a (Lua 5.1).
-- Never modifies cards, bets, balances, turns, or addon network messages.
local R=RPoker
local V=R.VisualTable
if not V then return end
local function db() return RaidPokerWotLKDB or {} end
local function clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end
local function label(parent,anchor,x,y,width,font)
 local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontNormalSmall')
 t:SetPoint(anchor,parent,anchor,x,y);t:SetWidth(width);t:SetJustifyH('CENTER')
 return t
end
local function money(n) return R.Money and R.Money(n) or tostring(n or 0)..'s' end
local oldBuild=R.BuildGame
function R.BuildGame(main)
 oldBuild(main)
 if not V.frame or V.table7Built then return end
 V.table7Built=true
 local f=V.frame
 V.title:SetText('POKER TABLE 7.0')
 V.goldStack={}
 for i=1,4 do
  local t=f:CreateTexture(nil,'ARTWORK')
  t:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon')
  t:SetWidth(21);t:SetHeight(21)
  t:SetPoint('CENTER',f,'TOP',-32+(i-1)*7,-306+(i-1)*3)
  t:Hide();V.goldStack[i]=t
 end
 V.silverStack={}
 for i=1,4 do
  local t=f:CreateTexture(nil,'ARTWORK')
  t:SetTexture('Interface\\MoneyFrame\\UI-SilverIcon')
  t:SetWidth(21);t:SetHeight(21)
  t:SetPoint('CENTER',f,'TOP',15+(i-1)*7,-306+(i-1)*3)
  t:Hide();V.silverStack[i]=t
 end
 -- The only winner banner is V.winBanner from VisualTable.lua.
 V.winnerBanner=nil
 for _,s in ipairs(V.seats or {}) do
  s.table7Border=s:CreateTexture(nil,'BORDER')
  s.table7Border:SetTexture('Interface\\Buttons\\WHITE8X8')
  s.table7Border:SetPoint('TOPLEFT',s,'TOPLEFT',3,-3)
  s.table7Border:SetPoint('BOTTOMRIGHT',s,'BOTTOMRIGHT',-3,3)
  s.table7Border:SetVertexColor(0.15,0.10,0.05,0.17)
  s.timerBG=s:CreateTexture(nil,'OVERLAY')
  s.timerBG:SetTexture('Interface\\Buttons\\WHITE8X8')
  s.timerBG:SetWidth(34);s.timerBG:SetHeight(4)
  s.timerBG:SetPoint('TOPLEFT',s,'TOPLEFT',20,-38)
  s.timerBG:SetVertexColor(0.18,0.18,0.18,0.9)
  s.timerFill=s:CreateTexture(nil,'OVERLAY')
  s.timerFill:SetTexture('Interface\\Buttons\\WHITE8X8')
  s.timerFill:SetWidth(34);s.timerFill:SetHeight(4)
  s.timerFill:SetPoint('LEFT',s.timerBG,'LEFT',0,0)
  s.timerFill:SetVertexColor(0.25,0.82,0.28,1)
  s.timerText7=label(s,'TOPLEFT',18,-45,40,'GameFontNormalSmall')
  s.timerBG:Hide();s.timerFill:Hide();s.timerText7:Hide()
  s.dealer:SetTextColor(1,0.82,0.3)
 end
 -- Options are purely cosmetic, and saved independently of game state.
 local opt=V.options
 opt:SetHeight(620)
 local function slider(name,title,key,y,minimum,maximum,step,callback)
  local t=label(opt,'TOP',0,y,280,'GameFontNormalSmall')
  local sl=CreateFrame('Slider',name,opt,'OptionsSliderTemplate')
  sl:SetPoint('TOP',opt,'TOP',0,y-23);sl:SetWidth(215);sl:SetHeight(16)
  sl:SetMinMaxValues(minimum,maximum);sl:SetValueStep(step)
  local low=getglobal(name..'Low');local high=getglobal(name..'High')
  if low then low:SetText(tostring(math.floor(minimum*100))..'%') end
  if high then high:SetText(tostring(math.floor(maximum*100))..'%') end
  sl:SetScript('OnValueChanged',function(self,v)
   v=clamp(math.floor(v/step+0.5)*step,minimum,maximum)
   db()[key]=v;t:SetText(title..': '..math.floor(v*100+0.5)..'%')
   if callback then callback(v) end
  end)
  sl:SetValue(db()[key] or 1)
 end
 slider('RaidPokerTable7Portrait','Portrait size','portraitScale',-485,0.75,1.3,0.05,function()
  if V.arrangeSeats then V.arrangeSeats(#(R.G.players or {})) end
 end)
 slider('RaidPokerTable7Opacity','Table opacity','table7Opacity',-545,0.4,1,0.05)
 local effects=R.Button(opt,'Winner Effects: ON',250,22,45,-590,function()
  db().table7Effects=db().table7Effects==false and true or false
  V.effectsButton:SetText('Winner Effects: '..(db().table7Effects==false and 'OFF' or 'ON'))
 end)
 V.effectsButton=effects
 effects:SetText('Winner Effects: '..(db().table7Effects==false and 'OFF' or 'ON'))
 -- Preserve both the existing table toggles and the existing 3D/portrait options.
end
local oldRefresh=R.Refresh
function R.Refresh()
 oldRefresh()
 if not V.table7Built then return end
 local g=R.G or {}
 local pot=math.max(0,math.floor(tonumber(g.pot) or 0))
 local gold=math.floor(pot/100);local silver=pot%100
 for i,t in ipairs(V.goldStack) do t:Hide() end
 for i,t in ipairs(V.silverStack) do t:Hide() end
 -- Existing denomination icons are replaced with small coin stacks.
 -- Keep procedural G/S badges managed by VisualTable.lua visible.
 -- The legacy Table7 stack textures are hidden below (client-dependent).
 local phase=g.phase or 'IDLE'
 -- No duplicate winner text behind the cards; VisualTable owns the announcement.
 for _,s in ipairs(V.seats or {}) do
  -- Safety: never reveal cards before showdown, even after multiple rounds.
  if phase~='SHOWDOWN' then
   for _,face in ipairs(s.cardFaces or {}) do face:Hide() end
  end
  s.timerBG:Hide();s.timerFill:Hide();s.timerText7:Hide()
 end
end
local timer=CreateFrame('Frame')
local elapsed=0
local winnerTime=0
timer:SetScript('OnUpdate',function(self,dt)
 if not V.table7Built or not V.frame or not V.frame:IsShown() then return end
 elapsed=elapsed+dt
 if elapsed<0.05 then return end
 elapsed=0
 local g=R.G or {}
 local phase=g.phase or 'IDLE'
 if phase~='SHOWDOWN' then
  for _,s in ipairs(V.seats or {}) do
   for _,face in ipairs(s.cardFaces or {}) do face:Hide() end
  end
 end
 local opacity=clamp(tonumber(db().table7Opacity) or 1,0.4,1)
 V.felt:SetAlpha(opacity)
 V.ring:SetAlpha(opacity)
 local active=g.turn or ''
 local maxTime=tonumber(g.timer) or 30
 local remaining=0
 if active~='' and maxTime>0 then
  local deadline=(R.IsPokerHost and R.IsPokerHost()) or g.solo
  remaining=clamp(((deadline and g.deadline) or g.clientDeadline or 0)-GetTime(),0,maxTime)
 end
 -- The progress bar sits immediately below the portrait and serves as a
 -- 3.3.5-compatible turn-time indicator (no modern retail texture APIs).
 for _,s in ipairs(V.seats or {}) do
  if s:IsShown() and active~='' and s.name:GetText()==string.sub(active,1,16) and phase~='SHOWDOWN' then
   local fraction=clamp(remaining/math.max(1,maxTime),0,1)
   s.timerBG:Show();s.timerFill:Show();s.timerText7:Show()
   s.timerFill:SetWidth(math.max(0.1,34*fraction))
   s.timerFill:SetVertexColor(fraction<0.25 and 1 or 0.25,fraction<0.25 and 0.2 or 0.82,0.2,1)
   s.timerText7:SetText(math.ceil(remaining)..'s')
  else s.timerBG:Hide();s.timerFill:Hide();s.timerText7:Hide() end
 end
end)
