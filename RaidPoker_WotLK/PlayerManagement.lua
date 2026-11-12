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
f:SetWidth(660);f:SetHeight(930);f:SetPoint('CENTER',UIParent,'CENTER',90,0)
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
local createTable=btn(f,'Create Table',22,-76,145,function()
 if R.ActiveTableID()~='' then return end
 if #R.GetTableDirectory()>0 then R.Print('A raid table already exists. Join it instead.');return end
 R.CreateNamedTable('Ironforge Poker')
 R.RefreshPlayerManagement()
end)
local joinTable=btn(f,'Join Table',22,-109,145,function()
 if R.ActiveTableID()~='' then R.Print('Already connected.');return end
 local list=R.GetTableDirectory()
 if #list==1 then R.JoinNamedTable(list[1].id)
 elseif #list==0 then R.DiscoverTables();if StaticPopup_Show then StaticPopup_Show('EPOKER_NO_ACTIVE_TABLE') end
 else R.Print('Multiple legacy tables detected. Use Table Browser.') end
end)
-- Fix 30: refresh discovery, state and peer-version information without changing balances.
local refreshButton=btn(f,'Refresh',342,-109,114,function()
 if R.DiscoverTables then R.DiscoverTables() end
 if R.RequestSync and R.ActiveTableID and R.ActiveTableID()~='' then R.RequestSync() end
 if R.RequestPokerPeerVersions then R.RequestPokerPeerVersions() end
 if R.RefreshPlayerManagement then R.RefreshPlayerManagement() end
end)
local refreshIcon=refreshButton:CreateTexture(nil,'OVERLAY')
refreshIcon:SetTexture('Interface\\Icons\\Ability_Rogue_Sprint')
refreshIcon:SetWidth(17);refreshIcon:SetHeight(17)
refreshIcon:SetPoint('LEFT',refreshButton,'LEFT',7,0)
local refreshText=refreshButton:GetFontString()
if refreshText then
 refreshText:ClearAllPoints()
 refreshText:SetPoint('LEFT',refreshButton,'LEFT',25,0)
 refreshText:SetPoint('RIGHT',refreshButton,'RIGHT',-4,0)
 refreshText:SetJustifyH('CENTER')
end
local createState=label(f,184,-82,320,'No active table')
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
line(20,-148,616,24,.22)
cell(30,-153,166,'PLAYER')
cell(207,-153,116,'BALANCE')
cell(330,-153,118,'STATUS')
cell(452,-153,52,'HAND')
cell(510,-153,60,'VERSION')
cell(575,-153,48,'ACTION')
for i=0,10 do line(20,-172-i*21,616,1,.34) end
for _,x in ipairs({196,319,448,506,572}) do line(x,-148,1,234,.25) end
local selectLabel=label(f,22,-400,600,'Selected Player: none')
selectLabel:SetFontObject('GameFontNormal')
for i=1,6 do
 local y=-174-(i-1)*21
 if i%2==0 then
  local bg=f:CreateTexture(nil,'BACKGROUND')
  bg:SetTexture('Interface\\Buttons\\WHITE8X8')
  bg:SetVertexColor(.9,.78,.48,.065)
  bg:SetPoint('TOPLEFT',f,'TOPLEFT',21,y+1);bg:SetWidth(614);bg:SetHeight(20)
 end
 local idx=i
 local row={}
 row.highlight=f:CreateTexture(nil,'ARTWORK')
 row.highlight:SetTexture('Interface\\Buttons\\WHITE8X8')
 row.highlight:SetVertexColor(1,.72,.16,.18)
 row.highlight:SetPoint('TOPLEFT',f,'TOPLEFT',21,y+1)
 row.highlight:SetWidth(551);row.highlight:SetHeight(20);row.highlight:Hide()
 row.top=f:CreateTexture(nil,'OVERLAY');row.top:SetTexture('Interface\\Buttons\\WHITE8X8')
 row.top:SetVertexColor(1,.75,.15,.9);row.top:SetPoint('TOPLEFT',f,'TOPLEFT',21,y+1)
 row.top:SetWidth(551);row.top:SetHeight(1);row.top:Hide()
 row.bottom=f:CreateTexture(nil,'OVERLAY');row.bottom:SetTexture('Interface\\Buttons\\WHITE8X8')
 row.bottom:SetVertexColor(1,.75,.15,.9);row.bottom:SetPoint('TOPLEFT',f,'TOPLEFT',21,y-18)
 row.bottom:SetWidth(551);row.bottom:SetHeight(1);row.bottom:Hide()
 row.name=cell(30,y-4,162,'')
 row.balance=cell(207,y-4,108,'')
 row.status=cell(330,y-4,112,'')
 row.hand=cell(452,y-4,52,'')
 row.version=cell(510,y-4,60,'')
 row.button=btn(f,'Select',575,y+1,58,function()
  local player=R.G.players[idx]
  if player then selected=player.name;selectLabel:SetText('Selected Player: '..selected);R.RefreshPlayerManagement() end
 end)
 rows[i]=row
end
label(f,26,-429,110,'Gold')
label(f,167,-429,85,'Silver')
-- InputBoxTemplate has decorative textures extending outside its anchor;
-- leave a wide gap and place both boxes above all action buttons.
local gold=edit(f,35,-449,56,'0')
local silver=edit(f,172,-449,56,'0')
btn(f,'Set Balance',272,-449,145,function()
 if not selected then return end
 local n=R.ReadMoney(gold,silver)
 if n then R.AdminSetBalance(selected,n) end
end)
btn(f,'Sit Out',22,-480,105,function()if selected then R.AdminSetStatus(selected,'Sitting Out')end end)
btn(f,'Sit In',136,-480,100,function()if selected then R.AdminSetStatus(selected,'Playing')end end)
-- Default stack applies to newly seated players; existing balances are unchanged.
label(f,478,-463,150,'Default stack (s)')
local defaultStack=edit(f,478,-480,82,tostring(R.G.stack or 1000))
btn(f,'Apply',568,-480,66,function()
 if not R.IsGameMaster or not R.IsGameMaster() then R.Print('Game Master only.');return end
 if R.G.phase~='LOBBY' and R.G.phase~='SHOWDOWN' then R.Print('Change default stack between hands.');return end
 local n=tonumber(defaultStack:GetText())
 if not n or n~=math.floor(n) or n<1 or n>100000000 then R.Print('Invalid default stack (1-100000000 silver).');return end
 R.G.stack=n
 if R.PublishManagedState then R.PublishManagedState() end
 R.Print('Default stack set to '..n..'s. New players only.')
 R.RefreshPlayerManagement()
end)
label(f,22,-506,610,'Sit Out: pause selected player for future hands; seat and balance remain.')
label(f,22,-524,610,'Sit In: resume participation from the next hand.')
local transferButton=btn(f,'Transfer GM',178,-109,154,function()
 if selected then R.AdminTransferGM(selected) else R.Print('Select a player first.') end
end)
local function addButtonIcon(button,path)
 local ico=button:CreateTexture(nil,'OVERLAY')
 ico:SetTexture(path);ico:SetWidth(16);ico:SetHeight(16)
 ico:SetPoint('LEFT',button,'LEFT',6,0)
 local fs=button:GetFontString()
 if fs then fs:ClearAllPoints();fs:SetPoint('LEFT',button,'LEFT',24,0);fs:SetPoint('RIGHT',button,'RIGHT',-3,0);fs:SetJustifyH('CENTER') end
end
addButtonIcon(transferButton,'Interface\\Icons\\INV_Misc_Head_Human_01')
label(f,22,-547,180,'TURN TIMER','GameFontNormal')
local timerButton=btn(f,'Turn Timer: 30s',178,-544,178,function()
 local g=R.G
 if not g then return end
 if not g.solo and g.phase~='LOBBY' and g.phase~='SHOWDOWN' and g.phase~='IDLE' then R.Print('Change the timer between hands.');return end
 if not R.IsPokerHost or not R.IsPokerHost() then R.Print('Game Master only.');return end
 local v=(g.timer==15 and 30 or g.timer==30 and 60 or g.timer==60 and 0 or 15)
 g.timer=v
 if R.PublishManagedState then R.PublishManagedState()end
 R.RefreshPlayerManagement()
end)
local timerHint=label(f,367,-551,250,'15s / 30s / 60s / OFF')
addButtonIcon(timerButton,'Interface\\Icons\\INV_Misc_PocketWatch_01')

label(f,22,-605,605,'Balance / status / GM transfer: between hands only.')
label(f,22,-625,605,'Players may leave voluntarily using Leave Table.')
label(f,22,-645,605,'Virtual currency only. No automatic gold transfer.')
label(f,22,-682,580,'ADMIN HISTORY (CURRENT SESSION)','GameFontNormal')
local historyLines={}
local historyPage=0
for i=1,7 do historyLines[i]=label(f,30,-709-(i-1)*21,590,'') end
local function refreshEmbeddedHistory()
 local entries=(RaidPokerWotLKDB and RaidPokerWotLKDB.adminHistory) or {}
 local maxPage=math.max(0,math.ceil(#entries/7)-1)
 historyPage=math.min(historyPage,maxPage)
 for i=1,7 do historyLines[i]:SetText(entries[historyPage*7+i] or '') end
end
btn(f,'< Previous',340,-865,130,function()historyPage=math.max(0,historyPage-1);refreshEmbeddedHistory()end)
btn(f,'Next >',480,-865,130,function()historyPage=historyPage+1;refreshEmbeddedHistory()end)
function R.RefreshPlayerManagement()
 if not f:IsShown() then return end
 local list=R.GetTableDirectory()
 local exists=R.ActiveTableID()~='' or #list>0
 if exists then createTable:Disable() else createTable:Enable() end
 createState:SetText(R.ActiveTableID()~='' and 'Table active' or (#list>0 and 'Raid table available' or 'No active table'))
 defaultStack:SetText(tostring(R.G.stack or 1000))
 timerButton:SetText('Turn Timer: '..((R.G.timer==0) and 'OFF' or tostring(R.G.timer or 30)..'s'))
 gm:SetText('Game Master: '..(R.GameMasterName()~='' and R.GameMasterName() or 'none')..
   (R.IsGameMaster() and '  (You have administrative control)' or '  (Read only)'))
 local found=false
 for i=1,6 do
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
  if p and p.name==selected then row.highlight:Show();row.top:Show();row.bottom:Show()
  else row.highlight:Hide();row.top:Hide();row.bottom:Hide() end
  if p then row.button:Show() else row.button:Hide() end
 end
 if selected and not found then selected=nil end
 selectLabel:SetText('Selected Player: '..(selected or 'none'))
 refreshEmbeddedHistory()
end
f:SetScript('OnShow',R.RefreshPlayerManagement)
f:Hide()
R.PlayerManagementFrame=f
function R.TogglePlayerManagement()
 if f:IsShown() then f:Hide() else f:Show();if R.RequestPokerPeerVersions then R.RequestPokerPeerVersions()end end
end
-- Backward-compatible entry point; history is now embedded in Player Management.
function R.ToggleAdminHistory()
 if not f:IsShown() then f:Show() end
 refreshEmbeddedHistory()
end

local historyElapsed=0
f:HookScript('OnUpdate',function(self,elapsed)
 historyElapsed=historyElapsed+elapsed
 if historyElapsed>=1 then historyElapsed=0;refreshEmbeddedHistory() end
end)
