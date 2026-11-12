-- EpokerWoW Raid mode selection artwork / WoW 3.3.5a / Lua 5.1.
-- Visual name only: addon folder and SavedVariables intentionally remain compatible.
local R=RPoker
if not R then return end
R.GameModes={DRAW={id='DRAW',name='Ironforge 5-Card Draw',available=true},
 HOLDEM={id='HOLDEM',name="The Barrens Hold'em",available=true}}
local originalToggle=R.Toggle
local launcher
local function openDraw()
 if RaidPokerWotLKDB then RaidPokerWotLKDB.launcherLastMode='DRAW' end
 if launcher then launcher:Hide() end
 if R.Main and not R.Main:IsShown() then originalToggle() end
end
local function openHoldem()
 if RaidPokerWotLKDB then RaidPokerWotLKDB.launcherLastMode='HOLDEM' end
 if launcher then launcher:Hide() end
 if R.OpenBarrensControls then R.OpenBarrensControls()
 elseif R.OpenBarrensPreview then R.OpenBarrensPreview() end
end
local function panel(parent,x,y,w,h,tooltip,click)
 local b=CreateFrame('Button',nil,parent)
 b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetSize(w,h)
 local glow=b:CreateTexture(nil,'OVERLAY')
 glow:SetTexture('Interface\\Buttons\\WHITE8X8')
 glow:SetVertexColor(1,.82,.35,.12)
 glow:SetAllPoints(b);glow:Hide()
 b:SetScript('OnEnter',function(self)
  glow:Show()
  GameTooltip:SetOwner(self,'ANCHOR_CURSOR')
  GameTooltip:SetText(tooltip,1,.82,.2)
  GameTooltip:AddLine('Click to enter this poker mode.',1,1,1)
  GameTooltip:Show()
 end)
 b:SetScript('OnLeave',function()glow:Hide();GameTooltip:Hide()end)
 b:SetScript('OnClick',click)
 return b
end
local function build()
 if launcher then return end
 launcher=CreateFrame('Frame','RaidPokerGameModeLauncher',UIParent)
 launcher:SetSize(700,467)
 launcher:SetPoint('CENTER',UIParent,'CENTER',0,50)
 launcher:SetFrameStrata('FULLSCREEN_DIALOG');launcher:SetToplevel(true)
 launcher:SetMovable(true);launcher:EnableMouse(true)
 launcher:RegisterForDrag('LeftButton');launcher:SetClampedToScreen(true)
 launcher:SetScript('OnDragStart',function(self)self:StartMoving()end)
 launcher:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 local art=launcher:CreateTexture(nil,'BACKGROUND')
 art:SetTexture('Interface\\AddOns\\RaidPoker_WotLK\\LauncherArt\\EpokerWoW_Launcher')
 art:SetAllPoints(launcher)
 art:SetTexCoord(0,1,0,683/1024)
 -- Border-only frame; artwork remains fully opaque.
 local outer=CreateFrame('Frame',nil,launcher)
 outer:SetPoint('TOPLEFT',launcher,'TOPLEFT',-5,5)
 outer:SetPoint('BOTTOMRIGHT',launcher,'BOTTOMRIGHT',5,-5)
 outer:SetFrameLevel(launcher:GetFrameLevel()+1)
 outer:EnableMouse(false)
 outer:SetBackdrop({edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=30,
  insets={left=0,right=0,top=0,bottom=0}})
 outer:SetBackdropBorderColor(.85,.68,.35,1)
 -- Opaque illustrated artwork. No dark overlay on the two mode images.
 panel(launcher,31,-114,310,319,'Ironforge 5-Card Draw',openDraw)
 panel(launcher,359,-114,310,319,"The Barrens Hold'em",openHoldem)
 local close=CreateFrame('Button',nil,launcher,'UIPanelCloseButton')
 close:SetPoint('TOPRIGHT',launcher,'TOPRIGHT',-5,-5)
 close:SetScript('OnClick',function()launcher:Hide()end)
 launcher:Hide()
end
function R.OpenGameModeLauncher()
 build()
 if R.Main and R.Main:IsShown() then R.Main:Hide() end
 launcher:Show();launcher:Raise()
end
function R.Toggle()
 build()
 if launcher:IsShown() then launcher:Hide();return end
 if R.Main and R.Main:IsShown() then originalToggle();return end
 R.OpenGameModeLauncher()
end
local oldSlash=SlashCmdList.RAIDFIVEPOKER
if oldSlash then
 SlashCmdList.RAIDFIVEPOKER=function(s)
  local command=string.lower(string.gsub(s or '', '^%s*(.-)%s*$', '%1'))
  if command=='draw' then openDraw()
  elseif command=='holdem' or command=='barrens' then openHoldem()
  elseif command=='modes' then R.OpenGameModeLauncher()
  else oldSlash(s) end
 end
end
