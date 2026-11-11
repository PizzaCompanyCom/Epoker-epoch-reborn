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
  if members[name] and not used[name] and count<6 and string.match(name,'^[%w%-]+$') then
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
 V.title:SetText('')
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
 R.RegisterBackground(f,0.018,0.022,0.026,1)
 V.frame=f;R.TableFrame=f
 f:HookScript('OnMouseDown',function(self)self:Raise()end)
 f:SetScale(RaidPokerWotLKDB.tableScale or 1)
 local drag=CreateFrame('Frame',nil,f);drag:SetPoint('TOPLEFT',f,15,-9);drag:SetPoint('TOPRIGHT',f,-47,-9);drag:SetHeight(31)
 drag:EnableMouse(true);drag:RegisterForDrag('LeftButton')
 drag:SetScript('OnDragStart',function()f:Raise();f:StartMoving()end)
 drag:SetScript('OnDragStop',function()
  f:StopMovingOrSizing();local x,y=f:GetCenter();local a,b=UIParent:GetCenter()
  if x and a then RaidPokerWotLKDB.tableX=x-a;RaidPokerWotLKDB.tableY=y-b end
 end)
 V.title=txt(f,22,-19,340,'','GameFontNormalLarge')
 btn(f,'X',713,-13,29,function()f:Hide()end)
 -- One uninterrupted, full-window table material, behind every seat and card.
 V.tableSurface=f:CreateTexture(nil,'ARTWORK',nil,0)
 V.tableSurface:SetPoint('TOPLEFT',f,'TOPLEFT',36,-52)
 V.tableSurface:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-36,50)
 V.tableSurface:SetTexCoord(0,1,0,1)
 -- Opaque outer mat: it sits behind the reduced playing surface, not above it.
 V.outerMat=f:CreateTexture(nil,'ARTWORK',nil,-1)
 V.outerMat:SetTexture('Interface\\Buttons\\WHITE8X8')
 V.outerMat:SetVertexColor(0.025,0.035,0.035,1)
 V.outerMat:SetPoint('TOPLEFT',f,'TOPLEFT',12,-34)
 V.outerMat:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-12,18)

 -- Opaque dark header/footer mats hide the old brown backdrop strips.
 V.headerMat=f:CreateTexture(nil,'ARTWORK',nil,6)
 V.headerMat:SetTexture('Interface\\Buttons\\WHITE8X8')
 V.headerMat:SetVertexColor(0.018,0.022,0.026,1)
 V.headerMat:SetPoint('TOPLEFT',f,'TOPLEFT',12,-12)
 V.headerMat:SetPoint('BOTTOMRIGHT',f,'TOPRIGHT',-12,-51)
 V.footerMat=f:CreateTexture(nil,'ARTWORK',nil,6)
 V.footerMat:SetTexture('Interface\\Buttons\\WHITE8X8')
 V.footerMat:SetVertexColor(0.018,0.022,0.026,1)
 V.footerMat:SetPoint('TOPLEFT',f,'BOTTOMLEFT',12,51)
 V.footerMat:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-12,12)

 -- Keep the entire procedural tabletop inside the inner rectangular field.
 -- Procedural wood / cloth surface, all using WHITE8X8 supported by WotLK.
 -- Twelve wide horizontal planks with subtle, deterministic variation.
 V.tablePlanks={}
 for i=1,12 do
  local strip=f:CreateTexture(nil,'ARTWORK',nil,1)
  strip:SetTexture('Interface\\Buttons\\WHITE8X8')
  strip:SetPoint('TOPLEFT',f,'TOPLEFT',37,-53-(i-1)*34)
  strip:SetWidth(686);strip:SetHeight(33)
  V.tablePlanks[i]=strip
 end
 -- Dark join lines plus a light rim on the upper side of each plank.
 V.tableSeams={};V.tableHighlights={}
 for i=1,11 do
  local seam=f:CreateTexture(nil,'ARTWORK',nil,2)
  seam:SetTexture('Interface\\Buttons\\WHITE8X8')
  seam:SetPoint('TOPLEFT',f,'TOPLEFT',37,-53-i*34+1)
  seam:SetWidth(686);seam:SetHeight(2)
  V.tableSeams[i]=seam
  local highlight=f:CreateTexture(nil,'ARTWORK',nil,3)
  highlight:SetTexture('Interface\\Buttons\\WHITE8X8')
  highlight:SetPoint('TOPLEFT',f,'TOPLEFT',37,-53-i*34+3)
  highlight:SetWidth(686);highlight:SetHeight(1)
  V.tableHighlights[i]=highlight
 end
 -- Thin staggered grain strokes. No external artwork or runtime randomness.
 V.tableGrain={}
 for i=1,108 do
  local line=f:CreateTexture(nil,'ARTWORK',nil,4)
  line:SetTexture('Interface\\Buttons\\WHITE8X8')
  local plank=math.floor((i-1)/9)
  local within=(i-1)%9
  local x=45+((i*83+plank*41)%170)
  local y=-56-plank*34-within*2
  line:SetPoint('TOPLEFT',f,'TOPLEFT',x,y)
  line:SetWidth(180+((i*71)%240));line:SetHeight(1)
  V.tableGrain[i]=line
 end
 -- Corner plates, rivets, metal bands, maker mark and extra gold trim removed.
 -- These legacy arrays remain empty so the theme code does not recreate them.
 V.tableDetails={};V.decorTrim={};V.decorPlates={};V.decorRivets={}
 V.decorLabel=nil
 -- Legacy oval shapes are retained as hidden placeholders for Table7 compatibility.
 V.ring=f:CreateTexture(nil,'BACKGROUND');V.ring:SetTexture('Interface\\Buttons\\WHITE8X8');V.ring:SetPoint('TOPLEFT',f,95,-107);V.ring:SetWidth(570);V.ring:SetHeight(315)
 V.felt=f:CreateTexture(nil,'BORDER');V.felt:SetTexture('Interface\\Buttons\\WHITE8X8');V.felt:SetPoint('TOPLEFT',f,107,-119);V.felt:SetWidth(546);V.felt:SetHeight(291)
 V.ring:Hide();V.felt:Hide()
 local center=CreateFrame('Frame',nil,f);center:SetPoint('CENTER',f,'CENTER',0,4);center:SetWidth(280);center:SetHeight(130)
 -- Fix 22: interactive local five-card hand, driven by the existing Game.lua controls.
 -- This is deliberately display-only for networking: no card IDs are transmitted here.
 V.handPanel=CreateFrame('Frame',nil,f)
 V.handPanel:SetWidth(390);V.handPanel:SetHeight(180)
 V.handPanel:SetPoint('CENTER',f,'CENTER',0,-8)
 V.handPanel:SetFrameLevel(f:GetFrameLevel()+16)
 V.handCards={}
 for i=1,5 do
  local idx=i
  local card=CreateFrame('Button',nil,V.handPanel)
  card:SetWidth(68);card:SetHeight(98)
  card:SetPoint('TOPLEFT',V.handPanel,'TOPLEFT',13+(i-1)*75,-12)
  local edge=card:CreateTexture(nil,'BACKGROUND');edge:SetAllPoints(card)
  edge:SetTexture('Interface\\Buttons\\WHITE8X8');edge:SetVertexColor(.75,.58,.32,1)
  local art=card:CreateTexture(nil,'ARTWORK')
  art:SetPoint('TOPLEFT',card,2,-2);art:SetPoint('BOTTOMRIGHT',card,-2,2)
  art:SetTexture(CARD_BACK)
  local selection=card:CreateTexture(nil,'OVERLAY')
  selection:SetAllPoints(card);selection:SetTexture('Interface\\Buttons\\WHITE8X8')
  selection:SetVertexColor(1,.72,.15,.26);selection:Hide()
  card:SetScript('OnClick',function()
   local original=R.GameUI and R.GameUI.cards and R.GameUI.cards[idx]
   if original and original.Click then original:Click() end
  end)
  V.handCards[i]={button=card,art=art,selection=selection}
 end
 V.handNotice=V.handPanel:CreateFontString(nil,'OVERLAY','GameFontNormal')
 V.handNotice:SetPoint('TOP',V.handPanel,'TOP',0,9)
 V.handNotice:SetText('YOUR FIVE CARDS')
 V.handCount=V.handPanel:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 V.handCount:SetPoint('TOP',V.handPanel,'TOP',0,-116)
 V.handExchange=CreateFrame('Button',nil,V.handPanel,'UIPanelButtonTemplate')
 V.handExchange:SetWidth(110);V.handExchange:SetHeight(24)
 V.handExchange:SetPoint('TOPRIGHT',V.handPanel,'TOP',-4,-135)
 V.handExchange:SetText('Exchange')
 V.handExchange:SetScript('OnClick',function()
  local original=R.GameUI and R.GameUI.exchangeButton
  if original and original.Click then original:Click() end
 end)
 V.handPat=CreateFrame('Button',nil,V.handPanel,'UIPanelButtonTemplate')
 V.handPat:SetWidth(110);V.handPat:SetHeight(24)
 V.handPat:SetPoint('TOPLEFT',V.handPanel,'TOP',4,-135)
 V.handPat:SetText('Stand Pat')
 V.handPat:SetScript('OnClick',function()
  local original=R.GameUI and R.GameUI.patButton
  if original and original.Click then original:Click() end
 end)
 V.handPanel:Hide()
 V.pot=txt(center,30,-13,250,'POT  0s','GameFontNormalLarge')
 V.pot:ClearAllPoints();V.pot:SetPoint('TOP',f,'TOP',-10,-113);V.pot:SetWidth(170);V.pot:SetJustifyH('RIGHT')
 -- No redundant coin icon: gold and silver stacks are displayed next to the pot amount.
 V.phase=txt(center,30,-44,250,'Waiting for players')
 V.phase:ClearAllPoints();V.phase:SetPoint('BOTTOM',f,'BOTTOM',0,27);V.phase:SetWidth(340);V.phase:SetJustifyH('CENTER');V.phase:SetFontObject('GameFontNormalLarge')
 -- A clearly labelled central pot, separate from the five-card hands at each seat.
 V.chipLabel=txt(center,30,-62,150,'GOLD / SILVER','GameFontNormalSmall')
 V.chipLabel:Hide()
 -- Compact denomination stacks beside the pot label, above the five-card hand.
 -- Four overlapping coin sprites per denomination; no row of loose coins.
 V.chips={};V.chipBacks={};V.chipLetters={}
 for i=1,8 do
  local chip=f:CreateTexture(nil,'OVERLAY')
  chip:SetTexture(coinTexture(i>4))
  chip:SetWidth(23);chip:SetHeight(23)
  chip:Hide();V.chips[i]=chip
 end
 -- Static markers distinguish gold and silver when only one coin is visible.
 V.potStackGold=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 V.potStackGold:SetText('G');V.potStackGold:SetTextColor(1,0.76,0.18)
 V.potStackSilver=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 V.potStackSilver:SetText('S');V.potStackSilver:SetTextColor(0.8,0.86,0.95)
 -- Visual-only chip transfer and card-deal effects. All betting state remains in Game.lua.
 V.motion={};V.motionLayer=CreateFrame('Frame',nil,f)
 V.motionLayer:SetAllPoints(f);V.motionLayer:SetFrameStrata(f:GetFrameStrata());V.motionLayer:SetFrameLevel(f:GetFrameLevel()+30);V.motionLayer:EnableMouse(false)
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
 V.winBanner:SetWidth(390);V.winBanner:SetHeight(58)
 V.winBanner:SetPoint('TOP',f,'TOP',0,-194)
 V.winBanner:SetFrameLevel(f:GetFrameLevel()+40)
 V.winBanner:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 V.winBanner:SetBackdropColor(0.12,0.075,0.015,0.92)
 V.winBanner:SetBackdropBorderColor(0.95,0.75,0.24,1)
 V.winBannerText=V.winBanner:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 V.winBannerText:SetPoint('CENTER',V.winBanner,'CENTER',0,0)
 V.winBannerText:SetWidth(372);V.winBannerText:SetHeight(48);V.winBannerText:SetJustifyH('CENTER')
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
  count=math.min(6,math.max(0,count or 0))
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
 for i=1,6 do
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
  s.info=txt(s,73,-25,112,'','GameFontNormalLarge')
  s.info:SetJustifyH('LEFT')
  s.moneyIcon=s:CreateTexture(nil,'OVERLAY')
  s.moneyIcon:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon')
  s.moneyIcon:SetWidth(17);s.moneyIcon:SetHeight(17)
  s.moneyIcon:SetPoint('TOPLEFT',s,'TOPLEFT',56,-25)
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
  s.actionCover=s:CreateTexture(nil,'OVERLAY',nil,7);s.actionCover:SetTexture('Interface\\Buttons\\WHITE8X8');s.actionCover:SetPoint('TOPLEFT',s,3,-24);s.actionCover:SetPoint('BOTTOMRIGHT',s,-3,3);s.actionCover:SetVertexColor(.02,.05,.08,.97);s.actionCover:Hide()
  s.actionLabel=s:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');s.actionLabel:SetPoint('CENTER',s,0,-12);s.actionLabel:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE');s.actionLabel:SetShadowOffset(1,-1);s.actionLabel:Hide()
  s:SetScript('OnClick',function()setSeat(i)end)
  V.seats[i]=s
 end
 V.message=txt(f,20,-475,340,'');V.message:Hide()
 -- Theme selection moved into Settings Table.
 V.themeButton=nil
 -- Table Options is available from the Settings Table button in the header.

 local opt=CreateFrame('Frame',nil,UIParent);opt:SetWidth(340);opt:SetHeight(420);opt:SetFrameStrata('FULLSCREEN_DIALOG');opt:SetPoint('CENTER',UIParent,'CENTER',0,0);opt:SetMovable(true);opt:SetClampedToScreen(true);opt:EnableMouse(true)
 opt:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 opt:SetBackdropColor(0.06,0.055,0.045,0.97);V.options=opt
 local optDrag=CreateFrame('Frame',nil,opt)
 optDrag:SetPoint('TOPLEFT',opt,'TOPLEFT',12,-9);optDrag:SetPoint('TOPRIGHT',opt,'TOPRIGHT',-48,-9)
 optDrag:SetHeight(39);optDrag:EnableMouse(true);optDrag:RegisterForDrag('LeftButton')
 optDrag:SetScript('OnDragStart',function()opt:StartMoving()end)
 optDrag:SetScript('OnDragStop',function()opt:StopMovingOrSizing()end)
 txt(opt,30,-24,240,'SETTINGS TABLE','GameFontNormalLarge')
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
 V.settingsTheme=btn(opt,'Table Theme',40,-350,260,toggleTheme)
 V.updateOptions();opt:Hide()
 local settings=R.SettingsFrame
 if settings then
  -- Theme button is now inside the Poker Table settings window.
  -- Table effects are configured through Settings Table on the Poker Table.
 end
 -- Hotfix 33: navigation and settings are directly available on Poker Table.
 local function arrangeGeneral(general)
  if not general or not general:IsShown() or not f:IsShown() then return end
  local l1,r1=f:GetLeft(),f:GetRight();local l2,r2=general:GetLeft(),general:GetRight()
  if l1 and r1 and l2 and r2 and (r1<=l2 or r2<=l1) then return end
  local sw=UIParent:GetWidth()
  local ts=RaidPokerWotLKDB.tableScale or 1
  local gs=general:GetScale() or 1
  local ratio=math.min(1,(sw-40)/(f:GetWidth()*ts+general:GetWidth()*gs+20))
  ts=ts*ratio;gs=gs*ratio
  f:SetScale(ts);general:SetScale(gs)
  local left=(sw-f:GetWidth()*ts-general:GetWidth()*gs-20)/2
  f:ClearAllPoints();f:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',left/ts,(UIParent:GetHeight()/2-f:GetHeight()*ts/2)/ts)
  general:ClearAllPoints();general:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',(left+f:GetWidth()*ts+20)/gs,(UIParent:GetHeight()/2-general:GetHeight()*gs/2)/gs)
 end
 local function showGeneral()
  -- Use the live GameUI reference; R.Main is not assigned by BuildGame.
  local general=(R.GameUI and R.GameUI.main) or R.Main
  if not general then
   if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('Raid Poker: General window is not available yet.') end
   return
  end
  general:Show()
  general:Raise()
  arrangeGeneral(general)
 end
 local generalButton=btn(f,'Open General',468,-15,108,showGeneral)
 generalButton:SetFrameStrata('DIALOG')
 generalButton:SetFrameLevel(f:GetFrameLevel()+50)
 local function toggleSettings()
  if opt:IsShown() then opt:Hide();return end
  if V.updateOptions then V.updateOptions() end
  opt:ClearAllPoints()
  -- Keep the options at the upper right of the screen, independently of table scale.
  opt:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',-45,-95)
  opt:Show()
  opt:Raise()
 end
 local settingsButton=btn(f,'Settings Table',580,-15,119,toggleSettings)
 local startGameButton=btn(f,'Start Game',333,-15,120,function()
  if not (R.G and R.G.solo) and R.ActiveTableID and R.ActiveTableID()~='' and R.IsPokerHost and not R.IsPokerHost() then
   StaticPopup_Show('EPOKER_GM_START_WARNING',R.GameMasterName and R.GameMasterName() or 'Unknown')
   return
  end
  if R.StartPokerHandFromTable then R.StartPokerHandFromTable() end
 end)
 local closeBotsButton=btn(f,'Close Bots',22,-15,123,function()
  if R.SoloStop then R.SoloStop() end
 end)
  local soloBotsButton=btn(f,'Solo Bots',157,-15,125,function()
   if R.ToggleDebugPanel then R.ToggleDebugPanel() end
 end)
 local leaveTableButton=btn(f,'Leave Table',292,-46,128,function()
  if R.G and R.G.solo then
   if R.SoloStop then R.SoloStop() end
  elseif R.ActiveTableID and R.ActiveTableID()~='' then
   if R.IsPokerHost and R.IsPokerHost() then
    StaticPopup_Show('EPOKER_GM_LEAVE_WARNING')
   elseif R.LeaveNamedTable then R.LeaveNamedTable() end
  elseif R.Print then R.Print('You are not seated at a multiplayer table.') end
 end)
 -- Compact Blizzard icon textures; preserve all original click handlers.
 local function headerIcon(b,texture)
  local t=b:CreateTexture(nil,'OVERLAY')
  t:SetTexture(texture);t:SetSize(15,15);t:SetPoint('LEFT',b,'LEFT',5,0)
  b:SetText('   '..b:GetText())
 end
 headerIcon(soloBotsButton,'Interface\\Icons\\INV_Misc_Dice_02')
 headerIcon(leaveTableButton,'Interface\\Icons\\Ability_Rogue_FeignDeath')
 headerIcon(closeBotsButton,'Interface\\Icons\\Ability_Rogue_FeignDeath')
 headerIcon(startGameButton,'Interface\\Icons\\INV_Misc_Coin_01')
 headerIcon(generalButton,'Interface\\Icons\\INV_Misc_Book_09')
 headerIcon(settingsButton,'Interface\\Icons\\Trade_Engineering')
 -- Header drag and decorative layers must never intercept these controls.
 for _,b in ipairs({generalButton,settingsButton,startGameButton,closeBotsButton,soloBotsButton,leaveTableButton}) do
  b:SetFrameStrata('DIALOG')
  b:SetFrameLevel(f:GetFrameLevel()+70)
  b:EnableMouse(true)
  b:HookScript('OnMouseDown',function() f:Raise() end)
 end
 settingsButton:SetFrameStrata('DIALOG')
 settingsButton:SetFrameLevel(f:GetFrameLevel()+70)
 -- The old 405px list is not shown, but its data and existing UI hooks remain.
 R.ToggleTable=function()
  V.oldTable:Hide()
  if f:IsShown() then f:Hide();opt:Hide() else f:Show();requestSeats();R.Refresh();arrangeGeneral((R.GameUI and R.GameUI.main) or R.Main); if V.pendingDeal then V.pendingDeal=false;V.launch('CARD',1) end end
 end
 f:SetScript('OnHide',function()opt:Hide()end)
 -- The visual table has UIParent as its parent and is not hidden with the main frame.
 if f:GetParent()~=UIParent then f:SetParent(UIParent) end
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
 -- Hand visuals use the same local hand/selection as the main window.
 local myTurn=(g.phase=='DRAW' and g.turn==UnitName('player'))
 local hand=g.hand or {}
 local hasHand=(#hand==5 and g.phase~='IDLE' and g.phase~='LOBBY')
 if hasHand then
  V.handPanel:Show()
  local selectedCount=0
  for i=1,5 do
   local entry=V.handCards[i]
   entry.art:SetTexture(artFor(hand[i]))
   local chosen=(g.selected and g.selected[i]) and true or false
   if chosen then selectedCount=selectedCount+1;entry.selection:Show()
   else entry.selection:Hide() end
   entry.button:EnableMouse(myTurn)
  end
  V.handCount:SetText(myTurn and ('Cards selected: '..selectedCount..'/3') or 'YOUR CURRENT HAND')
  V.handNotice:SetText(myTurn and 'YOUR TURN - CARD EXCHANGE' or 'YOUR FIVE CARDS')
  V.handNotice:SetTextColor(myTurn and 1 or .95,myTurn and .75 or .86,.35)
  if myTurn then V.handExchange:Show();V.handPat:Show()
  else V.handExchange:Hide();V.handPat:Hide() end
  if myTurn and selectedCount>0 and selectedCount<=3 then
   V.handExchange:Enable()
  else
   V.handExchange:Disable()
  end
 else V.handPanel:Hide() end
 V.pot:SetText('POT  '..formatMoney(g.pot))
 if V.potCoin then V.potCoin:Hide() end
 if g.solo then V.message:SetText('SOLO DEBUG  |  Local game')
 elseif isHost() then V.message:SetText('RAID HOST  |  Seat sync enabled')
 elseif g.host and g.host~='' then V.message:SetText('RAID CLIENT  |  Host: '..g.host)
 else V.message:SetText('Not connected to a poker host') end
 V.chipLabel:SetText('')
 V.phase:SetText('Round '..tostring(g.round or 0)..'  |  '..tostring(g.phase or 'IDLE'))
 if V.winBanner and (g.phase~='SHOWDOWN' or RaidPokerWotLKDB.tableWinnerEffects==false) then V.winBanner:Hide();V.winBannerTime=nil end
 if g.phase=='SHOWDOWN' and g.winner and g.winner~='' then
  V.phase:SetText('Round '..tostring(g.round or 0)..'  |  SHOWDOWN')
  if V.lastWinnerRound~=(g.round or 0) then
   V.lastWinnerRound=g.round or 0;V.winElapsed=0;V.winName=string.match(g.winner,'^([^ ;]+)')
   V.winTransferPending=true
   if V.winBanner and RaidPokerWotLKDB.tableWinnerEffects~=false then
    -- The game result uses `Name +120s (One Pair)`; display the actual
    -- winning combination beneath the winner name, including split pots.
    local winnerLines={}
    for result in string.gmatch(g.winner,'([^;]+)') do
     local name,combo=string.match(result,'^%s*([^%s]+)%s+%+%d+s%s+%(([^%)]+)%)')
     if name then
      table.insert(winnerLines,'WINNER: '..string.sub(name,1,22)..'\nWinning Hand: '..(combo or 'Unknown'))
     end
    end
    if #winnerLines==0 then
     table.insert(winnerLines,'WINNER: '..string.sub(V.winName or '?',1,22))
    end
    V.winBannerText:SetText(table.concat(winnerLines,'  |  '))
    V.winBannerTime=0;V.winBanner:Show()
   end

  end
 end
 -- Compact gold/silver stacks: each denomination grows vertically instead
 -- of consuming horizontal space. All values are cosmetic; pot is authoritative.
 local potAmount=math.max(0,math.floor(tonumber(g.pot) or 0))
 local gold=math.floor(potAmount/100)
 local silver=potAmount%100
 local function stackHeight(amount)
  if amount<=0 then return 0 end
  if amount<5 then return 1 end
  if amount<20 then return 2 end
  if amount<50 then return 3 end
  return 4
 end
 local goldHeight=stackHeight(gold)
 local silverHeight=stackHeight(silver)
 for i,chip in ipairs(V.chips) do
  local isSilver=i>4
  local index=isSilver and (i-4) or i
  local height=isSilver and silverHeight or goldHeight
  chip:ClearAllPoints()
  chip:SetPoint('TOP',V.pot,'TOPRIGHT',isSilver and 79 or 42,-(4-index)*5+1)
  chip:SetTexture(coinTexture(isSilver))
  chip:SetVertexColor(1,1,1,1)
  if index<=height then chip:Show() else chip:Hide() end
 end
 V.potStackGold:ClearAllPoints();V.potStackGold:SetPoint('TOP',V.pot,'TOPRIGHT',42,-27)
 V.potStackSilver:ClearAllPoints();V.potStackSilver:SetPoint('TOP',V.pot,'TOPRIGHT',79,-27)
 if goldHeight>0 then V.potStackGold:Show() else V.potStackGold:Hide() end
 if silverHeight>0 then V.potStackSilver:Show() else V.potStackSilver:Hide() end
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
   local action=R.HF19ActionFor and R.HF19ActionFor('DRAW',p.name,g.log,g.round)
   if action then s.actionCover:Show();s.actionLabel:SetText(action);s.actionLabel:SetTextColor(R.HF19ActionColor(action));s.actionLabel:Show()
   else s.actionCover:Hide();s.actionLabel:Hide() end
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
   local stack=math.max(0,math.floor(tonumber(p.balance) or 0))
   s.info:SetText(formatMoney(stack))
   s.moneyIcon:SetTexture(coinTexture(stack<100))
   s.moneyIcon:Show()
   s.status:SetText(st)
   s.betChip:Hide() -- Player seat shows stack only; current wager remains in main betting UI.
   s.status:SetTextColor(p.fold and 0.6 or 1,p.fold and 0.6 or (p.allin and 0.4 or 0.83),p.fold and 0.6 or 0.2)
   s.dealer:SetText(i==dealerIndex and 'D' or '')
   s.win:SetText('')
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
   s.name:SetText('Empty seat');s.info:SetText('');s.moneyIcon:Hide();s.dealer:SetText('');s.status:SetText('');s.win:SetText('');s.portrait:Hide();s.betChip:Hide()
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
