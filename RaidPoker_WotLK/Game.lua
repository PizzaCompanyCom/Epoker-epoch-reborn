local R=RPoker
local G={clientDeadline=0,phase='IDLE',round=0,host='',players={},pot=0,bet=0,turn='',ante=10,stack=1000,timer=30,deadline=0,log={},hand={},selected={},history={},winner='',myBalance=0}
R.G=G
local PREFIX='R5CP03'
local tables={} -- discovery only; each client plays at one table
local activeID=''
local tableName=''
local lastAdvert=0
local function validID(id) return type(id)=='string' and string.match(id,'^[%w%-]+$') and #id<=48 end
local function remember(id,name,gm,count,phase)
 if not validID(id) then return end
 tables[id]={id=id,name=string.sub(name or 'Poker Table',1,32),gm=gm or '',count=tonumber(count) or 0,phase=phase or 'LOBBY',seen=GetTime()}
 if RPoker.RefreshTableBrowser then RPoker.RefreshTableBrowser() end
end
local function cleanName(s)
 s=tostring(s or ''):gsub('[|;,~]',' '):gsub('[%c]',' ')
 s=s:gsub('^%s+',''):gsub('%s+$','')
 return string.sub(s,1,32)
end

local suits={'S','H','D','C'}
local ranks={'2','3','4','5','6','7','8','9','T','J','Q','K','A'}
local function me() return UnitName('player') or '' end
local function short(s) return string.gsub(s or '','%-.*$','') end
local function raid() return GetNumRaidMembers and GetNumRaidMembers()>0 end
local function leader()
 if not raid() then return false end
 return UnitIsRaidLeader('player') or UnitIsRaidOfficer('player')
end
local function host() return G.host==me() end
local function send(kind,data,target)
 if G.solo or not raid() then return end
 local channel=target and 'WHISPER' or 'RAID'
 local id=(kind=='DISCOVER' or kind=='ADVERT' or kind=='CLOSED') and '-' or activeID
 if id=='' then return end
 SendAddonMessage(PREFIX,id..'|'..kind..'|'..(data or ''),channel,target)
end
local function say(s) R.Print(s) end
local function split(s,sep)
 local a={};for part in string.gmatch((s or '')..sep,'(.-)'..sep) do table.insert(a,part) end;return a
end
local function esc(s) return string.gsub(tostring(s or ''),'[|;,]',' ') end
local function player(n)
 for _,p in ipairs(G.players) do if p.name==n then return p end end
end
local function countActive()
 local n=0;for _,p in ipairs(G.players) do if p.inhand and not p.fold then n=n+1 end end;return n
end
local function canAct(p) return p and p.inhand and not p.fold and not p.allin end
local function log(s)
 table.insert(G.log,1,s);if #G.log>11 then table.remove(G.log) end
end
local function cardLabel(id)
 id=tonumber(id)
 if not id or id<1 or id>52 then return '??' end
 return ranks[(id-1)%13+1]..suits[math.floor((id-1)/13)+1]
end
local function handString(cards)
 local out={};for _,id in ipairs(cards or {}) do table.insert(out,cardLabel(id)) end
 return table.concat(out,',')
end
local function parseCards(s)
 local out={};for v in string.gmatch(s or '','%d+') do table.insert(out,tonumber(v)) end;return out
end
local function shuffle()
 local d={};for i=1,52 do d[i]=i end
 for i=52,2,-1 do local j=math.random(i);d[i],d[j]=d[j],d[i] end
 return d
end
local function score(cards)
 if not cards or #cards~=5 then return {0,0,0,0,0,0},'Unknown' end
 local nums,counts,suit={}, {}, nil
 local flush=true
 for _,id in ipairs(cards) do
  local v=(id-1)%13+2;local st=math.floor((id-1)/13)
  table.insert(nums,v);counts[v]=(counts[v] or 0)+1
  if suit==nil then suit=st elseif suit~=st then flush=false end
 end
 table.sort(nums,function(a,b)return a>b end)
 local uniq={};for _,v in ipairs(nums) do if not uniq[#uniq] or uniq[#uniq]~=v then table.insert(uniq,v) end end
 local straight=0
 if #uniq==5 then
  if uniq[1]-uniq[5]==4 then straight=uniq[1]
  elseif uniq[1]==14 and uniq[2]==5 and uniq[5]==2 then straight=5 end
 end
 local groups={};for v,n in pairs(counts) do table.insert(groups,{n=n,v=v}) end
 table.sort(groups,function(a,b) if a.n==b.n then return a.v>b.v end return a.n>b.n end)
 if flush and straight>0 then return {8,straight},straight==14 and 'Royal Flush' or 'Straight Flush' end
 if groups[1].n==4 then return {7,groups[1].v,groups[2].v},'Four of a Kind' end
 if groups[1].n==3 and groups[2].n==2 then return {6,groups[1].v,groups[2].v},'Full House' end
 if flush then return {5,unpack(nums)},'Flush' end
 if straight>0 then return {4,straight},'Straight' end
 if groups[1].n==3 then return {3,groups[1].v,groups[2].v,groups[3].v},'Three of a Kind' end
 if groups[1].n==2 and groups[2].n==2 then return {2,groups[1].v,groups[2].v,groups[3].v},'Two Pair' end
 if groups[1].n==2 then return {1,groups[1].v,groups[2].v,groups[3].v,groups[4].v},'One Pair' end
 return {0,unpack(nums)},'High Card'
end
function R.DebugEvaluateCards(cards) return score(cards) end
local function better(a,b)
 for i=1,6 do
  local x=(a and a[i]) or 0;local y=(b and b[i]) or 0
  if x>y then return 1 elseif x<y then return -1 end
 end
 return 0
end
local function state()
 local out={}
 for _,p in ipairs(G.players) do
  table.insert(out,table.concat({p.name,p.balance,p.inhand and 1 or 0,p.fold and 1 or 0,p.allin and 1 or 0,p.paid or 0,p.total or 0,p.done and 1 or 0,p.status or 'Playing'},','))
 end
 return table.concat(out,';')
end
local function broadcast()
 if not host() then return end
 send('HOST',tableName)
 send('STATE',table.concat({G.round,G.phase,G.pot,G.bet,G.turn,G.ante,G.stack,G.timer,string.gsub(G.winner or '',';',' / ')},';'))
 -- Keep player records short to fit the 255-byte addon message limit.
 send('CLEAR','')
 for _,p in ipairs(G.players) do
  send('PLAYER',table.concat({p.name,p.balance,p.inhand and 1 or 0,p.fold and 1 or 0,p.allin and 1 or 0,p.paid or 0,p.total or 0,p.done and 1 or 0,p.status or 'Playing'},';'))
 end
 send('LOG',string.sub(table.concat(G.log,'~'),1,190))
 send('READY','')
 remember(activeID,tableName,G.host,#G.players,G.phase)
 send('ADVERT',table.concat({activeID,cleanName(tableName),G.host,#G.players,G.phase},';'))
 if RaidPokerWotLKDB and not G.solo then RaidPokerWotLKDB.hostSnapshot={tableID=activeID,tableName=tableName,host=G.host,round=G.round,phase=G.phase,players=state(),pot=G.pot,bet=G.bet,turn=G.turn,ante=G.ante,stack=G.stack,timer=G.timer,winner=G.winner} end
 R.Refresh()
end
local function sendHand(p)
 if p and p.cards then
  if p.name==me() then G.hand=p.cards;G.selected={} else send('HAND',table.concat(p.cards,','),p.name) end
 end
end
local function updateHostBalance()
 local p=player(me());if p then G.myBalance=p.balance end
end
local function nextTurn(after)
 local start=0
 for i,p in ipairs(G.players) do if p.name==after then start=i end end
 for offset=1,#G.players do
  local i=(start+offset-1)%#G.players+1;local p=G.players[i]
  if canAct(p) and not p.done then
   G.turn=p.name;G.deadline=GetTime()+G.timer;return true
  end
 end
 G.turn='';return false
end
local function finishHand(reason)
 G.phase='SHOWDOWN';G.turn='';G.winner='';G.lastPot=G.pot
 -- Reveal only eligible, non-folded hands after betting is finished.
 G.showdownHands={}
 for _,entry in ipairs(G.players) do
  if entry.inhand and not entry.fold and entry.cards and #entry.cards==5 then
   G.showdownHands[entry.name]={cards={unpack(entry.cards)},combo=entry.combo or ''}
  end
 end
 local eligible={}
 local winnings={}
 for _,p in ipairs(G.players) do
  if p.inhand and not p.fold then
   p.rank,p.combo=score(p.cards);table.insert(eligible,p)
  end
 end
 if #eligible==0 then
  for _,p in ipairs(G.players) do p.balance=p.balance+(p.total or 0) end
  G.winner='Hand cancelled - all contributions refunded.'
 else
  -- Side pots: each contribution tier is awarded only to eligible contenders.
  local levels={}
  for _,p in ipairs(G.players) do
   if (p.total or 0)>0 then
    local seen=false;for _,v in ipairs(levels) do if v==p.total then seen=true end end
    if not seen then table.insert(levels,p.total) end
   end
  end
  table.sort(levels)
  local previous=0
  for _,level in ipairs(levels) do
   local contributors,contenders={},{}
   for _,p in ipairs(G.players) do
    if (p.total or 0)>=level then
     table.insert(contributors,p)
     if p.inhand and not p.fold then table.insert(contenders,p) end
    end
   end
   local amount=(level-previous)*#contributors
   if #contenders==0 then
    -- An uncalled contribution tier is returned to its contributors.
    for _,p in ipairs(contributors) do p.balance=p.balance+(level-previous) end
   else
    local best=nil;local winners={}
    for _,p in ipairs(contenders) do
     if not best or better(p.rank,best)>0 then best=p.rank;winners={p}
     elseif better(p.rank,best)==0 then table.insert(winners,p) end
    end
    local each=math.floor(amount/#winners);local extra=amount-each*#winners
    for i,p in ipairs(winners) do
     local win=each+(i<=extra and 1 or 0);p.balance=p.balance+win;winnings[p.name]=(winnings[p.name] or 0)+win
    end
   end
   previous=level
  end
  local lines={}
  for _,p in ipairs(eligible) do
   if (winnings[p.name] or 0)>0 then table.insert(lines,p.name..' +'..winnings[p.name]..'s ('..p.combo..')') end
  end
  G.winner=table.concat(lines,'; ')
  if G.winner=='' then G.winner='No eligible winner' end
 end
 -- Automatically mark players with zero balance as Busted only after
 -- all side pots and winnings have been settled (not during an all-in).
 for _,entry in ipairs(G.players) do
  if (entry.balance or 0)<=0 and entry.status~='Busted' then
   entry.status='Busted'
   log('Auto Busted: '..entry.name..' (0g 0s)')
  end
 end
 -- Capture evaluated combination names before publishing the result.
 for _,entry in ipairs(G.players) do
  if G.showdownHands and G.showdownHands[entry.name] then G.showdownHands[entry.name].combo=entry.combo or 'High Card' end
 end
 if R.PublishShowdown then R.PublishShowdown(G.round,G.showdownHands) end
 log('WINNER: '..G.winner)
 local record={round=G.round,pot=G.pot,winner=G.winner,players={},events={}}
 for _,entry in ipairs(G.players) do table.insert(record.players,{name=entry.name,contributed=entry.total or 0,balance=entry.balance or 0,fold=entry.fold,combo=entry.combo or ''}) end
 for i=#G.log,1,-1 do table.insert(record.events,G.log[i]) end
 if not G.solo then
  RaidPokerWotLKDB.detailedHistory=RaidPokerWotLKDB.detailedHistory or {};table.insert(RaidPokerWotLKDB.detailedHistory,1,record)
  while #RaidPokerWotLKDB.detailedHistory>100 do table.remove(RaidPokerWotLKDB.detailedHistory) end
  RaidPokerWotLKDB.statistics=RaidPokerWotLKDB.statistics or {}
  for _,entry in ipairs(G.players) do local st=RaidPokerWotLKDB.statistics[entry.name] or {played=0,won=0,winnings=0,losses=0,net=0};RaidPokerWotLKDB.statistics[entry.name]=st
   if entry.total and entry.total>0 then st.played=st.played+1;local payout=(winnings and winnings[entry.name]) or 0;st.winnings=st.winnings+payout;st.losses=st.losses+entry.total;st.net=st.net+payout-entry.total;if payout>0 then st.won=st.won+1 end end
  end
 end
 if G.solo then G.debugHistory=G.debugHistory or {};table.insert(G.debugHistory,1,date('%m/%d %H:%M')..'  ['..tableName..' / '..activeID..'] Round '..G.round..'  Pot '..R.Money(G.pot)..'  '..G.winner)
 else table.insert(RaidPokerWotLKDB.history,1,date('%m/%d %H:%M')..'  ['..tableName..' / '..activeID..'] Round '..G.round..'  Pot '..R.Money(G.pot)..'  '..G.winner)
 end
 while #RaidPokerWotLKDB.history>100 do table.remove(RaidPokerWotLKDB.history) end
 for _,p in ipairs(G.players) do p.inhand=false end
 G.pot=0;G.bet=0
 broadcast()
 send('RESULT',string.sub(G.winner,1,210))
end
local function advance()
 if countActive()<=1 then finishHand('last');return end
 if G.phase=='BET1' then
  G.phase='DRAW';G.bet=0
  for _,p in ipairs(G.players) do p.done=not canAct(p);p.paid=0 end
 elseif G.phase=='DRAW' then
  G.phase='BET2';G.bet=0
  for _,p in ipairs(G.players) do p.done=not canAct(p);p.paid=0 end
 else finishHand('showdown');return end
 nextTurn('');log('Phase: '..G.phase);broadcast()
 if G.turn=='' then advance() end
end
local function doneTurn()
 if countActive()<=1 then finishHand('fold');return end
 if not nextTurn(G.turn) then advance() else broadcast() end
end
local function hostAction(who,action,value)
 if not host() then return end
 local p=player(who)
 if not p or not p.inhand or p.fold or G.turn~=who then return end
 local v=math.floor(tonumber(value) or 0)
 if G.phase=='DRAW' then
  if action~='DRAW' then return end
  local indexes={};for n in string.gmatch(value or '','%d+') do local i=tonumber(n);if i and i>=1 and i<=5 then indexes[i]=true end end
  local count=0;for _ in pairs(indexes) do count=count+1 end
  if count>3 then return end
  for i=1,5 do if indexes[i] then
   if G.deckPos<=52 then p.cards[i]=G.deck[G.deckPos];G.deckPos=G.deckPos+1 end
  end end
  p.done=true;sendHand(p);log(who..' exchanged '..count..' cards');doneTurn();return
 end
 if G.phase~='BET1' and G.phase~='BET2' then return end
 local owed=math.max(0,G.bet-p.paid)
 if action=='FOLD' then p.fold=true;p.done=true;log(who..' folds')
 elseif action=='CHECK' then if owed~=0 then return end;p.done=true;log(who..' checks')
 elseif action=='CALL' then
  local pay=math.min(owed,p.balance);p.balance=p.balance-pay;p.paid=p.paid+pay;p.total=p.total+pay;G.pot=G.pot+pay
  if p.balance==0 then p.allin=true end;p.done=true;log(who..' calls '..pay..'s')
 elseif action=='RAISE' or action=='ALLIN' then
  local pay=action=='ALLIN' and p.balance or v
  if pay<=owed or pay>p.balance or pay<1 then return end
  p.balance=p.balance-pay;p.paid=p.paid+pay;p.total=p.total+pay;G.pot=G.pot+pay
  if p.balance==0 then p.allin=true end
  if p.paid>G.bet then
   G.bet=p.paid
   for _,other in ipairs(G.players) do if other.name~=who and canAct(other) then other.done=false end end
  end
  p.done=true;log(who..' raises '..pay..'s')
 else return end
 doneTurn()
end
local function startHand()
 if not host() then return end
 if G.phase~='LOBBY' and G.phase~='SHOWDOWN' and G.phase~='IDLE' then return end
 if #G.players<2 then say('At least two players must join.');return end
 if not G.solo and R.PokerVersionMatches then
  for _,p in ipairs(G.players) do
   if p.balance>0 and p.status~='Sitting Out' and p.status~='Busted' and R.PokerVersionMatches(p.name)~=true then
    say('Cannot start: incompatible or unknown addon version: '..p.name);return
   end
  end
 end
 G.showdownHands=nil;G.round=G.round+1;G.phase='BET1';G.pot=0;G.bet=0;G.winner='';G.deck=shuffle();G.deckPos=1;G.hand={};G.selected={}
 for _,p in ipairs(G.players) do
  p.inhand=p.balance>0 and p.status~='Sitting Out' and p.status~='Busted';p.fold=false;p.allin=false;p.done=false;p.paid=0;p.total=0;p.cards={}
  if p.inhand then
   local pay=math.min(G.ante,p.balance);p.balance=p.balance-pay;p.total=pay;G.pot=G.pot+pay
   if p.balance==0 then p.allin=true;p.done=true end
   for i=1,5 do p.cards[i]=G.deck[G.deckPos];G.deckPos=G.deckPos+1 end
   sendHand(p)
  end
 end
 log('Round '..G.round..' started. Ante '..G.ante..'s')
 nextTurn('');broadcast()
 if G.turn=='' then advance() end
end
local function join(name)
 if not host() or G.phase~='LOBBY' then return end
 if player(name) or #G.players>=10 then return end
 if not G.solo and not UnitInRaid(name) then return end
 table.insert(G.players,{name=name,balance=G.stack,inhand=false,fold=false,allin=false,paid=0,total=0,done=false})
 log(name..' joined table');broadcast()
end
local function request(kind,payload)
 if G.solo and kind=='JOIN' then say('Solo Debug Mode: bots are already seated.');return end
 if host() then
  if kind=='ACT' then local a=split(payload,';');hostAction(me(),a[1],a[2])
  elseif kind=='JOIN' then join(me()) end
 elseif G.host~='' then send(kind,payload,G.host)
 else say('No active table. Click Host Table to create one.') end
end
local function resetTable()
 G.host='';G.phase='IDLE';G.players={};G.round=0;G.pot=0;G.bet=0
 G.turn='';G.winner='';G.log={};G.hand={};G.selected={}
 activeID='';tableName=''
 R.Refresh()
end
local function hostTable(name)
 if not G.solo and not raid() then say('Join a raid first.');return end
 if activeID~='' then say('Leave or close your current table first.');return end
 name=cleanName(name)
 if name=='' then say('Enter a table name.');return end
 activeID=me()..'-'..tostring(time())..'-'..tostring(math.random(10000,99999))
 tableName=name
 G.host=me();G.phase='LOBBY';G.players={};G.round=0;G.pot=0;G.bet=0
 G.turn='';G.winner='';G.log={};G.hand={}
 join(me());broadcast()
 say('Created '..tableName..'. You are Game Master.')
end
function R.CreateNamedTable(name)
 if G.solo then
  if not raid() then say('Join a raid before creating a multiplayer table.');return end
  if cleanName(name)=='' then say('Enter a table name.');return end
  if R.SoloStop then R.SoloStop() end
 end
 hostTable(name)
end
function R.GetTableDirectory()
 local out={}
 for id,t in pairs(tables) do
  if GetTime()-t.seen<45 and (t.gm==me() or UnitInRaid(t.gm)) then table.insert(out,t) end
 end
 table.sort(out,function(a,b) return a.name<b.name end)
 return out
end
function R.ActiveTableID() return activeID end
function R.ActiveTableName() return tableName end
function R.DiscoverTables()
 if not raid() then say('Join a raid to discover tables.');return end
 SendAddonMessage(PREFIX,'-|DISCOVER|','RAID')
 if host() then broadcast() end
end
function R.JoinNamedTable(id)
 if activeID~='' then say('Leave your current table first.');return end
 local t=tables[id]
 if not t or GetTime()-t.seen>45 then say('Refresh the table list.');return end
 if t.count>=10 or t.phase~='LOBBY' then say('Table is full or a hand is in progress.');return end
 if G.solo and R.SoloStop then R.SoloStop() end
 activeID=id;tableName=t.name;G.host=t.gm;G.phase='LOBBY';G.players={}
 if R.PokerVersionMatches and R.PokerVersionMatches(t.gm)==false then
  if R.PokerShowVersionWarning then R.PokerShowVersionWarning(t.gm,R.GetPokerPeerVersion(t.gm)) end
  activeID='';tableName='';return
 end
 send('JOIN',(R.PokerLocalVersion and R.PokerLocalVersion() or 'Unknown')..';'..tostring(R.PokerNetworkProtocol or '0'),t.gm)
 send('SYNC','',t.gm)
 R.Refresh();say('Joining '..t.name..'...')
end
function R.LeaveNamedTable()
 if activeID=='' then return end
 if host() then say('Transfer Game Master or Close Table first.');return end
 if G.phase~='LOBBY' and G.phase~='SHOWDOWN' then say('Leave between hands only.');return end
 send('LEAVE','',G.host)
 resetTable()
end
function R.CloseNamedTable()
 if not host() then say('Only the Game Master can close this table.');return end
 if G.phase~='LOBBY' and G.phase~='SHOWDOWN' then say('Finish or cancel the hand first.');return end
 local id=activeID
 send('CLOSE','')
 send('CLOSED',id)
 tables[id]=nil
 RaidPokerWotLKDB.hostSnapshot=nil
 resetTable()
 say('Table closed. Game history retained.')
end
local function cancelHand()
 if not host() then return end
 if G.phase~='BET1' and G.phase~='BET2' and G.phase~='DRAW' then return end
 for _,p in ipairs(G.players) do p.balance=p.balance+(p.total or 0);p.total=0;p.paid=0;p.inhand=false end
 G.phase='LOBBY';G.turn='';G.pot=0;G.bet=0;G.winner='Hand cancelled - bets refunded.';log(G.winner);broadcast()
end
local function adjustBalance(name,amount)
 if not host() or (G.phase~='LOBBY' and G.phase~='SHOWDOWN') then return end
 local p=player(name);local v=tonumber(amount)
 if p and v and v>=0 and v<=100000000 then p.balance=math.floor(v);log('Balance set: '..name..' '..p.balance..'s');broadcast() end
end
local function receive(prefix,msg,channel,sender)
 if G.solo then return end
 if prefix~=PREFIX or not raid() then return end
 sender=short(sender)
 local id,k,d=string.match(msg or '','^([^|]+)|([^|]+)|?(.*)$')
 if not k then return end
 if k=='DISCOVER' then if host() then broadcast() end;return end
 if k=='ADVERT' then
  local a=split(d,';')
  if a[1] and a[3]==sender and UnitInRaid(sender) then remember(a[1],a[2],sender,a[4],a[5]) end
  return
 end
 if k=='CLOSED' then
  if tables[d] and tables[d].gm==sender then tables[d]=nil end
  if R.RefreshTableBrowser then R.RefreshTableBrowser() end
  return
 end
 if id~=activeID or activeID=='' then return end
 if k=='CLOSE' then
  if sender==G.host then tables[activeID]=nil;resetTable();say('Game Master closed the table.') end
  return
 end
 if k=='LEAVE' then
  if host() and (G.phase=='LOBBY' or G.phase=='SHOWDOWN') and sender~=me() then
   for i=#G.players,1,-1 do if G.players[i].name==sender then table.remove(G.players,i) end end
   broadcast()
  end
  return
 end
 if k=='HOST' then
  if sender==me() or (G.host~='' and G.host~=sender) then return end
  if not UnitInRaid(sender) then return end
  if G.host~=sender then G.host=sender;G.phase='LOBBY';G.players={} end;tableName=cleanName(d);R.Refresh();return
 end
 if k=='GMX' then
  if sender~=G.host then return end
  local target=short(d)
  if target=='' or not UnitInRaid(target) then return end
  G.host=target
  if tables[activeID] then tables[activeID].gm=target end
  if target==me() then
   G.phase='LOBBY';G.turn='';G.pot=0;G.bet=0
   for _,p in ipairs(G.players) do p.inhand=false;p.fold=false;p.allin=false;p.done=false;p.paid=0;p.total=0 end
   broadcast();say('You are now Game Master.')
  else say('Game Master transferred to '..target);R.Refresh() end
  return
 end
 if k=='ADMINLOG' then
  if sender==G.host then
   RaidPokerWotLKDB.adminHistory=RaidPokerWotLKDB.adminHistory or {}
   table.insert(RaidPokerWotLKDB.adminHistory,1,d)
   while #RaidPokerWotLKDB.adminHistory>100 do table.remove(RaidPokerWotLKDB.adminHistory) end
   if R.RefreshPlayerManagement then R.RefreshPlayerManagement() end
  end
  return
 end
 if k=='JOIN' then
  if host() then
   local ver,proto=d:match('^([%w%._%-]+);(%d+)$')
   if not ver or proto~=tostring(R.PokerNetworkProtocol or '20') or ver~=(R.PokerLocalVersion and R.PokerLocalVersion() or '') then
    send('VERSION_REJECT',(R.PokerLocalVersion and R.PokerLocalVersion() or 'Unknown')..';'..tostring(R.PokerNetworkProtocol or '20'),sender)
    say('Rejected incompatible player: '..sender)
   else
    if R.PokerRecordPeerVersion then R.PokerRecordPeerVersion(sender,ver,proto) end
    join(sender)
   end
  end
  return
 end
 if k=='VERSION_REJECT' then
  if sender==G.host then
   local required=d:match('^([^;]+)') or 'Unknown'
   if R.PokerShowVersionWarning then R.PokerShowVersionWarning(sender,required) end
   resetTable()
  end
  return
 end
 if k=='ACT' then if host() then local a=split(d,';');hostAction(sender,a[1],a[2]) end;return end
 if k=='SYNC' then if host() then send('HOST',tableName,sender);broadcast();local p=player(sender);if p then sendHand(p) end end;return end
 if k=='SET' then if host() then local a=split(d,';');adjustBalance(sender,a[1]) end;return end
 -- Only accept state updates from the active raid host.
 if sender~=G.host or sender==me() then return end
 if k=='STATE' then
  local a=split(d,';');local previousTurn=G.turn;G.round=tonumber(a[1]) or 0;G.phase=a[2] or 'IDLE';G.pot=tonumber(a[3]) or 0;G.bet=tonumber(a[4]) or 0;G.turn=a[5] or '';G.ante=tonumber(a[6]) or 10;G.stack=tonumber(a[7]) or 1000;G.timer=tonumber(a[8]) or 30;G.winner=a[9] or ''
  if G.turn~=previousTurn then G.clientDeadline=GetTime()+G.timer end
 elseif k=='CLEAR' then G.players={}
 elseif k=='PLAYER' then
  local a=split(d,';');table.insert(G.players,{name=a[1],balance=tonumber(a[2]) or 0,inhand=a[3]=='1',fold=a[4]=='1',allin=a[5]=='1',paid=tonumber(a[6]) or 0,total=tonumber(a[7]) or 0,done=a[8]=='1',status=a[9] or 'Playing'})
 elseif k=='HAND' then G.hand=parseCards(d);G.selected={}
 elseif k=='LOG' then G.log=split(d,'~')
 elseif k=='RESULT' then if G.winner~=d then G.winner=d;log('WINNER: '..d);table.insert(RaidPokerWotLKDB.history,1,date('%m/%d %H:%M')..'  ['..tableName..' / '..activeID..'] '..d) end
 elseif k=='READY' then updateHostBalance() end
 R.Refresh()
end
local ui={}
local function text(parent,x,y,width,size)
 local f=parent:CreateFontString(nil,'OVERLAY',size or 'GameFontHighlightSmall');f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(width);f:SetJustifyH('LEFT');return f
end
local function input(parent,x,y,w,default)
 -- A self-contained edit box avoids the oversized InputBoxTemplate side textures
 -- which can overlap neighbouring fields in the 3.3.5a client.
 local e=CreateFrame('EditBox',nil,parent)
 e:SetWidth(w);e:SetHeight(23);e:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y)
 e:SetFrameLevel(parent:GetFrameLevel()+5)
 e:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 e:SetBackdropColor(0.025,0.025,0.025,0.94);e:SetBackdropBorderColor(0.68,0.52,0.27,1)
 e:SetFontObject('GameFontHighlight');e:SetTextInsets(8,8,0,0)
 e:SetJustifyH('LEFT');e:SetAutoFocus(false);e:SetText(tostring(default or ''))
 e:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
 e:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
 return e
end
local function button(parent,label,x,y,w,fn)
 return R.Button(parent,label,w or 90,(parent==R.Main and (label=='Tables' or label=='Join Table' or label=='Leave Table' or label=='Start Hand' or label=='History' or label=='Leader' or label=='Check' or label=='Call' or label=='Raise' or label=='Fold' or label=='All-In' or label=='Exchange' or label=='Stand Pat' or label=='Poker Table') and 32 or 24),x,y,fn)
end
local function panel(parent,x,y,w,h)
 local f=CreateFrame('Frame',nil,parent);f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(w);f:SetHeight(h)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});R.RegisterBackground(f,0.025,0.07,0.065,0.83);return f
end
local function makeHistory(parent)
 local f=CreateFrame('Frame','RaidFivePokerHistory',UIParent);f:SetWidth(640);f:SetHeight(440);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');R.Backdrop(f)
 local t=text(f,24,-23,550,'GameFontNormalLarge');t:SetText('Game History (last 100 hands)')
 button(f,'Close',526,-20,85,function()f:Hide()end)
 local lines={};for i=1,16 do lines[i]=text(f,25,-57-(i-1)*22,585,'GameFontHighlightSmall') end
 f:SetScript('OnShow',function()for i=1,16 do lines[i]:SetText(R.MoneyText(((G.solo and G.debugHistory) or RaidPokerWotLKDB.history or {})[i] or '')) end end)
 R.HistoryFrame=f;f:Hide();return f
end
function R.BuildGame(main)
 ui.main=main
 ui.status=text(main,24,-52,730,'GameFontNormal');ui.status:SetText('');ui.status:Hide()
 ui.info=text(main,24,-75,730,'GameFontHighlightSmall');ui.info:Hide()
 ui.table=CreateFrame('Frame','RaidFivePokerFloatingTable',UIParent)
 ui.table:SetWidth(405);ui.table:SetHeight(365);ui.table:SetFrameStrata('DIALOG');ui.table:SetMovable(true);ui.table:EnableMouse(true);ui.table:SetClampedToScreen(true)
 ui.table:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=28,insets={left=10,right=10,top=10,bottom=10}})
 R.RegisterBackground(ui.table,0.04,0.045,0.04,1)
 ui.table:SetPoint('CENTER',UIParent,'CENTER',RaidPokerWotLKDB.tableX or 0,RaidPokerWotLKDB.tableY or 220)
 ui.table:RegisterForDrag('LeftButton')
 ui.table:SetScript('OnDragStart',function(self)self:StartMoving()end)
 ui.table:SetScript('OnDragStop',function(self)self:StopMovingOrSizing();local x,y=self:GetCenter();local a,b=UIParent:GetCenter();if x then RaidPokerWotLKDB.tableX=x-a;RaidPokerWotLKDB.tableY=y-b end end)
 R.TableFrame=ui.table
 R.ToggleTable=function()if ui.table:IsShown() then ui.table:Hide() else ui.table:Show() end end
 local tableClose=R.Button(ui.table,'X',25,21,365,-10,function()ui.table:Hide()end)
 ui.table:Hide()
 local label=text(ui.table,14,-10,350,'GameFontNormal');label:SetText('POKER TABLE  -  RAID PLAYERS')
 ui.rows={}
 for i=1,10 do
  ui.rows[i]=text(ui.table,18,-43-(i-1)*29,365,'GameFontHighlightSmall')
 end
 ui.cards={};ui.cardNames={}
 local cardArea=panel(main,22,-100,735,205)
 local handTitle=text(cardArea,12,-8,690,'GameFontNormal');handTitle:SetText('YOUR FIVE CARDS - CLICK TO SELECT UP TO THREE FOR EXCHANGE')
 for i=1,5 do
  local index=i
  local b=CreateFrame('Button',nil,cardArea);b:SetWidth(100);b:SetHeight(146);b:SetPoint('TOPLEFT',cardArea,'TOPLEFT',69+(i-1)*124,-35)
  local art=b:CreateTexture(nil,'ARTWORK');art:SetAllPoints(b);art:SetTexCoord(0,1,0,1);b.cardArt=art
  -- Card back shown before a hand and whenever a card is not dealt.
 local rim=b:CreateTexture(nil,'BORDER');rim:SetAllPoints(b)
 rim:SetTexture('Interface\\Buttons\\WHITE8X8');rim:SetVertexColor(0.77,0.59,0.31,1);b.cardBackRim=rim
 local back=b:CreateTexture(nil,'ARTWORK',nil,-2)
 back:SetPoint('TOPLEFT',b,'TOPLEFT',4,-4);back:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-4,4)
 back:SetTexture('Interface\\Buttons\\WHITE8X8');back:SetVertexColor(0.055,0.11,0.25,1);back:SetAlpha(1);back:SetBlendMode('BLEND');b.cardBack=back
 local inner=b:CreateTexture(nil,'ARTWORK',nil,-1)
 inner:SetPoint('TOPLEFT',b,'TOPLEFT',10,-10);inner:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-10,10)
 inner:SetTexture('Interface\\Buttons\\WHITE8X8');inner:SetVertexColor(0.12,0.24,0.43,1);inner:SetAlpha(1);inner:SetBlendMode('BLEND');b.cardBackInner=inner
 local ornament=b:CreateTexture(nil,'OVERLAY');ornament:SetWidth(52);ornament:SetHeight(52)
 ornament:SetPoint('CENTER',b,0,0);ornament:SetTexture('Interface\\Icons\\INV_Misc_Ticket_Tarot_Furies')
 ornament:SetWidth(46);ornament:SetHeight(46);ornament:SetVertexColor(1,1,1,1);b.cardBackOrnament=ornament
 local cardSymbol=b:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');cardSymbol:SetPoint('CENTER',b,0,21);cardSymbol:SetText('A');cardSymbol:SetTextColor(0.95,0.79,0.43,1);b.cardBackSymbol=cardSymbol
 local crest=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');crest:SetPoint('BOTTOM',b,0,17)
 crest:SetPoint('CENTER',b,0,-39);crest:SetText('RAID POKER');b.cardBackCrest=crest
  local caption=b:CreateFontString(nil,'OVERLAY','GameFontNormal');caption:SetPoint('CENTER',b,'CENTER');b.cardCaption=caption
  local select=b:CreateTexture(nil,'OVERLAY');select:SetTexture('Interface\\Buttons\\CheckButtonHilight');select:SetBlendMode('ADD');select:SetAllPoints(b);select:Hide();b.cardSelect=select
  -- Consistent opaque backing on all five cards (client 3.3.5a).
  -- SetBackdrop paints an identical solid surface independent of the cardArea layers.
  b:SetAlpha(1)
  b:SetFrameLevel(cardArea:GetFrameLevel()+2)
  b:SetNormalTexture(nil);b:SetPushedTexture(nil);b:SetHighlightTexture(nil)
  b:SetScript('OnEnter',function(self)self:SetAlpha(1)end)
  b:SetScript('OnLeave',function(self)self:SetAlpha(1)end)
  b:SetScript('OnClick',function()
   if G.phase~='DRAW' or G.turn~=me() then return end
   G.selected[index]=not G.selected[index]
   local n=0;for _,v in pairs(G.selected) do if v then n=n+1 end end
   if n>3 then G.selected[index]=false end
   R.Refresh()
  end)
  ui.cards[i]=b
 end
 ui.pot=text(main,25,-335,710,'GameFontNormalLarge')
 ui.pot:SetText('')
 ui.moneyCells={}
 local specs={{25,145,{1,.80,.20}},{176,176,{1,.58,.24}},{358,145,{.35,.82,1}},{509,245,{.42,1,.53}}}
 for i,spec in ipairs(specs) do
  local cell=text(main,spec[1],-333,spec[2],'GameFontNormalLarge')
  cell:SetFont('Fonts\\FRIZQT__.TTF',15,'OUTLINE')
  cell:SetShadowOffset(1,-1);cell:SetShadowColor(0,0,0,1)
  cell:SetTextColor(unpack(spec[3]));ui.moneyCells[i]=cell
 end
 ui.timer=text(main,600,-354,150,'GameFontNormal')
 button(main,'Join Table',24,-375,135,function()
  if R.ActiveTableID()~='' then R.Print('Already connected to a table.');return end
  local list=R.GetTableDirectory()
  if #list==1 then R.JoinNamedTable(list[1].id)
  elseif #list==0 then R.DiscoverTables();R.HF19LastMode='DRAW';if StaticPopup_Show then StaticPopup_Show('EPOKER_NO_ACTIVE_TABLE') end
  else R.Print('Multiple legacy tables detected. Open Player Management to choose.') end
 end)
 button(main,'Leave Table',168,-375,135,function()R.LeaveNamedTable()end)
 button(main,'Start Hand',312,-375,135,function()startHand()end)
 button(main,'History',456,-375,135,function()if ui.history:IsShown() then ui.history:Hide() else ui.history:Show() end end)
 button(main,'Leader',600,-375,135,function()if ui.leader:IsShown() then ui.leader:Hide() else ui.leader:Show() end end)
 ui.checkButton=button(main,'Check',24,-416,100,function()request('ACT','CHECK;0')end)
 ui.callButton=button(main,'Call',128,-416,100,function()request('ACT','CALL;0')end)
 ui.raiseButton=button(main,'Raise',232,-416,100,function()local amount=R.ReadMoney(ui.raiseGold,ui.raiseSilver)
 if not amount or amount<1 then say('Enter a valid raise amount (silver 0-99).');return end
 request('ACT','RAISE;'..amount)end)
 ui.foldButton=button(main,'Fold',336,-416,100,function()request('ACT','FOLD;0')end)
 ui.allinButton=button(main,'All-In',440,-416,100,function()request('ACT','ALLIN;0')end)
 ui.exchangeButton=button(main,'Exchange',544,-416,110,function()
  local a={};for i=1,5 do if G.selected[i] then table.insert(a,i) end end
  if G.phase=='DRAW' and G.turn==me() and #a<=3 then
   if R.PokerSound then R.PokerSound('draw') end
  end
  request('ACT','DRAW;'..table.concat(a,','))
 end)
 ui.patButton=button(main,'Stand Pat',658,-416,100,function()
 if G.phase=='DRAW' and G.turn==me() and R.PokerSound then R.PokerSound('draw') end
 request('ACT','DRAW;')
 end)
 -- Each label sits above its own edit box; no shared horizontal row with label text.
 -- InputBoxTemplate has a wide border, so leave generous spacing between fields.
 local r=text(main,30,-456,170,'GameFontHighlightSmall');r:SetText('Raise (Gold / Silver):')
 ui.raiseGold=input(main,36,-482,54,0)
 ui.raiseSilver=input(main,101,-482,54,20)
 local a=text(main,260,-456,170,'GameFontHighlightSmall');a:SetText('Ante (Gold / Silver):')
 ui.anteGold=input(main,266,-482,54,0)
 ui.anteSilver=input(main,331,-482,54,10)
 local b=text(main,485,-456,170,'GameFontHighlightSmall');b:SetText('Starting stack (G / S):')
 ui.stackGold=input(main,491,-482,54,10)
 ui.stackSilver=input(main,556,-482,54,0)
 button(main,'Apply',650,-482,85,function()
  if not host() or G.phase~='LOBBY' then say('Host only, lobby only.');return end
  local ante=R.ReadMoney(ui.anteGold,ui.anteSilver);local stack=R.ReadMoney(ui.stackGold,ui.stackSilver)
  if not ante or not stack then say('Invalid gold / silver amount. Silver must be 0-99.');return end
  if ante<0 or stack<1 or stack>100000000 then return end
  G.ante=ante;G.stack=stack;broadcast()
 end)
 local pokerTableButton=R.Button(main,'Poker Table',145,30,24,-11,function()R.ToggleTable()end)
 pokerTableButton:SetFrameLevel(main:GetFrameLevel()+5)
 pokerTableButton:SetText('POKER TABLE')
 local closeSolo=R.Button(main,'Close Solo',145,26,24,-47,function()
  if R.SoloStop then R.SoloStop() end
 end)
 local closeIcon=closeSolo:CreateTexture(nil,'OVERLAY')
 closeIcon:SetTexture('Interface\\Icons\\INV_Misc_Dice_02');closeIcon:SetSize(20,20)
 closeIcon:SetPoint('LEFT',closeSolo,'LEFT',7,0)
 closeSolo:SetText('     CLOSE SOLO')
 closeSolo:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Close Solo Debug Game')
  GameTooltip:AddLine('Clears local bots and returns to raid mode.',1,1,1,true);GameTooltip:Show()
 end)
 closeSolo:SetScript('OnLeave',function()GameTooltip:Hide()end)

 local tableText=pokerTableButton:GetFontString()
 if tableText then tableText:SetTextColor(1,0.86,0.34,1) end
 ui.help=text(main,25,-721,715,'GameFontHighlightSmall');ui.help:SetText('');ui.help:Hide()
 ui.history=makeHistory(main)
 R.GameUI=ui
 local leaderFrame=CreateFrame('Frame','RaidFivePokerLeader',UIParent);leaderFrame:SetWidth(420);leaderFrame:SetHeight(320);leaderFrame:SetPoint('CENTER',UIParent,'CENTER',250,0);leaderFrame:SetFrameStrata('FULLSCREEN_DIALOG');leaderFrame:SetMovable(true);leaderFrame:SetClampedToScreen(true);leaderFrame:EnableMouse(true);R.Backdrop(leaderFrame);R.LeaderFrame=leaderFrame
 local gmDrag=CreateFrame('Frame',nil,leaderFrame)
 gmDrag:SetPoint('TOPLEFT',leaderFrame,'TOPLEFT',10,-6)
 gmDrag:SetPoint('TOPRIGHT',leaderFrame,'TOPRIGHT',-48,-6)
 gmDrag:SetHeight(38);gmDrag:EnableMouse(true);gmDrag:RegisterForDrag('LeftButton')
 gmDrag:SetScript('OnDragStart',function()leaderFrame:StartMoving()end)
 gmDrag:SetScript('OnDragStop',function()leaderFrame:StopMovingOrSizing()end)
 ui.leader=leaderFrame
 local lt=text(leaderFrame,20,-22,330,'GameFontNormalLarge');lt:SetText('Game Master Controls')
 button(leaderFrame,'X',493,-18,28,function()leaderFrame:Hide()end)
 -- GM controls are built in Management.lua to avoid duplicate actions.
 leaderFrame:Hide()
end
function R.Refresh()
 if not ui.status then return end
 ui.status:SetText((G.solo and '[SOLO DEBUG]  ' or '')..'Table: '..(tableName~='' and tableName or 'none')..'  |  Game Master: '..(G.host~='' and G.host or 'none')..'   |   Round: '..G.round..'   |   Phase: '..G.phase)
 ui.info:SetText('Players: '..#G.players..'/10     Ante: '..R.Money(G.ante)..'     Starting stack: '..R.Money(G.stack)..'     Turn timer: '..G.timer..'s')
 for i=1,10 do
  local p=G.players[i]
  if p then
   local flag=(p.status=='Sitting Out' or p.status=='Busted') and p.status or p.fold and 'FOLD' or p.allin and 'ALL-IN' or p.inhand and 'PLAYING' or 'WAITING'
   ui.rows[i]:SetText(string.format('%d. %s  |  %s  |  %s',i,p.name,R.Money(p.balance),flag))
  else ui.rows[i]:SetText('') end
 end
 for i=1,5 do
  local v=G.hand[i]
  local name=v and cardLabel(v) or '??'
  if G.selected[i] then name='['..name..']' end
  ui.cards[i].cardCaption:SetText('')
  if v then ui.cards[i].cardArt:SetTexture('Interface\\AddOns\\RaidPoker_WotLK\\Cards\\'..string.gsub(cardLabel(v),'T','10')..'.tga');ui.cards[i].cardArt:Show();ui.cards[i].cardBack:Hide();ui.cards[i].cardBackRim:Hide();ui.cards[i].cardBackInner:Hide();ui.cards[i].cardBackOrnament:Hide();ui.cards[i].cardBackCrest:Hide();ui.cards[i].cardBackSymbol:Hide()
  else ui.cards[i].cardArt:Hide();ui.cards[i].cardArt:SetTexture(nil);ui.cards[i].cardBack:Show();ui.cards[i].cardBackRim:Show();ui.cards[i].cardBackInner:Show();ui.cards[i].cardBackOrnament:Show();ui.cards[i].cardBackCrest:Show();ui.cards[i].cardBackSymbol:Show() end
  ui.cards[i].cardBack:SetVertexColor(0.055,0.11,0.25,1)
  ui.cards[i].cardBackInner:SetVertexColor(0.12,0.24,0.43,1)
  ui.cards[i].cardBack:SetAlpha(1);ui.cards[i].cardBackInner:SetAlpha(1)
  ui.cards[i]:SetAlpha(1)
  ui.cards[i].cardSelect:Hide() -- v0.9.1: no overlay on boss art
  ui.cards[i]:ClearAllPoints()
  ui.cards[i]:SetPoint('TOPLEFT',ui.cards[i]:GetParent(),'TOPLEFT',69+(i-1)*124,G.selected[i] and -26 or -35)
 end
 local p=player(me());local bal=p and p.balance or 0;local owed=p and math.max(0,G.bet-(p.paid or 0)) or 0
 ui.pot:SetText('')
 local amounts={G.pot,G.bet,owed,bal}
 local names={'POT','CURRENT BET','TO CALL','YOUR BALANCE'}
 for i=1,4 do ui.moneyCells[i]:SetText(names[i]..': '..R.Money(amounts[i])) end
end
local events=CreateFrame('Frame')
local lastSyncRequest=0
events:RegisterEvent('CHAT_MSG_ADDON');events:RegisterEvent('RAID_ROSTER_UPDATE');events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:SetScript('OnEvent',function(self,event,...)
 if event=='CHAT_MSG_ADDON' then receive(...)
 elseif event=='PLAYER_ENTERING_WORLD' then if raid() and not G.solo then R.DiscoverTables();if activeID~='' then send('SYNC','') end;lastSyncRequest=GetTime() end end
 if event=='RAID_ROSTER_UPDATE' and raid() and not G.solo and GetTime()-lastSyncRequest>8 then lastSyncRequest=GetTime();R.DiscoverTables();if activeID~='' then send('SYNC','') end end
 if event=='RAID_ROSTER_UPDATE' and not G.solo and G.host~='' and not raid() then
  resetTable()
 end
end)
local botAt=0
local function botStep()
 if not G.solo or not host() or G.turn=='' or G.turn==me() then botAt=0;return end
 local p=player(G.turn)
 if not p then return end
 if botAt==0 then botAt=GetTime()+1.2;return end
 if GetTime()<botAt then return end
 botAt=0
 if G.phase=='DRAW' then
  -- Bots exchange zero to three random cards, without inspecting the human hand.
  local picks={};local n=math.random(0,3)
  while #picks<n do local v=math.random(1,5);local exists=false
   for _,k in ipairs(picks) do if k==v then exists=true end end
   if not exists then table.insert(picks,v) end
  end
  hostAction(p.name,'DRAW',table.concat(picks,','))
 else
  local owed=math.max(0,G.bet-(p.paid or 0))
  if owed==0 then hostAction(p.name,'CHECK','0')
  elseif owed>=p.balance then hostAction(p.name,'CALL','0')
  elseif math.random(1,100)<=(G.botStyle=='AGGRESSIVE' and 4 or G.botStyle=='PASSIVE' and 20 or 12) then hostAction(p.name,'FOLD','0')
  elseif G.botStyle=='AGGRESSIVE' and p.balance>owed+10 and math.random(1,100)<=25 then hostAction(p.name,'RAISE',tostring(owed+math.min(30,p.balance-owed)))
  else hostAction(p.name,'CALL','0') end
 end
end
function R.SoloStart(count)
 if activeID~='' then say('Leave or close your network table before starting Solo Debug.');return end
 if G.solo then say('Solo Debug Mode already active. Use /poker debug off to exit.');return end
 if G.phase~='IDLE' and G.phase~='LOBBY' and G.phase~='SHOWDOWN' then say('Finish the current hand before enabling debug.');return end
 count=math.floor(tonumber(count) or 3);if count<1 then count=1 elseif count>9 then count=9 end
 G.solo=true;G.debugHistory={};G.host=me();G.phase='LOBBY';G.players={};G.round=0;G.pot=0;G.bet=0;G.turn='';G.winner='';G.log={};G.hand={};G.selected={}
 join(me())
 for i=1,count do join('DebugBot'..i) end
 say('Solo Debug Mode ON - '..count..' simulated opponents. No raid required. /poker debug off to exit.')
 R.Refresh()
end
function R.SoloStop()
 if not G.solo then say('Solo Debug Mode is not active.');return end
 G.solo=false;G.host='';G.phase='IDLE';G.players={};G.round=0;G.pot=0;G.bet=0;G.turn='';G.hand={};G.selected={};G.winner='';botAt=0
 say('Solo Debug Mode OFF. Normal raid play restored.');R.Refresh()
end
function R.SoloStatus()
 say('Solo Debug: '..(G.solo and 'ON' or 'OFF')..', phase '..G.phase..', players '..#G.players..', round '..G.round)
end
local elapsed=0
events:SetScript('OnUpdate',function(self,dt)
 if host() and not G.solo and raid() and activeID~='' and GetTime()-lastAdvert>15 then
  lastAdvert=GetTime()
  send('ADVERT',table.concat({activeID,cleanName(tableName),G.host,#G.players,G.phase},';'))
 end
 elapsed=elapsed+dt;if elapsed<0.25 then return end;elapsed=0
 botStep()
 if host() and G.turn~='' and G.timer>0 and GetTime()>=G.deadline then
  local p=player(G.turn)
  if G.phase=='DRAW' then hostAction(G.turn,'DRAW','')
  elseif p and G.bet<=p.paid then hostAction(G.turn,'CHECK','0')
  else hostAction(G.turn,'FOLD','0') end
 end
 if ui.timer then
  if host() and G.turn~='' then ui.timer:SetText('Time: '..math.max(0,math.ceil(G.deadline-GetTime()))..'s')
  elseif G.turn~='' then ui.timer:SetText('Time: '..math.max(0,math.ceil(G.clientDeadline-GetTime()))..'s')
  else ui.timer:SetText('Timer: '..G.timer..'s') end
 end
end)
function R.InitGame()
 if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
 G.history=RaidPokerWotLKDB.history
 local snap=RaidPokerWotLKDB.hostSnapshot
 if snap and validID(snap.tableID) and raid() and snap.host==me() and (snap.phase=='LOBBY' or snap.phase=='SHOWDOWN') then
  activeID=snap.tableID or '';tableName=snap.tableName or 'Restored Table';G.host=me();G.phase=snap.phase;G.round=snap.round or 0;G.pot=0;G.bet=0;G.turn='';G.ante=snap.ante or 10;G.stack=snap.stack or 1000;G.timer=snap.timer or 30;G.winner=snap.winner or '';G.players={}
  for record in string.gmatch(snap.players or '','[^;]+') do local a=split(record,',');if a[1] and a[1]~='' then table.insert(G.players,{name=a[1],balance=tonumber(a[2]) or 0,inhand=false,fold=false,allin=false,paid=0,total=0,done=false,status=a[9] or 'Playing'}) end end
 end
 if raid() then R.DiscoverTables();if activeID~='' then send('SYNC','') end end
end

-- Public, debug-only helpers for the visual diagnostics panel.
function R.DebugNextBot()
 if not G.solo or not host() then return end
 if G.turn==me() then say('It is your turn; use the betting buttons.') return end
 if G.turn=='' then say('No active turn.') return end
 local p=player(G.turn)
 if not p then return end
 if G.phase=='DRAW' then hostAction(p.name,'DRAW','')
 elseif G.phase=='BET1' or G.phase=='BET2' then
  local owed=math.max(0,G.bet-(p.paid or 0))
  if owed==0 then hostAction(p.name,'CHECK','0') else hostAction(p.name,'CALL','0') end
 end
end
function R.DebugForceShowdown()
 if G.solo and host() and (G.phase=='BET1' or G.phase=='DRAW' or G.phase=='BET2') then finishHand('debug') end
end
function R.DebugNewHand()
 if G.solo and host() then startHand() end
end
function R.DebugCredit()
 if not G.solo or not host() or (G.phase~='LOBBY' and G.phase~='SHOWDOWN') then return end
 local p=player(me());if p then p.balance=p.balance+500;log('Debug: +500s to '..me());broadcast() end
end

-- WotLK 0.4.0 management bridge: all mutations remain in the host's game engine.
function R.RequestSync() if not G.solo then send('SYNC','');say('State synchronization requested.') else R.Refresh() end end
function R.SetManagedBalance(name,value) adjustBalance(name,value) end
function R.IsPokerHost() return host() end
function R.CancelManagedHand() cancelHand() end
function R.BroadcastManagedState() if host() then broadcast() end end
function R.AnnounceManaged(kind,channel)
 if not host() then say('Game Master only.');return end
 channel=channel or 'SAY'
 if channel~='RAID' and channel~='SAY' and channel~='YELL' and channel~='GUILD' and channel~='EPOKER' then return end
 local lines={}
 if kind=='WINNER' then if G.winner=='' then say('No winner to announce.');return end;lines[1]='Winner: '..G.winner..' | Pot: '..R.Money(G.lastPot or G.pot)
 elseif kind=='BALANCES' then for _,p in ipairs(G.players) do table.insert(lines,p.name..': '..R.Money(p.balance)) end
 elseif kind=='TABLE' then lines[1]='Table: '..#G.players..' players | '..G.phase..' | Pot: '..R.Money(G.pot) end
 if G.solo then for _,line in ipairs(lines) do say(string.gsub(line,'|',' - ')) end;return end
 local channelId=nil
 if channel=='EPOKER' then
  channelId=GetChannelName and GetChannelName('Epoker') or 0
  if not channelId or channelId==0 then say('Join /Epoker before announcing.');return end
  channel='CHANNEL'
 elseif channel=='RAID' and not raid() then say('Join a raid to announce.');return
 elseif channel=='GUILD' and not IsInGuild() then say('Join a guild to announce.');return end
 for _,line in ipairs(lines) do
  local clean=string.gsub(string.gsub(line,'|',' - '),'[%c]',' ')
  SendChatMessage(string.sub('[Raid Poker] '..clean,1,220),channel,nil,channelId)
 end
end
function R.ResendManagedWinner() if not host() or G.winner=='' then return end;broadcast();send('RESULT',G.winner) end

-- v0.5.0: host-authoritative administration and diagnostics.
function R.EndManagedBetting()
 if not host() or (G.phase~='BET1' and G.phase~='BET2') then return end
 for _,p in ipairs(G.players) do if canAct(p) and (not p.done or p.paid<G.bet) then say('Players still need to act or call.');return end end
 advance()
end
function R.ForceManagedShowdown() if host() and (G.phase=='BET1' or G.phase=='BET2' or G.phase=='DRAW') then finishHand('forced') end end
function R.AdjustManagedBalance(name,delta)
 if not host() or (G.phase~='LOBBY' and G.phase~='SHOWDOWN') then say('Balance changes require host and an inactive hand.');return end
 local p=player(name);if not p then say('Player not found.');return end
 adjustBalance(name,math.max(0,p.balance+(tonumber(delta) or 0)))
end
function R.ResetManagedBalance(name) if host() then adjustBalance(name,G.stack) end end
function R.GetManagedHistory() return G.solo and (G.debugHistory or {}) or (RaidPokerWotLKDB.detailedHistory or {}) end
function R.GetManagedStats() return RaidPokerWotLKDB.statistics or {} end
function R.NetDiagnostics()
 say('Network: '..(G.solo and 'SOLO' or raid() and 'RAID' or 'NO RAID')..' | Host: '..(G.host~='' and G.host or 'unknown')..' | Phase: '..G.phase..' | Players: '..#G.players)
 if not G.solo then send('SYNC','') end
end

function R.DebugBotStyle(style)
 if not G.solo then say('Enable Solo Debug first.');return end
 style=string.upper(tostring(style or ''))
 if style~='PASSIVE' and style~='AGGRESSIVE' and style~='NORMAL' then say('Use /poker botstyle passive, normal, or aggressive.');return end
 G.botStyle=style;say('Solo bot behavior: '..style)
end

-- v0.7.0 safe host-only table management. No new network protocol.
function R.KickManagedPlayer(name)
 if not host() or (G.phase~='LOBBY' and G.phase~='SHOWDOWN') then say('Host only; finish the current hand first.');return end
 if not name or name=='' then return end
 for i,p in ipairs(G.players) do
  if string.lower(p.name)==string.lower(name) then
   table.remove(G.players,i);log(p.name..' removed from table');broadcast();return
  end
 end
 say('Player not found at table.')
end
function R.DebugAssignHand(cards)
 if not G.solo or not host() or (G.phase~='BET1' and G.phase~='DRAW' and G.phase~='BET2') then
  say('Hand assignment requires an active Solo Debug hand.');return
 end
 if type(cards)~='table' or #cards~=5 then return end
 local seen={}
 for _,id in ipairs(cards) do
  if type(id)~='number' or id<1 or id>52 or seen[id] then say('Invalid or duplicate card.');return end
  seen[id]=true
 end
 local p=player(me());if not p or not p.inhand then return end
 p.cards={};G.hand={};G.selected={}
 for i,id in ipairs(cards) do p.cards[i]=id;G.hand[i]=id end
 local _,rank=score(cards)
 say('SOLO TEST hand assigned: '..rank..' (not available in raid mode).')
 R.Refresh()
end

function R.PublishManagedState() if host() then broadcast() end end

-- v1.6.0 authoritative table administration
local function adminRecord(action)
 local entry=date('%m/%d %H:%M')..'  ['..tableName..'] '..me()..': '..action
 RaidPokerWotLKDB.adminHistory=RaidPokerWotLKDB.adminHistory or {}
 table.insert(RaidPokerWotLKDB.adminHistory,1,entry)
 while #RaidPokerWotLKDB.adminHistory>100 do table.remove(RaidPokerWotLKDB.adminHistory) end
 send('ADMINLOG',entry)
 log(action)
 if R.RefreshPlayerManagement then R.RefreshPlayerManagement() end
end
function R.GameMasterName() return G.host end
function R.IsGameMaster() return host() end
function R.AdminSetBalance(name,amount)
 if not host() then say('Game Master only.');return end
 if G.phase~='LOBBY' and G.phase~='SHOWDOWN' then say('Change balances between hands.');return end
 local p=player(name);local n=tonumber(amount)
 if not p or not n or n<0 or n>100000000 then say('Invalid player or amount.');return end
 n=math.floor(n)
 local old=p.balance
 adjustBalance(p.name,n)
 if n==0 and p.status~='Busted' then
  p.status='Busted'
  adminRecord('Auto Busted: '..p.name..' (0g 0s)')
  broadcast()
 elseif n>0 and p.status=='Busted' then
  p.status='Playing'
  adminRecord('Rejoined: '..p.name..' (balance restored)')
  broadcast()
 end
 adminRecord('Balance '..p.name..': '..old..'s -> '..n..'s')
end
function R.AdminSetStatus(name,status)
 if not host() then say('Game Master only.');return end
 if status~='Playing' and status~='Sitting Out' and status~='Busted' then return end
 if G.phase~='LOBBY' and G.phase~='SHOWDOWN' then say('Change status between hands. Use Force Fold during a hand.');return end
 local p=player(name);if not p then say('Player not found.');return end
 p.status=status
 adminRecord(p.name..' status: '..status);broadcast()
end
function R.AdminRemove(name)
 if not host() then say('Game Master only.');return end
 if G.phase~='LOBBY' and G.phase~='SHOWDOWN' then say('Remove players between hands.');return end
 if name==me() then say('Transfer Game Master before removing yourself.');return end
 local p=player(name);if not p then return end
 R.KickManagedPlayer(p.name)
 adminRecord('Removed '..name)
end
function R.AdminForceFold(name)
 if not host() then say('Game Master only.');return end
 if G.phase~='BET1' and G.phase~='DRAW' and G.phase~='BET2' then say('No active hand.');return end
 local p=player(name)
 if not p or not p.inhand or p.fold then say('Player is not in the hand.');return end
 p.fold=true;p.done=true
 adminRecord('Force Fold: '..p.name)
 if G.turn==p.name then doneTurn() else
  if countActive()<=1 then finishHand('forced fold') else broadcast() end
 end
end
function R.AdminTransferGM(name)
 if not host() then say('Game Master only.');return end
 if G.solo then say('GM transfer requires a raid.');return end
 if G.phase~='LOBBY' and G.phase~='SHOWDOWN' then say('Transfer between hands only.');return end
 local p=player(name)
 if not p or p.name==me() or not UnitInRaid(p.name) then say('Choose another seated raid member.');return end
 adminRecord('Transferred Game Master to '..p.name)
 -- The full state is broadcast before the handoff so the recipient has the current balances.
 broadcast()
 send('GMX',p.name)
 G.host=p.name
 if tables[activeID] then tables[activeID].gm=p.name end
 R.Refresh()
end
