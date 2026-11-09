-- EpokerWoW Raid RC1 Hotfix 12: raid peer addon-version discovery.
-- Version is self-reported; it is a compatibility hint, not authentication.
local R=RPoker
if not R then return end
local PREFIX='EPRVER1'
local peers={}
local lastQuery=0
local function selfName() return UnitName('player') or '' end
local function myVersion()
 local v=GetAddOnMetadata and GetAddOnMetadata('RaidPoker_WotLK','Version')
 return tostring(v or R.version or 'Unknown'):sub(1,35)
end
local function inRaid(name)
 if not GetNumRaidMembers or GetNumRaidMembers()==0 then return false end
 for i=1,GetNumRaidMembers() do
  local n=GetRaidRosterInfo(i)
  if n==name then return true end
 end
 return false
end
local function send(msg)
 if SendAddonMessage and GetNumRaidMembers and GetNumRaidMembers()>0 then
  SendAddonMessage(PREFIX,msg,'RAID')
 end
end
function R.GetPokerPeerVersion(name)
 if not name then return nil end
 if name==selfName() then return myVersion() end
 return peers[name]
end
function R.PokerVersionMatches(name)
 local v=R.GetPokerPeerVersion(name)
 if not v then return nil end
 return v==myVersion()
end
function R.RequestPokerPeerVersions()
 local now=GetTime and GetTime() or 0
 if now-lastQuery<3 then return end
 lastQuery=now
 send('Q')
end
local ev=CreateFrame('Frame')
ev:RegisterEvent('PLAYER_LOGIN')
ev:RegisterEvent('CHAT_MSG_ADDON')
ev:RegisterEvent('RAID_ROSTER_UPDATE')
ev:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
  return
 elseif event=='RAID_ROSTER_UPDATE' then
  for name in pairs(peers) do if not inRaid(name) then peers[name]=nil end end
  return
 end
 local prefix,msg,channel,sender=...
 if prefix~=PREFIX or channel~='RAID' or not inRaid(sender) or sender==selfName() then return end
 if msg=='Q' then
  send('V|'..myVersion())
 elseif type(msg)=='string' then
  local version=msg:match('^V|([%w%._%-]+)$')
  if version and #version<=35 then
   peers[sender]=version
   if R.HoldemManagement and R.HoldemManagement.Refresh then R.HoldemManagement.Refresh() end
   if R.RefreshPlayerManagement then R.RefreshPlayerManagement() end
  end
 end
end)
