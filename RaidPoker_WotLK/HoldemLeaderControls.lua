-- EpokerWoW Raid HF25: unified icon-based Game Master Controls for Hold'em (WoW 3.3.5a).
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local W
local function label(p,s,x,y,w)
 local t=p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',p,'TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetText(s);return t
end
local icons={
 ['Player Management']='Interface\\Icons\\INV_Misc_GroupLooking',
 ['Transfer Game Master']='Interface\\Icons\\INV_Misc_Head_Human_01',
 ['Force Seat Sync']='Interface\\Icons\\INV_Misc_Note_01',
 ['Turn Timer']='Interface\\Icons\\INV_Misc_PocketWatch_01',
 ['Announce Balances']='Interface\\Icons\\INV_Misc_Coin_01',
 ['Announce Winner']='Interface\\Icons\\INV_Misc_Coin_01',
 ['Announce Table']='Interface\\Icons\\INV_Misc_Note_01',
 ['Channel']='Interface\\Icons\\INV_Misc_Note_01',
}
local function button(p,s,x,y,w,fn,icon)
 local b=CreateFrame('Button',nil,p,'UIPanelButtonTemplate')
 b:SetSize(w,26);b:SetPoint('TOPLEFT',p,'TOPLEFT',x,y);b:SetText(s);b:SetScript('OnClick',fn)
 local path=icons[icon or s] or (string.find(s,'Turn Timer',1,true) and icons['Turn Timer'])
 if path and w>=70 then
  local ico=b:CreateTexture(nil,'OVERLAY');ico:SetTexture(path);ico:SetSize(15,15);ico:SetPoint('LEFT',b,'LEFT',5,0)
  local fs=b:GetFontString();if fs then fs:ClearAllPoints();fs:SetPoint('LEFT',b,'LEFT',22,0);fs:SetPoint('RIGHT',b,'RIGHT',-3,0);fs:SetJustifyH('CENTER') end
 end
 return b
end
local function gm()
 local n=R.HoldemNetwork
 return n and n.active and n.owner and n.host==UnitName('player')
end
local function solo()
 return not (R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK')
end
local function warn(s) if R.Print then R.Print('Hold\'em Leader: '..s) end end
local function canAnnounce()
 if solo() then return true end
 if not gm() then warn('Game Master only.');return false end
 return true
end
local function money(v)
 v=math.floor(tonumber(v) or 0)
 return math.floor(v/100)..'g '..(v%100)..'s'
end
local function announce(kind,channel)
 if not canAnnounce() then return end
 local lines={}
 local snap=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot() or H
 if kind=='WINNER' then
  local wins=snap and snap.winners or H.winners
  local players=snap and snap.players or H.players
  for seat,amount in pairs(wins or {}) do
   local player=players and players[seat]
   if player and player.name then lines[#lines+1]=player.name..' wins '..money(amount) end
  end
  if #lines==0 then warn('No winner to announce.');return end
 elseif kind=='TABLE' then
  local players=snap and snap.players or {}
  lines[1]='Table: '..tostring(#players)..' players | '..tostring(snap.phase or 'LOBBY')..' | Pot: '..money(snap.pot)
 elseif kind=='BALANCES' then
  local players=(not solo() and R.HoldemMultiplayer and R.HoldemMultiplayer.seats) or (snap and snap.players) or {}
  for _,player in ipairs(players) do
   if player.name then lines[#lines+1]=player.name..': '..money(player.stack) end
  end
  if #lines==0 then warn('No player balances to announce.');return end
 end
 if solo() then for _,line in ipairs(lines) do warn(line) end;return end
 local id=nil
 if channel=='EPOKER' then
  id=GetChannelName and GetChannelName('Epoker') or 0
  if not id or id==0 then warn('Join /Epoker before announcing.');return end
  channel='CHANNEL'
 elseif channel=='RAID' and (not GetNumRaidMembers or GetNumRaidMembers()==0) then warn('Join a raid first.');return
 elseif channel=='GUILD' and (not IsInGuild or not IsInGuild()) then warn('Join a guild first.');return end
 for _,line in ipairs(lines) do
  local clean=string.gsub(string.gsub(line,'|',' - '),'[%c]',' ')
  SendChatMessage(string.sub('[Epoker] '..clean,1,220),channel,nil,id)
 end
end
local function build()
 if W then return end
 W=CreateFrame('Frame','RaidPokerBarrensLeaderControls',UIParent)
 W:SetSize(540,615);W:SetPoint('CENTER',UIParent,'CENTER',270,0)
 W:SetFrameStrata('FULLSCREEN_DIALOG');W:SetMovable(true);W:EnableMouse(true)
 W:SetClampedToScreen(true);W:RegisterForDrag('LeftButton')
 W:SetScript('OnDragStart',function(self)self:StartMoving()end)
 W:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 W:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 local title=label(W,'Game master control',20,-20,445);title:SetFontObject('GameFontNormalLarge')
 button(W,'X',500,-16,26,function()W:Hide()end)
 local function desc(y,message) local t=label(W,message,225,y,290);t:SetTextColor(.85,.82,.7) end
 button(W,'Player Management',20,-58,200,function()if R.OpenBarrensManagement then R.OpenBarrensManagement()end end)
 desc(-62,'Manage players, balances and seating.')
 button(W,'Transfer Game Master',20,-94,200,function()if R.OpenBarrensGMTransfer then R.OpenBarrensGMTransfer()end end)
 desc(-98,'Transfer table authority to another player.')
 button(W,'Force Seat Sync',20,-130,200,function()
  if not gm() then warn('Game Master only.');return end
  local a=R.HoldemAdminBridge
  if a and a.BroadcastSeats then local ok,err=a.BroadcastSeats();if not ok then warn(err or 'Sync unavailable') end
  else warn('Seat synchronization unavailable') end
 end)
 desc(-134,'Resend the public seating state to players.')
 W.timerButton=button(W,'Turn Timer: 30s',20,-166,200,function()
  if R.CycleBarrensTurnTimer then R.CycleBarrensTurnTimer() end
  if R.RefreshBarrensTimerSetting then R.RefreshBarrensTimerSetting() end
 end,'Turn Timer')
 desc(-170,'Cycle: 15s / 30s / 60s / OFF.')
 label(W,'ANNOUNCEMENTS  -  Select a channel for each message',20,-234,495)
 local channels={{'SAY','/s'},{'RAID','/raid'},{'GUILD','/g'},{'YELL','/y'},{'EPOKER','/Epoker'}}
 local kinds={{'WINNER','Winner'},{'TABLE','Table'},{'BALANCES','Balances'}}
 for row,entry in ipairs(kinds) do
  local y=-265-(row-1)*88
  label(W,entry[2]..' announcement',20,y,480)
  for i,ch in ipairs(channels) do
   local channel=ch[1]
   button(W,ch[2],20+(i-1)*101,y-22,96,function()announce(entry[1],channel)end,'Channel')
  end
 end
 label(W,'Announcements are sent by the Game Master in network mode.',20,-555,490)
 W:Hide()
end
function R.OpenBarrensLeaderControls()
 build()
 if R.RefreshBarrensTimerSetting then R.RefreshBarrensTimerSetting() end
 if W:IsShown() then W:Hide() else W:Show();W:Raise() end
end
