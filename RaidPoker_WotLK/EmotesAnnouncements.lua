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
  if d[mode..'Actions']==nil then d[mode..'Actions']=true end
  if d[mode..'ActionChannel']==nil then d[mode..'ActionChannel']='SAY' end
 end
 return d
end
local function channelValid(ch)
 if ch=='RAID' then return IsInRaid and IsInRaid() or GetNumRaidMembers()>0 end
 if ch=='GUILD' then return IsInGuild() end
 return true
end
local function send(text,ch)
 if not channelValid(ch) then if R.Print then R.Print('Channel '..ch..' unavailable.') end return end
 SendChatMessage(string.sub(text,1,230),ch)
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
 local f=CreateFrame('Frame','RaidPokerEmotes'..mode,UIParent);f:SetSize(470,365);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetMovable(true);f:EnableMouse(true);f:SetClampedToScreen(true)
 f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=9,right=9,top=9,bottom=9}})
 f:SetScript('OnMouseDown',function(self,button)if button=='LeftButton' then self:StartMoving()end end)
 f:SetScript('OnMouseUp',function(self)self:StopMovingOrSizing()end)
 label(f,'EMOTES & ANNOUNCEMENTS  -  '..(mode=='DRAW' and '5-CARD DRAW' or "HOLD'EM"),20,-19)
 btn(f,'X',430,-12,25,function()f:Hide()end)
 label(f,'PLAYER EMOTES',22,-62)
 local emotes={{'Cry','/cry','Ability_Creature_Cursed_01'},{'Cheer','/cheer','INV_Misc_EngGizmos_19'},{'Roar','/roar','Ability_Druid_ChallangingRoar'},{'Train','/train','INV_Misc_Toy_10'},{'Chicken','/chicken','Spell_Magic_PolymorphChicken'}}
 for i,v in ipairs(emotes) do
  local b=btn(f,v[1],18+(i-1)*89,-85,86,function()if DoEmote then DoEmote(string.upper(string.sub(v[2],2)))end end)
  local ico=b:CreateTexture(nil,'OVERLAY');ico:SetTexture('Interface\\Icons\\'..v[3]);ico:SetSize(16,16);ico:SetPoint('LEFT',b,4,0)
 end
 label(f,'LAST HAND WINNER',22,-134)
 local winnerPreview=label(f,'No completed hand yet',22,-156);winnerPreview:SetWidth(425);winnerPreview:SetJustifyH('LEFT')
 label(f,'Winner channel:',22,-188)
 local channels={'SAY','YELL','GUILD','RAID'}
 local c=btn(f,'',155,-180,130,function(self)
  local d=config();local idx=1
  for i,v in ipairs(channels) do if v==(d[mode..'WinnerChannel'] or 'RAID') then idx=i end end
  d[mode..'WinnerChannel']=channels[idx%#channels+1];self:SetText('/'..string.lower(d[mode..'WinnerChannel']))
 end)
 btn(f,'Announce Winner',295,-180,150,function()
  local r=result(mode);if not r then if R.Print then R.Print('No completed hand result available.')end return end
  send('[EpokerWoW] Winner: '..r,config()[mode..'WinnerChannel'] or 'RAID')
 end)
 label(f,'BETTING ACTION ANNOUNCEMENTS',22,-234)
 local toggle=btn(f,'',22,-257,250,function(self)
  local d=config();d[mode..'Actions']=not d[mode..'Actions'];self:SetText('Auto Announce: '..(d[mode..'Actions'] and 'ON' or 'OFF'))
 end)
 local actionChannel=btn(f,'',282,-257,162,function(self)
  local d=config();d[mode..'ActionChannel']=(d[mode..'ActionChannel']=='SAY' and 'RAID' or 'SAY');self:SetText('Channel: /'..string.lower(d[mode..'ActionChannel']))
 end)
 label(f,'Check / Call / Raise / Fold / All-In',22,-302)
 label(f,'Only your actions are announced. No automatic gold transfer.',22,-326)
 f:SetScript('OnShow',function()
  local d=config()
  c:SetText('/'..string.lower(d[mode..'WinnerChannel'] or 'RAID'))
  toggle:SetText('Auto Announce: '..(d[mode..'Actions'] and 'ON' or 'OFF'))
  actionChannel:SetText('Channel: /'..string.lower(d[mode..'ActionChannel'] or 'SAY'))
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
