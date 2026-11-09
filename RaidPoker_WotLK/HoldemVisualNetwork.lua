-- The Barrens Hold'em beta4c6: visual network spectator table.
-- Uses only synchronized public state and the local player's private cards.
-- WotLK 3.3.5a, Lua 5.1. No changes to Draw or betting engine.
local R=RPoker
if not R or not R.Holdem or not R.HoldemNetwork then return end
local H,N=R.Holdem,R.HoldemNetwork
local V={};R.HoldemVisualNetwork=V
local win,headline,phaseText,potText,notice,board,private,seats,turnGlow
local function money(n)
 n=math.max(0,math.floor(tonumber(n) or 0))
 return math.floor(n/100)..'g '..(n%100)..'s'
end
local function state()
 if not N.active then return nil end
 if N.owner then
  if R.HoldemMultiplayer and R.HoldemMultiplayer.active then return H end
  return nil
 end
 return R.HoldemSync and R.HoldemSync.remote
end
local function text(parent,style)
 local f=parent:CreateFontString(nil,'OVERLAY',style or 'GameFontHighlightSmall')
 f:SetJustifyH('CENTER');return f
end
local function rectangle(parent,w,h,r,g,b,a,layer)
 local t=parent:CreateTexture(nil,layer or 'BACKGROUND')
 t:SetTexture('Interface\\Buttons\\WHITE8X8');t:SetSize(w,h)
 t:SetVertexColor(r,g,b,a or 1);return t
end
local function card(parent,w,h)
 local f=CreateFrame('Frame',nil,parent);f:SetSize(w,h)
 local border=rectangle(f,w,h,.76,.57,.26,1);border:SetPoint('CENTER')
 local face=rectangle(f,w-4,h-4,.06,.12,.21,1);face:SetPoint('CENTER')
 local art=f:CreateTexture(nil,'ARTWORK');art:SetPoint('TOPLEFT',f,2,-2);art:SetPoint('BOTTOMRIGHT',f,-2,2)
 local label=text(f,'GameFontNormalSmall');label:SetPoint('CENTER');label:SetText('RAID')
 function f:SetValue(c,hidden)
  if hidden then art:Hide();face:SetVertexColor(.06,.12,.21,1);label:SetText('RAID');label:Show();return end
  local rank,suit
  if type(c)=='table' then rank=c.rank;suit=c.suit
  elseif type(c)=='string' then rank,suit=c:match('^(%d+)([SHDC])$');if not rank then rank,suit=c:match('^([JQKA])([SHDC])$') end end
  if rank and suit then
   rank=tostring(rank)
   local names={['11']='J',['12']='Q',['13']='K',['14']='A'}
   local alt=names[rank] or rank
   art:SetTexture('Interface\\AddOns\\RaidPoker_WotLK\\Cards\\'..alt..suit..'.tga')
   art:Show();face:SetVertexColor(.94,.92,.83,1);label:Hide()
  else art:Hide();face:SetVertexColor(.12,.16,.18,1);label:SetText('--');label:Show() end
 end
 f:SetValue(nil,false)
 return f
end
local function button(parent,title,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,23);b:SetPoint('TOPLEFT',parent,x,y);b:SetText(title);b:SetScript('OnClick',fn)
 return b
end
local positions={{0,202},{-204,177},{-310,79},{-310,-60},{-205,-177},{0,-202},{205,-177},{310,-60},{310,79},{204,177}}
local function create()
 if win then return end
 win=CreateFrame('Frame','RaidPokerBarrensVisualNetwork',UIParent)
 win:SetSize(850,650);win:SetPoint('CENTER');win:SetFrameStrata('DIALOG')
 win:SetMovable(true);win:EnableMouse(true);win:SetClampedToScreen(true)
 win:RegisterForDrag('LeftButton');win:SetScript('OnDragStart',function(self)self:StartMoving()end)
 win:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 win:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 local felt=CreateFrame('Frame',nil,win);felt:SetSize(770,490);felt:SetPoint('CENTER',win,'CENTER',0,5)
 local surface=rectangle(felt,770,490,.07,.22,.15,.96);surface:SetPoint('CENTER')
 local rim=rectangle(felt,778,498,.40,.25,.10,.95);rim:SetPoint('CENTER');rim:SetDrawLayer('BACKGROUND',-1)
 headline=text(win,'GameFontNormalLarge');headline:SetPoint('TOP',win,0,-17);headline:SetText("THE BARRENS HOLD'EM - VISUAL NETWORK TABLE")
 button(win,'X',811,-12,27,function()win:Hide()end)
 phaseText=text(felt,'GameFontNormal');phaseText:SetPoint('CENTER',felt,0,78)
 potText=text(felt,'GameFontNormalLarge');potText:SetPoint('CENTER',felt,0,-17)
 local gold=felt:CreateTexture(nil,'ARTWORK');gold:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon');gold:SetSize(19,19);gold:SetPoint('RIGHT',potText,'LEFT',-8,0)
 board={}
 for i=1,5 do board[i]=card(felt,49,70);board[i]:SetPoint('CENTER',felt,'CENTER',(i-3)*58,32) end
 private={}
 for i=1,2 do private[i]=card(felt,42,58);private[i]:SetPoint('CENTER',felt,'CENTER',(i==1 and -26 or 26),-103) end
 local yourCards=text(felt);yourCards:SetPoint('CENTER',felt,0,-145);yourCards:SetText('YOUR PRIVATE CARDS')
 seats={}
 for i=1,10 do
  local s=CreateFrame('Frame',nil,felt);s:SetSize(139,56);s:SetPoint('CENTER',felt,'CENTER',positions[i][1],positions[i][2])
  local bg=rectangle(s,139,56,.06,.09,.09,.95);bg:SetPoint('CENTER')
  s.glow=rectangle(s,143,60,.12,.8,.28,.55);s.glow:SetPoint('CENTER');s.glow:SetDrawLayer('BACKGROUND',-1);s.glow:Hide()
  s.name=text(s,'GameFontNormalSmall');s.name:SetPoint('TOP',s,0,-4);s.name:SetWidth(133)
  s.detail=text(s);s.detail:SetPoint('TOP',s,0,-23);s.detail:SetWidth(133)
  seats[i]=s
 end
 notice=text(win);notice:SetPoint('BOTTOM',win,0,57);notice:SetWidth(790)
 button(win,'Betting Controls',18,-609,139,function()if R.OpenBarrensNetworkTable then R.OpenBarrensNetworkTable()end end)
 button(win,'Player Management',166,-609,153,function()if R.OpenBarrensManagement then R.OpenBarrensManagement()end end)
 button(win,'Network Lobby',329,-609,124,function()if R.OpenBarrensNetworkLobby then R.OpenBarrensNetworkLobby()end end)
 button(win,'Solo Debug',462,-609,116,function()if R.OpenBarrensSoloDebug then R.OpenBarrensSoloDebug() end end)
 button(win,'Refresh',589,-609,105,function()V.Refresh()end)
 win:Hide()
end
function V.Refresh()
 if not win then return end
 local s=state()
 if not s then
  phaseText:SetText('No active synchronized hand')
  potText:SetText('POT: --')
  notice:SetText('Create or join a Network Lobby, then start a multiplayer hand.')
  for i=1,5 do board[i]:SetValue(nil,false) end
  for i=1,2 do private[i]:SetValue(nil,true) end
  for i=1,10 do seats[i].name:SetText(i..'. [EMPTY]');seats[i].detail:SetText('');seats[i].glow:Hide() end
  return
 end
 phaseText:SetText('HAND '..tostring(s.handNumber or 0)..'  |  '..tostring(s.phase or '?')..'  |  HOST: '..tostring(N.host or '-'))
 potText:SetText('POT: '..money(s.pot))
 for i=1,5 do board[i]:SetValue(s.board and s.board[i],false) end
 local P=R.HoldemProtocol
 local mycards=P and P.privateCards
 local valid=mycards and #mycards==2 and P.privateHand==s.handNumber
 -- The host can read only its own hole cards from the engine.
 if not valid and N.owner then
  for i,p in ipairs(s.players or {}) do
   if p.name==(UnitName('player') or '') and p.hole and #p.hole==2 then mycards=p.hole;valid=true;break end
  end
 end
 for i=1,2 do private[i]:SetValue(valid and mycards[i] or nil,not valid) end
 for i=1,10 do
  local p=s.players and s.players[i];local seat=seats[i]
  if p then
   seat.name:SetText(i..'. '..tostring(p.name or '?'))
   local status=p.folded and 'FOLD' or (p.allIn and 'ALL-IN' or (p.sittingOut and 'SIT OUT' or 'ACTIVE'))
   seat.detail:SetText(money(p.stack)..'  |  '..status..'  |  '..money(p.street))
   if s.actionSeat==i then seat.glow:Show() else seat.glow:Hide() end
  else seat.name:SetText(i..'. [EMPTY]');seat.detail:SetText('');seat.glow:Hide() end
 end
 notice:SetText('Only your private cards are visible. Use Betting Controls for actions.')
end
function R.OpenBarrensVisualNetwork() create();V.Refresh();win:Show();win:Raise() end
SLASH_BARRVISUALNET1='/holdemvisual'
SlashCmdList.BARRVISUALNET=function()R.OpenBarrensVisualNetwork()end
local prev=SlashCmdList.RAIDFIVEPOKER
if prev then
 SlashCmdList.RAIDFIVEPOKER=function(input)
  local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
  if cmd=='holdemvisual' then R.OpenBarrensVisualNetwork() else prev(input) end
 end
end
local timer=CreateFrame('Frame');local elapsed=0
 timer:SetScript('OnUpdate',function(self,dt)
  elapsed=elapsed+dt
  if elapsed>=.5 then elapsed=0;if win and win:IsShown() then V.Refresh() end end
 end)
