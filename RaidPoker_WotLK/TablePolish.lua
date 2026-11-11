-- Poker Table 6.0: presentation only; no changes to game rules or addon messages.
local R=RPoker
local V=R.VisualTable
if not V then return end
local function db() return RaidPokerWotLKDB or {} end
local function money(n) return R.Money and R.Money(n) or tostring(n or 0)..'s' end
local function newLabel(parent,font)
 local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
 t:SetJustifyH('CENTER')
 return t
end
local oldBuild=R.BuildGame
function R.BuildGame(main)
 oldBuild(main)
 if not V.frame or V.polishBuilt then return end
 V.polishBuilt=true
 local f=V.frame
 V.title:SetText('POKER TABLE 6.0')
 -- All seat coordinates are inside the 760x515 frame. The inner center is kept clear.
 -- For few players the seats are spread evenly; unused frames remain hidden.
 local cx,cy=380,256
 local spots={
  {380,91},{562,115},{660,206},{660,307},{562,398},
  {380,398},{198,398},{100,307},{100,206},{198,115}
 }
 local layouts={
  [1]={1},[2]={9,3},[3]={10,3,6},[4]={10,3,5,8},
  [5]={1,3,5,7,9},[6]={10,2,4,6,7,9},
  [7]={1,2,4,5,6,8,9},[8]={1,2,3,4,6,7,8,9},
  [9]={1,2,3,4,5,6,7,8,9},[10]={1,2,3,4,5,6,7,8,9,10}
 }
 local function refreshGeometry()
  local list=R.G and R.G.players or {}
  local n=math.min(6,#list)
  local layout=layouts[n] or {}
  local size=math.max(0.8,math.min(1.2,tonumber(db().seatSize) or 1))
  local cardSize=math.max(0.7,math.min(1.3,tonumber(db().miniCardScale) or 1))
  local portraitSize=math.max(0.75,math.min(1.3,tonumber(db().portraitScale) or 1))
  local width=(n>=7 and 150 or 174)*size;local height=(n>=7 and 80 or 92)*size
  for i,s in ipairs(V.seats or {}) do
   if i<=n then
    local spot=spots[layout[i]]
    s:ClearAllPoints();s:SetPoint('CENTER',f,'TOPLEFT',spot[1],-spot[2])
    s:SetWidth(width);s:SetHeight(height);s:Show()
   else s:Hide() end
   if s.portrait then
    s.portrait:SetWidth(29*portraitSize);s.portrait:SetHeight(29*portraitSize)
   end
   if s.name then s.name:SetWidth(94*size) end
   if s.info then s.info:SetWidth(114*size) end
   if s.status then
    s.status:ClearAllPoints();s.status:SetPoint('TOPRIGHT',s,'TOPRIGHT',-5,-33)
    s.status:SetWidth(58);s.status:SetJustifyH('RIGHT')
   end
   if s.betChip then s.betChip:ClearAllPoints();s.betChip:SetPoint('TOPRIGHT',s,'TOPRIGHT',-6,-51) end
   if s.win then s.win:ClearAllPoints();s.win:SetPoint('BOTTOMLEFT',s,'BOTTOMLEFT',6,5);s.win:SetWidth(width-12) end
   for j,card in ipairs(s.cards or {}) do
    card:ClearAllPoints();card:SetPoint('BOTTOMLEFT',s,'BOTTOMLEFT',56+(j-1)*19*cardSize,6)
    card:SetWidth(15*cardSize);card:SetHeight(22*cardSize)
   end
  end
 end
 V.arrangeSeats=function(count) refreshGeometry() end
 -- The base game tracks virtual silver; gold/silver are display denominations.
 V.pot:ClearAllPoints();V.pot:SetPoint('TOP',f,'TOP',-10,-113)
 V.pot:SetWidth(170);V.pot:SetJustifyH('RIGHT')
 V.phase:ClearAllPoints();V.phase:SetPoint('BOTTOM',f,'BOTTOM',0,27)
 V.phase:SetWidth(340);V.phase:SetJustifyH('CENTER');V.phase:SetFontObject('GameFontNormalLarge')
 V.chipLabel:ClearAllPoints();V.chipLabel:SetPoint('TOP',f,'TOP',0,-270)
 V.chipLabel:SetWidth(220);V.chipLabel:SetJustifyH('CENTER')
 -- Coin stacks are anchored dynamically to V.pot by VisualTable.Refresh.
 -- Remove square backing textures entirely; native gold/silver icons are circular.
 for _,t in ipairs(V.chipBacks or {}) do t:Hide() end
 -- Add a dedicated current-turn strip, independent from the bank label.
 V.turnText=newLabel(f,'GameFontNormalLarge')
 V.turnText:SetPoint('TOP',f,'TOP',0,-342);V.turnText:SetWidth(320)
 -- Per-seat visible bet amounts, dealer marker and turn timer.
 for _,s in ipairs(V.seats or {}) do
  s.betText=newLabel(s,'GameFontHighlightSmall')
  s.betText:SetPoint('TOPLEFT',s,'TOPLEFT',57,-38)
  s.betText:SetWidth(110);s.betText:SetJustifyH('LEFT')
  s.turnText=newLabel(s,'GameFontNormalSmall')
  s.turnText:SetPoint('TOPLEFT',s,'TOPLEFT',6,-35);s.turnText:SetWidth(48)
  s.dealer:SetTextColor(1,0.82,0.3)
 end
 -- Extend Table Options without changing the existing scale and theme controls.
 local opt=V.options
 opt:SetHeight(620)
 local function slider(name,label,key,y,minimum,maximum,step)
  local text=newLabel(opt,'GameFontNormalSmall')
  text:SetPoint('TOP',opt,'TOP',0,y);text:SetWidth(280)
  local sl=CreateFrame('Slider',name,opt,'OptionsSliderTemplate')
  sl:SetPoint('TOP',opt,'TOP',0,y-24);sl:SetWidth(220);sl:SetHeight(16)
  sl:SetMinMaxValues(minimum,maximum);sl:SetValueStep(step)
  local low=getglobal(name..'Low');local high=getglobal(name..'High')
  if low then low:SetText(tostring(math.floor(minimum*100))..'%') end
  if high then high:SetText(tostring(math.floor(maximum*100))..'%') end
  sl:SetScript('OnValueChanged',function(self,value)
   value=math.floor(value/step+0.5)*step
   db()[key]=value
   text:SetText(label..': '..math.floor(value*100+0.5)..'%')
   refreshGeometry()
  end)
  sl:SetValue(db()[key] or 1)
 end
 slider('RaidPokerSeatSizeSlider','Player frame size','seatSize',-365,0.8,1.2,0.05)
 slider('RaidPokerMiniCardSizeSlider','Mini-card size','miniCardScale',-425,0.7,1.3,0.05)
 -- Portrait size is available as a slash command to avoid crowding options.
 R.SetPortraitScale=function(value)
  local n=tonumber(value)
  if not n or n<75 or n>130 then R.Print('Usage: /poker portraitscale 75-130');return end
  db().portraitScale=n/100;refreshGeometry()
  R.Print('Poker Table portrait scale: '..n..'%')
 end
 refreshGeometry()
end
local oldRefresh=R.Refresh
function R.Refresh()
 oldRefresh()
 if not V.polishBuilt then return end
 local g=R.G or {}
 local active=g.turn or ''
 local turnSeconds=tonumber(g.turnLeft or g.timeLeft or 0) or 0
 if active~='' and g.phase~='SHOWDOWN' then
  V.turnText:SetText('TURN: '..active..(turnSeconds>0 and ('  |  '..math.ceil(turnSeconds)..'s') or ''))
 else V.turnText:SetText('') end
 local players={}
 for _,p in ipairs(g.players or {}) do players[p.name]=p end
 local ordered={}
 for _,p in ipairs(g.players or {}) do table.insert(ordered,p) end
 local map=db().seatPositions or {}
 table.sort(ordered,function(a,b)
  local ia,ib=map[a.name],map[b.name]
  if ia and ib and ia~=ib then return ia<ib end
  if ia and not ib then return true end
  if ib and not ia then return false end
  for j,p in ipairs(g.players or {}) do
   if p==a then ia=j end
   if p==b then ib=j end
  end
  return (ia or 99)<(ib or 99)
 end)
 local count=#ordered
 local dealerIndex=(db().dealerRotation==false) and 1 or ((math.max(1,g.round or 1)-1)%math.max(1,count)+1)
 for i,s in ipairs(V.seats or {}) do
  local p=ordered[i]
  -- Never allow a face texture to survive a new round or a non-showdown phase.
  if g.phase~='SHOWDOWN' then
   for _,face in ipairs(s.cardFaces or {}) do face:Hide() end
  end
  if p then
   s.betText:SetText('')
   -- Class-colored names when the corresponding raid unit is available.
   local class
   if p.name==UnitName('player') then _,class=UnitClass('player')
   elseif GetNumRaidMembers and GetNumRaidMembers()>0 then
    for unitIndex=1,GetNumRaidMembers() do
     local unit='raid'..unitIndex
     if UnitName(unit)==p.name then _,class=UnitClass(unit);break end
    end
   end
   local color=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
   if color and s.name then s.name:SetTextColor(color.r,color.g,color.b) end
   s.turnText:SetText('')
   s.dealer:SetText(i==dealerIndex and 'D' or '')
   -- Seat labels show stack and status only; no separate bet amount.
   if g.phase=='SHOWDOWN' and V.winName==p.name then
    s.win:SetText('')
   end
  else s.betText:SetText('');s.turnText:SetText('') end
 end
 -- Pot coin visibility is controlled by VisualTable.Refresh.
 -- Do not hide it here: this wrapper runs after the main refresh.

end
