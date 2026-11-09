-- Raid Poker 1.8.0-alpha3: isolated local betting preview; English UI.
local R=RPoker
if not R or not R.Holdem then return end
local H=R.Holdem
local frame,info,board,players,start,actionButtons,raiseBox,history,help
local function line(parent,x,y,width,font)
 local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlight')
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(width);f:SetJustifyH('LEFT');return f
end
local function button(parent,label,x,y,w,callback)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
 b:SetSize(w,26);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',callback);return b
end
local function feedback(ok,msg)
 if not ok and R.Print then R.Print('Barrens Holdem: '..(msg or 'Invalid action')) end
end
local function build()
 if frame then return end
 frame=CreateFrame('Frame','RaidPokerBarrensPreview',UIParent)
 frame:SetSize(680,530);frame:SetPoint('CENTER');frame:SetFrameStrata('DIALOG')
 frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true)
 frame:SetScript('OnDragStart',function(self)self:StartMoving()end)
 frame:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 frame:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
 local title=line(frame,22,-22,600,'GameFontNormalLarge');title:SetText("THE BARRENS HOLD'EM — BETTING PREVIEW")
 info=line(frame,22,-61,630);board=line(frame,22,-90,630)
 players={}
 for i=1,4 do players[i]=line(frame,22,-130-(i-1)*37,635) end
 help=line(frame,22,-287,630);help:SetText('Raise amount is additional Silver above Call. All-In commits the entire remaining stack.')
 local raiseLabel=line(frame,22,-319,130);raiseLabel:SetText('Raise by (Silver):')
 raiseBox=CreateFrame('EditBox',nil,frame,'InputBoxTemplate');raiseBox:SetSize(75,24);raiseBox:SetPoint('TOPLEFT',frame,'TOPLEFT',152,-310);raiseBox:SetAutoFocus(false);raiseBox:SetNumeric(true);raiseBox:SetMaxLetters(7);raiseBox:SetText('10')
 actionButtons={}
 local labels={'Fold','Check','Call','Raise','All-In'}
 local actions={'FOLD','CHECK','CALL','RAISE','ALLIN'}
 for i=1,5 do
  local act=actions[i]
  actionButtons[i]=button(frame,labels[i],22+(i-1)*112,-350,105,function()
   local ok,msg=H.Action(act,raiseBox:GetNumber());feedback(ok,msg)
  end)
 end
 history=line(frame,22,-390,635)
 start=button(frame,'Start Hand',22,-475,140,function()feedback(H.StartPreviewHand())end)
 button(frame,'Reset Preview',174,-475,145,function()H.ResetPreview()end)
 button(frame,'Close',555,-475,95,function()frame:Hide()end)
 frame:Hide()
end
function H.Refresh()
 if not frame then return end
 local s=H.GetPublicSnapshot()
 info:SetText('Hand # '..s.handNumber..'   Phase: '..s.phase..'   Pot: '..s.pot..'s   Current Bet: '..s.currentBet..'s   Min Raise: '..s.minRaise..'s')
 board:SetText('Community: '..(#s.board>0 and table.concat(s.board,'  ') or '(not dealt)'))
 for i,p in ipairs(s.players) do
  local tags=(p.dealer and ' [D]' or '')..(p.smallBlind and ' [SB]' or '')..(p.bigBlind and ' [BB]' or '')
  local cards=H.players[i].hole
  local hole=(cards and #cards==2) and (H.CardLabel(cards[1])..' '..H.CardLabel(cards[2])) or '--'
  local state=(p.folded and 'FOLD' or (p.allIn and 'ALL-IN' or (s.actionSeat==i and 'YOUR TURN' or '')))
  local won=s.winners[i] and ('  WON +'..s.winners[i]..'s') or ''
  players[i]:SetText((s.actionSeat==i and '> ' or '  ')..p.name..tags..'   '..hole..'   Stack '..p.stack..'s   Bet '..p.street..'s   '..state..won)
 end
 local active=s.phase~='LOBBY' and s.phase~='SHOWDOWN'
 if active and s.actionSeat then
  local p=s.players[s.actionSeat]
  help:SetText('Acting: '..p.name..' | To call: '..math.max(0,s.currentBet-p.street)..'s | Raise amount is additional Silver above Call.')
 else help:SetText('LOCAL TEST ONLY — no raid sync or real player balances. Use Start Hand to deal.') end
 for _,b in ipairs(actionButtons) do if active and s.actionSeat then b:Enable() else b:Disable() end end
 if s.phase=='LOBBY' or s.phase=='SHOWDOWN' then start:Enable() else start:Disable() end
 local lines={}
 for i=math.max(1,#s.log-2),#s.log do if s.log[i] then lines[#lines+1]=s.log[i] end end
 if s.phase=='SHOWDOWN' and #s.sidePots>0 then
  local totals={}
  for i,pot in ipairs(s.sidePots) do totals[#totals+1]='Pot '..i..': '..pot.amount..'s' end
  lines[#lines+1]=table.concat(totals,'  |  ')
 end
 history:SetText('History: '..table.concat(lines,'\n'))
end
function R.OpenBarrensPreview()
 if R.OpenBarrensControls then R.OpenBarrensControls();return end
 build();H.Refresh();frame:Show();frame:Raise()
end
