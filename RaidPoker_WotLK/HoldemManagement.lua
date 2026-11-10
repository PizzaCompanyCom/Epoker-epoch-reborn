-- Barrens Hold'em beta4c4: management extension for beta4c3.
-- WoW 3.3.5a, Lua 5.1. Does not modify 5-Card Draw.
local R=RPoker
if not R or not R.Holdem or not R.HoldemMultiplayer or not R.HoldemNetwork then return end
local H,M,N=R.Holdem,R.HoldemMultiplayer,R.HoldemNetwork
local W={selected=nil,logs={},rows={}}
R.HoldemManagement=W
local frame,head,detail,logText,balanceInput,initialInput,raiseInput,goldInput,silverInput
local availableRows,availablePage,availableNames={},0,{}
local function me() return UnitName('player') or '' end
local function gm() return N.active and N.owner and N.host==me() end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function money(n) n=math.floor(tonumber(n) or 0);return math.floor(n/100)..'g '..(n%100)..'s' end
local function log(s)
 W.logs[#W.logs+1]=date('%H:%M:%S')..' '..s
 if #W.logs>30 then table.remove(W.logs,1) end
end
local function visibleSeats()
 if gm() then return M.seats end
 return (R.HoldemSync and R.HoldemSync.remote and R.HoldemSync.remote.players) or {}
end
local function seat()
 for i,s in ipairs(M.seats) do if s.name==W.selected then return s,i end end
 return nil
end
local function result(ok,err)
 if not ok then log('REJECT '..tostring(err));if R.Print then R.Print('Barrens: '..tostring(err)) end end
 W.Refresh()
end
local function font(parent,x,y,w,text,style)
 local f=parent:CreateFontString(nil,'OVERLAY',style or 'GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetJustifyH('LEFT');f:SetText(text or '')
 return f
end
local managementIcons={
 ['Create Table']='Interface\\Icons\\INV_Misc_Key_03',
 ['Join Table']='Interface\\Icons\\INV_Misc_GroupLooking',
 ['Auto Seat Joined']='Interface\\Icons\\INV_Misc_GroupLooking',
 ['Refresh']='Interface\\Icons\\INV_Misc_PocketWatch_01',
 ['Lobby']='Interface\\Icons\\INV_Misc_Note_01',
 ['Transfer GM']='Interface\\Icons\\INV_Misc_Head_Human_01',
 ['Set Balance']='Interface\\Icons\\INV_Misc_Coin_01',
 ['Sit Out']='Interface\\Icons\\Ability_Rogue_FeignDeath',
 ['Sit In']='Interface\\Icons\\Ability_Warrior_RallyingCry',
 ['Remove']='Interface\\Icons\\INV_Misc_Bone_01',
 ['Turn Timer: 30s']='Interface\\Icons\\INV_Misc_PocketWatch_01',
 ['Force Fold']='Interface\\Icons\\Ability_Rogue_FeignDeath',
 ['Auto Seat']='Interface\\Icons\\INV_Misc_GroupLooking',
}
local function button(parent,text,x,y,w,callback)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetWidth(w);b:SetHeight(22);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',callback)
 local path=managementIcons[text]
 if not path then
  if string.find(text,'Balance') or string.find(text,'Stack') then path='Interface\\Icons\\INV_Misc_Coin_01'
  elseif string.find(text,'Timer') then path='Interface\\Icons\\INV_Misc_PocketWatch_01'
  elseif string.find(text,'Fold') then path='Interface\\Icons\\Ability_Rogue_FeignDeath'
  elseif string.find(text,'Seat') then path='Interface\\Icons\\INV_Misc_GroupLooking' end
  if not path and text~='X' and text~='<' and text~='>' then path='Interface\\Icons\\INV_Misc_Note_01' end
 end
 if path and w>=78 then
  local ico=b:CreateTexture(nil,'OVERLAY');ico:SetTexture(path);ico:SetSize(15,15);ico:SetPoint('LEFT',b,'LEFT',5,0)
  local fs=b:GetFontString();if fs then fs:ClearAllPoints();fs:SetPoint('LEFT',b,'LEFT',22,0);fs:SetPoint('RIGHT',b,'RIGHT',-2,0);fs:SetJustifyH('CENTER');fs:SetFontObject('GameFontNormalSmall') end
 end
 return b
end
local function input(x,y,w)
 local e=CreateFrame('EditBox',nil,frame)
 e:SetWidth(w);e:SetHeight(22);e:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y);e:SetAutoFocus(false)
 e:SetNumeric(true);e:SetMaxLetters(9)
 e:SetFontObject('ChatFontNormal');e:SetTextInsets(6,6,0,0)
 e:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
 e:SetBackdropColor(.04,.04,.04,.96)
 e:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
 e:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
 return e
end
function W.Refresh()
 if not frame then return end
 if frame.hf19Create then
  if N.PruneDiscovery then N.PruneDiscovery() end
  local exists=N.active
  if not exists then
   for name in pairs(N.discovered or {}) do
    if GetNumRaidMembers and GetRaidRosterInfo then
     for i=1,GetNumRaidMembers() do if GetRaidRosterInfo(i)==name then exists=true;break end end
    end
    if exists then break end
   end
  end
  if exists then frame.hf19Create:Disable() else frame.hf19Create:Enable() end
  frame.hf19Status:SetText(N.active and ('Table: '..tostring(N.host or '-')..' [ACTIVE]') or (exists and 'Table already created in raid' or 'No active table'))
 end
 head:SetText('Game Master: '..tostring(N.host or '-')..'   '..(gm() and '[HOST]' or '[READ ONLY]')..'   Hand '..tostring(H.handNumber or 0)..'   '..tostring(H.phase))
 for i=1,10 do
  local seatData=visibleSeats()[i]
  local row=W.rows[i]
  local name=seatData and seatData.name or nil
  local state=seatData and (seatData.sittingOut and 'SIT OUT' or (seatData.stack==0 and 'BUSTED' or 'PLAYING')) or '-'
  row.name:SetText(name or '[Empty]')
  row.balance:SetText(seatData and money(seatData.stack) or '-')
  row.status:SetText(state)
  local version=R.GetPokerPeerVersion and R.GetPokerPeerVersion(name) or nil
  row.version:SetText(name and (version or 'Unknown') or '-')
  if name then
   local same=R.PokerVersionMatches and R.PokerVersionMatches(name)
   if same==true then row.version:SetTextColor(.2,1,.25)
   elseif same==false then row.version:SetTextColor(1,.25,.25)
   else row.version:SetTextColor(.7,.7,.7) end
  else row.version:SetTextColor(.7,.7,.7) end
  if W.selected==name and name then
   row.name:SetTextColor(1,.85,.2)
   row.highlight:Show();row.top:Show();row.bottom:Show()
  else
   row.name:SetTextColor(1,1,1)
   row.highlight:Hide();row.top:Hide();row.bottom:Hide()
  end
 end
 local s=seat()
 detail:SetText(s and ('Selected Player: '..s.name..'   Balance '..money(s.stack)) or 'Selected Player: none  |  Select a seat to manage.')
 logText:SetText(table.concat(W.logs,'\n'))
 availableNames={}
 if GetNumRaidMembers and GetNumRaidMembers()>0 then
  local seated={};for _,v in ipairs(visibleSeats()) do seated[v.name]=true end
  for i=1,GetNumRaidMembers() do
   local name=GetRaidRosterInfo(i)
   if name and not seated[name] and R.GetPokerPeerVersion and R.GetPokerPeerVersion(name) then
    availableNames[#availableNames+1]=name
   end
  end
 end
 table.sort(availableNames)
 local pages=math.max(1,math.ceil(#availableNames/4))
 availablePage=math.min(availablePage,pages-1)
 for i,row in ipairs(availableRows) do
  local name=availableNames[availablePage*4+i]
  row.name=name
  if name then
   local state=N.members[name] and 'IN LOBBY' or 'IN RAID'
   row.label:SetText(name..'  |  '..(R.GetPokerPeerVersion(name) or '?')..'  |  '..state)
   row.button:Show();if gm() and N.members[name] and R.PokerVersionMatches and R.PokerVersionMatches(name)==true then row.button:Enable() else row.button:Disable() end
  else row.label:SetText('');row.button:Hide() end
 end

end
local function perform(fn)
 if not gm() then result(false,'Game Master only');return end
 if not idle() then result(false,'Finish the current hand first');return end
 local s=seat();if not s then result(false,'Select a player');return end
 local ok,err=fn(s)
 if ok then log('ADMIN '..s.name..' updated') end
 result(ok,err)
end
local function start()
 if not gm() then result(false,'Game Master only');return end
 local ok,err=M.StartHand()
 if ok then log('HAND '..tostring(H.handNumber)..' started ('..tostring(#M.seats)..' seats)') end
 result(ok,err)
end
local function action(a)
 if not gm() or not M.active then result(false,'Active host hand required');return end
 local p=H.players[H.actionSeat or 0]
 if not p then result(false,'No active turn');return end
 -- Host testing only: do not impersonate a remote real player.
 if p.name~=me() then result(false,'Remote player must send their own action');return end
 local amount=a=='RAISE' and tonumber(raiseInput:GetText()) or 0
 local ok,err=H.Action(a,amount)
 if ok then log('ACTION '..p.name..' '..a) end
 result(ok,err)
end
local function build()
 if frame then return end
 frame=CreateFrame('Frame','RaidPokerBarrensManagement',UIParent)
 frame:SetWidth(740);frame:SetHeight(710);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG')
 frame:SetMovable(true);frame:EnableMouse(true);frame:SetClampedToScreen(true);frame:RegisterForDrag('LeftButton')
 frame:SetScript('OnDragStart',function(self)self:StartMoving()end)
 frame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 frame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 font(frame,20,-18,590,"THE BARRENS HOLD'EM - PLAYER MANAGEMENT",'GameFontNormalLarge')
 button(frame,'X',695,-16,28,function()frame:Hide()end)
 head=font(frame,20,-52,690,'')
 local createBtn=button(frame,'Create Table',20,-78,145,function()
  if N.CreateSingle then N.CreateSingle() end
  W.Refresh()
 end)
 local tx=createBtn:GetNormalTexture();if tx then tx:SetVertexColor(.82,.22,.22) end
 local joinBtn=button(frame,'Join Table',490,-78,120,function()
  if N.JoinSingle then
   local ok,why=N.JoinSingle()
   if not ok and why~='No active table' and R.Print then R.Print(why or 'Unable to join table.') end
  end
  W.Refresh()
 end)
 local tableStatus=font(frame,180,-82,300,'No active table detected')
 frame.hf19Create=createBtn;frame.hf19Join=joinBtn;frame.hf19Status=tableStatus

 button(frame,'Auto Seat Joined',20,-112,135,function()local ok,err=M.AutoSeat();result(ok,err)end)
 button(frame,'Refresh',165,-112,85,function()W.Refresh()end)
 button(frame,'Lobby',260,-112,80,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button(frame,'Transfer GM',350,-112,120,function()if R.OpenBarrensGMTransfer then R.OpenBarrensGMTransfer() end end)
 font(frame,20,-149,315,'SEATS / VIRTUAL BALANCES','GameFontNormal')
 local function rule(x,y,w,h,alpha)
  local t=frame:CreateTexture(nil,'ARTWORK');t:SetTexture('Interface\\Buttons\\WHITE8X8')
  t:SetVertexColor(.75,.59,.31,alpha or .3);t:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y)
  t:SetWidth(w);t:SetHeight(h)
 end
 rule(20,-170,320,23,.22)
 font(frame,25,-175,28,'#')
 font(frame,51,-175,89,'PLAYER')
 font(frame,144,-175,63,'BALANCE')
 font(frame,215,-175,63,'STATUS')
 font(frame,281,-175,54,'VERSION')
 for _,x in ipairs({45,139,210,276,340}) do rule(x,-170,1,242,.24) end
 for i=0,10 do rule(20,-193-i*22,320,1,.35) end
 for i=1,10 do
  local idx=i
  local y=-196-(i-1)*22
  if i%2==0 then
   local bg=frame:CreateTexture(nil,'BACKGROUND');bg:SetTexture('Interface\\Buttons\\WHITE8X8')
   bg:SetVertexColor(.9,.8,.5,.07);bg:SetPoint('TOPLEFT',frame,'TOPLEFT',21,y+2)
   bg:SetWidth(318);bg:SetHeight(21)
  end
  local row={}
  row.highlight=frame:CreateTexture(nil,'ARTWORK');row.highlight:SetTexture('Interface\\Buttons\\WHITE8X8')
  row.highlight:SetVertexColor(1,.72,.16,.2);row.highlight:SetPoint('TOPLEFT',frame,'TOPLEFT',21,y+1)
  row.highlight:SetWidth(318);row.highlight:SetHeight(21);row.highlight:Hide()
  row.top=frame:CreateTexture(nil,'OVERLAY');row.top:SetTexture('Interface\\Buttons\\WHITE8X8')
  row.top:SetVertexColor(1,.75,.15,.95);row.top:SetPoint('TOPLEFT',frame,'TOPLEFT',21,y+1)
  row.top:SetWidth(318);row.top:SetHeight(1);row.top:Hide()
  row.bottom=frame:CreateTexture(nil,'OVERLAY');row.bottom:SetTexture('Interface\\Buttons\\WHITE8X8')
  row.bottom:SetVertexColor(1,.75,.15,.95);row.bottom:SetPoint('TOPLEFT',frame,'TOPLEFT',21,y-20)
  row.bottom:SetWidth(318);row.bottom:SetHeight(1);row.bottom:Hide()
  row.number=font(frame,25,y-3,19,tostring(i))
  row.name=font(frame,51,y-3,87,'[Empty]')
  row.balance=font(frame,144,y-3,63,'-')
  row.status=font(frame,215,y-3,61,'-')
  row.version=font(frame,281,y-3,53,'-')
  local hit=CreateFrame('Button',nil,frame)
  hit:SetPoint('TOPLEFT',frame,'TOPLEFT',20,y+1);hit:SetWidth(320);hit:SetHeight(21)
  hit:SetScript('OnClick',function()
   W.selected=visibleSeats()[idx] and visibleSeats()[idx].name or nil
   local chosen=visibleSeats()[idx]
   if chosen then
    balanceInput:SetText(tostring(chosen.stack))
    goldInput:SetText(tostring(math.floor(chosen.stack/100)))
    silverInput:SetText(tostring(chosen.stack%100))
   end
   W.Refresh()
  end)
  W.rows[i]=row
 end
 font(frame,355,-149,280,'GAME MASTER CONTROLS','GameFontNormal')
 detail=font(frame,355,-178,295,'')
 font(frame,355,-211,100,'Balance (s)')
 balanceInput=input(458,-209,85)
 button(frame,'Set',566,-209,65,function()
  perform(function(s)return M.SetStack(s.name,tonumber(balanceInput:GetText()))end)
 end)
 font(frame,355,-250,100,'Gold / Silver')
 goldInput=input(460,-248,44);goldInput:SetText('0')
 silverInput=input(522,-248,37);silverInput:SetText('0')
 button(frame,'Set G/S',566,-248,65,function()
  local g=tonumber(goldInput:GetText());local v=tonumber(silverInput:GetText())
  if not g or not v or g<0 or v<0 or g~=math.floor(g) or v~=math.floor(v) or v>=100 then result(false,'Enter Gold and Silver (0-99)');return end
  perform(function(seat)return M.SetStack(seat.name,g*100+v)end)
 end)
 button(frame,'Sit Out',355,-285,90,function()perform(function(s)return M.SitOut(s.name,true)end)end)
 button(frame,'Sit In',455,-285,80,function()perform(function(s)return M.SitOut(s.name,false)end)end)
 button(frame,'Remove',545,-285,80,function()perform(function(s)
  local name=s.name;local ok,err=M.Remove(name);if ok then W.selected=nil end;return ok,err
 end)end)
 font(frame,355,-324,135,'Default stack (s)')
 initialInput=input(485,-317,95);initialInput:SetText(tostring(M.initialStack or 1000))
 button(frame,'Apply',585,-317,60,function()
  if not gm() or not idle() then result(false,'Game Master / idle hand required');return end
  local n=tonumber(initialInput:GetText())
  if not n or n<0 or n>100000000 or n~=math.floor(n) then result(false,'Invalid default stack');return end
  M.initialStack=n;log('DEFAULT STACK '..n..'s');W.Refresh()
 end)
 font(frame,355,-364,280,'HOST ACTION TEST (OWN TURN ONLY)','GameFontNormal')
 button(frame,'Fold',355,-390,63,function()action('FOLD')end)
 button(frame,'Check',424,-390,63,function()action('CHECK')end)
 button(frame,'Call',493,-390,63,function()action('CALL')end)
 button(frame,'All-In',562,-390,65,function()action('ALLIN')end)
 font(frame,355,-424,85,'Raise (s)')
 raiseInput=input(443,-417,75);raiseInput:SetText('10')
 button(frame,'Raise',535,-417,90,function()action('RAISE')end)
 button(frame,'Force Fold',535,-444,90,function()
  if not gm() or not M.active then result(false,'Active host hand required');return end
  local player=H.players[H.actionSeat or 0]
  if not player then result(false,'No active player');return end
  local ok,err=H.Action('FOLD',0)
  if ok then log('GM FORCE FOLD '..tostring(player.name)) end
  result(ok,err)
 end)
 font(frame,355,-464,290,'ADMIN HISTORY (CURRENT SESSION)','GameFontNormal')
 logText=font(frame,355,-487,295,'')
 font(frame,20,-428,315,'RAID PLAYERS AVAILABLE','GameFontNormal')
 font(frame,20,-447,310,'Addon detected | Not seated')
 for i=1,4 do
  local row={}
  row.label=font(frame,20,-464-(i-1)*20,230,'')
  row.button=button(frame,'Seat',260,-459-(i-1)*20,70,function()
   if row.name then local ok,err=M.Assign(row.name);result(ok,err) end
  end)
  availableRows[i]=row
 end
 button(frame,'<',20,-545,32,function()availablePage=math.max(0,availablePage-1);W.Refresh()end)
 button(frame,'>',58,-545,32,function()availablePage=availablePage+1;W.Refresh()end)
 font(frame,100,-549,225,'Only joined players can be seated')

 font(frame,355,-554,330,'TURN TIMER - GAME MASTER','GameFontNormal')
 local timerButton=button(frame,'Turn Timer: 30s',355,-579,178,function()
  if R.CycleBarrensTurnTimer then R.CycleBarrensTurnTimer() end
  if R.RefreshBarrensTimerSetting then R.RefreshBarrensTimerSetting() end
 end)
 frame.barrensTurnTimerButton=timerButton
 font(frame,355,-609,310,'15s / 30s / 60s / OFF')
 if R.RefreshBarrensTimerSetting then R.RefreshBarrensTimerSetting() end
 frame:Hide()
end
function R.OpenBarrensManagement() build();if R.RequestPokerPeerVersions then R.RequestPokerPeerVersions()end;W.Refresh();frame:Show();frame:Raise() end
SLASH_BARRMANAGE1='/holdemmanage'
SlashCmdList.BARRMANAGE=function()R.OpenBarrensManagement()end
local old=SlashCmdList and SlashCmdList.RAIDFIVEPOKER
if old then SlashCmdList.RAIDFIVEPOKER=function(input)
 local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
 if cmd=='holdemmanage' or cmd=='holdemadmin' then R.OpenBarrensManagement() else old(input) end
end end
-- Extend original c3 management with a second UI, without replacing its methods.
local originalAssign=M.Assign
M.Assign=function(name)
 local ok,err=originalAssign(name)
 if ok then log('SEAT '..tostring(name)) end
 W.Refresh();return ok,err
end
local originalAction=H.Action
H.Action=function(a,v)
 local ok,err=originalAction(a,v)
 if ok then W.Refresh() end
 return ok,err
end
