-- The Barrens Hold'em beta4e6: guarded session reconnect and admin audit relay.
-- WoW 3.3.5a Lua 5.1. Does not touch 5-Card Draw or resume hidden cards.
local R=RPoker
if not R or not R.Holdem or not R.HoldemNetwork or not R.HoldemMultiplayer then return end
local H,N,M=R.Holdem,R.HoldemNetwork,R.HoldemMultiplayer
local S={};R.HoldemSessionRecovery=S
local PREFIX='RPBHR6'
local frame,status,logText
local pending=nil
local function me() return UnitName('player') or '' end
local function raidMember(name)
 if not name or not GetNumRaidMembers or GetNumRaidMembers()<1 then return false end
 for i=1,GetNumRaidMembers() do if GetRaidRosterInfo(i)==name then return true end end
 return false
end
local function safe(v) return type(v)=='string' and #v>0 and #v<=50 and not v:find('[|\r\n]') end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function host() return N.active and N.owner and N.host==me() and raidMember(me()) end
local function send(msg,channel,target)
 if not SendAddonMessage or #msg>230 then return false end
 if channel=='WHISPER' then SendAddonMessage(PREFIX,msg,'WHISPER',target)
 elseif GetNumRaidMembers and GetNumRaidMembers()>0 then SendAddonMessage(PREFIX,msg,'RAID')
 else return false end
 return true
end
local function db()
 if type(RaidPokerHoldemRecoveryDB)~='table' then RaidPokerHoldemRecoveryDB={} end
 return RaidPokerHoldemRecoveryDB
end
local function report(s)
 if R.Print then R.Print('Barrens Recovery: '..s) end
end
local function update()
 if not frame then return end
 local d=db()
 status:SetText('Current: '..tostring(N.session or 'offline')..' | Host: '..tostring(N.host or '-')..' | '..(idle() and 'IDLE' or 'HAND IN PROGRESS'))
 logText:SetText('Saved: '..tostring(d.session or 'none')..' | '..tostring(d.host or '-')..'\n'..(S.message or 'No reconnect pending.')..'\n\nOnly the live host can confirm a reconnect.\nActive hands are never resumed from a local snapshot.')
end
function S.Remember()
 if N.active and safe(N.session) and safe(N.host) then
  local d=db();d.session=N.session;d.host=N.host;d.member=me()
  d.wasHost=N.owner and true or false
  d.savedAt=date('%Y-%m-%d %H:%M')
 end
 update()
end
function S.Request()
 if N.active then S.message='Already connected. Use Sync Seats between hands.';update();return false end
 local d=db()
 if not safe(d.session) or not safe(d.host) or not raidMember(d.host) or d.host==me() then
  S.message='Saved host is unavailable. Use Network Lobby to create or join a table.';update();return false
 end
 pending={session=d.session,host=d.host}
 send('Q|'..d.session..'|'..me(),'WHISPER',d.host)
 S.message='Reconnect requested from '..d.host..'. Waiting for host confirmation.'
 update();return true
end
function S.Clear()
 RaidPokerHoldemRecoveryDB={}
 pending=nil;S.message='Saved reconnect hint cleared.';update()
end
function S.Sync()
 if not host() or not idle() or M.active then
  S.message='Only the idle Game Master can sync seats.';update();return false
 end
 if R.HoldemAdminBridge and R.HoldemAdminBridge.BroadcastSeats then
  local ok,err=R.HoldemAdminBridge.BroadcastSeats()
  S.message=ok and 'Seat snapshot broadcast.' or tostring(err);update();return ok
 end
 S.message='Admin bridge unavailable.';update();return false
end
local function label(parent,text,x,y,w)
 local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetText(text);return t
end
local function button(parent,text,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,25);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',fn);return b
end
local function build()
 if frame then return end
 frame=CreateFrame('Frame','RaidPokerBarrensSessionRecovery',UIParent)
 frame:SetSize(560,290);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG')
 frame:SetFrameLevel(450);frame:SetToplevel(true);frame:SetMovable(true);frame:EnableMouse(true)
 frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true)
 frame:SetScript('OnDragStart',function(self)self:StartMoving()end)
 frame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 frame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 label(frame,"THE BARRENS HOLD'EM - SESSION RECOVERY",20,-20,470)
 local close=button(frame,'X',510,-12,30,function()frame:Hide()end)
 close:SetFrameLevel(frame:GetFrameLevel()+15)
 if UISpecialFrames then table.insert(UISpecialFrames,'RaidPokerBarrensSessionRecovery') end
 status=label(frame,'',20,-55,515)
 logText=label(frame,'',20,-92,515)
 button(frame,'Request Reconnect',20,-220,145,S.Request)
 button(frame,'Network Lobby',185,-220,145,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button(frame,'Clear Saved',365,-220,145,S.Clear)
 frame:Hide()
end
function R.OpenBarrensSessionRecovery() build();update();frame:Show();frame:Raise()end
SLASH_BARRSESSIONREC1='/holdemrecover'
SlashCmdList.BARRSESSIONREC=function()build();if frame:IsShown() then frame:Hide() else R.OpenBarrensSessionRecovery() end end
local ev=CreateFrame('Frame')
ev:RegisterEvent('PLAYER_LOGIN');ev:RegisterEvent('PLAYER_LOGOUT');ev:RegisterEvent('CHAT_MSG_ADDON')
ev:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
  update();return
 elseif event=='PLAYER_LOGOUT' then S.Remember();return end
 local prefix,msg,channel,sender=...
 if prefix~=PREFIX or type(msg)~='string' or #msg>230 or not raidMember(sender) then return end
 local kind,session,who=msg:match('^([QAY])|([^|]+)|([^|]+)$')
 if not kind or not safe(session) or not safe(who) then return end
 if kind=='Q' then
  if not host() or session~=N.session or sender~=who or not N.members[sender] then return end
  if not idle() or M.active then send('Y|'..session..'|BUSY','WHISPER',sender);return end
  send('A|'..session..'|'..me(),'WHISPER',sender)
  if R.HoldemAdminBridge and R.HoldemAdminBridge.BroadcastSeats then R.HoldemAdminBridge.BroadcastSeats() end
 elseif kind=='Y' then
  if pending and pending.host==sender and pending.session==session then
   S.message='Host is in an active hand. Reconnect after showdown.';pending=nil;update()
  end
 elseif kind=='A' then
  if not pending or sender~=pending.host or session~=pending.session or who~=sender or channel~='WHISPER' then return end
  if N.active then pending=nil;return end
  N.active=true;N.owner=false;N.host=sender;N.session=session
  N.members={[sender]=true,[me()]=true}
  pending=nil
  S.message='Host confirmed reconnect. Requesting seat sync.'
  -- Reannounce membership through the original lobby protocol.
  if SendAddonMessage then SendAddonMessage('RPBH4A','J|'..session..'|'..me(),'RAID') end
  S.Remember();update();report('Reconnected to '..sender..'. Active hand not resumed.')
 end
end)
-- Refresh saved hint during normal session activity without modifying network internals.
local ticker=CreateFrame('Frame');local elapsed=0
ticker:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt;if elapsed<10 then return end;elapsed=0
 if N.active then S.Remember() end
end)
