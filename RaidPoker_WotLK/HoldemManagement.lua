-- Barrens Hold'em beta4c4: management extension for beta4c3.
-- WoW 3.3.5a, Lua 5.1. Does not modify 5-Card Draw.
local R=RPoker
if not R or not R.Holdem or not R.HoldemMultiplayer or not R.HoldemNetwork then return end
local H,M,N=R.Holdem,R.HoldemMultiplayer,R.HoldemNetwork
local W={selected=nil,logs={},rows={}}
R.HoldemManagement=W
local frame,head,detail,logText,balanceInput,initialInput,raiseInput,goldInput,silverInput
local function me() return UnitName('player') or '' end
local function gm() return N.active and N.owner and N.host==me() end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function money(n) n=math.floor(tonumber(n) or 0);return math.floor(n/100)..'g '..(n%100)..'s' end
local function log(s)
 W.logs[#W.logs+1]=date('%H:%M:%S')..' '..s
 if #W.logs>30 then table.remove(W.logs,1) end
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
local function button(parent,text,x,y,w,callback)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetWidth(w);b:SetHeight(22);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',callback)
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
 head:SetText('Game Master: '..tostring(N.host or '-')..'   '..(gm() and '[HOST]' or '[READ ONLY]')..'   Hand '..tostring(H.handNumber or 0)..'   '..tostring(H.phase))
 for i=1,10 do
  local seatData=M.seats[i]
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
  if W.selected==name and name then row.name:SetTextColor(1,.85,.2) else row.name:SetTextColor(1,1,1) end
 end
 local s=seat()
 detail:SetText(s and ('Selected: '..s.name..'   Balance '..money(s.stack)) or 'Select a player seat to manage.')
 logText:SetText(table.concat(W.logs,'\n'))
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
 frame:SetWidth(740);frame:SetHeight(640);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG')
 frame:SetMovable(true);frame:EnableMouse(true);frame:SetClampedToScreen(true);frame:RegisterForDrag('LeftButton')
 frame:SetScript('OnDragStart',function(self)self:StartMoving()end)
 frame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 frame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 font(frame,20,-18,590,"THE BARRENS HOLD'EM - PLAYER MANAGEMENT",'GameFontNormalLarge')
 button(frame,'X',695,-16,28,function()frame:Hide()end)
 head=font(frame,20,-52,690,'')
 button(frame,'Auto Seat Joined',20,-78,135,function()local ok,err=M.AutoSeat();result(ok,err)end)
 button(frame,'Start Hand',165,-78,110,start)
 button(frame,'Refresh',285,-78,85,function()W.Refresh()end)
 button(frame,'Lobby',380,-78,80,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button(frame,'Table 7.0',470,-78,90,function()if R.OpenBarrensTable then R.OpenBarrensTable() end end)
 font(frame,20,-115,315,'SEATS / VIRTUAL BALANCES','GameFontNormal')
 local function rule(x,y,w,h,alpha)
  local t=frame:CreateTexture(nil,'ARTWORK');t:SetTexture('Interface\\Buttons\\WHITE8X8')
  t:SetVertexColor(.75,.59,.31,alpha or .3);t:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y)
  t:SetWidth(w);t:SetHeight(h)
 end
 rule(20,-136,320,23,.22)
 font(frame,25,-141,28,'#')
 font(frame,51,-141,89,'PLAYER')
 font(frame,144,-141,63,'BALANCE')
 font(frame,215,-141,63,'STATUS')
 font(frame,281,-141,54,'VERSION')
 for _,x in ipairs({45,139,210,276,340}) do rule(x,-136,1,242,.24) end
 for i=0,10 do rule(20,-159-i*22,320,1,.35) end
 for i=1,10 do
  local idx=i
  local y=-162-(i-1)*22
  if i%2==0 then
   local bg=frame:CreateTexture(nil,'BACKGROUND');bg:SetTexture('Interface\\Buttons\\WHITE8X8')
   bg:SetVertexColor(.9,.8,.5,.07);bg:SetPoint('TOPLEFT',frame,'TOPLEFT',21,y+2)
   bg:SetWidth(318);bg:SetHeight(21)
  end
  local row={}
  row.number=font(frame,25,y-3,19,tostring(i))
  row.name=font(frame,51,y-3,87,'[Empty]')
  row.balance=font(frame,144,y-3,63,'-')
  row.status=font(frame,215,y-3,61,'-')
  row.version=font(frame,281,y-3,53,'-')
  local hit=CreateFrame('Button',nil,frame)
  hit:SetPoint('TOPLEFT',frame,'TOPLEFT',20,y+1);hit:SetWidth(320);hit:SetHeight(21)
  hit:SetScript('OnClick',function()
   W.selected=M.seats[idx] and M.seats[idx].name or nil
   local chosen=M.seats[idx]
   if chosen then
    balanceInput:SetText(tostring(chosen.stack))
    goldInput:SetText(tostring(math.floor(chosen.stack/100)))
    silverInput:SetText(tostring(chosen.stack%100))
   end
   W.Refresh()
  end)
  W.rows[i]=row
 end
 font(frame,355,-115,280,'GAME MASTER CONTROLS','GameFontNormal')
 detail=font(frame,355,-144,295,'')
 font(frame,355,-177,100,'Balance (s)')
 balanceInput=input(458,-175,85)
 button(frame,'Set',566,-175,65,function()
  perform(function(s)return M.SetStack(s.name,tonumber(balanceInput:GetText()))end)
 end)
 font(frame,355,-216,100,'Gold / Silver')
 goldInput=input(460,-214,44);goldInput:SetText('0')
 silverInput=input(522,-214,37);silverInput:SetText('0')
 button(frame,'Set G/S',566,-214,65,function()
  local g=tonumber(goldInput:GetText());local v=tonumber(silverInput:GetText())
  if not g or not v or g<0 or v<0 or g~=math.floor(g) or v~=math.floor(v) or v>=100 then result(false,'Enter Gold and Silver (0-99)');return end
  perform(function(seat)return M.SetStack(seat.name,g*100+v)end)
 end)
 button(frame,'Sit Out',355,-251,90,function()perform(function(s)return M.SitOut(s.name,true)end)end)
 button(frame,'Sit In',455,-251,80,function()perform(function(s)return M.SitOut(s.name,false)end)end)
 button(frame,'Remove',545,-251,80,function()perform(function(s)
  local name=s.name;local ok,err=M.Remove(name);if ok then W.selected=nil end;return ok,err
 end)end)
 font(frame,355,-290,135,'Default stack (s)')
 initialInput=input(485,-283,95);initialInput:SetText(tostring(M.initialStack or 1000))
 button(frame,'Apply',585,-283,60,function()
  if not gm() or not idle() then result(false,'Game Master / idle hand required');return end
  local n=tonumber(initialInput:GetText())
  if not n or n<0 or n>100000000 or n~=math.floor(n) then result(false,'Invalid default stack');return end
  M.initialStack=n;log('DEFAULT STACK '..n..'s');W.Refresh()
 end)
 font(frame,355,-330,280,'HOST ACTION TEST (OWN TURN ONLY)','GameFontNormal')
 button(frame,'Fold',355,-356,63,function()action('FOLD')end)
 button(frame,'Check',424,-356,63,function()action('CHECK')end)
 button(frame,'Call',493,-356,63,function()action('CALL')end)
 button(frame,'All-In',562,-356,65,function()action('ALLIN')end)
 font(frame,355,-390,85,'Raise (s)')
 raiseInput=input(443,-383,75);raiseInput:SetText('10')
 button(frame,'Raise',535,-383,90,function()action('RAISE')end)
 button(frame,'Force Fold',535,-410,90,function()
  if not gm() or not M.active then result(false,'Active host hand required');return end
  local player=H.players[H.actionSeat or 0]
  if not player then result(false,'No active player');return end
  local ok,err=H.Action('FOLD',0)
  if ok then log('GM FORCE FOLD '..tostring(player.name)) end
  result(ok,err)
 end)
 font(frame,355,-430,290,'ADMIN HISTORY (CURRENT SESSION)','GameFontNormal')
 logText=font(frame,355,-453,295,'')
 font(frame,20,-485,315,'GM administration is restricted to idle hands.\nVirtual balances; no actual gold transfer.')
 font(frame,20,-523,330,'TURN TIMER - GAME MASTER','GameFontNormal')
 local timerButton=button(frame,'Turn Timer: 30s',20,-545,178,function()
  if R.CycleBarrensTurnTimer then R.CycleBarrensTurnTimer() end
  if R.RefreshBarrensTimerSetting then R.RefreshBarrensTimerSetting() end
 end)
 frame.barrensTurnTimerButton=timerButton
 font(frame,214,-550,420,'15s / 30s / 60s / OFF - change between hands')
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
