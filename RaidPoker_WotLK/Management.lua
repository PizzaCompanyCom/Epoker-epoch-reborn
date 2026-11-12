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
 local stats=window('RaidFivePokerStatistics','PLAYER STATISTICS / HAND HISTORY',650,520,100,0)
 R.StatisticsFrame=stats
 local statRows={}
 for i=1,15 do
  statRows[i]=text(stats,25,-63-(i-1)*23,590,'')
  if i>=4 and i<=9 then
   local stripe=stats:CreateTexture(nil,'BACKGROUND');stripe:SetTexture('Interface\\Buttons\\WHITE8X8');stripe:SetPoint('TOPLEFT',stats,'TOPLEFT',20,-152-(i-4)*23);stripe:SetSize(610,21)
   stripe:SetVertexColor(.18,.20,.22,(i%2==0) and .26 or .12)
  end
 end
 local function col(x,y,w,v) local t=text(stats,x,y,w,v);t:SetJustifyH('LEFT');return t end
 col(25,-140,175,'PLAYER');col(210,-140,80,'PLAYED');col(300,-140,70,'WON');col(400,-140,170,'NET')
 local cells={}
 for i=1,6 do
  local y=-155-(i-1)*23
  cells[i]={col(25,y,175,''),col(210,y,80,''),col(300,y,70,''),col(400,y,170,'')}
 end
 stats:SetScript('OnShow',function()
  statRows[1]:SetText('Completed hands this session: '..tostring(G.round or 0))
  statRows[2]:SetText('Current phase: '..tostring(G.phase or 'IDLE'))
  statRows[3]:SetText('Latest winner: '..tostring(G.winner or ''))
  local hist=G.solo and G.debugHistory or (RaidPokerWotLKDB and RaidPokerWotLKDB.history) or {}
  local stats=R.GetManagedStats and R.GetManagedStats() or {}
  local names={}
  for n in pairs(stats) do table.insert(names,n) end
  table.sort(names)
  for i=4,9 do local n=names[i-3];local v=n and stats[n];statRows[i]:SetText('');local c=cells[i-3];c[1]:SetText(n or '');c[2]:SetText(v and tostring(v.played or 0) or '');c[3]:SetText(v and tostring(v.won or 0) or '');c[4]:SetText(v and R.Money(v.net or 0) or '') end
  for i=10,15 do statRows[i]:ClearAllPoints();statRows[i]:SetPoint('TOPLEFT',stats,'TOPLEFT',25,-320-(i-10)*24);statRows[i]:SetText(string.sub(R.MoneyText(hist[i-9] or ''),1,100)) end
 end)
 R.ToggleStatistics=function()if stats:IsShown()then stats:Hide()else stats:Show()end end
 -- Separate window launchers without changing the game's betting buttons.
 button(main,'Player Management',452,-674,155,function()R.TogglePlayerManagement()end)
 button(main,'Statistics',632,-674,155,function()R.ToggleStatistics()end)
 -- Single, vertically organized Game Master control panel.
 local lf=R.LeaderFrame
 if lf then
  lf:SetWidth(540);lf:SetHeight(615)
  local leaderIcons={
   ['End Hand & Determine Winner']='Interface\\Icons\\INV_Misc_Coin_01',
   ['Cancel Hand']='Interface\\Icons\\Ability_Rogue_FeignDeath',
   ['Resend Winner']='Interface\\Icons\\INV_Misc_Note_01',
   ['Player Management']='Interface\\Icons\\INV_Misc_GroupLooking',
   ['Transfer Game Master']='Interface\\Icons\\INV_Misc_Head_Human_01',
  }
  local function leaderButton(title,x,y,w,fn)
   local b=button(lf,title,x,y,w,fn)
   local path=leaderIcons[title] or (string.find(title,'Turn Timer',1,true) and 'Interface\\Icons\\INV_Misc_PocketWatch_01') or (string.sub(title,1,1)=='/' and 'Interface\\Icons\\INV_Misc_Note_01')
   if path then
    local ico=b:CreateTexture(nil,'OVERLAY');ico:SetTexture(path);ico:SetWidth(15);ico:SetHeight(15);ico:SetPoint('LEFT',b,'LEFT',5,0)
    local fs=b:GetFontString();if fs then fs:ClearAllPoints();fs:SetPoint('LEFT',b,'LEFT',23,0);fs:SetPoint('RIGHT',b,'RIGHT',-2,0);fs:SetJustifyH('CENTER') end
   end
   return b
  end
  local function desc(y,message) local t=text(lf,225,y,290,message);t:SetTextColor(0.85,0.82,0.7) end
  local finishBtn=leaderButton('End Hand & Determine Winner',20,-58,200,function()R.ForceManagedShowdown()end)
  desc(-62,'Finish the hand and determine the winner.')
  local cancelBtn=leaderButton('Cancel Hand',20,-94,200,function()R.CancelManagedHand()end)
  desc(-98,'Cancel the hand and refund all bets.')
  local resendBtn=leaderButton('Resend Winner',20,-130,200,function()R.ResendManagedWinner()end)
  desc(-134,'Resend the last winner result to players.')
  leaderButton('Player Management',20,-166,200,function()R.TogglePlayerManagement()end)
  desc(-170,'Manage players, balances and seating.')
  local transferBtn=leaderButton('Transfer Game Master',20,-202,200,function()R.TogglePlayerManagement()end)
  desc(-206,'Select a player in Player Management.')
  local function stateTip(btn,title,why)
   btn:SetScript('OnEnter',function(self)
    GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(title)
    if why then GameTooltip:AddLine(why(),1,1,1,true) end
    GameTooltip:Show()
   end)
   btn:SetScript('OnLeave',function()GameTooltip:Hide()end)
  end
  local function active()return G.phase=='BET1' or G.phase=='DRAW' or G.phase=='BET2' end
  stateTip(finishBtn,'End Hand & Determine Winner',function()return active() and 'Finish the current hand.' or 'No active hand to finish.' end)
  stateTip(cancelBtn,'Cancel Hand',function()return active() and 'Cancel the current hand and refund bets.' or 'No active hand to cancel.' end)
  stateTip(resendBtn,'Resend Winner',function()return G.winner~='' and 'Resend the last winner result.' or 'No winner result to resend.' end)
  stateTip(transferBtn,'Transfer Game Master',function()return active() and 'Cannot transfer Game Master during an active hand. Finish or cancel it first.' or 'Choose a player in Player Management, then click Transfer GM.' end)
  local function refreshGMButtons()
   local isHost=R.IsPokerHost and R.IsPokerHost()
   local live=active()
   if isHost and live then finishBtn:Enable();cancelBtn:Enable() else finishBtn:Disable();cancelBtn:Disable() end
   if isHost and G.winner~='' then resendBtn:Enable() else resendBtn:Disable() end
   if isHost and not live then transferBtn:Enable() else transferBtn:Disable() end
  end
  local timerBtn
  local function timerLabel() return 'Turn Timer: '..((G.timer or 0)>0 and (tostring(G.timer)..'s') or 'OFF') end
  timerBtn=leaderButton(timerLabel(),20,-238,200,function()
   if not R.IsPokerHost() then return end
   local t=tonumber(G.timer) or 0
   G.timer=(t==15 and 30) or (t==30 and 60) or (t==60 and 0) or 15
   if R.BroadcastManagedState then R.BroadcastManagedState() elseif R.RequestSync then R.Refresh() end
   timerBtn:SetText(timerLabel())
  end)
  desc(-242,'Cycle: 15s / 30s / 60s / OFF.')
  lf:SetScript('OnShow',function()timerBtn:SetText(timerLabel());refreshGMButtons()end)
  text(lf,20,-290,485,'ANNOUNCEMENTS  -  Select a channel for each message')
  local channels={{'SAY','/s'},{'RAID','/raid'},{'GUILD','/g'},{'YELL','/y'},{'EPOKER','/Epoker'}}
  local kinds={{'WINNER','Winner'},{'TABLE','Table'},{'BALANCES','Balances'}}
  for row,entry in ipairs(kinds) do
   local y=-312-(row-1)*88
   text(lf,20,y,490,entry[2]..' announcement')
   for i,ch in ipairs(channels) do
    local channel=ch[1]
    leaderButton(ch[2],20+(i-1)*101,y-22,96,function()R.AnnounceManaged(entry[1],channel)end)
   end
  end
 end
end
