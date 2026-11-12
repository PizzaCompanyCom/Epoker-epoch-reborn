-- Raid Poker 1.8.0-beta4b: isolated LOCAL Solo Debug controller.
-- No addon messages, no real currency, no network lobby modifications.
local R=RPoker
if not R then return end
local H=R.Holdem
if not H then return end
local D={bots=3,auto=true,delay=0.8,reveal=false,active=false}
R.HoldemSoloDebug=D
local win,info,botLabel,autoButton,revealButton
local elapsed=0
local function say(s) if R.Print then R.Print('Barrens Solo Debug: '..s) else DEFAULT_CHAT_FRAME:AddMessage('Barrens Solo Debug: '..s) end end
local function button(parent,text,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,24);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',fn)
 return b
end
local function label(parent,x,y,w,text)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetJustifyH('LEFT');f:SetText(text or '')
 return f
end
local function update()
 if not win then return end
 botLabel:SetText('Local opponents: '..D.bots..'  |  Seats: '..(D.bots+1)..'/6')
 autoButton:SetText('Auto Bots: '..(D.auto and 'ON' or 'OFF'))
 revealButton:SetText('Reveal Bots: '..(D.reveal and 'ON' or 'OFF'))
 local actor=H.actionSeat and H.players[H.actionSeat]
 info:SetText('Phase: '..(H.phase or 'LOBBY')..'  |  Acting: '..(actor and actor.name or 'none')..'\nOnly local simulated stacks. No network or raid required.')
end
-- Explicit shutdown used only on transition from local preview to network play.
-- Never clear network seats or balances here: the unified adapter owns that transition.
function D.StopForNetwork()
 D.auto=false
 D.reveal=false
 D.active=false
 elapsed=0
 if win then win:Hide() end
end
local function reset()
 if R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK' then say('Leave the network table to play Solo Debug.');return end
 D.auto=true;D.active=true;H.debugBots=D.bots;H.ResetPreview();update()
end
local function choose(n)
 if H.phase~='LOBBY' and H.phase~='SHOWDOWN' then say('Finish the hand or Reset before changing bot count.');return end
 D.bots=n;reset()
end
local function act(a,amount)
 if R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK' then say('Solo Debug is unavailable during multiplayer.');return end
 if H.phase=='LOBBY' or H.phase=='SHOWDOWN' then say('Start a hand first.');return end
 local ok,msg=H.Action(a,amount)
 if not ok then say(msg or 'Action unavailable.') end
 update()
end
local function botStep()
 if R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK' then return end
 local i=H.actionSeat
 if not i or i==1 or H.phase=='SHOWDOWN' or H.phase=='LOBBY' then return end
 local p=H.players[i];if not p then return end
 local due=math.max(0,(H.currentBet or 0)-(p.street or 0))
 -- AI decisions are strictly local and pass through the existing legal action API.
 local action,amount
 if R.PokerAI then action,amount=R.PokerAI.HoldemBet(p,H.board,due,H.pot,H.minRaise) end
 if not action then action=due==0 and 'CHECK' or (due>=p.stack and 'ALLIN' or 'CALL') end
 local ok,msg=H.Action(action,amount)
 if not ok then
  local fallback=due==0 and 'CHECK' or (due>=p.stack and 'ALLIN' or 'CALL')
  H.Action(fallback)
 end
 update()
end
local function build()
 if win then return end
 win=CreateFrame('Frame','RaidPokerBarrensSoloDebug',UIParent)
 win:SetSize(430,320);win:SetPoint('CENTER',UIParent,'CENTER',0,-60)
 win:SetFrameStrata('DIALOG');win:SetMovable(true);win:EnableMouse(true);win:RegisterForDrag('LeftButton')
 win:SetClampedToScreen(true)
 win:SetScript('OnDragStart',function(self)self:StartMoving()end)
 win:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 win:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 label(win,20,-22,370,"THE BARRENS HOLD'EM - SOLO DEBUG")
 button(win,'X',385,-14,25,function()win:Hide()end)
 botLabel=label(win,20,-57,385,'')
 for j,n in ipairs({1,2,3,5}) do button(win,n..' Bot'..(n>1 and 's' or ''),20+(j-1)*99,-78,92,function()choose(n)end) end
 button(win,'Start Game',20,-117,120,function()
  if R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK' then say('Leave multiplayer first.');return end
  local ok,msg=H.StartPreviewHand();if not ok then say(msg or 'Cannot start hand') end;update()
 end)
 button(win,'Reset Game',148,-117,120,reset)
 autoButton=button(win,'Auto Bots: ON',276,-117,132,function()D.auto=not D.auto;update()end)
 label(win,20,-157,390,'Manual debug action: applies to CURRENT acting seat')
 button(win,'Force Fold',20,-176,95,function()act('FOLD')end)
 button(win,'Force Call',119,-176,95,function()
  local p=H.actionSeat and H.players[H.actionSeat]
  if p and (H.currentBet or 0)<=p.street then act('CHECK') else act('CALL') end
 end)
 button(win,'Force Raise',218,-176,95,function()act('RAISE',H.minRaise or H.bigBlind or 10)end)
 button(win,'Force All-In',317,-176,91,function()act('ALLIN')end)
 revealButton=button(win,'Reveal Bots: OFF',20,-217,190,function()
  D.reveal=not D.reveal
  -- This flag is local-only; the preview already displays test cards for debug.
  update()
 end)
 button(win,'Open Poker Table',218,-217,190,function()
  if R.OpenBarrensPreview then R.OpenBarrensPreview() end
 end)
 info=label(win,20,-257,390,'')
 win:Hide()
end
function R.OpenBarrensSoloDebug()
 if R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK' then say('Leave multiplayer first.');return end
 if not D.active then reset() end
 build();update();win:Show();win:Raise()
end
-- Slow auto-action loop is explicitly opt-in and never acts for seat 1.
local ticker=CreateFrame('Frame')
ticker:SetScript('OnUpdate',function(self,dt)
 -- Network play must never inherit the local auto-bot timer.
 if R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK' then
  D.auto=false;elapsed=0
  if win and win:IsShown() then update() end
  return
 end
 if not D.auto or H.phase=='LOBBY' or H.phase=='SHOWDOWN' then elapsed=0;return end
 elapsed=elapsed+dt
 if elapsed>=D.delay then elapsed=0;botStep() end
end)
local previous=SlashCmdList.RAIDFIVEPOKER
if previous then
 SlashCmdList.RAIDFIVEPOKER=function(input)
  local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
  if cmd=='holdemdebug' or cmd=='barrensdebug' then R.OpenBarrensSoloDebug()
  else previous(input) end
 end
end
