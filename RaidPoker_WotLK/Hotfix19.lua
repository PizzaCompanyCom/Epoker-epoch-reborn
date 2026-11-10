-- EpokerWoW Raid Hotfix 19: shared single-table entry and visible action labels.
local R=RPoker
if not R then return end
StaticPopupDialogs['EPOKER_NO_ACTIVE_TABLE']={
 text='No active poker table was found. You can create one in Player Management.',
 button1='Player Management',button2='Cancel',timeout=0,whileDead=1,hideOnEscape=1,
 OnAccept=function()
  if R.BarrensUnifiedMode and R.BarrensUnifiedMode()=='NETWORK' then
   if R.OpenBarrensManagement then R.OpenBarrensManagement() end
  elseif R.HF19LastMode=='HOLDEM' then
   if R.OpenBarrensManagement then R.OpenBarrensManagement() end
  elseif R.TogglePlayerManagement then R.TogglePlayerManagement()
  elseif R.OpenPlayerManagement then R.OpenPlayerManagement() end
 end
}
-- Action events may be followed by pot/phase log lines in the same tick.
-- Track the latest actionable line per hand and never restart an already seen event.
local actionState={DRAW={},HOLDEM={}}
local actionSeen={DRAW={},HOLDEM={}}
local actionColors={CHECK={.2,1,.3},CALL={.2,.75,1},RAISE={1,.8,.2},FOLD={1,.25,.25},ALLIN={1,.52,.16},EXCHANGE={.8,.4,1},STANDPAT={1,1,1}}
function R.HF19ActionColor(a) local c=actionColors[a] or {1,1,1};return c[1],c[2],c[3] end
function R.HF19ActionFromLog(line)
 if type(line)~='string' then return end
 local name,verb=line:match('^([^%s]+)%s+(%a+)')
 if not name then return end
 local names={checks='CHECK',calls='CALL',raises='RAISE',folds='FOLD',exchanged='EXCHANGE',stands='STANDPAT'}
 local action=names[verb]
 if action=='CALL' and line:find('All%-In') then action='ALLIN' end
 return name,action
end
function R.HF19ActionFor(mode,name,log,round)
 if type(log)~='table' or not name then return end
 local key=mode..':'..tostring(round or 0)
 local latest,actor,action
 -- Draw writes newest first; Hold'em appends newest last.
 if mode=='DRAW' then
  for i=1,#log do
   local n,a=R.HF19ActionFromLog(log[i])
   if n and a then latest=i;actor=n;action=a;break end
  end
 else
  for i=#log,1,-1 do
   local n,a=R.HF19ActionFromLog(log[i])
   if n and a then latest=i;actor=n;action=a;break end
  end
 end
 if latest then
  local event=key..':'..tostring(latest)..':'..log[latest]
  if actionSeen[mode][actor]~=event then
   actionSeen[mode][actor]=event
   local now=GetTime()
   actionState[mode][actor]={action=action,started=now,untilTime=now+3,roundKey=key}
  end
 end
 local v=actionState[mode][name]
 if v and v.roundKey==key and v.untilTime>GetTime() then return v.action end
end

function R.HF19ActionExpiry(mode,name)
 local v=actionState[mode] and actionState[mode][name]
 return v and v.untilTime or 0
end
