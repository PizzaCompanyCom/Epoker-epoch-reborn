-- Raid 5-Card Poker WotLK 0.4.0 - read-only management panels and host actions.
local R=RPoker
local G=R.G
local M={}
local function text(parent,x,y,w,value)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetJustifyH('LEFT');f:SetText(value or '');return f
end
local function button(parent,title,x,y,w,callback)
 return R.Button(parent,title,w,23,x,y,callback)
end
local function window(name,title,w,h,x,y)
 local f=CreateFrame('Frame',name,UIParent)
 f:SetWidth(w);f:SetHeight(h);f:SetFrameStrata('FULLSCREEN_DIALOG')
 f:SetPoint('CENTER',UIParent,'CENTER',x,y)
 f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true)
 R.Backdrop(f)
 local bar=CreateFrame('Frame',nil,f)
 bar:SetPoint('TOPLEFT',f,'TOPLEFT',14,-9);bar:SetPoint('TOPRIGHT',f,'TOPRIGHT',-42,-9);bar:SetHeight(34)
 bar:EnableMouse(true);bar:RegisterForDrag('LeftButton')
 bar:SetScript('OnDragStart',function()f:StartMoving()end)
 bar:SetScript('OnDragStop',function()f:StopMovingOrSizing()end)
 local heading=text(f,20,-24,w-65,title);heading:SetFontObject('GameFontNormalLarge')
 button(f,'X',w-39,-17,25,function()f:Hide()end)
 f:Hide();return f
end
local function edit(parent,x,y,w,initial)
 local f=CreateFrame('EditBox',nil,parent,'InputBoxTemplate')
 f:SetWidth(w);f:SetHeight(24);f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetAutoFocus(false)
 f:SetText(initial or '');f:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
 f:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
 return f
end
function R.BuildManagement(main)
 local stats=window('RaidFivePokerStatistics','PLAYER STATISTICS / HAND HISTORY',600,455,100,0)
 R.StatisticsFrame=stats
 local statRows={}
 for i=1,15 do statRows[i]=text(stats,25,-63-(i-1)*23,545,'') end
 stats:SetScript('OnShow',function()
  statRows[1]:SetText('Completed hands this session: '..tostring(G.round or 0))
  statRows[2]:SetText('Current phase: '..tostring(G.phase or 'IDLE'))
  statRows[3]:SetText('Latest winner: '..tostring(G.winner or ''))
  local hist=G.solo and G.debugHistory or (RaidPokerWotLKDB and RaidPokerWotLKDB.history) or {}
  local stats=R.GetManagedStats and R.GetManagedStats() or {}
  local names={}
  for n in pairs(stats) do table.insert(names,n) end
  table.sort(names)
  for i=4,9 do local n=names[i-3];local v=n and stats[n];statRows[i]:SetText(v and (n..'  Played '..v.played..'  Won '..v.won..'  Net '..R.Money(v.net)) or '') end
  for i=10,15 do statRows[i]:SetText(string.sub(R.MoneyText(hist[i-9] or ''),1,100)) end
 end)
 R.ToggleStatistics=function()if stats:IsShown()then stats:Hide()else stats:Show()end end
 -- Separate window launchers without changing the game's betting buttons.
 button(main,'Player Management',452,-674,155,function()R.TogglePlayerManagement()end)
 button(main,'Statistics',632,-674,155,function()R.ToggleStatistics()end)
 -- Extra host controls use the existing engine, not a second poker state.
 local lf=R.LeaderFrame
 if lf then
  lf:SetHeight(495)
  button(lf,'Resend Winner',20,-292,170,function()R.ResendManagedWinner()end)
  button(lf,'Cancel Hand',205,-292,170,function()R.CancelManagedHand()end)
  button(lf,'Winner /say',20,-325,170,function()R.AnnounceManaged('WINNER','SAY')end)
  button(lf,'Table /raid',205,-325,170,function()R.AnnounceManaged('TABLE','RAID')end)
  button(lf,'Balances /say',20,-358,170,function()R.AnnounceManaged('BALANCES','SAY')end)
  button(lf,'Balances /raid',205,-358,170,function()R.AnnounceManaged('BALANCES','RAID')end)
  button(lf,'End Betting',20,-391,170,function()R.EndManagedBetting()end)
  button(lf,'Force Showdown',205,-391,170,function()R.ForceManagedShowdown()end)
  button(lf,'Winner /raid',20,-424,170,function()R.AnnounceManaged('WINNER','RAID')end)
  button(lf,'Table /say',205,-424,170,function()R.AnnounceManaged('TABLE','SAY')end)
 end
end
