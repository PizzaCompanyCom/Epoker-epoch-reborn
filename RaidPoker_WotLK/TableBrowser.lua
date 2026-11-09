-- Raid 5-Card Poker v1.6.3: independent table discovery and selection.
local R=RPoker
local f=CreateFrame('Frame','RaidPokerTableBrowser',UIParent)
f:SetWidth(610);f:SetHeight(490);f:SetPoint('CENTER',UIParent,'CENTER',0,0)
f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetMovable(true);f:EnableMouse(true)
f:SetClampedToScreen(true);R.Backdrop(f)
f:RegisterForDrag('LeftButton')
f:SetScript('OnDragStart',function(self)self:StartMoving()end)
f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
local function label(x,y,w,text,large)
 local t=f:CreateFontString(nil,'OVERLAY',large and 'GameFontNormalLarge' or 'GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',f,'TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetText(text or '')
 return t
end
local function button(txt,x,y,w,fn)
 return R.Button(f,txt,w,24,x,y,fn)
end
label(24,-23,440,'TABLE BROWSER',true)
button('X',562,-15,26,function()f:Hide()end)
label(24,-60,550,'Create a named table or join an available raid table.')
local name=CreateFrame('EditBox',nil,f,'InputBoxTemplate')
name:SetPoint('TOPLEFT',f,'TOPLEFT',30,-84);name:SetWidth(250);name:SetHeight(25)
name:SetAutoFocus(false);name:SetMaxLetters(32)
name:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
name:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
name:SetText('')
button('Create Table',302,-84,130,function()
 R.CreateNamedTable(name:GetText())
 R.RefreshTableBrowser()
end)
button('Refresh',445,-84,115,function()R.DiscoverTables();R.RefreshTableBrowser()end)
local active=label(24,-124,550,'')
local rows={}
for i=1,8 do
 local y=-162-(i-1)*31
 local info=label(24,y-4,420,'')
 local join=button('Join',470,y-1,90,function()
  local t=R.GetTableDirectory()[i]
  if t then R.JoinNamedTable(t.id) end
  R.RefreshTableBrowser()
 end)
 rows[i]={info=info,join=join}
end
button('Leave Table',24,-423,130,function()R.LeaveNamedTable();R.RefreshTableBrowser()end)
button('Close Table (GM)',168,-423,165,function()R.CloseNamedTable();R.RefreshTableBrowser()end)
label(24,-457,550,'One active table per character. GM must transfer or close before leaving.')
function R.RefreshTableBrowser()
 if not f:IsShown() then return end
 local id=R.ActiveTableID()
 active:SetText('Current table: '..(id~='' and (R.ActiveTableName()..'  ['..id..']') or 'None'))
 local list=R.GetTableDirectory()
 for i=1,8 do
  local t=list[i]
  if t then
   rows[i].info:SetText(t.name..'  |  GM: '..t.gm..'  |  '..t.count..'/10  |  '..t.phase)
   rows[i].join:Show()
   if id~='' or t.count>=10 or t.phase~='LOBBY' then rows[i].join:Disable() else rows[i].join:Enable() end
  else rows[i].info:SetText('');rows[i].join:Hide() end
 end
end
function R.ToggleTableBrowser()
 if f:IsShown() then f:Hide() else f:Show();R.RefreshTableBrowser();R.DiscoverTables() end
end
f:Hide()
