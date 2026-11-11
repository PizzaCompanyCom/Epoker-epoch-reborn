-- Raid Poker 1.8.0-alpha3: LOCAL TEST ENGINE ONLY. No raid messages or real balances.
local R=RPoker
if not R then return end
local H={phase='LOBBY',players={},board={},deck={},dealer=0,smallBlind=5,bigBlind=10,handNumber=0,pot=0,log={},sidePots={},winners={}}
R.Holdem=H
local suits={'S','H','D','C'}
local function notify() if H.Refresh then H.Refresh() end end
local function shuffle()
 H.deck={}
 for s=1,4 do for v=2,14 do H.deck[#H.deck+1]={rank=v,suit=suits[s]} end end
 for i=#H.deck,2,-1 do local j=math.random(i);H.deck[i],H.deck[j]=H.deck[j],H.deck[i] end
end
local function draw() return table.remove(H.deck) end
local function live(i)
 local p=H.players[i];return p and not p.sittingOut and p.stack>0
end
local function nextFunded(i)
 local n=#H.players
 for k=1,n do local j=((i+k-1)%n)+1;if live(j) then return j end end
end
local function inHand(i)
 local p=H.players[i];return p and p.dealt and not p.folded
end
local function canAct(i)
 local p=H.players[i];return inHand(i) and not p.allIn and p.stack>0
end
local function nextActor(i)
 for k=1,#H.players do local j=((i+k-1)%#H.players)+1;if canAct(j) and not H.players[j].done then return j end end
end
local function countContestants()
 local n=0;for i=1,#H.players do if inHand(i) then n=n+1 end end;return n
end
local function countAble()
 local n=0;for i=1,#H.players do if canAct(i) then n=n+1 end end;return n
end
local function commit(i,amount)
 local p=H.players[i];local paid=math.min(p.stack,math.max(0,math.floor(amount)))
 p.stack=p.stack-paid;p.street=p.street+paid;p.committed=p.committed+paid;H.pot=H.pot+paid
 if p.stack==0 then p.allIn=true end
 return paid
end
local function log(message)
 H.log[#H.log+1]=message
 if #H.log>30 then table.remove(H.log,1) end
end
local function score5(cards)
 local counts={}
 local ranks={};local suit=cards[1].suit;local flush=true
 for _,c in ipairs(cards) do counts[c.rank]=(counts[c.rank] or 0)+1;if c.suit~=suit then flush=false end end
 for r in pairs(counts) do ranks[#ranks+1]=r end
 table.sort(ranks,function(a,b)return a>b end)
 local straight=0
 local present={};for _,r in ipairs(ranks) do present[r]=true end
 if present[14] then present[1]=true end
 for hi=14,5,-1 do if present[hi] and present[hi-1] and present[hi-2] and present[hi-3] and present[hi-4] then straight=hi;break end end
 local groups={}
 for _,r in ipairs(ranks) do groups[#groups+1]={r=r,n=counts[r]} end
 table.sort(groups,function(a,b)if a.n==b.n then return a.r>b.r end return a.n>b.n end)
 if flush and straight>0 then return {8,straight} end
 if groups[1].n==4 then return {7,groups[1].r,groups[2].r} end
 if groups[1].n==3 and groups[2].n==2 then return {6,groups[1].r,groups[2].r} end
 if flush then return {5,unpack(ranks)} end
 if straight>0 then return {4,straight} end
 if groups[1].n==3 then return {3,groups[1].r,groups[2].r,groups[3].r} end
 if groups[1].n==2 and groups[2].n==2 then return {2,groups[1].r,groups[2].r,groups[3].r} end
 if groups[1].n==2 then return {1,groups[1].r,groups[2].r,groups[3].r,groups[4].r} end
 return {0,unpack(ranks)}
end
local function better(a,b)
 if not b then return true end
 for i=1,6 do local x=a[i] or 0;local y=b[i] or 0;if x~=y then return x>y end end
 return false
end
local function equal(a,b)return not better(a,b) and not better(b,a) end
local function best7(cards)
 local best
 for a=1,#cards-4 do for b=a+1,#cards-3 do for c=b+1,#cards-2 do for d=c+1,#cards-1 do for e=d+1,#cards do
  local s=score5({cards[a],cards[b],cards[c],cards[d],cards[e]});if better(s,best) then best=s end
 end end end end end
 return best
end
local function calculatePots()
 local levels={};local seen={}
 for _,p in ipairs(H.players) do if p.committed>0 and not seen[p.committed] then seen[p.committed]=true;levels[#levels+1]=p.committed end end
 table.sort(levels)
 local pots={};local previous=0
 for _,level in ipairs(levels) do
  local participants={};local eligible={}
  for i,p in ipairs(H.players) do
   if p.committed>=level then participants[#participants+1]=i;if inHand(i) then eligible[#eligible+1]=i end end
  end
  local amount=(level-previous)*#participants
  if amount>0 then pots[#pots+1]={amount=amount,eligible=eligible,contributors=participants,winners={}} end
  previous=level
 end
 return pots
end
local function finish()
 H.phase='SHOWDOWN';H.actionSeat=nil;H.winners={};H.winningRanks={};H.sidePots=calculatePots()
 local strengths={}
 for i,p in ipairs(H.players) do
  if inHand(i) then
   local cards={};for _,c in ipairs(H.board) do cards[#cards+1]=c end
   for _,c in ipairs(p.hole) do cards[#cards+1]=c end
   if #cards>=5 then strengths[i]=best7(cards) end
  end
 end
 H.winningRanks=strengths
 local paid=0
 for pi,pot in ipairs(H.sidePots) do
  local best;local winners={}
  for _,i in ipairs(pot.eligible) do
   local s=strengths[i]
   if not best or (s and better(s,best)) then best=s;winners={i}
   elseif s and equal(s,best) then winners[#winners+1]=i end
  end
  if #winners==0 then -- folded-out pots are not expected, but never destroy chips
   for _,i in ipairs(pot.contributors) do if inHand(i) then winners={i};break end end
  end
  if #winners==0 then winners={pot.contributors[1]} end
  local share=math.floor(pot.amount/#winners);local remainder=pot.amount-share*#winners
  -- Odd chips: first eligible winner clockwise after dealer.
  table.sort(winners,function(a,b)
   local da=(a-H.dealer-1)%#H.players;local db=(b-H.dealer-1)%#H.players;return da<db
  end)
  for k,i in ipairs(winners) do
   local gain=share+(k<=remainder and 1 or 0)
   H.players[i].stack=H.players[i].stack+gain;paid=paid+gain;H.winners[i]=(H.winners[i] or 0)+gain
  end
  pot.winners=winners
  log('Pot '..pi..': '..pot.amount..'s paid to '..table.concat((function()local t={} for _,i in ipairs(winners) do t[#t+1]=H.players[i].name end return t end)(),', '))
 end
 H.pot=0
 notify()
end
local function reveal()
 if H.phase=='PREFLOP' then draw();for i=1,3 do H.board[#H.board+1]=draw() end;H.phase='FLOP'
 elseif H.phase=='FLOP' then draw();H.board[#H.board+1]=draw();H.phase='TURN'
 elseif H.phase=='TURN' then draw();H.board[#H.board+1]=draw();H.phase='RIVER'
 else finish();return end
 H.currentBet=0;H.minRaise=H.bigBlind;H.lastFullRaise=H.bigBlind
 for _,p in ipairs(H.players) do p.street=0;p.done=false;p.raiseAllowed=true end
 H.actionSeat=nextActor(H.dealer)
 log(H.phase..' dealt')
end
local function advanceIfReady()
 if countContestants()<=1 then finish();return end
 if countAble()==0 then
  while H.phase~='SHOWDOWN' do reveal() end
  return
 end
 -- If only one player can act, no further bets can be made after matching existing bet.
 if countAble()==1 then
  local one;for i=1,#H.players do if canAct(i) then one=i end end
  if H.players[one].street>=H.currentBet then
   while H.phase~='SHOWDOWN' do reveal() end
   return
  end
 end
 local pending=false
 for i,p in ipairs(H.players) do if canAct(i) and (not p.done or p.street<H.currentBet) then pending=true;break end end
 if not pending then
  reveal()
  if H.phase=='SHOWDOWN' then return end
  -- reveal() has already selected the first eligible actor after the dealer.
  -- Do not call advanceIfReady() again for a normal betting street: its
  -- pending branch would advance past that actor before they can act.
  -- Only auto-run the board when no further betting is possible.
  if countAble()<=1 then advanceIfReady() end
 else
  H.actionSeat=nextActor(H.actionSeat or H.dealer)
 end
end
function H.ResetPreview()
 H.phase='LOBBY';H.board={};H.deck={};H.pot=0;H.dealer=0;H.handNumber=0;H.actionSeat=nil;H.sidePots={};H.winners={};H.winningRanks={};H.log={}
 H.players={}
 local bots=math.max(1,math.min(5,math.floor(tonumber(H.debugBots) or 3)))
 for i=1,bots+1 do
  local name=(i==1 and ((UnitName and UnitName('player')) or 'You')) or ('Debug Bot '..(i-1))
  H.players[i]={name=name,stack=1000,hole={},committed=0,street=0,folded=false,allIn=false,sittingOut=false,dealt=false,done=false,raiseAllowed=true}
 end
 notify()
end
function H.StartPreviewHand()
 if H.phase~='LOBBY' and H.phase~='SHOWDOWN' then return false,'Finish the current preview first.' end
 local funded=0;for i=1,#H.players do if live(i) then funded=funded+1 end end
 if funded<2 then return false,'At least two funded players required.' end
 H.dealer=nextFunded(H.dealer);H.board={};H.pot=0;H.sidePots={};H.winners={};H.handNumber=H.handNumber+1;H.log={}
 for i,p in ipairs(H.players) do p.hole={};p.committed=0;p.street=0;p.folded=false;p.allIn=false;p.dealt=live(i) and true or false;p.done=false;p.raiseAllowed=true end
 shuffle()
 if funded==2 then H.smallBlindSeat=H.dealer;H.bigBlindSeat=nextFunded(H.dealer)
 else H.smallBlindSeat=nextFunded(H.dealer);H.bigBlindSeat=nextFunded(H.smallBlindSeat) end
 commit(H.smallBlindSeat,H.smallBlind);commit(H.bigBlindSeat,H.bigBlind)
 H.currentBet=H.players[H.bigBlindSeat].street;H.minRaise=H.bigBlind;H.lastFullRaise=H.bigBlind
 for round=1,2 do local i=H.dealer;for j=1,funded do i=nextFunded(i);H.players[i].hole[#H.players[i].hole+1]=draw() end end
 H.phase='PREFLOP';H.actionSeat=nextActor(H.bigBlindSeat)
 log('Hand '..H.handNumber..' started. SB '..H.smallBlind..'s / BB '..H.bigBlind..'s')
 advanceIfReady();notify();return true
end
function H.Action(action,amount)
 if H.phase=='LOBBY' or H.phase=='SHOWDOWN' then return false,'No active betting round.' end
 local i=H.actionSeat;local p=i and H.players[i]
 if not p or not canAct(i) then return false,'No player can act.' end
 local due=math.max(0,H.currentBet-p.street)
 if action=='FOLD' then p.folded=true;p.done=true;log(p.name..' folds')
 elseif action=='CHECK' then
  if due>0 then return false,'Cannot check: '..due..'s to call.' end
  p.done=true;log(p.name..' checks')
 elseif action=='CALL' then
  if due==0 then return false,'Nothing to call. Use Check.' end
  local paid=commit(i,due);p.done=true;log(p.name..' calls '..paid..'s'..(p.allIn and ' (All-In)' or ''))
 elseif action=='RAISE' or action=='ALLIN' then
  local paid
  if action=='ALLIN' then paid=p.stack else
   if not p.raiseAllowed then return false,'Betting is not reopened for this player.' end
   local raiseBy=tonumber(amount)
   if not raiseBy or raiseBy~=math.floor(raiseBy) or raiseBy<=0 then return false,'Enter a positive integer raise in Silver.' end
   paid=due+raiseBy
   if paid>p.stack then return false,'Not enough chips; use All-In.' end
  end
  if paid<=due then
   if action~='ALLIN' then return false,'Raise must exceed the call.' end
   commit(i,paid);p.done=true;log(p.name..' calls All-In '..paid..'s')
  else
   if not p.raiseAllowed then return false,'Betting is not reopened for this player.' end
   local increase=paid-due
   if increase<H.minRaise and paid<p.stack then return false,'Minimum raise: '..H.minRaise..'s.' end
   local previous=H.currentBet;commit(i,paid);H.currentBet=p.street;p.done=true
   if H.currentBet-previous>=H.minRaise then
    H.minRaise=H.currentBet-previous
    for j,other in ipairs(H.players) do if j~=i and canAct(j) then other.done=false;other.raiseAllowed=true end end
   else
    -- A short all-in does not reopen raising for players who already acted.
    for j,other in ipairs(H.players) do if j~=i and canAct(j) then
     if other.done then other.raiseAllowed=false end
     if other.street<H.currentBet then other.done=false end
    end end
   end
   log(p.name..' raises to '..H.currentBet..'s'..(p.allIn and ' (All-In)' or ''))
  end
 else return false,'Unknown action.' end
 advanceIfReady();notify();return true
end
-- Host-authoritative departure: fold without altering committed chips or pot.
-- Unlike H.Action('FOLD'), this can handle a player who is not the current actor.
function H.ForceFoldDeparting(name)
 if H.phase=='LOBBY' or H.phase=='SHOWDOWN' then return false,'No active hand' end
 local index
 for i,p in ipairs(H.players) do if p.name==name then index=i;break end end
 if not index then return false,'Player not in hand' end
 local p=H.players[index]
 if not p.dealt or p.folded then return true end
 local acting=(H.actionSeat==index)
 p.folded=true;p.done=true;p.sittingOut=true
 log(name..' leaves the table (automatic fold)')
 if acting or countContestants()<=1 then advanceIfReady() end
 notify()
 return true
end
function H.AdvancePreview()
 -- Retained for compatibility, but cannot bypass a live betting round.
 if H.phase=='LOBBY' or H.phase=='SHOWDOWN' then return false,'Start a preview hand first.' end
 return false,'Betting is active. Use Fold, Check, Call, Raise or All-In.'
end
function H.CardLabel(card)
 if not card then return '--' end
 local ranks={[11]='J',[12]='Q',[13]='K',[14]='A'}
 return (ranks[card.rank] or tostring(card.rank))..card.suit
end
function H.GetPublicSnapshot()
 local s={phase=H.phase,handNumber=H.handNumber,pot=H.pot,board={},players={},actionSeat=H.actionSeat,currentBet=H.currentBet or 0,minRaise=H.minRaise or H.bigBlind,sidePots=H.sidePots,winners=H.winners,winningRanks=H.winningRanks,log=H.log}
 for i,c in ipairs(H.board) do s.board[i]=H.CardLabel(c) end
 for i,p in ipairs(H.players) do
  s.players[i]={name=p.name,stack=p.stack,committed=p.committed,street=p.street,allIn=p.allIn,folded=p.folded,dealer=(i==H.dealer),smallBlind=(i==H.smallBlindSeat),bigBlind=(i==H.bigBlindSeat),dealt=p.dealt}
 end
 return s
end
-- Fix 22: a fresh addon load must not populate the public Poker Table with debug bots.
-- ResetPreview() remains available for an explicitly started Solo Debug session.
H.phase='LOBBY';H.players={};H.board={};H.deck={};H.pot=0
H.dealer=0;H.handNumber=0;H.actionSeat=nil;H.sidePots={};H.winners={};H.winningRanks={};H.log={}
