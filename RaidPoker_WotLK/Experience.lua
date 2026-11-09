-- Raid 5-Card Poker WotLK v0.7.0: additional client-side experience features.
-- WoW 3.3.5a API only. No change to the raid addon message protocol.
local R=RPoker
local X={}
local function label(parent,x,y,w,value,font)
 local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetText(value or '')
 return t
end
local function button(parent,value,x,y,w,cb) return R.Button(parent,value,w,23,x,y,cb) end
local function window(id,title,w,h,x,y)
 local f=CreateFrame('Frame',id,UIParent);f:SetWidth(w);f:SetHeight(h);f:SetFrameStrata('FULLSCREEN_DIALOG')
 f:SetPoint('CENTER',UIParent,'CENTER',x,y);f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true);R.Backdrop(f)
 local bar=CreateFrame('Frame',nil,f);bar:SetPoint('TOPLEFT',f,'TOPLEFT',10,-7);bar:SetPoint('TOPRIGHT',f,'TOPRIGHT',-42,-7);bar:SetHeight(31)
 bar:EnableMouse(true);bar:RegisterForDrag('LeftButton');bar:SetScript('OnDragStart',function()f:StartMoving()end)
 bar:SetScript('OnDragStop',function()f:StopMovingOrSizing()end)
 label(f,19,-19,w-60,title,'GameFontNormalLarge')
 button(f,'X',w-37,-14,25,function()f:Hide()end)
 f:Hide();return f
end
local rankings={
 '1. ROYAL FLUSH      A K Q J 10 of the same suit',
 '2. STRAIGHT FLUSH  Five consecutive cards of one suit',
 '3. FOUR OF A KIND  Four cards of equal rank',
 '4. FULL HOUSE      Three of a kind plus a pair',
 '5. FLUSH           Five cards of the same suit',
 '6. STRAIGHT        Five consecutive ranks',
 '7. THREE OF A KIND Three cards of equal rank',
 '8. TWO PAIR        Two different pairs',
 '9. ONE PAIR        Two cards of equal rank',
 '10. HIGH CARD      Highest card when no other hand qualifies',
 'Ace can be high or low in a straight (A-2-3-4-5).',
 'Equal combinations use kickers; equal eligible hands split the pot.'
}
local rules={
 'FIVE-CARD DRAW - GAME RULES',
 'Each player receives five private cards from a 52-card deck.',
 'An ante may be collected before cards are dealt.',
 'FIRST BETTING ROUND: Check (if no bet), Call, Raise, Fold, All-In.',
 'DRAW ROUND: Select up to three cards and click Exchange.',
 'Stand Pat: keep all five cards without exchanging.',
 'SECOND BETTING ROUND: Check, Call, Raise, Fold or All-In.',
 'SHOWDOWN: The best eligible five-card poker hand wins.',
 'The last player who has not folded wins without showdown.',
 'Side pots are awarded only to eligible players.',
 'HAND STRENGTH: Royal Flush > Straight Flush > Four of a Kind',
 '> Full House > Flush > Straight > Three of a Kind > Two Pair',
 '> One Pair > High Card. Compare ranks and then kickers.',
 'An Ace may be high or low in a straight (A-2-3-4-5).',
 'Equal winning hands split the eligible pot.',
 'Virtual Gold/Silver only: no automatic real-money transfer.'
}
local help={
 'GETTING STARTED - GAME MASTER',
 '1. Join a raid. Open the addon and click Tables.',
 '2. Enter a table name and click Create Table.',
 '3. You automatically become Game Master of that table.',
 '4. Wait for players to join from their Table Browser.',
 '5. Set ante and starting stack in the main window; Apply.',
 '6. Use Player Management to edit balances and statuses.',
 '7. Set Turn Timer in Player Management (15/30/60s or OFF).',
 '8. Click Start Hand when everyone is ready.',
 '9. GM may Force Fold or transfer GM between hands.',
 '10. Close Table between hands to end the session.',
 'GETTING STARTED - PLAYER',
 '1. Join the same raid and install the same addon version.',
 '2. Open Tables and click Refresh to discover tables.',
 '3. Select a waiting table and click Join.',
 '4. Wait for the GM to start the hand.',
 '5. On your turn choose Check, Call, Raise, Fold or All-In.',
 '6. During Draw select cards to Exchange, or Stand Pat.',
 '7. Watch the showdown and your virtual balance.',
 '8. Use Leave Table between hands to switch tables.',
 'COMMANDS: /poker, /poker tables, /poker settings,',
 '/poker rankings, /poker rules, /poker help.',
 'One active table per character. No real gold is moved.'
}

local function fill(parent,lines,startY,step)
 for i,s in ipairs(lines) do label(parent,22,startY-(i-1)*step,parent:GetWidth()-42,s) end
end
local priorBuild=R.BuildGame
function R.BuildGame(main)
 priorBuild(main)
 local ui=R.GameUI
 X.rank=window('RaidFivePokerRankings','POKER HAND RANKINGS',530,370,-110,40)
 R.RankingsFrame=X.rank;fill(X.rank,rankings,-55,24)
 X.rules=window('RaidFivePokerRules','FIVE-CARD DRAW RULES',690,485,80,0)
 R.RulesFrame=X.rules;fill(X.rules,rules,-54,25)
 X.help=window('RaidFivePokerHelp','HOW TO PLAY - GM & PLAYER',690,705,100,-10)
 R.HelpFrame=X.help;fill(X.help,help,-54,24)
 R.ToggleRankings=function()if X.rank:IsShown() then X.rank:Hide()else X.rank:Show()end end
 R.ToggleRules=function()if X.rules:IsShown()then X.rules:Hide()else X.rules:Show()end end
 R.ToggleHelp=function()if X.help:IsShown()then X.help:Hide()else X.help:Show()end end
 -- Matching WoW-style icon launchers beside the existing Settings gear.
 local function iconButton(name,texture,offset,tip,fn)
  local b=CreateFrame('Button',name,main)
  b:SetWidth(30);b:SetHeight(30)
  b:SetPoint('TOPRIGHT',main,'TOPRIGHT',offset,-12)
  local ico=b:CreateTexture(nil,'ARTWORK');ico:SetTexture(texture);ico:SetAllPoints(b)
  b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
  b:SetScript('OnClick',fn)
  b:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine(tip);GameTooltip:Show()end)
  b:SetScript('OnLeave',function()GameTooltip:Hide()end)
 end
 iconButton('RaidPokerRankingsIcon','Interface\\Icons\\INV_Misc_Note_01',-120,'Rankings',function()R.ToggleRankings()end)
 iconButton('RaidPokerRulesIcon','Interface\\Icons\\INV_Misc_Book_09',-156,'Rules: Five-Card Draw',function()R.ToggleRules()end)
 iconButton('RaidPokerHelpIcon','Interface\\Icons\\INV_Misc_QuestionMark',-192,'Help: Game Master / Player',function()R.ToggleHelp()end)
 -- Lightweight chip pulse animation: a label, not a real currency transfer.
 X.chips=label(main,500,-323,250,'','GameFontNormal')
 X.chips:SetTextColor(1,0.78,0.25);X.chips:Hide()
 X.previousPot=0;X.previousRound=0;X.lastResult='';X.cardAnim=0;X.soundReady=false;X.lastTurn='';X.lastHand=''
 X.anim=CreateFrame('Frame',nil,main)
 X.anim:SetScript('OnUpdate',function(self,dt)
  if X.chipTime and X.chipTime>0 then
   X.chipTime=X.chipTime-dt
   X.chips:SetAlpha(math.max(0,math.min(1,X.chipTime/0.65)))
   if X.chipTime<=0 then X.chips:Hide()end
  end
  if X.cardAnim>0 then
   X.cardAnim=X.cardAnim-dt
   local t=math.max(0,X.cardAnim)
   for i,b in ipairs(ui.cards or {}) do
    if b.cardArt then b.cardArt:SetAlpha(math.min(1,math.max(0,(0.5-t)*5+(i-1)*-0.12))) end
   end
  end
 end)
end
local priorManagement=R.BuildManagement
function R.BuildManagement(main)
 if priorManagement then priorManagement(main)end
 local settings=R.SettingsFrame
 if settings then
  -- New settings are placed in the previously unused upper section.
  label(settings,35,-329,270,'GAME SETTINGS 3.0','GameFontNormal')
  X.dealerButton=button(settings,'Dealer Rotation: ON',36,-394,220,function()
   RaidPokerWotLKDB.dealerRotation=not (RaidPokerWotLKDB.dealerRotation~=false)
   X.dealerButton:SetText('Dealer Rotation: '..(RaidPokerWotLKDB.dealerRotation and 'ON' or 'OFF'))
  end)
  X.dealerButton:SetText('Dealer Rotation: '..(RaidPokerWotLKDB.dealerRotation==false and 'OFF' or 'ON'))
 end
 local balances=R.BalancesFrame
 if balances then
  local manage=window('RaidFivePokerPlayerManagement','PLAYER MANAGEMENT',375,160,210,-140)
  X.management=manage
  label(manage,20,-54,325,'Player name (exact table name):')
  X.kickName=CreateFrame('EditBox',nil,manage,'InputBoxTemplate')
  X.kickName:SetPoint('TOPLEFT',manage,'TOPLEFT',25,-80)
  X.kickName:SetWidth(155);X.kickName:SetHeight(22);X.kickName:SetAutoFocus(false)
  X.kickName:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
  button(manage,'Kick Player',200,-76,145,function()
   if R.KickManagedPlayer then R.KickManagedPlayer(X.kickName:GetText())end
  end)
  label(manage,20,-123,335,'Host only. Available between hands.')
  button(balances,'Manage Players',340,-14,145,function()
   if manage:IsShown()then manage:Hide()else manage:Show()end
  end)
  local hide=balances:GetScript('OnHide')
  balances:SetScript('OnHide',function(self)if hide then hide(self)end;manage:Hide()end)
  local mainHide=main:GetScript('OnHide')
  main:SetScript('OnHide',function(self)if mainHide then mainHide(self)end;manage:Hide()end)
 end
 local debug=RaidFivePokerSoloDebug
 if debug then
  debug:SetHeight(520)
  label(debug,12,-380,270,'ADVANCED SOLO DEBUG - TEST HANDS')
  label(debug,12,-402,270,'Assign one preset to YOUR hand (solo only).')
  button(debug,'Royal Flush',12,-428,130,function()R.DebugAssignHand({9,10,11,12,13})end)
  button(debug,'Four of a Kind',156,-428,130,function()R.DebugAssignHand({1,14,27,40,13})end)
  button(debug,'Straight',12,-459,130,function()R.DebugAssignHand({1,15,29,43,5})end)
  button(debug,'Full House',156,-459,130,function()R.DebugAssignHand({1,14,27,2,15})end)
 end
end
local previousRefresh=R.Refresh
function R.Refresh()
 previousRefresh()
 local g=R.G;local ui=R.GameUI
 if not ui or not ui.cards then return end
 -- Show a dealer marker without changing the underlying game turn rules.
 local dealer=(RaidPokerWotLKDB.dealerRotation==false and 1 or ((math.max(1,g.round)-1)%math.max(1,#g.players)+1))
 for i,row in ipairs(ui.rows or {}) do
  local p=g.players[i]
  if p and row then
   local status=p.fold and 'FOLD' or p.allin and 'ALL-IN' or p.inhand and 'PLAYING' or 'WAITING'
   local prefix=(i==dealer and '[D] ' or '')..(g.turn==p.name and '> ' or '')
   row:SetText(prefix..p.name..'   '..tostring(p.balance or 0)..'s   '..status)
   if g.turn==p.name then row:SetTextColor(1,0.88,0.35)
   elseif p.fold then row:SetTextColor(0.55,0.55,0.55)
   elseif p.allin then row:SetTextColor(1,0.52,0.2)
   else row:SetTextColor(0.85,0.9,0.85)end
  end
 end
 if X.previousRound~=g.round then
   X.lastResult=nil
  if X.soundReady and R.PokerSound then R.PokerSound('deal') end
  X.previousRound=g.round;X.cardAnim=0.65
 end
 local myName=UnitName('player')
 if X.soundReady and g.turn~=X.lastTurn and g.turn==myName and R.PokerSound then R.PokerSound('turn') end
 X.lastTurn=g.turn
 local cardsKey=table.concat(g.hand or {},',')
 -- Exchange sound is triggered directly on Exchange / Stand Pat, avoiding missed or duplicate sync events.
 X.lastHand=cardsKey
 if X.previousPot~=g.pot then
  local delta=g.pot-X.previousPot
  X.previousPot=g.pot
  if delta>0 and (g.phase=='BET1' or g.phase=='BET2') then
   X.chips:SetText('+'..delta..'s  TO POT');X.chips:SetAlpha(1);X.chips:Show();X.chipTime=1.1
   if X.soundReady and R.PokerSound then R.PokerSound('bet') end
  end
 end
 if X.soundReady and g.phase=='SHOWDOWN' and g.winner and g.winner~='' and X.lastResult~=g.winner then
  X.lastResult=g.winner
  -- Server winner text lists payout recipients as `Name +amounts (hand)`;
  -- only payees hear the victory cue. All other participants hear a quiet loss cue.
  local ownWin=false
  local who=UnitName('player') or ''
  for name in string.gmatch(g.winner,'([^;]+)') do
   local winner=string.match(name,'^%s*([^%s]+)%s+%+%d+s')
   if winner==who then ownWin=true;break end
  end
  if R.PokerSound then R.PokerSound(ownWin and 'win' or 'loss') end
 end
 X.soundReady=true
 if X.timerButton then X.timerButton:SetText('Turn Timer: '..(g.timer==0 and 'OFF' or tostring(g.timer)..'s'))end
end
