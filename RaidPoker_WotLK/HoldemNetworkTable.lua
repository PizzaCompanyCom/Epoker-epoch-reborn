-- The Barrens Hold'em beta4c5: multiplayer-safe public table and local action controls.
-- This view deliberately never reads another player's private cards.
-- Compatible with WoW 3.3.5a Lua 5.1.
local R=RPoker
if not R or not R.Holdem or not R.HoldemNetwork then return end
local H,N=R.Holdem,R.HoldemNetwork
local T={};R.HoldemNetworkTable=T
local win,header,boardText,potText,turnText,privateText,notice
local rows={}
local raiseBox,historyText
local function me() return UnitName('player') or '' end
local function fmt(n) n=math.max(0,math.floor(tonumber(n) or 0));return math.floor(n/100)..'g '..(n%100)..'s' end
local function card(c)
 if type(c)=='table' then return H.CardLabel and H.CardLabel(c) or '--' end
 if type(c)=='string' and c~='-' then return c end
 return '--'
end
local function snapshot()
 if not N.active then return nil end
 if N.owner then
  if not R.HoldemMultiplayer or not R.HoldemMultiplayer.active then return nil end
  return H
 end
 return R.HoldemSync and R.HoldemSync.remote
end
local function label(x,y,w,style)
 local f=win:CreateFontString(nil,'OVERLAY',style or 'GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',win,'TOPLEFT',x,y);f:SetWidth(w);f:SetJustifyH('LEFT');return f
end
local function button(name,x,y,w,cb)
 local b=CreateFrame('Button',nil,win,'UIPanelButtonTemplate')
 b:SetSize(w,24);b:SetPoint('TOPLEFT',win,'TOPLEFT',x,y);b:SetText(name);b:SetScript('OnClick',cb);return b
end
local function act(action)
 if not N.active then notice:SetText('Create or join a network lobby first.');return end
 local s=snapshot()
 if not s then notice:SetText('Waiting for a multiplayer hand.');return end
 local p=s.players and s.players[s.actionSeat or 0]
 if not p or p.name~=me() then notice:SetText('Wait for your turn.');return end
 local amount=action=='RAISE' and tonumber(raiseBox:GetText()) or 0
 if action=='RAISE' and (not amount or amount<1 or amount~=math.floor(amount)) then notice:SetText('Enter a positive raise in Silver.');return end
 if N.owner then
  local ok,err=H.Action(action,amount)
  notice:SetText(ok and ('Action accepted: '..action) or tostring(err or 'Action rejected'))
 elseif R.HoldemProtocol and R.HoldemProtocol.SendAction then
  R.HoldemProtocol.SendAction(action,amount)
  notice:SetText('Action sent to host; awaiting synchronization.')
 else notice:SetText('Network action transport unavailable.') end
 T.Refresh()
end
function T.Refresh()
 if not win then return end
 local s=snapshot()
 header:SetText('Host: '..tostring(N.host or '-')..'  |  '..(N.owner and 'GAME MASTER' or 'CLIENT')..'  |  '..(N.active and 'CONNECTED' or 'OFFLINE'))
 if not s then
  boardText:SetText('Community: --   --   --   --   --')
  potText:SetText('Pot: --')
  turnText:SetText('No active synchronized hand')
  privateText:SetText('Your cards: [hidden] [hidden]')
  for i=1,6 do rows[i]:SetText(i..'. [Empty]') end
  return
 end
 local board={}
 for i=1,5 do board[#board+1]=card(s.board and s.board[i]) end
 boardText:SetText('Community: '..table.concat(board,'   '))
 potText:SetText('Hand '..tostring(s.handNumber or 0)..'   '..tostring(s.phase or '-')..'   Pot: '..fmt(s.pot))
 local acting=s.players and s.players[s.actionSeat or 0]
 turnText:SetText(acting and ('TURN: '..tostring(acting.name)) or 'No active turn')
 local P=R.HoldemProtocol
 local mycards=P and P.privateCards or nil
 if mycards and #mycards==2 and P.privateHand==s.handNumber then
  privateText:SetText('Your cards: '..card(mycards[1])..'   '..card(mycards[2]))
 else privateText:SetText('Your cards: [hidden] [hidden]') end
 for i=1,6 do
  local p=s.players and s.players[i]
  if p then
   local status=p.folded and 'FOLDED' or (p.allIn and 'ALL-IN' or (p.sittingOut and 'SIT OUT' or 'PLAYING'))
   local tag=s.actionSeat==i and '  < TURN' or ''
   rows[i]:SetText(i..'. '..tostring(p.name or '?')..'   '..fmt(p.stack)..'   Bet '..fmt(p.street)..'  ['..status..']'..tag)
  else rows[i]:SetText(i..'. [Empty]') end
 end
end
local function build()
 if win then return end
 win=CreateFrame('Frame','RaidPokerBarrensNetworkTable',UIParent)
 win:SetSize(670,640);win:SetPoint('CENTER');win:SetFrameStrata('DIALOG')
 win:SetMovable(true);win:EnableMouse(true);win:SetClampedToScreen(true);win:RegisterForDrag('LeftButton')
 win:SetScript('OnDragStart',function(self)self:StartMoving()end)
 win:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 win:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 label(20,-19,570,'GameFontNormalLarge'):SetText("THE BARRENS HOLD'EM - NETWORK TABLE")
 button('X',625,-15,28,function()win:Hide()end)
 header=label(20,-55,610)
 boardText=label(20,-93,610,'GameFontNormal')
 potText=label(20,-123,610,'GameFontNormal')
 turnText=label(20,-152,610,'GameFontNormal')
 privateText=label(20,-184,610,'GameFontNormal')
 for i=1,6 do rows[i]=label(22,-211-(i-1)*24,610) end
 notice=label(20,-465,615)
 notice:SetText('Public table state. Only your private cards are shown.')
 button('Fold',20,-495,80,function()act('FOLD')end)
 button('Check',108,-495,80,function()act('CHECK')end)
 button('Call',196,-495,80,function()act('CALL')end)
 button('All-In',284,-495,80,function()act('ALLIN')end)
 raiseBox=CreateFrame('EditBox',nil,win,'InputBoxTemplate')
 raiseBox:SetSize(65,24);raiseBox:SetPoint('TOPLEFT',win,'TOPLEFT',379,-495)
 raiseBox:SetNumeric(true);raiseBox:SetAutoFocus(false);raiseBox:SetText('10')
 button('Raise (s)',455,-495,115,function()act('RAISE')end)
 button('Player Management',20,-544,160,function()if R.OpenBarrensManagement then R.OpenBarrensManagement() end end)
 button('Lobby',188,-544,85,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button('Sync Viewer',281,-544,110,function()if R.OpenBarrensSyncViewer then R.OpenBarrensSyncViewer()end end)
 button('Local Poker Table',399,-544,160,function()if R.OpenBarrensTable then R.OpenBarrensTable()end end)
 label(20,-588,610):SetText('Network table is separate from Solo Debug. Host keeps the deck; clients receive public state.')
 win:Hide()
end
function R.OpenBarrensNetworkTable() build();T.Refresh();win:Show();win:Raise() end
local previous=SlashCmdList and SlashCmdList.RAIDFIVEPOKER
if previous then SlashCmdList.RAIDFIVEPOKER=function(input)
 local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
 if cmd=='holdemtable' or cmd=='holdemnetworktable' then R.OpenBarrensNetworkTable() else previous(input) end
end end
SLASH_BARRNETWORKTABLE1='/holdemtable'
SlashCmdList.BARRNETWORKTABLE=function()R.OpenBarrensNetworkTable()end
local tick=CreateFrame('Frame');local elapsed=0
 tick:SetScript('OnUpdate',function(self,dt)
  elapsed=elapsed+dt
  if elapsed>0.5 then elapsed=0;if win and win:IsShown() then T.Refresh() end end
 end)
