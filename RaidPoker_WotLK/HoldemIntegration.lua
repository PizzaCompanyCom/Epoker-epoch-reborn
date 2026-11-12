-- beta4e10: automatic management synchronization, session hygiene, and public updates.
-- No Draw-mode state is accessed. No private cards are broadcast.
local R=RPoker
if not R or not R.Holdem or not R.HoldemMultiplayer or not R.HoldemNetwork then return end
local H,N,M=R.Holdem,R.HoldemNetwork,R.HoldemMultiplayer
local T={events={},dirty=false};R.HoldemIntegration=T
local function me() return UnitName('player') or '' end
local function gm() return N.active and N.owner and N.host==me() end
local function idle() return H.phase=='LOBBY' or H.phase=='SHOWDOWN' end
local function record(msg)
 T.events[#T.events+1]=date('%H:%M:%S')..' '..msg
 if #T.events>60 then table.remove(T.events,1) end
end
local function afterAdmin(action,ok,name)
 if ok and gm() and idle() then
  T.dirty=true
  record(action..(name and (' '..tostring(name)) or ''))
  if R.HoldemManagement and R.HoldemManagement.Refresh then R.HoldemManagement.Refresh() end
  if R.RefreshBarrensTableDesk then R.RefreshBarrensTableDesk() end
  if R.HoldemPreflight and R.HoldemPreflight.Refresh then R.HoldemPreflight.Refresh() end
 end
end
for _,entry in ipairs({{'Assign','SEAT'},{'Remove','REMOVE'},{'SetStack','BALANCE'},{'SitOut','SIT'},{'AutoSeat','AUTO SEAT'}}) do
 local method,action=entry[1],entry[2]
 local previous=M[method]
 if type(previous)=='function' then
  M[method]=function(...)
   local ok,err=previous(...)
   afterAdmin(action,ok,select(1,...))
   return ok,err
  end
 end
end
-- Engine actions are already wrapped by Multiplayer.AfterAction; transmit a public
-- state update immediately after an accepted action instead of waiting for the timer.
local priorAction=H.Action
H.Action=function(action,amount)
 local ok,err=priorAction(action,amount)
 if ok and gm() and M.active and R.HoldemSync and R.HoldemSync.ForceBroadcast then
  R.HoldemSync.ForceBroadcast()
 end
 return ok,err
end
local oldStart=M.StartHand
M.StartHand=function(...)
 local ok,err=oldStart(...)
 if ok and gm() then
  T.dirty=false;record('HAND START '..tostring(H.handNumber))
  if R.HoldemSync and R.HoldemSync.ForceBroadcast then R.HoldemSync.ForceBroadcast() end
 end
 return ok,err
end
local ticker=CreateFrame('Frame');local elapsed=0
local lastSession=nil
local function clearRemote()
 local sync=R.HoldemSync
 if sync then sync.remote=nil;sync.pending=nil;sync.received=0;sync.hostLast=0 end
 local proto=R.HoldemProtocol
 if proto then proto.privateCards={};proto.privateHand=nil;proto.processed={} end
end
ticker:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt;if elapsed<0.75 then return end;elapsed=0
 local identity=N.active and ((N.session or '')..':'..(N.host or '')) or ''
 if identity~=lastSession then
  if lastSession~=nil then clearRemote() end
  lastSession=identity
 end
 if T.dirty and gm() and idle() and not M.active then
  T.dirty=false
  if R.HoldemAdminBridge and R.HoldemAdminBridge.BroadcastSeats then
   local ok=R.HoldemAdminBridge.BroadcastSeats()
   if not ok then T.dirty=true end
  end
 end
end)
function T.RefreshAll()
 if R.HoldemManagement and R.HoldemManagement.Refresh then R.HoldemManagement.Refresh() end
 if R.RefreshBarrensTableDesk then R.RefreshBarrensTableDesk() end
 if R.HoldemPreflight and R.HoldemPreflight.Refresh then R.HoldemPreflight.Refresh() end
 if R.RefreshBarrensControlCenter then R.RefreshBarrensControlCenter() end
end
