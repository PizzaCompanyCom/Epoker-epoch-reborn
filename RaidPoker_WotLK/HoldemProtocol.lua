-- The Barrens Hold'em beta4c2: isolated action transport, private hole-card delivery,
-- and local protocol simulation. This does not turn preview into a multiplayer game.
-- WoW 3.3.5a / Lua 5.1; independent from 5-Card Draw.
local R=RPoker
if not R or not R.Holdem or not R.HoldemNetwork then return end
local H,N=R.Holdem,R.HoldemNetwork
local PREFIX='RPBH4D'
local M={log={},sequence=0,privateCards={},simulated=false,auto=false,processed={},testPlayers={}}
R.HoldemProtocol=M
local window,output,info
local function me() return UnitName('player') or '' end
local function clean(s) return tostring(s or ''):gsub('[|,;\r\n]',''):sub(1,45) end
local function raidMember(name)
 if not GetNumRaidMembers or GetNumRaidMembers()==0 then return false end
 for i=1,GetNumRaidMembers() do if GetRaidRosterInfo(i)==name then return true end end
 return false
end
local function note(msg)
 M.log[#M.log+1]=date('%H:%M:%S')..' '..msg
 if #M.log>16 then table.remove(M.log,1) end
 if output then output:SetText(table.concat(M.log,'\n')) end
end
local function validCard(card)
 if type(card)~='table' then return nil end
 local rank=tonumber(card.rank)
 local suit=card.suit
 if not rank or rank<2 or rank>14 or rank~=math.floor(rank) then return nil end
 if suit~='S' and suit~='H' and suit~='D' and suit~='C' then return nil end
 return tostring(rank)..suit
end
local function decodeCard(s)
 local rank,suit=tostring(s or ''):match('^(%d+)([SHDC])$')
 rank=tonumber(rank)
 if not rank or rank<2 or rank>14 then return nil end
 return {rank=rank,suit=suit}
end
local function authorize(sender,seat)
 if not N.owner or not N.active or not N.members[sender] then return false,'Not an admitted member' end
 local p=H.players[seat]
 if not p or p.name~=sender then return false,'Seat ownership mismatch' end
 if H.actionSeat~=seat then return false,'Out of turn' end
 return true
end
local function hostAction(sender,seat,action,amount,seq)
 local ok,reason=authorize(sender,seat)
 if not ok then note('REJECT '..clean(sender)..': '..reason);return false end
 if type(action)~='string' or not ({FOLD=true,CHECK=true,CALL=true,RAISE=true,ALLIN=true})[action] then note('REJECT unknown action');return false end
 if not seq or not seq:match('^%d+$') or #seq>9 then note('REJECT invalid sequence');return false end
 local key=sender..':'..seq
 if M.processed[key] then note('REJECT duplicate action');return false end
 local value=tonumber(amount)
 if not value or value<0 or value>100000000 or value~=math.floor(value) then note('REJECT invalid amount');return false end
 if action~='RAISE' and value~=0 then note('REJECT unexpected amount');return false end
 local accepted,why=H.Action(action,value)
 if accepted then
  M.processed[key]=true;note('ACCEPT '..clean(sender)..' '..action..' seat '..seat)
  if R.HoldemSync and R.HoldemSync.ForceBroadcast then R.HoldemSync.ForceBroadcast() end
 else note('REJECT '..clean(sender)..': '..clean(why)) end
 return accepted
end
local function sendAction(action,amount)
 if not N.active or N.owner or not raidMember(N.host) then note('Join a remote lobby first');return false,'Join a remote lobby first' end
 local seat
 -- Seat indices must be assigned by host. The public mirror is not authoritative.
 local remote=R.HoldemSync and R.HoldemSync.remote
 for i,p in ipairs(remote and remote.players or {}) do if p.name==me() then seat=i;break end end
 if not seat then note('No host-assigned seat; action not sent');return false,'No host-assigned seat' end
 M.sequence=M.sequence+1
 local payload=table.concat({'A',clean(N.session),tostring(M.sequence),tostring(seat),action,tostring(amount or 0)},'|')
 if not SendAddonMessage then return false,'Addon messaging unavailable' end
 SendAddonMessage(PREFIX,payload,'WHISPER',N.host)
 note('SEND '..action..' (pending host validation)')
 return true,'Pending Game Master validation'
end
M.SendAction=sendAction
local function sendPrivate(seat)
 if not N.owner or not N.active then note('Only host can deal private cards');return end
 local p=H.players[seat]
 if not p or not N.members[p.name] or not raidMember(p.name) or not p.hole or #p.hole~=2 then note('No eligible real seat / cards');return end
 local c1,c2=validCard(p.hole[1]),validCard(p.hole[2])
 if not c1 or not c2 then note('Invalid cards');return end
 local msg=table.concat({'C',clean(N.session),tostring(H.handNumber or 0),c1,c2},'|')
 if p.name==me() then M.privateCards={decodeCard(c1),decodeCard(c2)};M.privateHand=H.handNumber
 else SendAddonMessage(PREFIX,msg,'WHISPER',p.name) end
 note('PRIVATE DEAL -> '..clean(p.name)..' (card values hidden)')
end
function M.DealPrivateToJoined()
 if not N.owner or not N.active then note('Host lobby required');return end
 for i,p in ipairs(H.players) do if N.members[p.name] then sendPrivate(i) end end
end
local function simulate()
 M.simulated=true
 local oldOwner,oldActive,oldMembers=N.owner,N.active,N.members
 local oldPlayers,oldSeat,oldPhase=H.players,H.actionSeat,H.phase
 local oldAction=H.Action
 local results={}
 N.owner=true;N.active=true;N.members={['Sim Alice']=true,['Sim Bob']=true}
 H.players={{name='Sim Alice',stack=1000,street=0},{name='Sim Bob',stack=1000,street=0}}
 H.actionSeat=1;H.phase='PREFLOP'
 H.Action=function(action,amount)
  if action=='CALL' then return true end
  return false,'Simulated engine refusal'
 end
 local function test(label,expected,sender,seat,action,amount,seq)
  local got=hostAction(sender,seat,action,amount,seq)
  results[#results+1]=(got==expected and 'PASS ' or 'FAIL ')..label
 end
 test('valid owner action',true,'Sim Alice',1,'CALL',0,'90001')
 test('duplicate sequence',false,'Sim Alice',1,'CALL',0,'90001')
 test('wrong seat',false,'Sim Bob',1,'CALL',0,'90002')
 test('unknown member',false,'Stranger',1,'CALL',0,'90003')
 test('invalid raise',false,'Sim Alice',1,'RAISE',-1,'90004')
 test('engine refusal',false,'Sim Alice',1,'CHECK',0,'90005')
 H.Action=oldAction;H.players=oldPlayers;H.actionSeat=oldSeat;H.phase=oldPhase
 N.owner=oldOwner;N.active=oldActive;N.members=oldMembers
 M.processed={};M.simulated=false
 for _,line in ipairs(results) do note(line) end
end
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('CHAT_MSG_ADDON')
events:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end;return end
 local prefix,msg,channel,sender=...
 if prefix~=PREFIX or channel~='WHISPER' or type(msg)~='string' or #msg>180 or not N.active or not raidMember(sender) then return end
 local kind,session,rest=msg:match('^([AC])|([^|]+)|(.+)$')
 if session~=clean(N.session) then return end
 if kind=='A' and N.owner then
  local seq,seat,action,amount=rest:match('^(%d+)|(%d+)|([A-Z]+)|(%d+)$')
  if seq then hostAction(sender,tonumber(seat),action,amount,seq) else note('REJECT malformed action') end
 elseif kind=='C' and not N.owner and sender==N.host then
  local hand,c1,c2=rest:match('^(%d+)|([^|]+)|([^|]+)$')
  local a,b=decodeCard(c1),decodeCard(c2)
  if a and b and tonumber(hand) then
   local current=R.HoldemSync and R.HoldemSync.remote
   if current and tonumber(hand)<(tonumber(current.handNumber) or 0) then return end
   M.privateCards={a,b};M.privateHand=tonumber(hand);note('RECEIVED private cards for hand '..hand)
  end
 end
end)
local function button(parent,label,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetWidth(w);b:SetHeight(24)
 b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',fn)
 return b
end
local function build()
 if window then return end
 window=CreateFrame('Frame','RaidPokerHoldemProtocolDebug',UIParent)
 window:SetWidth(520);window:SetHeight(430);window:SetPoint('CENTER');window:SetFrameStrata('DIALOG')
 window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag('LeftButton')
 window:SetScript('OnDragStart',function(self)self:StartMoving()end)
 window:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 window:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 local title=window:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',20,-20);title:SetText('BARRENS HOLD\'EM - PROTOCOL DEBUG')
 info=window:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');info:SetPoint('TOPLEFT',20,-52);info:SetWidth(470);info:SetJustifyH('LEFT')
 output=window:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');output:SetPoint('TOPLEFT',20,-152);output:SetWidth(480);output:SetJustifyH('LEFT')
 button(window,'Run Local Tests',20,-90,140,simulate)
 button(window,'Deal Private',168,-90,120,function()M.DealPrivateToJoined()end)
 button(window,'Fold',20,-120,72,function()sendAction('FOLD',0)end)
 button(window,'Check',96,-120,72,function()sendAction('CHECK',0)end)
 button(window,'Call',172,-120,72,function()sendAction('CALL',0)end)
 button(window,'All-In',248,-120,72,function()sendAction('ALLIN',0)end)
 button(window,'Raise +10s',324,-120,112,function()sendAction('RAISE',10)end)
 button(window,'X',468,-18,28,function()window:Hide()end)
 window:Hide()
end
function R.OpenHoldemProtocolDebug()
 build()
 info:SetText('Local protocol tests do not require a raid. Real action transport requires a host-assigned seat.\nPrivate cards are sent by WHISPER only; not displayed in this log.')
 output:SetText(table.concat(M.log,'\n'));window:Show();window:Raise()
end
local previous=SlashCmdList.RAIDFIVEPOKER
if previous then SlashCmdList.RAIDFIVEPOKER=function(input)
 local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
 if cmd=='holdemprotocol' or cmd=='holdemtest' then R.OpenHoldemProtocolDebug() else previous(input) end
end end
