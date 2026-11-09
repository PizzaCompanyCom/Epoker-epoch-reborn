-- Raid 5-Card Poker WotLK v1.0.3 - adaptive occupied-seat visual table and motion effects.
-- 3.3.5a compatible. Seat order is host-authoritative display only; never changes betting turn order.
local R=RPoker
local V={}
R.VisualTable=V
-- Original WotLK currency textures, shipped with the game client.
local function coinTexture(silver)
 return silver and 'Interface\\MoneyFrame\\UI-SilverIcon' or 'Interface\\MoneyFrame\\UI-GoldIcon'
end
-- Display-only conversion. Game balances and network amounts remain in silver.
local function formatMoney(silver)
 silver=math.max(0,math.floor(tonumber(silver) or 0))
 local gold=math.floor(silver/100)
 local rest=silver%100
 if gold==0 then return tostring(rest)..'s' end
 if rest==0 then return tostring(gold)..'g' end
 return tostring(gold)..'g '..tostring(rest)..'s'
end
local NET='R5CSEAT9'
local REVEAL_NET='R5CSHOW12'
local revealCache={}
local function clearOldReveals(round)
 for key in pairs(revealCache) do if key~=round then revealCache[key]=nil end end
end
local CARD_BACK='Interface\\AddOns\\RaidPoker_WotLK\\Textures\\MiniCardBack'
local CARD_ROOT='Interface\\AddOns\\RaidPoker_WotLK\\Cards\\'
local SUITS={'S','H','D','C'}
local RANKS={'2','3','4','5','6','7','8','9','10','J','Q','K','A'}
local function artFor(id)
 id=tonumber(id)
 if not id or id<1 or id>52 then return CARD_BACK end
 return CARD_ROOT..RANKS[(id-1)%13+1]..SUITS[math.floor((id-1)/13)+1]..'.tga'
end
local function isHost() return R.IsPokerHost and R.IsPokerHost() end
local function isRaid() return GetNumRaidMembers and GetNumRaidMembers()>0 end
function R.PublishShowdown(round,hands)
 if not isHost() or not hands then return end
 revealCache[round]=hands
 if R.G.solo or not isRaid() then return end
 for name,hand in pairs(hands) do
  if hand.cards and #hand.cards==5 then
   local data=tostring(round)..';'..name..';'..table.concat(hand.cards,',')..';'..(hand.combo or '')
   if #data<240 then SendAddonMessage(REVEAL_NET,data,'RAID') end
  end
 end
end
local function sendSeats(target)
 if R.G.solo or not isRaid() or not isHost() then return end
 local list={}
 for _,p in ipairs(R.G.players or {}) do table.insert(list,p.name) end
 local map=RaidPokerWotLKDB.seatPositions or {}
 table.sort(list,function(a,b) return (map[a] or 99)<(map[b] or 99) end)
 local payload=table.concat(list,',')
 if #payload<235 then SendAddonMessage(NET,'SEATS|'..payload,target and 'WHISPER' or 'RAID',target) end
end
local function requestSeats()
 if R.G.solo or not isRaid() or isHost() then return end
 SendAddonMessage(NET,'REQUEST','RAID')
end
local network=CreateFrame('Frame')
network:RegisterEvent('CHAT_MSG_ADDON')
network:RegisterEvent('PLAYER_ENTERING_WORLD')
network:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_ENTERING_WORLD' then
  if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(NET);RegisterAddonMessagePrefix(REVEAL_NET) end
  return
 end
 local prefix,msg,channel,sender=...
 if prefix==REVEAL_NET then
  if R.G.solo or R.G.phase~='SHOWDOWN' then return end
  local senderShort=string.gsub(sender or '','%-.*$','')
  local hostShort=string.gsub(R.G.host or '','%-.*$','')
  if hostShort=='' or senderShort~=hostShort then return end
  local round,name,ids,combo=string.match(msg or '','^(%d+);([%w%-]+);([%d,]+);([%w ]*)$')
  round=tonumber(round)
  if not round or round<(R.G.round or 0) or round>(R.G.round or 0)+1 then return end
  local found=false
  for _,p in ipairs(R.G.players or {}) do if p.name==name then found=true;break end end
  if not found then return end
  local cards={}
  for id in string.gmatch(ids,'[^,]+') do
   local n=tonumber(id);if not n or n<1 or n>52 then return end
   table.insert(cards,n)
  end
  if #cards~=5 then return end
  revealCache[round]=revealCache[round] or {}
  revealCache[round][name]={cards=cards,combo=combo}
  if R.Refresh then R.Refresh() end
  return
 end
 if prefix~=NET or R.G.solo then return end
 local shortSender=string.gsub(sender or '','%-.*$','')
 local shortHost=string.gsub(R.G.host or '','%-.*$','')
 if msg=='REQUEST' then
  if isHost() and sender and sender~='' then
   local member=false
   for _,p in ipairs(R.G.players or {}) do if p.name==shortSender then member=true;break end end
   if member then sendSeats(sender) end
  end
  return
 end
 if string.sub(msg,1,6)~='SEATS|' or shortSender~=shortHost or shortHost=='' then return end
 local positions={};local used={};local count=0
 local members={}
 for _,player in ipairs(R.G.players or {}) do members[player.name]=true end
 for name in string.gmatch(string.sub(msg,7),'[^,]+') do
  if members[name] and not used[name] and count<10 and string.match(name,'^[%w%-]+$') then
   count=count+1;positions[name]=count;used[name]=true
  end
 end
 -- Reject incomplete or foreign seat layouts instead of applying partial updates.
 if count~=#(R.G.players or {}) then return end
 RaidPokerWotLKDB.seatPositions=positions
 if R.Refresh then R.Refresh() end
end)

local function txt(parent,x,y,w,content,font)
 local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetJustifyH('LEFT');f:SetText(content or '')
 return f
end
local function btn(parent,title,x,y,w,callback)
 return R.Button(parent,title,w,22,x,y,callback)
end
local TABLE_THEMES={
 {id='TAVERN',name='Warcraft Tavern',file='Tavern'},
 {id='IRONFORGE',name='Ironforge',file='Ironforge'},
 {id='HORDE',name='Horde',file='Horde'},
 {id='STORMWIND',name='Stormwind',file='Stormwind'},
 {id='BOOTYBAY',name='Booty Bay',file='BootyBay'},
 {id='ARCANE',name='Arcane Casino',file='Arcane'},
 {id='SOLIDBLACK',name='Solid Black'},
 {id='SOLIDCHARCOAL',name='Dark Charcoal'},
 {id='SOLIDNAVY',name='Midnight Blue'},
 {id='SOLIDGREEN',name='Dark Green'},
 {id='SOLIDBURGUNDY',name='Burgundy'},
 {id='SOLIDBROWN',name='Dark Brown'},
}
local function theme()
 local t=RaidPokerWotLKDB.tableTheme
 if t=='DARKIRON' then t='IRONFORGE' end
 if t=='CLASSIC' then t='TAVERN' end
 for _,v in ipairs(TABLE_THEMES) do if v.id==t then return v end end
 return TABLE_THEMES[1]
end
local function themeApply()
 if not V.frame then return end
 local current=theme()
 -- Reliable 3.3.5a rendering: built-in opaque UI texture, tinted per theme.
 -- Do not depend on external TGA decoding or SetBackdrop custom bgFile.
 local colors={
  TAVERN={0.26,0.15,0.085}, IRONFORGE={0.23,0.24,0.26},
  HORDE={0.29,0.075,0.085}, STORMWIND={0.075,0.15,0.32},
  BOOTYBAY={0.27,0.18,0.11}, ARCANE={0.18,0.085,0.28},
   SOLIDBLACK={0.015,0.015,0.018}, SOLIDCHARCOAL={0.065,0.068,0.075},
   SOLIDNAVY={0.025,0.055,0.11}, SOLIDGREEN={0.025,0.09,0.06},
   SOLIDBURGUNDY={0.13,0.028,0.048}, SOLIDBROWN={0.12,0.068,0.04}
 }
 local c=colors[current.id] or colors.TAVERN
 V.frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=28,insets={left=11,right=11,top=11,bottom=11}})
 V.frame:SetBackdropColor(c[1],c[2],c[3],1)
 if V.tableSurface then
  -- All six themes use bundled, uncompressed 32-bit TGA images.
  -- Avoid experimental BLP2 textures that rendered white on WotLK 3.3.5a.
  V.tableSurface:SetTexture('Interface\\Buttons\\WHITE8X8')
  V.tableSurface:SetTexCoord(0,1,0,1)
  V.tableSurface:SetVertexColor(1,1,1,1)
  V.tableSurface:SetAlpha(1)
  V.tableSurface:Show()
 end
 -- Build the wood / cloth finish from native WoW textures. These render on 3.3.5a
 -- even when an external TGA/BLP file cannot be decoded by the client.
 local palettes={
  TAVERN={{0.30,0.17,0.09},{0.37,0.22,0.12},{0.33,0.19,0.10}},
  IRONFORGE={{0.19,0.20,0.22},{0.28,0.29,0.31},{0.23,0.24,0.26}},
  HORDE={{0.25,0.095,0.065},{0.34,0.13,0.075},{0.29,0.11,0.065}},
  STORMWIND={{0.09,0.16,0.29},{0.13,0.23,0.38},{0.11,0.19,0.34}},
  BOOTYBAY={{0.26,0.17,0.09},{0.38,0.26,0.14},{0.31,0.21,0.11}},
  ARCANE={{0.17,0.10,0.25},{0.25,0.15,0.35},{0.21,0.12,0.30}}
 }
 local pal=palettes[current.id] or palettes.TAVERN
  local isSolid=string.sub(current.id,1,5)=='SOLID'
 if isSolid then V.tableSurface:SetVertexColor(c[1],c[2],c[3],1) else V.tableSurface:SetVertexColor(pal[1][1],pal[1][2],pal[1][3],1) end
 if V.tablePlanks then
  for i,plank in ipairs(V.tablePlanks) do
   local tone=pal[((i*7)%3)+1]
   local variation=(((i*13)%7)-3)*0.008
   plank:SetVertexColor(math.max(0,tone[1]+variation),math.max(0,tone[2]+variation),math.max(0,tone[3]+variation),1)
   if isSolid then plank:Hide() else plank:Show() end
  end
 end
 if V.tableSeams then
  for i,seam in ipairs(V.tableSeams) do
   seam:SetVertexColor(0.025,0.018,0.012,0.52)
   if isSolid then seam:Hide() else seam:Show() end
  end
 end
 if V.tableHighlights then
  for i,line in ipairs(V.tableHighlights) do
   local tint=pal[((i*5)%3)+1]
   line:SetVertexColor(math.min(1,tint[1]*1.8),math.min(1,tint[2]*1.8),math.min(1,tint[3]*1.8),0.32)
   if isSolid then line:Hide() else line:Show() end
  end
 end
 if V.tableGrain then
  for i,line in ipairs(V.tableGrain) do
   local tint=pal[((i*3)%3)+1]
   if i%3==0 then line:SetVertexColor(0.025,0.02,0.015,0.22)
   else line:SetVertexColor(math.min(1,tint[1]*1.6),math.min(1,tint[2]*1.6),math.min(1,tint[3]*1.6),0.27) end
   if isSolid then line:Hide() else line:Show() end
  end
 end
 if V.tableDetails then
  for i,detail in ipairs(V.tableDetails) do
   if current.id=='IRONFORGE' then detail:SetVertexColor(0.57,0.50,0.36,0.70)
   elseif current.id=='ARCANE' then detail:SetVertexColor(0.54,0.34,0.74,0.48)
   elseif current.id=='STORMWIND' then detail:SetVertexColor(0.70,0.53,0.24,0.54)
   else detail:SetVertexColor(0.06,0.04,0.025,0.52) end
   if isSolid then detail:Hide() else detail:Show() end
  end
 end
 -- Theme-specific accents: restrained metal corner plates, trim and emblem.
 local accents={
  TAVERN={0.72,0.46,0.20,'TAVERN'},
  IRONFORGE={0.73,0.68,0.55,'IRONFORGE'},
  HORDE={0.67,0.24,0.17,'HORDE'},
  STORMWIND={0.78,0.62,0.29,'STORMWIND'},
  BOOTYBAY={0.62,0.46,0.24,'BOOTY BAY'},
  ARCANE={0.65,0.43,0.85,'ARCANE'}
 }
 local a=accents[current.id] or accents.TAVERN
 if V.decorTrim then
  for _,t in ipairs(V.decorTrim) do t:SetVertexColor(a[1],a[2],a[3],0.72);if isSolid then t:Hide() else t:Show() end end
 end
 if V.decorPlates then
  for _,t in ipairs(V.decorPlates) do t:SetVertexColor(a[1]*0.58,a[2]*0.58,a[3]*0.58,0.88);if isSolid then t:Hide() else t:Show() end end
 end
 if V.decorRivets then
  for _,t in ipairs(V.decorRivets) do t:SetVertexColor(math.min(1,a[1]*1.25),math.min(1,a[2]*1.25),math.min(1,a[3]*1.25),0.92);if isSolid then t:Hide() else t:Show() end end
 end
 if V.decorLabel then
  V.decorLabel:SetText(isSolid and "" or a[4]);V.decorLabel:SetTextColor(a[1],a[2],a[3],0.65)
 end
 V.title:SetText('POKER TABLE 7.0 - '..string.upper(current.name))
 if V.themeButton then V.themeButton:SetText('Theme: '..current.name) end
 if V.settingsTheme then V.settingsTheme:SetText('Table Theme: '..current.name) end
end
local function toggleTheme()
 local current=theme()
 for i,v in ipairs(TABLE_THEMES) do
  if v.id==current.id then RaidPokerWotLKDB.tableTheme=TABLE_THEMES[(i%#TABLE_THEMES)+1].id;break end
 end
 themeApply()
end
local function names()
 local g=R.G;local players={}
 for _,p in ipairs(g.players or {}) do table.insert(players,p) end
 local positions=RaidPokerWotLKDB.seatPositions or {}
 table.sort(players,function(a,b)
  local ia,ib=positions[a.name],positions[b.name]
  if ia and ib and ia~=ib then return ia<ib end
  if ia and not ib then return true end
  if ib and not ia then return false end
  local oa,ob=99,99
  for i,p in ipairs(g.players or {}) do if p.name==a.name then oa=i end;if p.name==b.name then ob=i end end
  return oa<ob
 end)
 return players
end
local function status(p)
 if p.fold then return 'FOLD' end
 if p.allin then return 'ALL-IN' end
 if p.inhand then return p.done and 'ACTED' or 'PLAYING' end
 return 'WAITING'
end
local function setSeat(index)
 local g=R.G
 if g.phase~='IDLE' and g.phase~='LOBBY' and g.phase~='SHOWDOWN' then R.Print('Change seats between hands only.');return end
 local me=UnitName('player')
 local canManage=(R.IsPokerHost and R.IsPokerHost()) or g.solo
 if not canManage then R.Print('Seat management: host only.');return end
 if not V.selectedSeat then
  V.selectedSeat=index;V.message:SetText('Selected seat '..index..'. Click another occupied seat to swap.')
  return
 end
 if V.selectedSeat==index then V.selectedSeat=nil;V.message:SetText('Seat selection cleared.');return end
 local list=names();local first=list[V.selectedSeat];local second=list[index]
 if not first or not second then V.selectedSeat=nil;V.message:SetText('Select two occupied seats.');return end
 RaidPokerWotLKDB.seatPositions=RaidPokerWotLKDB.seatPositions or {}
 local map=RaidPokerWotLKDB.seatPositions
 -- Materialize the current visual order before swapping positions.
 for i,p in ipairs(list) do map[p.name]=i end
 map[first.name]=index;map[second.name]=V.selectedSeat
 V.selectedSeat=nil;V.message:SetText('Seats updated for raid (display order only).')
 R.Refresh();sendSeats()
end
local oldBuild=R.BuildGame
function R.BuildGame(main)
 oldBuild(main)
 local ui=R.GameUI
 if not ui or not ui.table then return end
 -- Keep the original frame and sort logic intact, but use a separate visual table.
 V.oldTable=ui.table
 local f=CreateFrame('Frame','RaidFivePokerVisualTable',UIParent)
 f:SetWidth(760);f:SetHeight(515);f:SetFrameStrata('DIALOG');f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true)
 f:SetPoint('CENTER',UIParent,'CENTER',RaidPokerWotLKDB.tableX or 0,RaidPokerWotLKDB.tableY or 100)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=28,insets={left=11,right=11,top=11,bottom=11}})
 R.RegisterBackground(f,0.13,0.065,0.025,1)
 V.frame=f;R.TableFrame=f
 f:SetScale(RaidPokerWotLKDB.tableScale or 1)
 local drag=CreateFrame('Frame',nil,f);drag:SetPoint('TOPLEFT',f,15,-9);drag:SetPoint('TOPRIGHT',f,-47,-9);drag:SetHeight(31)
 drag:EnableMouse(true);drag:RegisterForDrag('LeftButton')
 drag:SetScript('OnDragStart',function()f:StartMoving()end)
 drag:SetScript('OnDragStop',function()
  f:StopMovingOrSizing();local x,y=f:GetCenter();local a,b=UIParent:GetCenter()
  if x and a then RaidPokerWotLKDB.tableX=x-a;RaidPokerWotLKDB.tableY=y-b end
 end)
 V.title=txt(f,22,-19,480,'POKER TABLE 4.0','GameFontNormalLarge')
 btn(f,'X',713,-13,29,function()f:Hide()end)
 -- One uninterrupted, full-window table material, behind every seat and card.
 V.tableSurface=f:CreateTexture(nil,'ARTWORK',nil,0)
 V.tableSurface:SetPoint('TOPLEFT',f,'TOPLEFT',12,-34)
 V.tableSurface:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-12,32)
 V.tableSurface:SetTexCoord(0,1,0,1)
 -- Procedural wood / cloth surface, all using WHITE8X8 supported by WotLK.
 -- Twelve wide horizontal planks with subtle, deterministic variation.
 V.tablePlanks={}
 for i=1,12 do
  local strip=f:CreateTexture(nil,'ARTWORK',nil,1)
  strip:SetTexture('Interface\\Buttons\\WHITE8X8')
  strip:SetPoint('TOPLEFT',f,'TOPLEFT',13,-35-(i-1)*39)
  strip:SetWidth(734);strip:SetHeight(38)
  V.tablePlanks[i]=strip
 end
 -- Dark join lines plus a light rim on the upper side of each plank.
 V.tableSeams={};V.tableHighlights={}
 for i=1,11 do
  local seam=f:CreateTexture(nil,'ARTWORK',nil,2)
  seam:SetTexture('Interface\\Buttons\\WHITE8X8')
  seam:SetPoint('TOPLEFT',f,'TOPLEFT',13,-35-i*39+1)
  seam:SetWidth(734);seam:SetHeight(2)
  V.tableSeams[i]=seam
  local highlight=f:CreateTexture(nil,'ARTWORK',nil,3)
  highlight:SetTexture('Interface\\Buttons\\WHITE8X8')
  highlight:SetPoint('TOPLEFT',f,'TOPLEFT',13,-35-i*39+3)
  highlight:SetWidth(734);highlight:SetHeight(1)
  V.tableHighlights[i]=highlight
 end
 -- Thin staggered grain strokes. No external artwork or runtime randomness.
 V.tableGrain={}
 for i=1,108 do
  local line=f:CreateTexture(nil,'ARTWORK',nil,4)
  line:SetTexture('Interface\\Buttons\\WHITE8X8')
  local plank=math.floor((i-1)/9)
  local within=(i-1)%9
  local x=23+((i*83+plank*41)%190)
  local y=-41-plank*39-within*3
  line:SetPoint('TOPLEFT',f,'TOPLEFT',x,y)
  line:SetWidth(260+((i*71)%265));line:SetHeight(1)
  V.tableGrain[i]=line
 end
 -- Small staggered nail / metal rivet marks near plank ends.
 V.tableDetails={}
 for i=1,24 do
  local dot=f:CreateTexture(nil,'ARTWORK',nil,5)
  dot:SetTexture('Interface\\Buttons\\WHITE8X8')
  local row=math.floor((i-1)/2)
  local side=(i%2==1) and 28 or 720
  dot:SetPoint('TOPLEFT',f,'TOPLEFT',side+((row*7)%13),-50-row*39)
  dot:SetWidth(3);dot:SetHeight(3)
  V.tableDetails[i]=dot
 end
 -- Decorative fittings are placed on the ARTWORK layer, below seat overlays.
 -- Use only native WHITE8X8 so every accent works in WoW 3.3.5a.
 local function decorRect(x,y,w,h,layer)
  local t=f:CreateTexture(nil,'ARTWORK',nil,layer or -1)
  t:SetTexture('Interface\\Buttons\\WHITE8X8')
  t:SetPoint('TOPLEFT',f,'TOPLEFT',x,y)
  t:SetWidth(w);t:SetHeight(h)
  return t
 end
 V.decorTrim={}
 -- Narrow metal bands inset from the tabletop edges.
 for _,v in ipairs({{19,-39,721,2},{19,-491,721,2},{19,-39,2,454},{738,-39,2,454}}) do
  table.insert(V.decorTrim,decorRect(v[1],v[2],v[3],v[4],6))
 end
 V.decorPlates={};V.decorRivets={}
 -- Corner brackets, with two distinct rivets on each plate.
 for _,p in ipairs({{23,-45},{699,-45},{23,-454},{699,-454}}) do
  table.insert(V.decorPlates,decorRect(p[1],p[2],35,29,6))
  table.insert(V.decorRivets,decorRect(p[1]+6,p[2]-7,4,4,7))
  table.insert(V.decorRivets,decorRect(p[1]+25,p[2]-19,4,4,7))
 end
 -- Small centered maker's mark, kept clear of the middle pot and player seats.
 V.decorLabel=f:CreateFontString(nil,'ARTWORK','GameFontNormalSmall')
 V.decorLabel:SetPoint('BOTTOM',f,'BOTTOM',0,41)
 V.decorLabel:SetWidth(170)
 V.decorLabel:SetJustifyH('CENTER')
 -- Legacy oval shapes are retained as hidden placeholders for Table7 compatibility.
 V.ring=f:CreateTexture(nil,'BACKGROUND');V.ring:SetTexture('Interface\\Buttons\\WHITE8X8');V.ring:SetPoint('TOPLEFT',f,95,-107);V.ring:SetWidth(570);V.ring:SetHeight(315)
 V.felt=f:CreateTexture(nil,'BORDER');V.felt:SetTexture('Interface\\Buttons\\WHITE8X8');V.felt:SetPoint('TOPLEFT',f,107,-119);V.felt:SetWidth(546);V.felt:SetHeight(291)
 V.ring:Hide();V.felt:Hide()
 local center=CreateFrame('Frame',nil,f);center:SetPoint('CENTER',f,'CENTER',0,4);center:SetWidth(280);center:SetHeight(130)
 V.pot=txt(center,30,-13,250,'POT  0s','GameFontNormalLarge')
 V.phase=txt(center,30,-44,250,'Waiting for players')
 -- A clearly labelled central pot, separate from the five-card hands at each seat.
 V.chipLabel=txt(center,30,-62,150,'GOLD / SILVER','GameFontNormalSmall')
 V.chips={}
 V.chipBacks={}
 for i=1,3 do
  local back=center:CreateTexture(nil,'ARTWORK')
  back:SetTexture('Interface\\Buttons\\WHITE8X8')
  back:SetVertexColor(0.82,0.58,0.18,0.9)
  back:SetWidth(24);back:SetHeight(24)
  back:SetPoint('TOPLEFT',center,45+(i-1)*27,-80)
  back:Hide()
  V.chipBacks[i]=back
 end
 for i=1,3 do
  local chip=center:CreateTexture(nil,'OVERLAY')
  chip:SetTexture(coinTexture(i==1))
  chip:SetWidth(30);chip:SetHeight(30)
  chip:SetPoint('TOPLEFT',center,42+(i-1)*27,-77)
  chip:Hide();V.chips[i]=chip
 end
 -- Guaranteed-visible denomination symbols on procedural coin badges.
 V.chipLetters={}
 for i=1,3 do
  local letter=center:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
  letter:SetPoint('CENTER',V.chips[i],'CENTER',0,0)
  letter:SetText('')
  letter:SetTextColor(0.10,0.08,0.04,1)
  letter:Hide()
  V.chipLetters[i]=letter
 end
 -- Visual-only chip transfer and card-deal effects. All betting state remains in Game.lua.
 V.motion={};V.motionLayer=CreateFrame('Frame',nil,f)
 V.motionLayer:SetAllPoints(f);V.motionLayer:SetFrameStrata(f:GetFrameStrata());V.motionLayer:SetFrameLevel(f:GetFrameLevel()+30)
 -- Restore the original v1.7.33a coin sprites (client-native currency icons).
 -- Unlike the procedural replacement, these are Texture objects, not Frames.
 local function sprite(texture,w,h)
  local t=V.motionLayer:CreateTexture(nil,'OVERLAY')
  t:SetTexture(texture);t:SetWidth(w);t:SetHeight(h);t:Hide()
  return t
 end
 for i=1,12 do V.motion[i]=sprite(coinTexture(i%2==1),26,26) end
 for i=13,62 do V.motion[i]=sprite(CARD_BACK,18,25) end
 V.animations={}
 V.winBanner=CreateFrame('Frame',nil,f)
 V.winBanner:SetWidth(310);V.winBanner:SetHeight(42)
 V.winBanner:SetPoint('CENTER',f,'CENTER',0,22)
 V.winBanner:SetFrameLevel(f:GetFrameLevel()+12)
 V.winBanner:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 V.winBanner:SetBackdropColor(0.12,0.075,0.015,0.92)
 V.winBanner:SetBackdropBorderColor(0.95,0.75,0.24,1)
 V.winBannerText=V.winBanner:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 V.winBannerText:SetPoint('CENTER',V.winBanner,'CENTER',0,0)
 V.winBannerText:SetTextColor(1,0.85,0.36)
 V.winBanner:Hide()

 V.launch=function(kind,index)
  if not f:IsShown() or RaidPokerWotLKDB.tableAnimations==false then return end
  if kind=='CHIP' and RaidPokerWotLKDB.tableBetEffects==false then return end
  if kind=='WIN' and RaidPokerWotLKDB.tableWinnerEffects==false then return end
  local count=0
  for motionIndex,t in ipairs(V.motion) do if (kind=='CARD' and motionIndex>=13 or kind~='CARD' and motionIndex<=12) and not t:IsShown() then
   count=count+1
   local seatNumber=kind=='CARD' and (math.floor((count-1)/5)+1) or (index or count)
   local from=V.seats and V.seats[seatNumber]
   local x,y=from and from:GetCenter() or f:GetCenter()
   local fx,fy=f:GetCenter()
   local dx,dy=(x or fx)-fx,(y or fy)-fy
   local isCard=kind=='CARD'
   local isWin=kind=='WIN'
   local sx,sy=isCard and 0 or (isWin and 0 or dx),isCard and 35 or (isWin and 0 or dy)
   local ex,ey=isCard and (dx-44+((count-1)%5)*24) or (isWin and dx or 0),isCard and (dy-13) or (isWin and dy or 0)
   local potValue=(RPoker.game and RPoker.game.pot) or 0
   local coinKind=(potValue>=100 and 2 or 1)
   t:SetTexture(isCard and CARD_BACK or coinTexture(coinKind==1))
   t:SetVertexColor(1,1,1,1)
   t:ClearAllPoints();t:SetPoint('CENTER',f,'CENTER',sx,sy);t:SetAlpha(1);t:Show()
   V.animations[t]={sx=sx,sy=sy,ex=ex,ey=ey,elapsed=0,duration=0.6+count*0.045}
   if count>= (isCard and math.min(50,#names()*5) or 3) then break end
  end end
 end
 -- Ten fixed positions around the felt, with compact five-card backs.
 local pos={{275,-64},{438,-84},{546,-154},{546,-273},{438,-380},{275,-380},{108,-380},{18,-273},{18,-154},{108,-84}}
 -- Active seats are arranged symmetrically; unused seat frames are hidden.
 -- The ten-player layout retains the established positions.
 local layouts={
  [1]={1},
  [2]={10,2},
  [3]={10,2,6},
  [4]={10,2,4,8},
  [5]={1,3,5,7,9},
  [6]={10,2,4,6,7,8},
  [7]={1,2,3,4,6,8,9},
  [8]={10,1,2,3,4,6,7,8},
  [9]={1,2,3,4,5,6,7,8,9},
  [10]={1,2,3,4,5,6,7,8,9,10},
 }
 V.arrangeSeats=function(count)
  count=math.min(10,math.max(0,count or 0))
  local layout=layouts[count] or {}
  for i,seat in ipairs(V.seats or {}) do
   if i<=count then
    local slot=layout[i]
    seat:ClearAllPoints()
    seat:SetPoint('TOPLEFT',f,'TOPLEFT',math.max(20,math.min(542,pos[slot][1])),pos[slot][2])
    seat:Show()
   else
    seat:Hide()
   end
  end
 end
 V.seats={}
 for i=1,10 do
  local x,y=pos[i][1],pos[i][2]
  local s=CreateFrame('Button',nil,f)
  s:SetWidth(194);s:SetHeight(74);s:SetPoint('TOPLEFT',f,'TOPLEFT',math.max(20,math.min(542,x)),y)
  s:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
  s:SetBackdropColor(0.035,0.035,0.04,0.94);s:SetBackdropBorderColor(0.43,0.34,0.2,1)
  s.number=txt(s,7,-7,16,tostring(i),'GameFontNormalSmall')
  s.portrait=s:CreateTexture(nil,'ARTWORK');s.portrait:SetWidth(30);s.portrait:SetHeight(30)
  s.portrait:SetPoint('TOPLEFT',s,'TOPLEFT',22,-7)
  s.portrait:SetTexture('Interface\\Icons\\INV_Misc_Dice_02')
  s.name=txt(s,58,-7,112,'Empty seat','GameFontHighlightSmall')
  s.info=txt(s,58,-24,130,'','GameFontHighlightSmall')
  s.dealer=txt(s,174,-7,18,'','GameFontNormal')
  s.status=txt(s,150,-24,44,'','GameFontNormalSmall')
  s.win=txt(s,6,-56,185,'','GameFontNormalSmall')
  -- Separate additive highlight; never changes card visibility or game state.
  s.turnGlow=s:CreateTexture(nil,'OVERLAY')
  s.turnGlow:SetTexture('Interface\\Buttons\\WHITE8X8')
  s.turnGlow:SetPoint('TOPLEFT',s,'TOPLEFT',3,-3)
  s.turnGlow:SetPoint('BOTTOMRIGHT',s,'BOTTOMRIGHT',-3,3)
  s.turnGlow:SetBlendMode('ADD');s.turnGlow:SetVertexColor(0.35,0.68,0.17,0.08);s.turnGlow:Hide()
  s.winGlow=s:CreateTexture(nil,'OVERLAY')
  s.winGlow:SetTexture('Interface\\Buttons\\WHITE8X8')
  s.winGlow:SetAllPoints(s.turnGlow)
  s.winGlow:SetBlendMode('ADD');s.winGlow:SetVertexColor(1,0.72,0.1,0.1);s.winGlow:Hide()
  s.betChip=s:CreateTexture(nil,'ARTWORK');s.betChip:SetTexture(coinTexture(true));s.betChip:SetWidth(18);s.betChip:SetHeight(18);s.betChip:SetPoint('TOPRIGHT',s,'TOPRIGHT',-5,-27);s.betChip:Hide()
  s.cards={}
  s.cardFaces={} -- separate face layer; never reuse the card-back texture for face art
  for c=1,5 do
   local t=s:CreateTexture(nil,'OVERLAY');t:SetTexture(CARD_BACK);t:SetTexCoord(0,1,0,1);t:SetWidth(19);t:SetHeight(26)
   t:SetPoint('TOPLEFT',s,57+(c-1)*24,-43);t:Hide();s.cards[c]=t
   local face=s:CreateTexture(nil,'OVERLAY')
   face:SetTexture(CARD_BACK);face:SetAllPoints(t);face:Hide()
   s.cardFaces[c]=face
  end
  s:SetScript('OnClick',function()setSeat(i)end)
  V.seats[i]=s
 end
 V.message=txt(f,20,-475,340,'Host: click two seats to swap positions for the raid.')
 V.themeButton=btn(f,'Theme: Tavern',492,-466,137,toggleTheme)
 btn(f,'Table Options',380,-466,108,function() if V.options:IsShown() then V.options:Hide() else V.options:Show() end end)
 btn(f,'Reset Seats',636,-466,105,function()
  RaidPokerWotLKDB.seatPositions={};V.selectedSeat=nil;V.message:SetText('Default seating restored.');R.Refresh();sendSeats()
 end)
 local opt=CreateFrame('Frame',nil,UIParent);opt:SetWidth(340);opt:SetHeight(620);opt:SetFrameStrata('FULLSCREEN_DIALOG');opt:SetPoint('CENTER',UIParent,'CENTER',0,0);opt:SetMovable(true);opt:SetClampedToScreen(true);opt:EnableMouse(true)
 opt:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 opt:SetBackdropColor(0.06,0.055,0.045,0.97);V.options=opt
 local optDrag=CreateFrame('Frame',nil,opt)
 optDrag:SetPoint('TOPLEFT',opt,'TOPLEFT',12,-9);optDrag:SetPoint('TOPRIGHT',opt,'TOPRIGHT',-48,-9)
 optDrag:SetHeight(39);optDrag:EnableMouse(true);optDrag:RegisterForDrag('LeftButton')
 optDrag:SetScript('OnDragStart',function()opt:StartMoving()end)
 optDrag:SetScript('OnDragStop',function()opt:StopMovingOrSizing()end)
 txt(opt,30,-24,240,'POKER TABLE OPTIONS','GameFontNormalLarge')
 btn(opt,'X',295,-15,27,function()opt:Hide()end)
 local scaleLabel=txt(opt,38,-72,250,'Table scale','GameFontNormal')
 local scaleSlider=CreateFrame('Slider','RaidPokerVisualTableScale',opt,'OptionsSliderTemplate')
 scaleSlider:SetWidth(225);scaleSlider:SetHeight(16);scaleSlider:SetPoint('TOP',opt,'TOP',0,-106)
 scaleSlider:SetMinMaxValues(0.7,1.3);scaleSlider:SetValueStep(0.05)
 getglobal(scaleSlider:GetName()..'Low'):SetText('70%');getglobal(scaleSlider:GetName()..'High'):SetText('130%')
 scaleSlider:SetValue(RaidPokerWotLKDB.tableScale or 1)
 scaleSlider:SetScript('OnValueChanged',function(self,value)
  value=math.floor(value*20+0.5)/20;RaidPokerWotLKDB.tableScale=value;f:SetScale(value);scaleLabel:SetText('Table scale: '..math.floor(value*100+0.5)..'%')
 end)
 local function option(label,key,y)
  local b=btn(opt,label,40,y,260,function()
   RaidPokerWotLKDB[key]=RaidPokerWotLKDB[key]==false and true or false
   if R.Refresh then R.Refresh() end
   if V.updateOptions then V.updateOptions() end
  end)
  return b
 end
 local cardsOption=option('Mini Cards', 'tableMiniCards',-152)
 local animOption=option('Animations','tableAnimations',-184)
 local portraitsOption=option('Player Portraits','tablePortraits',-216)
 local turnOption=option('Active Turn Glow','tableTurnGlow',-248)
 local betOption=option('Bet Effects','tableBetEffects',-280)
 local winOption=option('Winner Effects','tableWinnerEffects',-312)
 V.updateOptions=function()
  cardsOption:SetText('Mini Cards: '..(RaidPokerWotLKDB.tableMiniCards==false and 'OFF' or 'ON'))
  animOption:SetText('Animations: '..(RaidPokerWotLKDB.tableAnimations==false and 'OFF' or 'ON'))
  portraitsOption:SetText('Player Portraits: '..(RaidPokerWotLKDB.tablePortraits==false and 'OFF' or 'ON'))
  turnOption:SetText('Active Turn Glow: '..(RaidPokerWotLKDB.tableTurnGlow==false and 'OFF' or 'ON'))
  betOption:SetText('Bet Effects: '..(RaidPokerWotLKDB.tableBetEffects==false and 'OFF' or 'ON'))
  winOption:SetText('Winner Effects: '..(RaidPokerWotLKDB.tableWinnerEffects==false and 'OFF' or 'ON'))
 end
 V.updateOptions();opt:Hide()
 local settings=R.SettingsFrame
 if settings then
  V.settingsTheme=btn(settings,'Table Theme: Tavern',77,-427,210,toggleTheme)
  V.settingsEffects=btn(settings,'Poker Table Effects',90,-598,180,function()
   if not V.options then return end
   if V.options:IsShown() then V.options:Hide() else V.updateOptions();V.options:Show() end
  end)
 end
 -- The old 405px list is not shown, but its data and existing UI hooks remain.
 R.ToggleTable=function()
  V.oldTable:Hide()
  if f:IsShown() then f:Hide();opt:Hide() else f:Show();requestSeats();R.Refresh(); if V.pendingDeal then V.pendingDeal=false;V.launch('CARD',1) end end
 end
 f:SetScript('OnHide',function()opt:Hide()end)
 f:Hide();themeApply()
 -- Opening the main frame or closing it preserves the existing table behavior.
end
local oldRefresh=R.Refresh
function R.Refresh()
 oldRefresh()
 if not V.frame then return end
 local g=R.G
 clearOldReveals(g.round or 0)
 local list=names();local count=#list
 V.arrangeSeats(count)
 if (g.round or 0)>0 and g.phase~='LOBBY' and g.phase~='IDLE' and g.phase~='SHOWDOWN' and V.lastDealtRound~=(g.round or 0) then
  V.lastDealtRound=g.round or 0
  if V.frame:IsShown() then V.launch('CARD',1) else V.pendingDeal=true end
 end
 if V.lastPot~=nil and (g.pot or 0)>V.lastPot and (g.phase=='BET1' or g.phase=='BET2' or g.phase=='DRAW') then
  local idx=1;for j,p in ipairs(list) do if p.name==g.turn then idx=j;break end end
  V.launch('CHIP',idx)
 end
 V.lastRound=g.round or 0;V.lastPot=g.pot or 0
 V.pot:SetText('POT  '..formatMoney(g.pot))
 if g.solo then V.message:SetText('SOLO DEBUG  |  Local game')
 elseif isHost() then V.message:SetText('RAID HOST  |  Seat sync enabled')
 elseif g.host and g.host~='' then V.message:SetText('RAID CLIENT  |  Host: '..g.host)
 else V.message:SetText('Not connected to a poker host') end
 V.chipLabel:SetText((g.pot or 0)>0 and 'GOLD / SILVER' or '')
 V.phase:SetText('Round '..tostring(g.round or 0)..'  |  '..tostring(g.phase or 'IDLE'))
 if V.winBanner and (g.phase~='SHOWDOWN' or RaidPokerWotLKDB.tableWinnerEffects==false) then V.winBanner:Hide();V.winBannerTime=nil end
 if g.phase=='SHOWDOWN' and g.winner and g.winner~='' then
  V.phase:SetText('WINNER: '..string.sub(R.MoneyText(g.winner),1,40))
  if V.lastWinnerRound~=(g.round or 0) then
   V.lastWinnerRound=g.round or 0;V.winElapsed=0;V.winName=string.match(g.winner,'^([^ ;]+)')
   V.winTransferPending=true
   if V.winBanner and RaidPokerWotLKDB.tableWinnerEffects~=false then
    V.winBannerText:SetText('WINNER: '..string.sub(V.winName or '?',1,22))
    V.winBannerTime=0;V.winBanner:Show()
   end

  end
 end
 local n=math.min(3,math.max(1,math.ceil((g.pot or 0)/math.max(1,(g.ante or 10)*4))))
 local gold=math.floor((g.pot or 0)/100)
 local silver=(g.pot or 0)%100
 V.chipLabel:SetText('GOLD: '..gold..'  SILVER: '..silver)
 for i,chip in ipairs(V.chips) do
  local visible=(i==1 and gold>0) or (i==2 and silver>0) or (i==3 and gold>=5)
  chip:SetTexture(coinTexture(i==2))
  chip:SetVertexColor(1,1,1,1)
  if V.chipLetters and V.chipLetters[i] then if visible then V.chipLetters[i]:Show() else V.chipLetters[i]:Hide() end end
  if visible then
   chip:Show();V.chipBacks[i]:Hide()
   if i==2 then V.chipBacks[i]:SetVertexColor(0.64,0.72,0.8,0.95)
   else V.chipBacks[i]:SetVertexColor(0.82,0.58,0.18,0.95) end
  else chip:Hide();V.chipBacks[i]:Hide() end
 end
 if V.winTransferPending and V.frame:IsShown() then
  V.winTransferPending=false
  local winnerIndex
  for j,p in ipairs(list) do if p.name==V.winName then winnerIndex=j;break end end
  if winnerIndex then V.launch('WIN',winnerIndex) end
 end
 local dealerIndex=1
 if count>0 and RaidPokerWotLKDB.dealerRotation~=false then dealerIndex=((math.max(1,g.round or 1)-1)%count)+1 end
 local round=g.round or 0
 if V.round~=round then V.round=round;V.dealElapsed=0 end
 for i,s in ipairs(V.seats) do
  local p=list[i]
  if p then
   local st=status(p)
   s.name:SetText(string.sub(p.name or '?',1,16))
   local _,class=UnitClass(p.name or '')
   if p.name==UnitName('player') then _,class=UnitClass('player') end
   local portraitUnit=nil
   if p.name==UnitName('player') then portraitUnit='player'
   elseif isRaid() then
    for u=1,GetNumRaidMembers() do
     local unit='raid'..u
     if UnitName(unit)==p.name then portraitUnit=unit;break end
    end
   end
   if RaidPokerWotLKDB.tablePortraits~=false and portraitUnit and UnitExists(portraitUnit) then
    SetPortraitTexture(s.portrait,portraitUnit);s.portrait:SetTexCoord(0,1,0,1)
   elseif class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
    local c=CLASS_ICON_TCOORDS[class]
    s.portrait:SetTexture('Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes')
    s.portrait:SetTexCoord(c[1],c[2],c[3],c[4])
   else
    s.portrait:SetTexture('Interface\\Icons\\INV_Misc_Dice_02')
    s.portrait:SetTexCoord(0,1,0,1)
   end
   s.portrait:Show()
   s.info:SetText(R.Money(p.balance)..' | Bet '..R.Money(p.paid))
   s.status:SetText(st)
   if (p.paid or 0)>0 then s.betChip:SetTexture(coinTexture((p.paid or 0)<100));s.betChip:Show() else s.betChip:Hide() end
   s.status:SetTextColor(p.fold and 0.6 or 1,p.fold and 0.6 or (p.allin and 0.4 or 0.83),p.fold and 0.6 or 0.2)
   s.dealer:SetText(i==dealerIndex and 'D' or '')
   s.win:SetText((g.phase=='SHOWDOWN' and V.winName==p.name) and 'WINNER!' or '')
   if p.name==g.turn and RaidPokerWotLKDB.tableTurnGlow~=false and g.phase~='SHOWDOWN' then s.turnGlow:Show() else s.turnGlow:Hide() end
   if g.phase=='SHOWDOWN' and V.winName==p.name and RaidPokerWotLKDB.tableWinnerEffects~=false then s.winGlow:Show() else s.winGlow:Hide() end
   if p.name==g.turn then
    s:SetBackdropColor(0.1,0.24,0.12,0.96);s:SetBackdropBorderColor(1,0.82,0.3,1)
    s.name:SetTextColor(1,0.91,0.42)
   elseif p.fold then
    s:SetBackdropColor(0.045,0.045,0.045,0.86);s:SetBackdropBorderColor(0.25,0.25,0.25,1)
    s.name:SetTextColor(0.55,0.55,0.55)
   else
    s:SetBackdropColor(0.035,0.035,0.04,0.94);s:SetBackdropBorderColor(0.43,0.34,0.2,1)
    s.name:SetTextColor(0.9,0.88,0.77)
   end
   local revealed=g.phase=='SHOWDOWN' and revealCache[g.round or 0] and revealCache[g.round or 0][p.name]
   local active=p.inhand and not p.fold and (g.phase=='BET1' or g.phase=='DRAW' or g.phase=='BET2')
   for c,card in ipairs(s.cards) do
    card:SetAlpha(1)
    local face=s.cardFaces[c]
    -- Privacy invariant: the back texture is never changed to face art.
    -- Face art lives in a second texture and is shown only during SHOWDOWN.
    card:SetTexture(CARD_BACK)
    face:Hide()
    if RaidPokerWotLKDB.tableMiniCards==false then card:Hide()
    elseif revealed and revealed.cards[c] then
     face:SetTexture(artFor(revealed.cards[c]));card:Show();face:Show()
    elseif active then card:Show()
    else card:Hide() end
   end
   if revealed and revealed.combo and revealed.combo~='' then s.status:SetText(revealed.combo) end
  else
   s.turnGlow:Hide();s.winGlow:Hide()
   s.name:SetText('Empty seat');s.info:SetText('');s.dealer:SetText('');s.status:SetText('');s.win:SetText('');s.portrait:Hide();s.betChip:Hide()
   s:SetBackdropColor(0.025,0.025,0.025,0.65);s:SetBackdropBorderColor(0.28,0.25,0.2,1)
   s.name:SetTextColor(0.5,0.5,0.5)
   for _,card in ipairs(s.cards) do card:Hide() end
   for _,face in ipairs(s.cardFaces or {}) do face:Hide() end
  end
  if V.selectedSeat==i then s:SetBackdropBorderColor(0.2,0.8,1,1) end
 end
 -- Restore the chosen wood/solid finish after all gameplay refresh hooks.
 themeApply()
end
-- A lightweight staggered reveal for the decorative table card backs.
local ticker=CreateFrame('Frame')
ticker:SetScript('OnUpdate',function(self,dt)
 if not V.frame or not V.frame:IsShown() then return end
 -- Reassert native table layers when game phase changes. Some other table
 -- refresh paths may change visibility during DRAW / BETTING / SHOWDOWN.
 local currentPhase=(R.G and R.G.phase) or 'IDLE'
 if V.surfacePhase~=currentPhase then
  V.surfacePhase=currentPhase
  themeApply()
 end
 for t,a in pairs(V.animations or {}) do
  a.elapsed=a.elapsed+dt;local k=math.min(1,a.elapsed/a.duration)
  t:ClearAllPoints();t:SetPoint('CENTER',V.frame,'CENTER',a.sx+(a.ex-a.sx)*k,a.sy+(a.ey-a.sy)*k)
  t:SetAlpha(k>0.8 and (1-k)*5 or 1)
  if k>=1 then t:Hide();V.animations[t]=nil end
 end
 V.effectClock=(V.effectClock or 0)+dt
 if V.winBannerTime and V.winBanner and V.winBanner:IsShown() then
  V.winBannerTime=V.winBannerTime+dt
  local t=V.winBannerTime
  local alpha=math.min(1,t*3,math.max(0,(4.2-t)*2))
  V.winBanner:SetAlpha(alpha)
  if t>=4.2 then V.winBanner:Hide();V.winBannerTime=nil end
 end

 if V.seats then
  for _,seat in ipairs(V.seats) do
   if seat.turnGlow and seat.turnGlow:IsShown() then
    seat.turnGlow:SetVertexColor(0.3,0.85,0.22,0.09+0.13*(0.5+0.5*math.sin(V.effectClock*5)))
   end
   if seat.winGlow and seat.winGlow:IsShown() then
    seat.winGlow:SetVertexColor(1,0.75,0.12,0.08+0.19*(0.5+0.5*math.sin(V.effectClock*6)))
   end
  end
 end
 if V.winElapsed and RaidPokerWotLKDB.tableWinnerEffects~=false then
  V.winElapsed=V.winElapsed+dt
  for i,seat in ipairs(V.seats or {}) do
   if seat.win and seat.win:GetText()=='WINNER!' then seat.win:SetTextColor(1,0.7+0.3*math.abs(math.sin(V.winElapsed*4)),0.15) end
  end
  if V.winElapsed>5 then V.winElapsed=nil end
 end
 -- Safety: face-up opponent cards may only be visible in SHOWDOWN.
 -- This also fixes reused card textures lingering after a new hand starts.
 local phase=R.G and R.G.phase or 'IDLE'
 if phase~='SHOWDOWN' then
  for _,seat in ipairs(V.seats or {}) do
   for cardIndex,card in ipairs(seat.cards or {}) do
    if card:IsShown() then card:SetTexture(CARD_BACK) end
    if seat.cardFaces and seat.cardFaces[cardIndex] then seat.cardFaces[cardIndex]:Hide() end
   end
  end
 end
 if not V.dealElapsed then return end
 V.dealElapsed=math.min(3,V.dealElapsed+dt)
 for i,s in ipairs(V.seats or {}) do
  for c,card in ipairs(s.cards) do
   local a=(V.dealElapsed-(i-1)*0.08-(c-1)*0.12)*4
   card:SetAlpha(math.max(0,math.min(1,a)))
  end
 end
end)
