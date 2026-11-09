-- beta4e8: Network hand preflight and unified table operations.
-- Lua 5.1 / WoW 3.3.5a. Never exposes hidden cards or changes Draw mode.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local P={};R.HoldemPreflight=P
local frame,summary,rows,buttons,detail
local function mode() return R.BarrensUnifiedMode and R.BarrensUnifiedMode() or 'SOLO' end
local function me() return UnitName('player') or '' end
local function net() return R.HoldemNetwork end
local function multi() return R.HoldemMultiplayer end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function owner()
 local n=net();return n and n.active and n.owner and n.host==me()
end
local function state()
 local m=multi();local n=net();local count=0;local seated=0;local active=0
 local seats={}
 for i=1,10 do
  local p=m and m.seats and m.seats[i]
  if p and p.name then
   seated=seated+1
   local stack=math.max(0,math.floor(tonumber(p.stack) or 0))
   local member=n and n.members and n.members[p.name]
   local inRaid=false
   if GetNumRaidMembers then for j=1,GetNumRaidMembers() do if GetRaidRosterInfo(j)==p.name then inRaid=true;break end end end
   local playing=not p.sittingOut and stack>0 and member and inRaid
   if playing then active=active+1 end
   seats[i]={name=p.name,stack=stack,playing=playing,folded=p.folded and true or false}
  end
 end
 local problems={}
 if mode()~='NETWORK' then problems[#problems+1]='Switch to Network Mode' end
 if not n or not n.active then problems[#problems+1]='Create or join a Network Lobby' end
 if not owner() then problems[#problems+1]='Only the current Game Master may start a network hand' end
 if not idle() then problems[#problems+1]='Wait until the current hand ends' end
 if active<2 then problems[#problems+1]='At least two funded, seated players must be Playing' end
 return seats,seated,active,problems
end
local function label(parent,text,x,y,width,font)
 local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(text or '')
 return t
end
local function button(parent,text,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,24);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',fn)
 return b
end
function P.Refresh()
 if not frame then return end
 local seats,seated,active,problems=state()
 local n=net()
 summary:SetText('MODE: '..mode()..'    |    PHASE: '..tostring(H.phase or 'LOBBY')..'    |    HOST: '..tostring(n and n.host or '-')..'\nSEATED: '..seated..'/10    |    READY TO PLAY: '..active..'    |    GAME MASTER: '..(owner() and 'YOU' or 'OTHER / NONE'))
 for i=1,10 do
  local p=seats[i]
  if not p then rows[i]:SetText(string.format('%02d   [EMPTY]',i));rows[i]:SetTextColor(.60,.60,.60)
  else
   local g=math.floor(p.stack/100);local s=p.stack%100
   local status=p.playing and 'PLAYING' or (p.stack==0 and 'BUSTED / NO CHIPS' or 'SITTING OUT')
   rows[i]:SetText(string.format('%02d   %-22s   %dg %ds   %s',i,p.name,g,s,status))
   if p.playing then rows[i]:SetTextColor(.45,1,.50) else rows[i]:SetTextColor(1,.72,.35) end
  end
 end
 if #problems==0 then
  detail:SetText('|cff66ff66READY: Network hand can be started by the Game Master.|r')
 else detail:SetText('|cffffaa55NOT READY:|r '..table.concat(problems,'; ')) end
 if #problems==0 then buttons.start:Enable() else buttons.start:Disable() end
end
function P.Start()
 local _,_,_,problems=state()
 if #problems>0 then P.Refresh();return false,table.concat(problems,'; ') end
 local m=multi()
 if not m or type(m.StartHand)~='function' then return false,'Multiplayer StartHand unavailable' end
 local ok,err=m.StartHand()
 P.Refresh()
 if ok==false and R.Print then R.Print('Holdem Preflight: '..tostring(err or 'Start refused')) end
 return ok,err
end
local function build()
 if frame then return end
 frame=CreateFrame('Frame','RaidPokerBarrensPreflight',UIParent)
 frame:SetSize(600,630);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG');frame:SetFrameLevel(250)
 frame:SetMovable(true);frame:EnableMouse(true);frame:SetClampedToScreen(true)
 frame:RegisterForDrag('LeftButton');frame:SetScript('OnDragStart',function(self)self:StartMoving()end)
 frame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 frame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 label(frame,"THE BARRENS HOLD'EM - HAND PREFLIGHT",20,-19,520,'GameFontNormalLarge')
 button(frame,'X',550,-12,30,function()frame:Hide()end)
 summary=label(frame,'',20,-58,555,'GameFontHighlight')
 label(frame,'NETWORK SEATS / FUNDED PLAYER STATUS',20,-117,545,'GameFontNormal')
 rows={}
 for i=1,10 do rows[i]=label(frame,'',27,-145-(i-1)*30,540,'GameFontHighlight') end
 detail=label(frame,'',20,-467,555,'GameFontHighlightSmall');detail:SetHeight(60)
 buttons={}
 buttons.start=button(frame,'Start Network Hand',20,-541,165,P.Start)
 button(frame,'Player Management',197,-541,175,function()if R.OpenBarrensManagement then R.OpenBarrensManagement()end end)
 button(frame,'Network Lobby',382,-541,195,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button(frame,'Sync Seats',20,-574,165,function()
  if owner() and idle() and R.HoldemAdminBridge and R.HoldemAdminBridge.BroadcastSeats then
   local ok,err=R.HoldemAdminBridge.BroadcastSeats()
   if ok==false and R.Print then R.Print('Seat Sync: '..tostring(err)) end
  end
  P.Refresh()
 end)
 button(frame,'Poker Table',197,-574,175,function()if R.OpenBarrensTable then R.OpenBarrensTable()end end)
 button(frame,'Refresh',382,-574,195,P.Refresh)
 frame:SetScript('OnShow',P.Refresh)
 frame:Hide()
end
function R.OpenBarrensPreflight()build();P.Refresh();frame:Show();frame:Raise()end
SLASH_BARRPREFLIGHT1='/holdempreflight'
SlashCmdList.BARRPREFLIGHT=function()R.OpenBarrensPreflight()end
local watcher=CreateFrame('Frame');local elapsed=0
watcher:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt;if elapsed<2 then return end;elapsed=0
 if frame and frame:IsShown() then P.Refresh() end
end)
