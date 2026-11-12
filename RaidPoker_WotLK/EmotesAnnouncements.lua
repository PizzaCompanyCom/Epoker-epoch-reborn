-- EpokerWoW Raid RC1 Hotfix 13: shared emotes and chat announcements (WoW 3.3.5a)
local R=RPoker
if not R then return end
local frames={}
local function config()
 RaidPokerWotLKDB=RaidPokerWotLKDB or {}
 local db=RaidPokerWotLKDB
 db.emoteAnnouncements=db.emoteAnnouncements or {}
 local d=db.emoteAnnouncements
 for _,mode in ipairs({'DRAW','HOLDEM'}) do
  if d[mode..'Actions']==nil then d[mode..'Actions']=false end
  if d[mode..'ActionChannel']==nil then d[mode..'ActionChannel']='SAY' end
 end
 return d
end
local function channelValid(ch)
 if ch=='RAID' then return IsInRaid and IsInRaid() or GetNumRaidMembers()>0 end
 if ch=='GUILD' then return IsInGuild() end
 if ch=='CHANNEL' then return GetChannelName('Epoker') and GetChannelName('Epoker')>0 end
 return true
end
local function send(text,ch)
 if not channelValid(ch) then if R.Print then R.Print('Channel '..ch..' unavailable.') end return end
 if ch=='CHANNEL' then SendChatMessage(string.sub(text,1,230),'CHANNEL',nil,GetChannelName('Epoker'))
 else SendChatMessage(string.sub(text,1,230),ch) end
end
local function cash(s)
 s=math.max(0,math.floor(tonumber(s) or 0));return math.floor(s/100)..'g '..(s%100)..'s'
end
local function result(mode)
 if mode=='DRAW' then
  local g=R.G
  if not g or not g.winner or g.winner=='' or g.phase~='SHOWDOWN' then return nil end
  if string.find(g.winner,'cancelled') then return nil end
  return '5-Card Draw | '..string.gsub(g.winner,';','; ') -- includes payout and combination for showdown
 end
 local s=R.BarrensUnifiedSnapshot and R.BarrensUnifiedSnapshot()
 if not s or s.phase~='SHOWDOWN' or not s.winners then return nil end
 local list={}
 for seat,amount in pairs(s.winners) do
  if tonumber(amount) and tonumber(amount)>0 then
   local p=s.players and s.players[tonumber(seat)]
   list[#list+1]=(p and p.name or 'Seat '..tostring(seat))..' +'..cash(amount)
  end
 end
 table.sort(list)
 if #list==0 then return nil end
 -- Public Hold'em snapshot does not expose the winning five-card hand category.
 return "Hold'em | "..table.concat(list,'; ')..' | Hand: not available'
end
local function btn(parent,text,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,27);b:SetPoint('TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',fn);return b
end
local function label(parent,text,x,y)
 local t=parent:CreateFontString(nil,'OVERLAY','GameFontNormal');t:SetPoint('TOPLEFT',x,y);t:SetText(text);return t
end
local function window(mode)
 if frames[mode] then return frames[mode] end
 local f=CreateFrame('Frame','RaidPokerEmotes'..mode,UIParent);f:SetSize(470,410);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetMovable(true);f:EnableMouse(true);f:SetClampedToScreen(true)
 f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=9,right=9,top=9,bottom=9}})
 f:SetScript('OnMouseDown',function(self,button)if button=='LeftButton' then self:StartMoving()end end)
 f:SetScript('OnMouseUp',function(self)self:StopMovingOrSizing()end)
 label(f,'EMOTES & ANNOUNCEMENTS  -  '..(mode=='DRAW' and '5-CARD DRAW' or "HOLD'EM"),20,-19)
 btn(f,'X',430,-12,25,function()f:Hide()end)
 local joinChannel=btn(f,'Join /Epoker Channel',22,-51,205,function()
  if GetChannelName('Epoker') and GetChannelName('Epoker')>0 then
   if R.Print then R.Print('Already joined Epoker channel.') end
  elseif JoinChannelByName then JoinChannelByName('Epoker')
  elseif ChatFrame1EditBox then ChatFrame1EditBox:SetText('/join Epoker');ChatEdit_SendText(ChatFrame1EditBox,0) end
 end)
 local ic=joinChannel:CreateTexture(nil,'OVERLAY');ic:SetTexture('Interface\\Icons\\INV_Misc_Note_01');ic:SetSize(16,16);ic:SetPoint('LEFT',joinChannel,5,0)
 label(f,'PLAYER EMOTES',22,-89)
 local emotes={{'Cry','/cry','Ability_Creature_Cursed_01'},{'Cheer','/cheer','INV_Misc_EngGizmos_19'},{'Roar','/roar','Ability_Druid_ChallangingRoar'},{'Train','/train','INV_Misc_Toy_10'},{'Chicken','/chicken','Spell_Magic_PolymorphChicken'}}
 for i,v in ipairs(emotes) do
  local b=btn(f,v[1],18+(i-1)*89,-112,86,function()if DoEmote then DoEmote(string.upper(string.sub(v[2],2)))end end)
  local ico=b:CreateTexture(nil,'OVERLAY');ico:SetTexture('Interface\\Icons\\'..v[3]);ico:SetSize(16,16);ico:SetPoint('LEFT',b,4,0)
 end
 label(f,'LAST HAND WINNER',22,-162)
 local winnerPreview=label(f,'No completed hand yet',22,-184);winnerPreview:SetWidth(425);winnerPreview:SetJustifyH('LEFT')
 label(f,'Winner channel:',22,-216)
 local channels={'SAY','YELL','GUILD','RAID','CHANNEL'}
 local c=btn(f,'',155,-208,130,function(self)
  local d=config();local idx=1
  for i,v in ipairs(channels) do if v==(d[mode..'WinnerChannel'] or 'RAID') then idx=i end end
  d[mode..'WinnerChannel']=channels[idx%#channels+1];self:SetText((d[mode..'WinnerChannel']=='CHANNEL' and '/Epoker' or '/'..string.lower(d[mode..'WinnerChannel'])))
 end)
 btn(f,'Announce Winner',295,-208,150,function()
  local r=result(mode);if not r then if R.Print then R.Print('No completed hand result available.')end return end
  send('[EpokerWoW] Winner: '..r,config()[mode..'WinnerChannel'] or 'RAID')
 end)
 label(f,'BETTING ACTION ANNOUNCEMENTS',22,-262)
 local toggle=btn(f,'',22,-285,250,function(self)
  local d=config();d[mode..'Actions']=not d[mode..'Actions'];self:SetText('Auto Announce: '..(d[mode..'Actions'] and 'ON' or 'OFF'))
 end)
 local actionChannel=btn(f,'',282,-285,162,function(self)
  local d=config();local channels={'SAY','RAID','CHANNEL'};local i=1
  for j,v in ipairs(channels) do if v==d[mode..'ActionChannel'] then i=j end end
  d[mode..'ActionChannel']=channels[i%#channels+1]
  self:SetText('Channel: '..(d[mode..'ActionChannel']=='CHANNEL' and '/Epoker' or '/'..string.lower(d[mode..'ActionChannel'])))
 end)
 label(f,'Check / Call / Raise / Fold / All-In',22,-330)
 label(f,'Only your actions are announced. No automatic gold transfer.',22,-354)
 f:SetScript('OnShow',function()
  local d=config()
  c:SetText((d[mode..'WinnerChannel']=='CHANNEL' and '/Epoker' or '/'..string.lower(d[mode..'WinnerChannel'] or 'RAID')))
  toggle:SetText('Auto Announce: '..(d[mode..'Actions'] and 'ON' or 'OFF'))
  actionChannel:SetText('Channel: '..(d[mode..'ActionChannel']=='CHANNEL' and '/Epoker' or '/'..string.lower(d[mode..'ActionChannel'] or 'SAY')))
  local r=result(mode);winnerPreview:SetText(r and string.sub(r,1,75) or 'No completed hand yet')
 end)
 f:Hide();frames[mode]=f;return f
end
function R.ToggleEmotesAnnouncements(mode)
 mode=(mode=='HOLDEM') and 'HOLDEM' or 'DRAW'
 local f=window(mode);if f:IsShown() then f:Hide() else f:Show();f:Raise()end
end
function R.AnnounceLocalPokerAction(mode,action,amount)
 local d=config();if not d[mode..'Actions'] then return end
 local a=({CHECK='Check',CALL='Call',RAISE='Raise',FOLD='Fold',ALLIN='All-In'})[action]
 if not a then return end
 local suffix=(action=='RAISE' and tonumber(amount) and tonumber(amount)>0) and (' ('..cash(amount)..')') or ''
 send('[EpokerWoW] '..UnitName('player')..': '..a..suffix,d[mode..'ActionChannel'] or 'SAY')
end
