-- EpokerWoW Raid RC1: Hold'em turn timer shared UI convention with 5-Card Draw.
-- WoW 3.3.5a / Lua 5.1. Host authoritative timeout; public turn state only.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local PREFIX='EPRTMR1'
local duration=30
local key=nil
local deadline=nil
local lastBroadcast=nil
local elapsed=0
local function network()
 return R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK'
end
local function gm()
 local n=R.HoldemNetwork
 return n and n.active and n.owner and n.host==UnitName('player')
end
local function host() return not network() or gm() end
local function idle()
 local s=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot()
 return not s or s.phase=='LOBBY' or s.phase=='SHOWDOWN'
end
local function valid(v)
 v=tonumber(v)
 return v==0 or v==15 or v==30 or v==60
end
local function db()
 RaidPokerWotLKDB=RaidPokerWotLKDB or {}
 return RaidPokerWotLKDB
end
local function load()
 local v=tonumber(db().barrensTurnTimer)
 duration=valid(v) and v or 30
end
load()
local function announce()
 local n=R.HoldemNetwork
 if network() and gm() and n.session and GetNumRaidMembers and GetNumRaidMembers()>0 then
  SendAddonMessage(PREFIX,'D|'..tostring(n.session)..'|'..duration,'RAID')
 end
end
function R.RefreshBarrensTimerSetting()
 local f=_G.RaidPokerBarrensManagement
 if f and f.barrensTurnTimerButton then
  f.barrensTurnTimerButton:SetText('Turn Timer: '..(duration==0 and 'OFF' or duration..'s'))
 end
 local leader=_G.RaidPokerBarrensLeaderControls
 if leader and leader.timerButton then leader.timerButton:SetText('Turn Timer: '..(duration==0 and 'OFF' or duration..'s')) end
end
function R.CycleBarrensTurnTimer()
 if not host() then if R.Print then R.Print('Turn Timer: Game Master only.') end return end
 if network() and not idle() then if R.Print then R.Print('Change the timer between hands.') end return end
 duration=(duration==15 and 30 or duration==30 and 60 or duration==60 and 0 or 15)
 db().barrensTurnTimer=duration
 key=nil;deadline=nil
 R.RefreshBarrensTimerSetting()
 announce()
end
local function snapshot()
 return R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot() or H.GetPublicSnapshot()
end
local function turnKey(s)
 if not s or not s.actionSeat or s.phase=='LOBBY' or s.phase=='SHOWDOWN' then return nil end
 local p=s.players and s.players[s.actionSeat]
 return table.concat({tostring(network()),tostring(s.handNumber or 0),tostring(s.phase),tostring(s.actionSeat),tostring(p and p.name or ''),tostring(s.currentBet or 0)},':')
end
local function updateTurn(s)
 local k=turnKey(s)
 if k~=key then
  key=k
  deadline=k and duration>0 and (GetTime()+duration) or nil
  if network() and gm() and k and k~=lastBroadcast then
   lastBroadcast=k
   announce()
  end
 end
end
function R.GetBarrensTurnTimerProgress(s)
 updateTurn(s)
 if not key or duration==0 then return 0,false end
 local remain=deadline and math.max(0,deadline-GetTime()) or duration
 return math.max(0,math.min(1,remain/duration)),true
end
function R.GetBarrensTurnTimerText(s)
 updateTurn(s)
 if not key then return 'Waiting for players' end
 if duration==0 then return 'Turn Timer: OFF' end
 local remain=deadline and math.max(0,math.ceil(deadline-GetTime())) or duration
 return 'Turn Timer: '..remain..'s'
end
local events=CreateFrame('Frame')
events:RegisterEvent('CHAT_MSG_ADDON')
events:SetScript('OnEvent',function(self,event,prefix,msg,channel,sender)
 if prefix~=PREFIX or not network() or not sender then return end
 local n=R.HoldemNetwork
 if not n or not n.active or sender~=n.host then return end
 local kind,session,v=string.match(msg or '','^(%u)|([^|]+)|(%d+)$')
 if kind~='D' or tostring(session)~=tostring(n.session) or not valid(v) then return end
 duration=tonumber(v)
 key=nil;deadline=nil
 R.RefreshBarrensTimerSetting()
end)
local ticker=CreateFrame('Frame')
ticker:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt
 if elapsed<0.2 then return end
 elapsed=0
 local s=snapshot()
 updateTurn(s)
 if not deadline or GetTime()<deadline or not host() then return end
 -- The engine alone determines whether CHECK is legal. If not, fold.
 deadline=nil
 local p=s and s.players and s.players[s.actionSeat or 0]
 if not p then return end
 local due=math.max(0,(tonumber(s.currentBet) or 0)-(tonumber(p.street or p.streetBet or p.bet) or 0))
 local action=due==0 and 'CHECK' or 'FOLD'
 local ok=H.Action(action)
 if ok and network() and R.HoldemSync and R.HoldemSync.ForceBroadcast then
  R.HoldemSync.ForceBroadcast()
 end
end)
