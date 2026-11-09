-- The Barrens Hold'em beta4e3 - integrated gameplay and GM controls.
-- Uses existing HoldemMultiplayer, HoldemManagement, HoldemUnified and Network.
-- Never changes 5-Card Draw state. WoW 3.3.5a / Lua 5.1.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local window,modeLabel,hostLabel,seatLabel,detailLabel,amountBox,seatButtons,gmButtons
local selected=1
local function say(ok,err)
 if ok==false and R.Print then R.Print('Barrens Controls: '..tostring(err or 'Action refused')) end
 if R.RefreshBarrensControlCenter then R.RefreshBarrensControlCenter() end
end
local function uiText(parent,x,y,w,text,font)
 local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetText(text or '')
 return t
end
local function btn(parent,text,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,24);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text)
 b:SetScript('OnClick',fn);return b
end
local function network() return R.HoldemNetwork end
local function multi() return R.HoldemMultiplayer end
local function owner()
 local n=network()
 return n and n.active and n.owner and n.host==UnitName('player')
end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function chosen() local m=multi();return m and m.seats and m.seats[selected] end
local function money(v)
 v=math.max(0,math.floor(tonumber(v) or 0));return math.floor(v/100)..'g '..(v%100)..'s'
end
local function invoke(method,...)
 local m=multi();if not m or not m[method] then say(false,'Multiplayer module unavailable');return end
 say(m[method](...))
end
local function refresh()
 if not window then return end
 local n=network();local m=multi();local mode=R.BarrensUnifiedMode and R.BarrensUnifiedMode() or 'SOLO'
 modeLabel:SetText('GAME MODE: '..mode..'    |    PHASE: '..tostring(H.phase or '-')..'    |    HAND: '..tostring(H.handNumber or 0))
 hostLabel:SetText('GAME MASTER: '..tostring(n and n.host or '-')..'    |    '..(owner() and 'YOU ARE HOST' or 'READ ONLY / SOLO'))
 local s=chosen()
 detailLabel:SetText(s and ('SELECTED: '..s.name..'    |    '..money(s.stack)..'    |    '..(s.sittingOut and 'SITTING OUT' or 'PLAYING')) or 'SELECTED: Empty seat')
 for i,b in ipairs(seatButtons) do
  local v=m and m.seats and m.seats[i]
  b:SetText((i==selected and '> ' or '')..i..'. '..(v and (v.name..'  '..money(v.stack)) or '[Empty]'))
 end
 local can=owner() and idle() and mode=='NETWORK'
 for _,b in ipairs(gmButtons) do if can then b:Enable() else b:Disable() end end
end
function R.RefreshBarrensControlCenter() refresh() end
local function build()
 if window then return end
 window=CreateFrame('Frame','RaidPokerBarrensControlCenter',UIParent)
 window:SetSize(665,670);window:SetPoint('CENTER',UIParent,'CENTER',0,0)
 window:SetFrameStrata('DIALOG');window:SetMovable(true);window:EnableMouse(true)
 window:RegisterForDrag('LeftButton');window:SetClampedToScreen(true)
 window:SetScript('OnDragStart',function(self)self:StartMoving()end)
 window:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 window:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 uiText(window,20,-18,560,"THE BARRENS HOLD'EM - GAME MASTER & TABLE CONTROLS",'GameFontNormalLarge')
 btn(window,'X',625,-13,26,function()window:Hide()end)
 modeLabel=uiText(window,20,-52,610,'')
 hostLabel=uiText(window,20,-73,610,'')
 btn(window,'Solo Mode',20,-103,102,function()if R.HoldemUnified then say(R.HoldemUnified.SetMode('SOLO'))end end)
 btn(window,'Network Mode',129,-103,113,function()if R.HoldemUnified then say(R.HoldemUnified.SetMode('NETWORK'))end end)
 btn(window,'Network Lobby',249,-103,110,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 btn(window,'Poker Table',366,-103,105,function()if R.OpenBarrensTable then R.OpenBarrensTable()end end)
 btn(window,'Settings',478,-103,91,function()if R.OpenBarrensSettings then R.OpenBarrensSettings()end end)
 uiText(window,20,-144,300,'MULTIPLAYER SEATS','GameFontNormal')
 uiText(window,349,-144,280,'GAME MASTER ACTIONS','GameFontNormal')
 seatButtons={};gmButtons={}
 for i=1,10 do
  local idx=i
  seatButtons[i]=btn(window,'',20,-168-(i-1)*28,300,function()selected=idx;refresh()end)
 end
 detailLabel=uiText(window,20,-460,610,'')
 local function gmButton(text,x,y,w,fn)
  local b=btn(window,text,x,y,w,fn);gmButtons[#gmButtons+1]=b;return b
 end
 gmButton('Auto Seat Joined',349,-169,140,function()invoke('AutoSeat')end)
 gmButton('Start Network Hand',495,-169,145,function()invoke('StartHand')end)
 gmButton('Sit Out',349,-202,140,function()local s=chosen();if s then invoke('SitOut',s.name,true)end end)
 gmButton('Sit In',495,-202,145,function()local s=chosen();if s then invoke('SitOut',s.name,false)end end)
 gmButton('Remove Player',349,-235,140,function()local s=chosen();if s then invoke('Remove',s.name)end end)
 gmButton('Set Balance',495,-235,145,function()
  local s=chosen();if s then invoke('SetStack',s.name,tonumber(amountBox:GetText()))end
 end)
 uiText(window,349,-280,280,'Balance in silver (100s = 1g)')
 amountBox=CreateFrame('EditBox',nil,window)
 amountBox:SetSize(142,24);amountBox:SetPoint('TOPLEFT',window,'TOPLEFT',349,-300)
 amountBox:SetAutoFocus(false);amountBox:SetNumeric(true);amountBox:SetMaxLetters(9)
 amountBox:SetFontObject('ChatFontNormal')
 amountBox:SetTextInsets(7,7,0,0)
 amountBox:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 amountBox:SetBackdropColor(0.03,0.04,0.04,0.95);amountBox:SetText('1000')
 btn(window,'Player Management',349,-342,145,function()if R.OpenBarrensManagement then R.OpenBarrensManagement()end end)
 btn(window,'Multiplayer Seats',500,-342,140,function()if R.OpenBarrensMultiplayer then R.OpenBarrensMultiplayer()end end)
 btn(window,'Table Effects',349,-375,145,function()if R.OpenBarrensTableEffects then R.OpenBarrensTableEffects()elseif R.OpenBarrensTable then R.OpenBarrensTable()end end)
 btn(window,'Force Sync',500,-375,140,function()
  local sync=R.HoldemSync
  if sync and sync.ForceBroadcast then say(sync.ForceBroadcast())else say(false,'Sync not available')end
 end)
 btn(window,'Rules & Help',349,-408,145,function()if R.OpenBarrensGuide then R.OpenBarrensGuide('HELP')end end)
 btn(window,'Protocol Debug',500,-408,140,function()if R.OpenHoldemProtocolDebug then R.OpenHoldemProtocolDebug()end end)
 btn(window,'Betting Activity',349,-438,145,function()if R.OpenBarrensBettingActivity then R.OpenBarrensBettingActivity()end end)
 btn(window,'Hand History',500,-438,140,function()if R.OpenBarrensHandHistory then R.OpenBarrensHandHistory()end end)
 btn(window,'Transfer GM',349,-469,145,function()if R.OpenBarrensGMTransfer then R.OpenBarrensGMTransfer()end end)
 btn(window,'Sync Seats',500,-469,140,function()if R.HoldemAdminBridge then local ok,err=R.HoldemAdminBridge.BroadcastSeats();if not ok and R.Print then R.Print(tostring(err))end end end)
 uiText(window,20,-496,625,'Host actions require an active Network Lobby and an idle hand.','GameFontHighlightSmall')
 uiText(window,20,-514,625,'Real player actions remain player-authorized; no remote player impersonation.','GameFontHighlightSmall')
 uiText(window,20,-536,625,'SESSION, TABLE AND VISUAL CONTROLS','GameFontNormal')
 btn(window,'Hand Preflight',20,-559,145,function()if R.OpenBarrensPreflight then R.OpenBarrensPreflight() end end)
 btn(window,'Transfer GM',174,-559,145,function()if R.OpenBarrensGMTransfer then R.OpenBarrensGMTransfer() end end)
 btn(window,'Table Operations',328,-559,145,function()if R.OpenBarrensTableDesk then R.OpenBarrensTableDesk() end end)
 btn(window,'Table Themes',482,-559,145,function()if R.OpenBarrensSettings then R.OpenBarrensSettings() end end)
 btn(window,'Session Recovery',20,-592,145,function()if R.OpenBarrensSessionRecovery then R.OpenBarrensSessionRecovery() end end)
 btn(window,'Network Lobby',174,-592,145,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby() end end)
 btn(window,'Effects & Sounds',328,-592,145,function()if R.OpenBarrensTableEffects then R.OpenBarrensTableEffects() end end)
 btn(window,'Hand History',482,-592,145,function()if R.OpenBarrensHandHistory then R.OpenBarrensHandHistory() end end)
 window:Hide()
end
function R.OpenBarrensControlCenter() build();refresh();window:Show();window:Raise()end
SLASH_BARRCONTROL1='/holdemcontrol'
SLASH_BARRCONTROL2='/holdemgm'
SlashCmdList.BARRCONTROL=function()R.OpenBarrensControlCenter()end
