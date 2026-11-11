-- HF33 Fix30b: event sounds for both modes. Loaded after all poker UI modules.
local R=RPoker
if not R then return end
local function cue(name,kind)
 local db=RaidPokerWotLKDB
 if db and db.uiSound==false then return end
 if db and db.pokerSoundEvents and db.pokerSoundEvents[kind]==false then return end
 if PlaySound then PlaySound(name) end
end
-- Button feedback is separate from the player-join sound.
-- Hook only addon-owned buttons, including those created after addon load.
local function normalized(s)
 s=tostring(s or ''):lower()
 s=s:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
 s=s:gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
 return s
end
local function excluded(label)
 local s=normalized(label)
 if s=='' then return false end
 if s=='call' or s=='raise' or s=='fold' or s=='all-in' or s=='all in' or s=='all-in!' or s=='all in!' then return true end
 if s=='exchange' or s=='stand pat' or s=='stand pot' or s=='apply raise' then return true end
 if s=='pot' or s=='1/4 pot' or s=='1/2 pot' or s=='¼ pot' or s=='½ pot' then return true end
 if s:match('^%+%s*10%s*s$') or s:match('^%+%s*50%s*s$') or s:match('^%+%s*100%s*s$') then return true end
 return false
end
local function owned(button)
 local parent=button
 for i=1,20 do
  if not parent or parent==UIParent then return false end
  if parent==R.Main or parent==R.SettingsFrame or parent==R.TableFrame then return true end
  local name=parent.GetName and parent:GetName()
  if name and (name:find('^RaidPoker') or name:find('^RaidFivePoker') or name:find('^Barrens') or name:find('^Holdem')) then return true end
  parent=parent.GetParent and parent:GetParent()
 end
 return false
end
local function hookButton(button)
 if not button or button.epokerFix30gButtonHook or not button.HookScript then return end
 button.epokerFix30gButtonHook=true
 button:HookScript('OnClick',function(self)
  local label=self.GetText and self:GetText()
  if not excluded(label) then cue('gsCharacterSelection','button') end
 end)
end
if R.Button and not R.epokerFix30gButtonWrapped then
 local original=R.Button
 R.Button=function(...)
  local b=original(...)
  if b and owned(b) then hookButton(b) end
  return b
 end
 R.epokerFix30gButtonWrapped=true
end
local function scanButtons()
 if not EnumerateFrames then return end
 local frame=EnumerateFrames()
 while frame do
  if frame.IsObjectType and frame:IsObjectType('Button') and owned(frame) then hookButton(frame) end
  frame=EnumerateFrames(frame)
 end
end
local function snapshot(players)
 local found={}
 for _,p in ipairs(players or {}) do if p and p.name and not tostring(p.name):match('^DebugBot%d+$') then found[p.name]=true end end
 return found
end
local function newMember(old,now)
 if not old then return false end
 for name in pairs(now) do if not old[name] then return true end end
 return false
end
local oldDraw,oldHoldem,drawRound,holdemHand,exchangeKey
local initialized=false
local function update()
 local g=R.G
 if g then
  local now=snapshot(g.players)
  if initialized and newMember(oldDraw,now) then cue('igPlayerInvite','join') end
  oldDraw=now
  -- One deal cue per new 5-Card Draw round, never on passive refresh.
  local round=tonumber(g.round) or 0
  if initialized and drawRound and round>drawRound and g.phase~='LOBBY' and g.phase~='IDLE' then
   cue('igCharacterInfoTab','deal')
  end
  drawRound=round
  -- A single exchange-turn cue, including when the General window is closed.
  local me=UnitName and UnitName('player') or ''
  local isMine=g.phase=='DRAW' and g.turn==me and me~=''
  local key=isMine and (tostring(round)..':'..me) or nil
  if key and key~=exchangeKey then cue('gsCharacterSelection','turn') end
  exchangeKey=key
 end
 local h=R.Holdem
 if h then
  local now=snapshot(h.players)
  if initialized and newMember(oldHoldem,now) then cue('igPlayerInvite','join') end
  oldHoldem=now
  local snap=(R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot()) or (h.GetPublicSnapshot and h.GetPublicSnapshot())
  local hand=snap and tonumber(snap.handNumber) or tonumber(h.handNumber) or 0
  local phase=snap and snap.phase or h.phase
  if initialized and holdemHand~=nil and hand>holdemHand and phase~='LOBBY' and phase~='IDLE' then cue('igCharacterInfoTab','deal') end
  holdemHand=hand
 end
 initialized=true
end
local f=CreateFrame('Frame')
local elapsed=0
f:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt
 if elapsed<0.35 then return end
 elapsed=0
 update()
 scanButtons()
end)
