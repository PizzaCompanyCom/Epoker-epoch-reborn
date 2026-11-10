-- The Barrens Hold'em beta4c2b: restored network lobby module.
-- WoW 3.3.5a / Lua 5.1. Lobby only; no automatic multiplayer dealing.
local R=RPoker
if not R then return end
local N={active=false,owner=false,host=nil,session=nil,members={},discovered={},discoveredInfo={}}
R.HoldemNetwork=N
local PREFIX='RPBH4A'
local function localVersion() return R.PokerLocalVersion and R.PokerLocalVersion() or 'Unknown' end
local function protocol() return tostring(R.PokerNetworkProtocol or '20') end
local window,status,listing
local tableButtons={}
local function me() return UnitName('player') or '' end
local function raid()
 return GetNumRaidMembers and GetNumRaidMembers()>0
end
local function isRaidMember(name)
 if not raid() then return false end
 for i=1,GetNumRaidMembers() do
  local n=GetRaidRosterInfo(i)
  if n==name then return true end
 end
 return false
end
local function safe(s) return tostring(s or ''):gsub('[|,;\r\n]',''):sub(1,30) end
local function announce(msg)
 if raid() and SendAddonMessage then SendAddonMessage(PREFIX,msg,'RAID') end
end
local function tableInfo()
 local M=R.HoldemMultiplayer
 local count=M and #M.seats or 0
 local phase=(R.Holdem and R.Holdem.phase) or 'LOBBY'
 return 'T|'..safe(N.session)..'|'..safe(me())..'|'..tostring(count)..'|'..safe(phase)
end
function N.BroadcastTableInfo() if N.owner and N.active then announce(tableInfo()) end end
local function refresh()
 if not window then return end
 status:SetText('Status: '..(N.active and (N.owner and 'GAME MASTER' or 'JOINED') or 'OFFLINE')..'  Host: '..(N.host or '-'))
 local lines={}
 if N.active then
  lines[#lines+1]='Session: '..(N.session or '-')
  for name in pairs(N.members) do lines[#lines+1]='Member: '..safe(name) end
 else
  for name,id in pairs(N.discovered) do
   local info=N.discoveredInfo[name] or {}
   local status=(info.phase=='LOBBY' and (info.count or 0)<10) and 'OPEN' or (info.count or 0)>=10 and 'FULL' or 'IN GAME'
   lines[#lines+1]='|cff32ff76[ '..status..' TABLE ]|r  '..safe(name)..'  |  GM: '..safe(name)..'  |  '..tostring(info.count or '?')..'/10'
  end
 end
 if not N.active then
  listing:SetText('Select a highlighted table below to join. Refresh to discover tables.')
 else listing:SetText(#lines>0 and table.concat(lines,'\n') or 'No players connected.') end
 local names={}
 for name in pairs(N.discovered) do names[#names+1]=name end
 table.sort(names)
 for i,b in ipairs(tableButtons) do
  local name=not N.active and names[i] or nil
  if name then
   local info=N.discoveredInfo[name] or {}
   local status=(info.phase=='LOBBY' and (info.count or 0)<10) and 'OPEN' or (info.count or 0)>=10 and 'FULL' or 'IN GAME'
   b.host=name
   b:SetText('[ '..status..' ]   '..safe(name)..'   |   '..tostring(info.count or '?')..'/10 seats')
   b:Show()
   if status=='OPEN' then b:Enable() else b:Disable() end
  else b:Hide();b.host=nil end
 end
end
local function leave()
 if N.active then announce('L|'..safe(N.session)..'|'..safe(me())) end
 N.active=false;N.owner=false;N.host=nil;N.session=nil;N.members={}
 if R.HoldemMultiplayer then R.HoldemMultiplayer.active=false;R.HoldemMultiplayer.seats={} end
 if R.HoldemProtocol then R.HoldemProtocol.privateCards={};R.HoldemProtocol.privateHand=nil end
 if R.HoldemUnified then R.HoldemUnified.mode='SOLO' end
 if R.BarrensCloseSoloGame then R.BarrensCloseSoloGame() end
 refresh()
end
function R.BarrensNetworkLeave() leave() end
local function create()
 if not raid() then R.Print('Barrens Network: Join a raid first.');return end
 if N.active then R.Print('Already connected to a table.');return end
 for name in pairs(N.discovered) do if isRaidMember(name) then R.Print('An active Holdem table exists. Use Join Table.');return end end
 leave()
 N.active=true;N.owner=true;N.host=me();N.session=safe(me())..tostring(math.floor(GetTime()*1000)%10000000)
 N.members={[me()]=true}
 if R.HoldemUnified then R.HoldemUnified.SetMode('NETWORK') end
 if R.HoldemSync then R.HoldemSync.remote=nil;R.HoldemSync.pending=nil;R.HoldemSync.received=0 end
 announce('O|'..N.session..'|'..safe(me())..'|'..localVersion()..'|'..protocol())
 announce(tableInfo())
 -- Creating the table also reserves the creator's seat.
 if R.HoldemMultiplayer and R.HoldemMultiplayer.Assign then
  local ok,why=R.HoldemMultiplayer.Assign(me())
  if not ok and R.Print then R.Print('Barrens: Could not seat Game Master: '..tostring(why)) end
  if ok and R.HoldemMultiplayer.initialStack<=0 and R.Print then
   R.Print('Insufficient Balance: You are seated with 0s. Set a positive balance in Player Management before playing.')
  end
 end
 refresh()
end
function N.Discover()
 if not raid() then return end
 announce('D|'..safe(me()))
end
local function discover()
 if not raid() then R.Print('Barrens Network: Join a raid first.');return end
 N.discovered={};N.discoveredInfo={}
 announce('D|'..safe(me()))
 refresh()
end
local function join()
 if N.active then return end
 local host,session
 if N.selectedHost and N.discovered[N.selectedHost] then host=N.selectedHost;session=N.discovered[host] end
 if not host then for name,id in pairs(N.discovered) do host=name;session=id;break end end
 if not host or not isRaidMember(host) then R.Print('Barrens Network: No table found. Press Refresh.');return end
 local info=N.discoveredInfo[host] or {}
 if info.version~=localVersion() or info.protocol~=protocol() then
  if R.PokerShowVersionWarning then R.PokerShowVersionWarning(host,info.version or 'Unknown') end
  return
 end
 N.active=true;N.owner=false;N.host=host;N.session=session;N.members={[host]=true,[me()]=true}
 if R.HoldemUnified then R.HoldemUnified.SetMode('NETWORK') end
 if R.HoldemSync then R.HoldemSync.remote=nil;R.HoldemSync.pending=nil;R.HoldemSync.received=0 end
 announce('J|'..session..'|'..safe(me())..'|'..localVersion()..'|'..protocol())
 if R.HoldemSync and R.HoldemSync.Request then R.HoldemSync.Request() end
 refresh()
end
function N.CreateSingle() create() end
function N.JoinSingle()
 if N.active then
  if N.owner and R.HoldemMultiplayer and R.HoldemMultiplayer.Assign then
   R.HoldemMultiplayer.Assign(me())
  elseif not N.owner and N.session then
   announce('J|'..safe(N.session)..'|'..safe(me())..'|'..localVersion()..'|'..protocol())
  end
  if R.HoldemUnified then R.HoldemUnified.SetMode('NETWORK') end
  if R.OpenBarrensTable then R.OpenBarrensTable() end
  return true
 end
 local count=0
 for name in pairs(N.discovered) do if isRaidMember(name) then count=count+1 end end
 if count==0 then
  N.pendingJoinAt=nil
  N.Discover()
  R.HF19LastMode='HOLDEM'
  if StaticPopup_Show then StaticPopup_Show('EPOKER_NO_ACTIVE_TABLE') end
  return false,'No active table'
 end
 if count>1 then return false,'Multiple legacy tables detected. Select one in the Network Lobby.' end
 join()
 if N.active and R.OpenBarrensTable then R.OpenBarrensTable() end
 return N.active
end
local function button(text,x,y,w,fn)
 local b=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
 b:SetWidth(w);b:SetHeight(24);b:SetPoint('TOPLEFT',window,'TOPLEFT',x,y)
 b:SetText(text);b:SetScript('OnClick',fn)
 return b
end
local function build()
 if window then return end
 window=CreateFrame('Frame','RaidPokerBarrensNetworkLobby',UIParent)
 window:SetWidth(480);window:SetHeight(420);window:SetPoint('CENTER')
 window:SetFrameStrata('DIALOG');window:SetMovable(true);window:EnableMouse(true)
 window:RegisterForDrag('LeftButton');window:SetClampedToScreen(true)
 window:SetScript('OnDragStart',function(self) self:StartMoving() end)
 window:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
 window:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 local title=window:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 title:SetPoint('TOPLEFT',20,-20);title:SetText("THE BARRENS HOLD'EM - NETWORK LOBBY")
 status=window:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 status:SetPoint('TOPLEFT',20,-62);status:SetWidth(440);status:SetJustifyH('LEFT')
 listing=window:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 listing:SetPoint('TOPLEFT',20,-130);listing:SetWidth(440);listing:SetJustifyH('LEFT')
 button('Create Table',20,-90,104,create)
 button('Refresh',132,-90,90,discover)
 button('Join First Found Table',230,-90,162,join)
 button('Leave',400,-90,62,leave)
 for i=1,4 do
  local b=button('',20,-166-(i-1)*39,440,function(self)
   N.selectedHost=self.host
   join()
  end)
  local tex=b:GetNormalTexture();if tex then tex:SetVertexColor(.30,.95,.40,1) end
  tableButtons[i]=b
 end
 button('X',434,-14,26,function()window:Hide()end)
 window:Hide()
end
function R.OpenBarrensNetworkLobby() build();refresh();window:Show();window:Raise() end
local old=SlashCmdList and SlashCmdList.RAIDFIVEPOKER
if old then
 SlashCmdList.RAIDFIVEPOKER=function(input)
  local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
  if cmd=='holdemnet' or cmd=='barrensnet' then R.OpenBarrensNetworkLobby()
  else old(input) end
 end
end
local ev=CreateFrame('Frame')
ev:RegisterEvent('PLAYER_LOGIN');ev:RegisterEvent('CHAT_MSG_ADDON');ev:RegisterEvent('RAID_ROSTER_UPDATE')
ev:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
  return
 end
 if event=='RAID_ROSTER_UPDATE' then
  if N.active and (not raid() or (not N.owner and not isRaidMember(N.host))) then leave() end
  if raid() then N.Discover() end
  return
 end
 local prefix,msg,channel,sender=...
 if prefix~=PREFIX or channel~='RAID' or type(msg)~='string' or #msg>160 then return end
 if not isRaidMember(sender) or sender==me() then return end
 local kind,session,who,remoteVersion,remoteProtocol=msg:match('^([A-Z])|([^|]+)|([^|]+)|([%w%._%-]+)|(%d+)$')
 if not kind then kind,session,who=msg:match('^([A-Z])|([^|]+)|([^|]+)$') end
 if not kind then kind,session,who,remoteVersion=msg:match('^([A-Z])|([^|]+)|([^|]+)|([A-Z]+)$') end
 if not kind then
  if msg:match('^T|') and not N.active then
   local id,owner,count,phase=msg:match('^T|([^|]+)|([^|]+)|(%d+)|([A-Z]+)$')
   if owner==sender and N.discovered[sender]==id then
    local previous=N.discoveredInfo[sender] or {}
    N.discoveredInfo[sender]={count=tonumber(count),phase=phase,version=previous.version,protocol=previous.protocol}
   end
  end
  if msg:match('^D|') and N.active and N.owner then announce('O|'..safe(N.session)..'|'..safe(me())..'|'..localVersion()..'|'..protocol());announce(tableInfo()) end
  return
 end
 if kind=='D' then
  if N.active and N.owner then announce('O|'..safe(N.session)..'|'..safe(me())..'|'..localVersion()..'|'..protocol());announce(tableInfo()) end
 elseif kind=='O' and who==sender and not N.active then
  N.discovered[sender]=session
  N.discoveredInfo[sender]=N.discoveredInfo[sender] or {}
  N.discoveredInfo[sender].version=remoteVersion or 'Unknown'
  N.discoveredInfo[sender].protocol=remoteProtocol or 'legacy'
  if N.pendingJoinAt and not N.active then N.pendingJoinAt=nil;N.selectedHost=sender;join() end
 elseif kind=='J' and who==sender and N.active and N.owner and session==N.session then
  if remoteVersion~=localVersion() or remoteProtocol~=protocol() then
   announce('X|'..safe(N.session)..'|'..safe(sender)..'|'..localVersion()..'|'..protocol())
   R.Print('Rejected incompatible player: '..sender)
   return
  end
  if R.PokerRecordPeerVersion then R.PokerRecordPeerVersion(sender,remoteVersion,remoteProtocol) end
  N.members[sender]=true
  -- The Game Master seats a newly admitted, compatible player automatically.
  -- An existing seat is reused; no duplicate seat is created.
  if R.HoldemMultiplayer and R.HoldemMultiplayer.Assign then
   local ok,why=R.HoldemMultiplayer.Assign(sender)
   if ok then
    for _,seat in ipairs(R.HoldemMultiplayer.seats) do
     if seat.name==sender and (seat.stack or 0)<=0 then
      announce('E|'..safe(N.session)..'|'..safe(sender)..'|ZERO')
      break
     end
    end
   end
   if not ok then
    if R.Print then R.Print('Barrens: '..sender..' joined lobby but could not be seated: '..tostring(why)) end
    announce('E|'..safe(N.session)..'|'..safe(sender)..'|'..(why=='Table full (10 seats)' and 'FULL' or 'WAIT'))
   end
  end
  if R.HoldemSync and R.HoldemSync.ForceBroadcast then R.HoldemSync.ForceBroadcast() end
  -- Send existing lobby membership to the newcomer as well.
  for member in pairs(N.members) do announce('M|'..safe(N.session)..'|'..safe(member)) end
  announce('M|'..safe(N.session)..'|'..safe(sender))
 elseif kind=='E' and N.active and not N.owner and sender==N.host and who==me() and session==N.session then
  local code=remoteVersion or msg:match('^E|[^|]+|[^|]+|([A-Z]+)$')
  if code=='ZERO' then R.Print('Insufficient Balance: You are seated with 0s and cannot play until the Game Master adds funds.')
  elseif code=='FULL' then R.Print('Table is full. You are connected but not seated.')
  else R.Print('Connected, but automatic seating is not available yet. Contact the Game Master.') end
 elseif kind=='X' and N.active and not N.owner and sender==N.host and who==me() and session==N.session then
  if R.PokerShowVersionWarning then R.PokerShowVersionWarning(sender,remoteVersion or 'Unknown') end
  leave()
 elseif kind=='M' and N.active and not N.owner and sender==N.host and session==N.session then
  N.members[who]=true
 elseif kind=='L' and N.active and session==N.session and who==sender then
  if sender==N.host then leave() else
   N.members[sender]=nil
   if N.owner and R.HoldemMultiplayer and R.HoldemMultiplayer.Remove then R.HoldemMultiplayer.Remove(sender) end
  end
 end
 refresh()
end)

-- Wait briefly for the raid discovery response before showing the no-table dialog.
local pendingTicker=CreateFrame('Frame')
local pendingElapsed=0
pendingTicker:SetScript('OnUpdate',function(self,dt)
 pendingElapsed=pendingElapsed+dt
 if pendingElapsed<.25 then return end
 pendingElapsed=0
 if N.pendingJoinAt and GetTime()>=N.pendingJoinAt then
  N.pendingJoinAt=nil
  if not N.active then
   R.HF19LastMode='HOLDEM'
   if StaticPopup_Show then StaticPopup_Show('EPOKER_NO_ACTIVE_TABLE') end
  end
 end
end)
