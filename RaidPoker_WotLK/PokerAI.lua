-- Poker AI 2.0: local solo opponents only. No network messages or state mutation.
local R=RPoker
if not R then return end
local AI={}
R.PokerAI=AI
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function rank(c)
 if type(c)=='number' then return ((c-1)%13)+2 end
 return type(c)=='table' and tonumber(c.rank) or 2
end
local function suit(c)
 if type(c)=='number' then return math.floor((c-1)/13) end
 return type(c)=='table' and c.suit or 0
end
local function strength(cards)
 local n=#(cards or {});if n==0 then return 0,{},{} end
 local counts,sc={},{};local hi=2
 for _,c in ipairs(cards) do local r=rank(c);counts[r]=(counts[r] or 0)+1;sc[suit(c)]=(sc[suit(c)] or 0)+1;hi=math.max(hi,r) end
 local pair,three,four=0,0,0
 for _,v in pairs(counts) do if v==2 then pair=pair+1 elseif v==3 then three=three+1 elseif v==4 then four=four+1 end end
 local flush=false;for _,v in pairs(sc) do if v>=5 then flush=true end end
 local present={};for r in pairs(counts) do present[r]=true end;if present[14] then present[1]=true end
 local straight=false
 for h=14,5,-1 do local ok=true;for j=0,4 do if not present[h-j] then ok=false;break end end;if ok then straight=true;break end end
 local power=hi/70
 if pair>0 then power=0.29+hi/100 end
 if pair>=2 then power=0.48+hi/100 end
 if three>0 then power=0.64+hi/110 end
 if straight then power=0.77 end
 if flush then power=0.82 end
 if three>0 and pair>0 then power=0.90 end
 if four>0 then power=0.97 end
 if flush and straight then power=1 end
 return clamp(power,0,1),counts,sc
end
function AI.DrawExchange(cards)
 local power,counts,sc=strength(cards)
 local keep={};local flushSuit=nil
 for s,n in pairs(sc) do if n==4 then flushSuit=s end end
 if power>=0.77 then return '' end
 if flushSuit and power<0.48 then
  for i,c in ipairs(cards) do if suit(c)~=flushSuit then return tostring(i) end end
 end
 for i,c in ipairs(cards or {}) do if (counts[rank(c)] or 0)>=2 then keep[i]=true end end
 local picks={}
 for i,c in ipairs(cards or {}) do if not keep[i] then picks[#picks+1]=i end end
 if #picks>3 then while #picks>3 do table.remove(picks,1) end end
 return table.concat(picks,',')
end
function AI.DrawBet(p,owed,pot,style)
 local power=strength(p.cards or {})
 local stack=math.max(0,tonumber(p.balance) or 0)
 local aggression=style=='AGGRESSIVE' and 0.13 or style=='PASSIVE' and -0.12 or 0
 local pressure=owed/math.max(1,pot+owed)
 if owed>0 and stack>owed and power+aggression<0.23+pressure*0.65 then return 'FOLD','0' end
 if owed==0 then
  if stack>20 and power+aggression>0.58 and math.random()<0.50 then return 'RAISE',tostring(math.min(stack,math.max(10,math.floor(stack*0.09)))) end
  return 'CHECK','0'
 end
 if stack<=owed then return 'CALL','0' end
 if power+aggression>0.70 and math.random()<0.42 then
  local extra=math.min(stack-owed,math.max(10,math.floor((pot+owed)*0.28)))
  if extra>0 then return 'RAISE',tostring(owed+extra) end
 end
 return 'CALL','0'
end
function AI.HoldemBet(p,board,due,pot,minRaise)
 local cards={};for _,c in ipairs(board or {}) do cards[#cards+1]=c end
 for _,c in ipairs(p.hole or {}) do cards[#cards+1]=c end
 local power=strength(cards)
 local stack=math.max(0,tonumber(p.stack) or 0)
 local street=tonumber(p.street) or 0
 local canRaise=p.raiseAllowed~=false
 if #cards==2 then
  local a,b=rank(cards[1]),rank(cards[2]);power=clamp(0.20+(a+b)/75+(a==b and 0.30 or 0)+(suit(cards[1])==suit(cards[2]) and 0.06 or 0),0,1)
 elseif #cards<5 then power=clamp(power+0.13,0,1) end
 local pressure=due/math.max(1,pot+due)
 if due>0 and stack>due and power<0.28+pressure*0.45 then return 'FOLD' end
 if stack<=due and due>0 then return 'ALLIN' end
 local raise=math.max(1,math.floor(tonumber(minRaise) or 10))
 if canRaise and stack>=due+raise and power>0.72 and math.random()<0.37 then
  return 'RAISE',math.min(stack-due,math.max(raise,math.floor(math.max(pot,raise)*0.3)))
 end
 if due==0 then return 'CHECK' end
 return 'CALL'
end
