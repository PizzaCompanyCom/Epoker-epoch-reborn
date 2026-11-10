-- Raid Poker 1.6.0 Player Management, WoW 3.3.5a compatible.
local R=RPoker
local function label(parent,x,y,w,txt)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetJustifyH('LEFT');f:SetText(txt or '')
 return f
end
local function btn(parent,txt,x,y,w,fn)
 return R.Button(parent,txt,w,23,x,y,fn)
end
local function edit(parent,x,y,w,default)
 local e=CreateFrame('EditBox',nil,parent)
 e:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);e:SetWidth(w);e:SetHeight(24);e:SetAutoFocus(false)
 e:SetFontObject('ChatFontNormal');e:SetTextInsets(6,6,0,0)
 e:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
 e:SetBackdropColor(.04,.04,.04,.96)
 e:SetText(default or '');e:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
 e:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
 return e
end
local f=CreateFrame('Frame','RaidPokerPlayerManagement',UIParent)
f:SetWidth(660);f:SetHeight(815);f:SetPoint('CENTER',UIParent,'CENTER',90,0)
f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true)
R.Backdrop(f)
local drag=CreateFrame('Frame',nil,f)
drag:SetPoint('TOPLEFT',f,'TOPLEFT',10,-8);drag:SetPoint('TOPRIGHT',f,'TOPRIGHT',-45,-8)
drag:SetHeight(36);drag:EnableMouse(true);drag:RegisterForDrag('LeftButton')
drag:SetScript('OnDragStart',function()f:StartMoving()end)
drag:SetScript('OnDragStop',function()f:StopMovingOrSizing()end)
local title=label(f,22,-23,490,'PLAYER MANAGEMENT  |  GAME MASTER')
title:SetFontObject('GameFontNormalLarge')
btn(f,'X',617,-16,25,function()f:Hide()end)
local gm=label(f,22,-57,590,'')
local createTable=btn(f,'Create Table',22,-78,145,function()
 if R.ActiveTableID()~='' then return end
 if #R.GetTableDirectory()>0 then R.Print('A raid table already exists. Join it instead.');return end
 R.CreateNamedTable('Ironforge Poker')
 R.RefreshPlayerManagement()
end)
local joinTable=btn(f,'Join Table',178,-78,145,function()
 if R.ActiveTableID()~='' then R.Print('Already connected.');return end
 local list=R.GetTableDirectory()
 if #list==1 then R.JoinNamedTable(list[1].id)
 elseif #list==0 then R.DiscoverTables();if StaticPopup_Show then StaticPopup_Show('EPOKER_NO_ACTIVE_TABLE') end
 else R.Print('Multiple legacy tables detected. Use Table Browser.') end
end)
local createState=label(f,340,-83,280,'No active table')
local nt=createTable:GetNormalTexture();if nt then nt:SetVertexColor(.82,.22,.22) end
-- v1.6.7: fixed-column roster with alternating rows and grid rules.
local rows,selected={},nil
local function line(x,y,w,h,alpha)
 local t=f:CreateTexture(nil,'ARTWORK')
 t:SetTexture('Interface\\Buttons\\WHITE8X8')
 t:SetVertexColor(.72,.58,.34,alpha or .35)
 t:SetPoint('TOPLEFT',f,'TOPLEFT',x,y);t:SetWidth(w);t:SetHeight(h)
 return t
end
local function cell(x,y,w,txt)
 return label(f,x,y,w,txt)
end
line(20,-114,616,24,.22)
cell(30,-119,166,'PLAYER')
cell(207,-119,116,'BALANCE')
cell(330,-119,118,'STATUS')
cell(452,-119,52,'HAND')
cell(510,-119,60,'VERSION')
cell(575,-119,48,'ACTION')
for i=0,10 do line(20,-138-i*21,616,1,.34) end
for _,x in ipairs({196,319,448,506,572}) do line(x,-114,1,234,.25) end
local selectLabel=label(f,22,-366,600,'Selected: none')
for i=1,10 do
 local y=-140-(i-1)*21
 if i%2==0 then
  local bg=f:CreateTexture(nil,'BACKGROUND')
  bg:SetTexture('Interface\\Buttons\\WHITE8X8')
  bg:SetVertexColor(.9,.78,.48,.065)
  bg:SetPoint('TOPLEFT',f,'TOPLEFT',21,y+1);bg:SetWidth(614);bg:SetHeight(20)
 end
 local idx=i
 local row={}
 row.name=cell(30,y-4,162,'')
 row.balance=cell(207,y-4,108,'')
 row.status=cell(330,y-4,112,'')
 row.hand=cell(452,y-4,52,'')
 row.version=cell(510,y-4,60,'')
 row.button=btn(f,'Select',575,y+1,58,function()
  local player=R.G.players[idx]
  if player then selected=player.name;selectLabel:SetText('Selected: '..selected);R.RefreshPlayerManagement() end
 end)
 rows[i]=row
end
label(f,26,-395,110,'Gold')
label(f,167,-395,85,'Silver')
-- InputBoxTemplate has decorative textures extending outside its anchor;
-- leave a wide gap and place both boxes above all action buttons.
local gold=edit(f,35,-415,56,'0')
local silver=edit(f,172,-415,56,'0')
btn(f,'Set Balance',272,-415,105,function()
 if not selected then return end
 local n=R.ReadMoney(gold,silver)
 if n then R.AdminSetBalance(selected,n) end
end)
btn(f,'Add',389,-415,65,function()
 if not selected then return end
 local n=R.ReadMoney(gold,silver)
 if n then
  for _,p in ipairs(R.G.players) do if p.name==selected then R.AdminSetBalance(selected,p.balance+n);break end end
 end
end)
btn(f,'Remove',470,-415,85,function()
 if not selected then return end
 local n=R.ReadMoney(gold,silver)
 if n then
  for _,p in ipairs(R.G.players) do if p.name==selected then R.AdminSetBalance(selected,math.max(0,p.balance-n));break end end
 end
end)
btn(f,'Sit Out',22,-446,105,function()if selected then R.AdminSetStatus(selected,'Sitting Out')end end)
btn(f,'Sit In',136,-446,100,function()if selected then R.AdminSetStatus(selected,'Playing')end end)
btn(f,'Busted',245,-446,95,function()if selected then R.AdminSetStatus(selected,'Busted')end end)
btn(f,'Force Fold',350,-446,115,function()if selected then R.AdminForceFold(selected)end end)
btn(f,'Kick',475,-446,80,function()if selected then R.AdminRemove(selected)end end)
btn(f,'Transfer GM',22,-480,145,function()if selected then R.AdminTransferGM(selected)end end)
btn(f,'Admin History',178,-480,145,function()R.ToggleAdminHistory()end)
label(f,22,-513,180,'TURN TIMER','GameFontNormal')
local timerButton=btn(f,'Turn Timer: 30s',178,-510,178,function()
 local g=R.G
 if not g then return end
 if not g.solo and g.phase~='LOBBY' and g.phase~='SHOWDOWN' and g.phase~='IDLE' then R.Print('Change the timer between hands.');return end
 if not R.IsPokerHost or not R.IsPokerHost() then R.Print('Game Master only.');return end
 local v=(g.timer==15 and 30 or g.timer==30 and 60 or g.timer==60 and 0 or 15)
 g.timer=v
 if R.PublishManagedState then R.PublishManagedState()end
 R.RefreshPlayerManagement()
end)
local timerHint=label(f,367,-517,250,'15s / 30s / 60s / OFF')

label(f,22,-571,605,'Balance / status / removal / GM transfer: between hands only.')
label(f,22,-591,605,'Force Fold: during an active hand. Only the Game Master may administer.')
label(f,22,-611,605,'Virtual currency only. No automatic gold transfer.')
label(f,22,-643,580,'RAID PLAYERS AVAILABLE - ADDON DETECTED','GameFontNormal')
label(f,22,-665,580,'Not seated at this table. Join through Tables to request a seat.')
local availableRows={}
local availablePage=0
local availableNames={}
for i=1,4 do
 availableRows[i]=label(f,30,-689-(i-1)*19,585,'')
end
btn(f,'< Previous',390,-759,110,function()availablePage=math.max(0,availablePage-1);R.RefreshPlayerManagement()end)
btn(f,'Next >',510,-759,105,function()availablePage=availablePage+1;R.RefreshPlayerManagement()end)
function R.RefreshPlayerManagement()
 if not f:IsShown() then return end
 local list=R.GetTableDirectory()
 local exists=R.ActiveTableID()~='' or #list>0
 if exists then createTable:Disable() else createTable:Enable() end
 createState:SetText(R.ActiveTableID()~='' and 'Table active' or (#list>0 and 'Raid table available' or 'No active table'))
 timerButton:SetText('Turn Timer: '..((R.G.timer==0) and 'OFF' or tostring(R.G.timer or 30)..'s'))
 gm:SetText('Game Master: '..(R.GameMasterName()~='' and R.GameMasterName() or 'none')..
   (R.IsGameMaster() and '  (You have administrative control)' or '  (Read only)'))
 local found=false
 for i=1,10 do
  local p=R.G.players[i]
  local row=rows[i]
  row.name:SetText(p and p.name or '')
  row.balance:SetText(p and R.Money(p.balance or 0) or '')
  row.status:SetText(p and (p.status or ((p.balance or 0)<=0 and 'Busted' or 'Playing')) or '')
  local version=p and R.GetPokerPeerVersion and R.GetPokerPeerVersion(p.name) or nil
  row.version:SetText(p and (version or 'Unknown') or '')
  local match=p and R.PokerVersionMatches and R.PokerVersionMatches(p.name) or nil
  if match==true then row.version:SetTextColor(.2,1,.25) elseif match==false then row.version:SetTextColor(1,.25,.25) else row.version:SetTextColor(.7,.7,.7) end
  row.hand:SetText(p and (p.inhand and (p.fold and 'FOLD' or 'IN HAND') or '-') or '')
  if p and p.name==selected then
   found=true
   row.name:SetTextColor(1,.84,.35)
  else row.name:SetTextColor(1,1,1) end
  if p then row.button:Show() else row.button:Hide() end
 end
 if selected and not found then selected=nil;selectLabel:SetText('Selected: none') end
 availableNames={}
 local seated={};for _,p in ipairs(R.G.players or {}) do seated[p.name]=true end
 if GetNumRaidMembers and GetNumRaidMembers()>0 then
  for i=1,GetNumRaidMembers() do
   local name=GetRaidRosterInfo(i)
   if name and not seated[name] and R.GetPokerPeerVersion and R.GetPokerPeerVersion(name) then
    availableNames[#availableNames+1]=name
   end
  end
 end
 table.sort(availableNames)
 availablePage=math.min(availablePage,math.max(0,math.ceil(#availableNames/4)-1))
 for i,row in ipairs(availableRows) do
  local name=availableNames[availablePage*4+i]
  row:SetText(name and (name..'  |  '..(R.GetPokerPeerVersion(name) or 'Unknown')..'  |  IN RAID / NOT SEATED') or '')
 end

end
f:SetScript('OnShow',R.RefreshPlayerManagement)
f:Hide()
R.PlayerManagementFrame=f
function R.TogglePlayerManagement()
 if f:IsShown() then f:Hide() else f:Show();if R.RequestPokerPeerVersions then R.RequestPokerPeerVersions()end end
end
local h=CreateFrame('Frame','RaidPokerAdminHistory',UIParent)
h:SetWidth(650);h:SetHeight(490);h:SetPoint('CENTER',UIParent,'CENTER',140,-15)
h:SetFrameStrata('FULLSCREEN_DIALOG');h:SetMovable(true);h:EnableMouse(true);R.Backdrop(h)
local bar=CreateFrame('Frame',nil,h)
bar:SetPoint('TOPLEFT',h,'TOPLEFT',10,-8);bar:SetPoint('TOPRIGHT',h,'TOPRIGHT',-50,-8)
bar:SetHeight(35);bar:EnableMouse(true);bar:RegisterForDrag('LeftButton')
bar:SetScript('OnDragStart',function()h:StartMoving()end)
bar:SetScript('OnDragStop',function()h:StopMovingOrSizing()end)
local head=label(h,22,-24,500,'ADMINISTRATIVE ACTION HISTORY');head:SetFontObject('GameFontNormalLarge')
btn(h,'X',605,-16,25,function()h:Hide()end)
local history={}
for i=1,16 do history[i]=label(h,22,-62-(i-1)*24,600,'') end
local page=0
local function update()
 local entries=(RaidPokerWotLKDB and RaidPokerWotLKDB.adminHistory) or {}
 for i=1,16 do history[i]:SetText(entries[page*16+i] or '') end
end
btn(h,'Previous',22,-451,105,function()page=math.max(0,page-1);update()end)
btn(h,'Next',140,-451,105,function()page=page+1;update()end)
h:SetScript('OnShow',function()page=0;update()end)
h:Hide()
function R.ToggleAdminHistory()if h:IsShown() then h:Hide() else h:Show() end end
