-- The Barrens Hold'em beta4c2b: restored network lobby module.
-- WoW 3.3.5a / Lua 5.1. Lobby only; no automatic multiplayer dealing.
local R=RPoker
if not R then return end
local N={active=false,owner=false,host=nil,session=nil,members={},discovered={}}
R.HoldemNetwork=N
local PREFIX='RPBH4A'
local window,status,listing
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
local function refresh()
 if not window then return end
 status:SetText('Status: '..(N.active and (N.owner and 'GAME MASTER' or 'JOINED') or 'OFFLINE')..'  Host: '..(N.host or '-'))
 local lines={}
 if N.active then
  lines[#lines+1]='Session: '..(N.session or '-')
  for name in pairs(N.members) do lines[#lines+1]='Member: '..safe(name) end
 else
  for name in pairs(N.discovered) do lines[#lines+1]='Available table: '..safe(name) end
 end
 listing:SetText(#lines>0 and table.concat(lines,'\n') or 'No discovered tables. Use Refresh while in a raid.')
end
local function leave()
 if N.active then announce('L|'..safe(N.session)..'|'..safe(me())) end
 N.active=false;N.owner=false;N.host=nil;N.session=nil;N.members={}
 refresh()
end
function R.BarrensNetworkLeave() leave() end
local function create()
 if not raid() then R.Print('Barrens Network: Join a raid first.');return end
 leave()
 N.active=true;N.owner=true;N.host=me();N.session=safe(me())..tostring(math.floor(GetTime()*1000)%10000000)
 N.members={[me()]=true}
 announce('O|'..N.session..'|'..safe(me()))
 refresh()
end
local function discover()
 if not raid() then R.Print('Barrens Network: Join a raid first.');return end
 N.discovered={}
 announce('D|'..safe(me()))
 refresh()
end
local function join()
 if N.active then return end
 local host,session
 for name,id in pairs(N.discovered) do host=name;session=id;break end
 if not host or not isRaidMember(host) then R.Print('Barrens Network: No table found. Press Refresh.');return end
 N.active=true;N.owner=false;N.host=host;N.session=session;N.members={[host]=true,[me()]=true}
 announce('J|'..session..'|'..safe(me()))
 refresh()
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
 window:SetWidth(480);window:SetHeight(360);window:SetPoint('CENTER')
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
  return
 end
 local prefix,msg,channel,sender=...
 if prefix~=PREFIX or channel~='RAID' or type(msg)~='string' or #msg>160 then return end
 if not isRaidMember(sender) or sender==me() then return end
 local kind,session,who=msg:match('^([A-Z])|([^|]+)|([^|]+)$')
 if not kind then
  if msg:match('^D|') and N.active and N.owner then announce('O|'..safe(N.session)..'|'..safe(me())) end
  return
 end
 if kind=='D' then
  if N.active and N.owner then announce('O|'..safe(N.session)..'|'..safe(me())) end
 elseif kind=='O' and who==sender and not N.active then
  N.discovered[sender]=session
 elseif kind=='J' and who==sender and N.active and N.owner and session==N.session then
  N.members[sender]=true
  announce('M|'..safe(N.session)..'|'..safe(sender))
 elseif kind=='M' and N.active and not N.owner and sender==N.host and session==N.session then
  N.members[who]=true
 elseif kind=='L' and N.active and session==N.session and who==sender then
  if sender==N.host then leave() else N.members[sender]=nil end
 end
 refresh()
end)
