-- Barrens Hold'em beta4e5: authoritative GM transfer and seat state bridge.
-- WoW 3.3.5a / Lua 5.1. Never touches 5-Card Draw.
local R=RPoker
if not R or not R.Holdem or not R.HoldemNetwork or not R.HoldemMultiplayer then return end
local H,N,M=R.Holdem,R.HoldemNetwork,R.HoldemMultiplayer
local A={};R.HoldemAdminBridge=A
local PREFIX='RPBHGM5'
local panel,header,memberButtons,chosen,rows,logLabel
local selected=nil
local incoming=nil
local snapshotSerial=0
local pendingTransfer=nil
local lastCompleteSnapshot=nil
local function me() return UnitName('player') or '' end
local function raidMember(name)
 if not name or not GetNumRaidMembers then return false end
 for i=1,GetNumRaidMembers() do if GetRaidRosterInfo(i)==name then return true end end
 return false
end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function isGM() return N.active and N.owner and N.host==me() and raidMember(me()) end
local function safeName(name) return type(name)=='string' and name:match('^[%a][%a%-]*$') and #name<=24 end
local function send(s)
 if not SendAddonMessage or not GetNumRaidMembers or GetNumRaidMembers()<1 then return false end
 SendAddonMessage(PREFIX,s,'RAID');return true
end
local function notify(msg) if R.Print then R.Print('Barrens GM: '..msg) end end
local function log(s)
 A.log=A.log or {};A.log[#A.log+1]=date('%H:%M:%S')..' '..s
 if #A.log>30 then table.remove(A.log,1) end
end
local function refresh()
 if not panel then return end
 header:SetText('Host: '..tostring(N.host or '-')..'  |  '..(isGM() and 'YOU ARE GAME MASTER' or 'READ ONLY')..'  |  '..tostring(H.phase))
 local list={}
 for name in pairs(N.members or {}) do if raidMember(name) then list[#list+1]=name end end
 table.sort(list)
 for i=1,6 do
  local b=memberButtons[i];local name=list[i]
  b:SetText(name and ((selected==name and '> ' or '')..name) or '[No member]')
  if name then b:Enable() else b:Disable() end;b.target=name
 end
 chosen:SetText('Selected successor: '..tostring(selected or '-'))
 for i=1,6 do
  local s=M.seats[i]
  rows[i]:SetText(i..'. '..(s and (s.name..' | '..tostring(s.stack or 0)..'s | '..(s.sittingOut and 'SIT OUT' or 'IN')) or '[Empty]'))
 end
 logLabel:SetText(table.concat(A.log or {},'\n'))
end
local function encodeSeat(i,s)
 if not s then return 'S|'..N.session..'|'..i..'|-|0|0' end
 return 'S|'..N.session..'|'..i..'|'..s.name..'|'..math.floor(tonumber(s.stack) or 0)..'|'..(s.sittingOut and '1' or '0')
end
function A.BroadcastSeats()
 if not isGM() or not idle() then return false,'Game Master / idle hand required' end
 if not N.session then return false,'No session' end
 snapshotSerial=snapshotSerial+1
 local serial=tostring(snapshotSerial)
 send('B|'..N.session..'|'..serial)
 for name in pairs(N.members or {}) do if safeName(name) and raidMember(name) then send('J|'..N.session..'|'..name) end end
 for i=1,6 do send(encodeSeat(i,M.seats[i])) end
 send('E|'..N.session..'|'..serial)
 log('SEATS SYNCED');refresh();return true
end
function A.Transfer(target)
 if not isGM() or not idle() or M.active then return false,'Game Master / idle hand required' end
 if not safeName(target) or target==me() or not raidMember(target) or not N.members[target] then return false,'Choose a joined raid member' end
 local ok,err=A.BroadcastSeats();if not ok then return false,err end
 -- Do not surrender host authority until the recipient acknowledges a valid seat snapshot.
 pendingTransfer={target=target,started=GetTime()}
 send('P|'..N.session..'|'..target)
 notify('Transfer requested from '..target..'. Waiting for acknowledgement.')
 refresh();return true
end
local ev=CreateFrame('Frame')
ev:RegisterEvent('PLAYER_LOGIN');ev:RegisterEvent('CHAT_MSG_ADDON')
ev:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end;return end
 local prefix,msg,channel,sender=...
 if prefix~=PREFIX or channel~='RAID' or type(msg)~='string' or #msg>240 then return end
 if not N.active or not N.session or not raidMember(sender) or sender==me() then return end
 -- Acknowledgements come from the successor, not from the current host.
 local ackSession,ackTarget=msg:match('^A|([^|]+)|([^|]+)$')
 if ackSession==N.session and isGM() and pendingTransfer and sender==pendingTransfer.target and ackTarget==me() then
  if not idle() or M.active then pendingTransfer=nil;return end
  local target=pendingTransfer.target
  pendingTransfer=nil
  send('T|'..N.session..'|'..target)
  N.host=target;N.owner=false;incoming=nil
  log('TRANSFERRED GAME MASTER TO '..target)
  notify('Game Master transferred to '..target)
  if R.RefreshBarrensControlCenter then R.RefreshBarrensControlCenter() end
  refresh();return
 end
 if sender~=N.host then return end
 if incoming and incoming.from~=sender then incoming=nil end
 local kind,session,rest=msg:match('^([BSETJP])|([^|]+)|(.+)$')
 if not kind or session~=N.session then return end
 if kind=='B' then
  if not idle() or M.active or not rest:match('^%d+$') then return end
  incoming={serial=rest,from=sender,seats={},seen={},invalid=false,received=0}
 elseif kind=='J' then
  if safeName(rest) and raidMember(rest) then N.members[rest]=true end
 elseif kind=='S' then
  if not idle() or M.active or not incoming or incoming.from~=sender then return end
  local idx,name,stack,out=rest:match('^(%d+)|([^|]+)|(%d+)|([01])$')
  idx=tonumber(idx);stack=tonumber(stack)
  if not idx or idx<1 or idx>6 or incoming.seen[idx] or not stack or stack>100000000 then
   incoming.invalid=true;return
  end
  incoming.seen[idx]=true;incoming.received=incoming.received+1
  if name~='-' then
   if not safeName(name) or not raidMember(name) then incoming.invalid=true;return end
   incoming.seats[idx]={name=name,stack=stack,sittingOut=(out=='1')}
  end
 elseif kind=='P' then
  -- Only the designated successor can accept; snapshot must have been received.
  if rest==me() and idle() and not M.active and lastCompleteSnapshot==sender then
   send('A|'..N.session..'|'..sender)
   notify('Accepting Game Master transfer from '..sender)
  end
 elseif kind=='T' then
  if not idle() or M.active or not safeName(rest) or not raidMember(rest) or not N.members[rest] then return end
  N.host=rest;N.owner=(rest==me())
  incoming=nil
  log('GAME MASTER: '..sender..' -> '..rest)
  notify('New Game Master: '..rest)
  if R.RefreshBarrensControlCenter then R.RefreshBarrensControlCenter() end
 elseif kind=='E' then
  if not incoming or incoming.from~=sender or incoming.serial~=rest or incoming.invalid or incoming.received~=6 then return end
  -- Reject non-contiguous seats; the engine uses ipairs and # on seat arrays.
  local packed={};local gap=false
  for i=1,6 do
   local seat=incoming.seats[i]
   if seat then
    if gap then incoming=nil;return end
    packed[#packed+1]=seat
   else gap=true end
  end
  M.seats=packed;incoming=nil;lastCompleteSnapshot=sender
  log('SEAT SNAPSHOT RECEIVED')
 end
 if R.HoldemManagement and R.HoldemManagement.Refresh then R.HoldemManagement.Refresh() end
 refresh()
end)
local function label(parent,text,x,y,width)
 local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(text);return t
end
local function button(parent,text,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,23);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',fn);return b
end
local function build()
 if panel then return end
 panel=CreateFrame('Frame','RaidPokerBarrensGMTransfer',UIParent)
 panel:SetSize(650,530);panel:SetPoint('CENTER',UIParent,'CENTER',0,0)
 panel:SetFrameStrata('FULLSCREEN_DIALOG');panel:SetMovable(true);panel:EnableMouse(true)
 panel:RegisterForDrag('LeftButton');panel:SetClampedToScreen(true)
 panel:SetScript('OnDragStart',function(self)self:StartMoving()end)
 panel:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 panel:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 label(panel,"THE BARRENS HOLD'EM - GAME MASTER TRANSFER",20,-18,570)
 button(panel,'X',610,-14,26,function()panel:Hide()end)
 header=label(panel,'',20,-52,610)
 label(panel,'JOINED RAID MEMBERS',20,-88,260)
 label(panel,'NETWORK SEATS / VIRTUAL BALANCES',330,-88,300)
 memberButtons={};rows={}
 for i=1,6 do
  memberButtons[i]=button(panel,'',20,-110-(i-1)*28,260,function(self)selected=self.target;refresh()end)
  rows[i]=label(panel,'',330,-114-(i-1)*28,300)
 end
 chosen=label(panel,'',20,-403,600)
 button(panel,'Transfer Game Master',20,-430,188,function()
  local ok,err=A.Transfer(selected)
  if not ok then notify(err) end
 end)
 -- Manual Force Seat Sync removed; automatic synchronization remains enabled.
 button(panel,'Refresh',385,-430,100,refresh)
 label(panel,'Transfer requires an idle hand and a joined raid member. Virtual gold only.',20,-472,600)
 logLabel=label(panel,'',20,-494,610)
 panel:Hide()
end
function R.OpenBarrensGMTransfer() if R.OpenBarrensManagement then R.OpenBarrensManagement() end end
SLASH_BARRGMTRANSFER1='/holdemtransfer'
SlashCmdList.BARRGMTRANSFER=function()R.OpenBarrensGMTransfer()end

-- A lost acknowledgement must never leave the old Game Master in limbo.
local transferWatch=CreateFrame('Frame')
local transferClock=0
transferWatch:SetScript('OnUpdate',function(self,dt)
 transferClock=transferClock+dt
 if transferClock<1 then return end
 transferClock=0
 if pendingTransfer and GetTime()-pendingTransfer.started>12 then
  notify('Transfer timed out. You are still Game Master.')
  pendingTransfer=nil
 end
end)
