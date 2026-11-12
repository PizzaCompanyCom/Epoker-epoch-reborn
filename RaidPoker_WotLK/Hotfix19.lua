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
local logCursor={DRAW={key=nil,lines={}},HOLDEM={key=nil,lines={}}}
local actionColors={CHECK={.2,1,.3},CALL={.2,.75,1},RAISE={1,.8,.2},FOLD={1,.25,.25},ALLIN={1,.52,.16},EXCHANGE={.8,.4,1},STANDPAT={1,1,1}}
function R.HF19ActionColor(a) local c=actionColors[a] or {1,1,1};return c[1],c[2],c[3] end
function R.HF19ActionFromLog(line)
 if type(line)~='string' then return end
 local name,verb
 for _,candidate in ipairs({'checks','calls','raises','folds','exchanged','stands'}) do
  local prefix=line:match('^(.-)%s+'..candidate..'%f[%A]')
  if prefix and prefix~='' then name=prefix;verb=candidate;break end
 end
 if not name then return end
 local names={checks='CHECK',calls='CALL',raises='RAISE',folds='FOLD',exchanged='EXCHANGE',stands='STANDPAT'}
 local action=names[verb]
 if (action=='CALL' or action=='RAISE') and line:find('All%-In') then action='ALLIN' end
 return name,action
end
function R.HF19ActionFor(mode,name,log,round)
 if type(log)~='table' or not name or not logCursor[mode] then return end
 local key=tostring(round or 0)
 local cursor=logCursor[mode]
 if cursor.key~=key then
  cursor.key=key;cursor.lines={};actionState[mode]={}
 end
 local old=cursor.lines
 -- The Hold'em log is chronological and capped at 30 entries. Find the
 -- overlapping suffix/prefix so repeated redraws never refresh badge timers.
 local overlap=0
 if mode=='HOLDEM' then
  for n=math.min(#old,#log),1,-1 do
   local same=true
   for j=1,n do if old[#old-n+j]~=log[j] then same=false;break end end
   if same then overlap=n;break end
  end
 else
  -- Draw history is newest-first; find overlap with the previous prefix.
  for n=math.min(#old,#log),1,-1 do
   local same=true
   for j=1,n do if old[j]~=log[#log-n+j] then same=false;break end end
   if same then overlap=n;break end
  end
 end
 if mode=='HOLDEM' then
  for i=overlap+1,#log do
   local n,action=R.HF19ActionFromLog(log[i])
   if n and action then actionState[mode][n]={action=action,untilTime=GetTime()+3} end
  end
 else
  for i=#log-overlap,1,-1 do
   local n,action=R.HF19ActionFromLog(log[i])
   if n and action then actionState[mode][n]={action=action,untilTime=GetTime()+3} end
  end
 end
 cursor.lines={}
 for i=1,#log do cursor.lines[i]=log[i] end
 local v=actionState[mode][name]
 if v and v.untilTime>GetTime() then return v.action end
end

function R.HF19ActionExpiry(mode,name)
 local v=actionState[mode] and actionState[mode][name]
 return v and v.untilTime or 0
end
