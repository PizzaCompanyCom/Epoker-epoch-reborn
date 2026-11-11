local A=CreateFrame('Frame','RaidFivePokerBootstrap')
RPoker={version='1.8.0-alpha2'}
local R=RPoker
local function msg(s) DEFAULT_CHAT_FRAME:AddMessage('|cffffcc55Raid 5-Card Poker:|r '..tostring(s)) end
R.Print=msg
R.DB=function() return RaidPokerWotLKDB end
local main,settings,mini
local backgroundThemes={'Classic Dark','Tavern','Alliance','Horde','Poker Felt','Ironforge','Booty Bay Tavern','Pirate Ship'}
local themeTextureFiles={'ClassicDark','Tavern','Alliance','Horde','PokerFelt','Ironforge','BootyBayTavern','PirateShip'}
local themeImage,backgroundPanel
function R.ApplyTheme()
 if not themeImage or not RaidPokerWotLKDB then return end
 local db=RaidPokerWotLKDB
 local n=math.max(1,math.min(8,tonumber(db.backgroundTheme) or 1))
 if n==1 then themeImage:Hide() else
  themeImage:SetTexture('Interface\\AddOns\\RaidPoker_WotLK\\Backgrounds\\'..themeTextureFiles[n]..'.tga')
  themeImage:SetAlpha(db.themeOpacity or 0.85)
  local bright=db.themeBrightness or 0.95
  themeImage:SetVertexColor(bright,bright,bright)
  themeImage:Show()
 end
 if backgroundPanel and backgroundPanel.themeButtons then
  for i,b in ipairs(backgroundPanel.themeButtons) do
   b:SetText((i==n and '> ' or '')..backgroundThemes[i])
  end
 end
end
R.backgroundFrames={}
R.fontPaths={
 {name='Default',path='Fonts\\FRIZQT__.TTF'},
 {name='Arial Narrow',path='Fonts\\ARIALN.TTF'},
 {name='Morpheus',path='Fonts\\MORPHEUS.TTF'},
 {name='Skurri',path='Fonts\\SKURRI.TTF'},
}
function R.RegisterBackground(frame,r,g,b,baseAlpha)
 table.insert(R.backgroundFrames,{frame=frame,r=r,g=g,b=b,alpha=baseAlpha})
 local db=RaidPokerWotLKDB or {}
 frame:SetBackdropColor(r,g,b,(db.backgroundAlpha or 0.96)*baseAlpha)
end
function R.ApplyBackgroundAlpha()
 local v=RaidPokerWotLKDB.backgroundAlpha or 0.96
 for _,item in ipairs(R.backgroundFrames) do
  if item.frame then item.frame:SetBackdropColor(item.r,item.g,item.b,v*item.alpha) end
 end
end
function R.ApplyFonts()
 local idx=RaidPokerWotLKDB.fontIndex or 1
 local path=(R.fontPaths[idx] or R.fontPaths[1]).path
 local function visit(frame)
  if not frame then return end
  local regions={frame:GetRegions()}
  for _,region in ipairs(regions) do
   if region and region.IsObjectType and region:IsObjectType('FontString') then
    local _,size,flags=region:GetFont()
    if size and size>0 then region:SetFont(path,size,flags) end
   end
  end
  local children={frame:GetChildren()}
  for _,child in ipairs(children) do visit(child) end
 end
 visit(R.Main)
 visit(R.SettingsFrame)
 if R.HistoryFrame then visit(R.HistoryFrame) end
 if R.LeaderFrame then visit(R.LeaderFrame) end
 if R.TableFrame then visit(R.TableFrame) end
 if R.StatisticsFrame then visit(R.StatisticsFrame) end
 if R.EnhancementFrames then for _,f in ipairs(R.EnhancementFrames) do visit(f) end end
end
-- Warcraft-style icons for the main poker controls (native 3.3.5a textures).
local buttonIcons={
 ['Fold']='Interface\\Icons\\Ability_Rogue_FeignDeath',
 ['Betting Activity']='Interface\\Icons\\INV_Misc_Note_01',
 ['Emotes']='Interface\\Icons\\INV_Misc_Head_Human_02',
 ['Check']='Interface\\Icons\\INV_Shield_05',
 ['Call']='Interface\\Icons\\INV_Misc_Coin_01',
 ['Raise']='Interface\\Icons\\Ability_Warrior_Charge',
 ['All-In']='Interface\\Icons\\INV_Misc_Bag_10',
 ['Exchange']='Interface\\Icons\\INV_Misc_Note_01',
 ['Stand Pat']='Interface\\Icons\\INV_Misc_Book_09',
 ['Tables']='Interface\\Icons\\INV_Misc_Book_09',
 ['Join Table']='Interface\\Icons\\INV_Misc_GroupLooking',
 ['Leave Table']='Interface\\Icons\\Spell_Shadow_Teleport',
 ['Start Hand']='Interface\\Icons\\INV_Misc_Book_09',
 ['History']='Interface\\Icons\\INV_Misc_Note_01',
 ['Leader']='Interface\\Icons\\INV_Misc_Head_Human_01',
 ['Poker Table']='Interface\\Icons\\INV_Misc_Coin_01',
 ['Player Management']='Interface\\Icons\\INV_Misc_Head_Human_01',
 ['Statistics']='Interface\\Icons\\INV_Misc_Book_09',
 ['Set Balance']='Interface\\Icons\\INV_Misc_Coin_02',
 ['Sit Out']='Interface\\Icons\\Ability_Rogue_Sprint',
 ['Sit In']='Interface\\Icons\\Ability_Warrior_RallyingCry',
 ['Busted']='Interface\\Icons\\Ability_Rogue_FeignDeath',
 ['Force Fold']='Interface\\Icons\\Ability_Rogue_FeignDeath',
 ['Transfer GM']='Interface\\Icons\\INV_Crown_01',
 ['Kick']='Interface\\Icons\\Spell_Shadow_DeathScream',
 ['Create Table']='Interface\\Icons\\INV_Misc_Key_03',
 ['Close Table (GM)']='Interface\\Icons\\INV_Misc_Lockbox_01',
 ['Refresh']='Interface\\Icons\\Spell_Nature_EarthBind',
 ['Join']='Interface\\Icons\\INV_Misc_GroupLooking',
 ['Leave Table']='Interface\\Icons\\Spell_Shadow_Teleport',
 ['Add']='Interface\\Icons\\Spell_Holy_GreaterHeal',
 ['Remove']='Interface\\Icons\\Spell_Shadow_DeathScream',
}
local function button(p,label,w,h,x,y,click)
 local b=CreateFrame('Button',nil,p,'UIPanelButtonTemplate')
 b:SetWidth(w);b:SetHeight(h);b:SetPoint('TOPLEFT',p,'TOPLEFT',x,y)
 b:SetText(label);b:SetScript('OnClick',click)
 if p==R.Main and (label=='Player Management' or label=='Statistics' or label=='Betting Activity' or label=='Emotes') then b:SetHeight(34) end
 local path=buttonIcons[label]
 if path and w>=55 then
  local size=math.min(23,b:GetHeight()-6)
  local icon=b:CreateTexture(nil,'OVERLAY')
  icon:SetTexture(path)
  icon:SetWidth(size);icon:SetHeight(size)
  icon:SetPoint('LEFT',b,'LEFT',7,0)
  local font=b:GetFontString()
  if font then
   font:ClearAllPoints()
   font:SetPoint('LEFT',b,'LEFT',size+13,0)
   font:SetPoint('RIGHT',b,'RIGHT',-3,0)
   font:SetJustifyH('CENTER')
   if w<95 then font:SetFontObject('GameFontNormalSmall') else font:SetFontObject('GameFontNormal') end
  end
  b.WarcraftIcon=icon
  if (label=='Poker Table' or label=='Join Table') and p==R.Main then
   local normal=b:GetNormalTexture()
   if normal then normal:SetVertexColor(0.82,0.22,0.22,1) end
   local pushed=b:GetPushedTexture()
   if pushed then pushed:SetVertexColor(0.65,0.16,0.16,1) end
  end
  local hover=b:CreateTexture(nil,'HIGHLIGHT')
  hover:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
  hover:SetBlendMode('ADD')
  hover:SetPoint('TOPLEFT',b,'TOPLEFT',2,-1)
  hover:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-2,1)
  hover:SetVertexColor(1,0.78,0.28,0.42)
 end
 return b
end
R.Button=button
local function backdrop(f)
 f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=28,insets={left=10,right=10,top=10,bottom=10}})
 R.RegisterBackground(f,0.06,0.045,0.03,1)
end
R.Backdrop=backdrop
local function position()
 if not main then return end
 main:ClearAllPoints();main:SetPoint('CENTER',UIParent,'CENTER',RaidPokerWotLKDB.x or 0,RaidPokerWotLKDB.y or 0)
 main:SetScale(RaidPokerWotLKDB.scale or 1)
end
local function miniPosition()
 if not mini then return end
 local a=math.rad(RaidPokerWotLKDB.miniAngle or 225)
 mini:ClearAllPoints();mini:SetPoint('CENTER',Minimap,'CENTER',math.cos(a)*80,math.sin(a)*80)
 if RaidPokerWotLKDB.showMini then mini:Show() else mini:Hide() end
end
function R.Toggle() if main:IsShown() then main:Hide() else main:Show();R.Refresh() end end
function R.Settings() if settings:IsShown() then settings:Hide() else settings:Show() end end
local function init()
 main=CreateFrame('Frame','RaidFivePokerMain',UIParent)
 main:SetWidth(790);main:SetHeight(745);main:SetFrameStrata('DIALOG');main:SetMovable(true);main:SetClampedToScreen(true);main:EnableMouse(true);main:RegisterForDrag('LeftButton')
 main:SetScript('OnDragStart',function(self) self:StartMoving() end)
 main:SetScript('OnDragStop',function(self)
  self:StopMovingOrSizing()
  local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
  if x and ux then RaidPokerWotLKDB.x=(x-ux)/self:GetScale();RaidPokerWotLKDB.y=(y-uy)/self:GetScale() end
 end)
 backdrop(main);position();R.Main=main
 -- Draw above the frame backdrop; BACKGROUND was hidden by the WoW backdrop.
 themeImage=main:CreateTexture(nil,'BORDER')
 themeImage:SetPoint('TOPLEFT',main,'TOPLEFT',12,-38)
 themeImage:SetPoint('BOTTOMRIGHT',main,'BOTTOMRIGHT',-12,12)
 themeImage:SetTexCoord(0,1,0,1)
 -- Theme application deferred until complete initialization.
 main:SetScript('OnHide',function() if settings then settings:Hide() end if R.PlayerManagementFrame then R.PlayerManagementFrame:Hide() end if R.StatisticsFrame then R.StatisticsFrame:Hide() end if R.RankingsFrame then R.RankingsFrame:Hide() end if R.RulesFrame then R.RulesFrame:Hide() end if R.HelpFrame then R.HelpFrame:Hide() end if RaidPokerBettingActivity then RaidPokerBettingActivity:Hide() end end)
 local t=main:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');t:SetPoint('TOP',main,'TOP',0,-19);t:SetText('')
 button(main,'X',27,23,755,-15,function() main:Hide() end)

 settings=CreateFrame('Frame','RaidFivePokerSettings',UIParent);settings:SetWidth(360);settings:SetHeight(690)
 settings:SetPoint('CENTER',UIParent,'CENTER',RaidPokerWotLKDB.settingsX or 290,RaidPokerWotLKDB.settingsY or 0)
 settings:SetFrameStrata('FULLSCREEN_DIALOG');settings:SetMovable(true);settings:SetClampedToScreen(true)
 settings:EnableMouse(true);backdrop(settings);settings:SetBackdropColor(0.025,0.025,0.03,0.98);R.SettingsFrame=settings
 -- Only the title bar starts dragging, so sliders and buttons remain usable.
 local dragBar=CreateFrame('Frame',nil,settings)
 dragBar:SetPoint('TOPLEFT',settings,'TOPLEFT',14,-10);dragBar:SetPoint('TOPRIGHT',settings,'TOPRIGHT',-50,-10)
 dragBar:SetHeight(36);dragBar:EnableMouse(true);dragBar:RegisterForDrag('LeftButton')
 dragBar:SetScript('OnDragStart',function() settings:StartMoving() end)
 dragBar:SetScript('OnDragStop',function()
  settings:StopMovingOrSizing()
  local x,y=settings:GetCenter();local ux,uy=UIParent:GetCenter()
  if x and ux then RaidPokerWotLKDB.settingsX=x-ux;RaidPokerWotLKDB.settingsY=y-uy end
 end)
 local st=settings:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');st:SetPoint('TOP',settings,'TOP',0,-25);st:SetText('EPOKERWOW RAID - SETTINGS')
 button(settings,'X',27,23,315,-17,function()settings:Hide()end)

 local alphaLabel=settings:CreateFontString(nil,'OVERLAY','GameFontNormal');alphaLabel:SetPoint('TOP',settings,'TOP',0,-160);alphaLabel:SetText('Game Window Background Opacity')
 local alphaSlider=CreateFrame('Slider','RaidFivePokerBackgroundOpacity',settings,'OptionsSliderTemplate')
 alphaSlider:SetWidth(230);alphaSlider:SetHeight(17);alphaSlider:SetPoint('TOP',settings,'TOP',0,-193)
 alphaSlider:SetMinMaxValues(0.15,1);alphaSlider:SetValueStep(0.05)
 getglobal(alphaSlider:GetName()..'Low'):SetText('15%')
 getglobal(alphaSlider:GetName()..'High'):SetText('100%')
 local alphaValue=getglobal(alphaSlider:GetName()..'Text')
 alphaSlider:SetValue(RaidPokerWotLKDB.backgroundAlpha or 0.96)
 alphaSlider:SetScript('OnValueChanged',function(self,v)
  v=math.floor(v*20+0.5)/20
  RaidPokerWotLKDB.backgroundAlpha=v
  alphaValue:SetText('Opacity: '..math.floor(v*100+0.5)..'%')
  R.ApplyBackgroundAlpha()
 end)
 alphaValue:SetText('Opacity: '..math.floor((RaidPokerWotLKDB.backgroundAlpha or 0.96)*100+0.5)..'%')
 local fontLabel=settings:CreateFontString(nil,'OVERLAY','GameFontNormal');fontLabel:SetPoint('TOP',settings,'TOP',0,-242);fontLabel:SetText('Interface Font')
 local fontButton=button(settings,'Font',195,26,82,-264,function()
  local i=(RaidPokerWotLKDB.fontIndex or 1)+1
  if i>#R.fontPaths then i=1 end
  RaidPokerWotLKDB.fontIndex=i
  R.ApplyFonts()
  if R.FontButton then R.FontButton:SetText(R.fontPaths[i].name..'  >') end
 end)
 R.FontButton=fontButton
 fontButton:SetText(R.fontPaths[RaidPokerWotLKDB.fontIndex or 1].name..'  >')
 local function openBackgroundPanel()
  if backgroundPanel then
   if backgroundPanel:IsShown() then backgroundPanel:Hide() else backgroundPanel:Show() end
   return
  end
  backgroundPanel=CreateFrame('Frame','RaidFivePokerBackgroundThemes',UIParent)
  backgroundPanel:SetWidth(400);backgroundPanel:SetHeight(455)
  backgroundPanel:SetPoint('CENTER',settings,'CENTER',385,0)
  backgroundPanel:SetFrameStrata('FULLSCREEN_DIALOG')
  backgroundPanel:SetFrameLevel(settings:GetFrameLevel()+10)
  backgroundPanel:SetMovable(true);backgroundPanel:EnableMouse(true)
  backgroundPanel:RegisterForDrag('LeftButton')
  backgroundPanel:SetScript('OnDragStart',function(self)self:StartMoving()end)
  backgroundPanel:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
  backdrop(backgroundPanel)
  local title=backgroundPanel:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
  title:SetPoint('TOP',0,-23);title:SetText('Main Window Background')
  button(backgroundPanel,'X',25,23,360,-13,function()backgroundPanel:Hide()end)
  local hint=backgroundPanel:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  hint:SetPoint('TOP',0,-53);hint:SetText('Choose one of eight background themes')
  backgroundPanel.themeButtons={}
  for i,name in ipairs(backgroundThemes) do
   local col=(i-1)%2;local row=math.floor((i-1)/2)
   local b=button(backgroundPanel,name,175,34,18+col*190,-77-row*44,function()
    RaidPokerWotLKDB.backgroundTheme=i
    R.ApplyTheme()
   end)
   backgroundPanel.themeButtons[i]=b
  end
  local opacity=backgroundPanel:CreateFontString(nil,'OVERLAY','GameFontNormal')
  opacity:SetPoint('TOP',0,-273);opacity:SetText('Theme Opacity')
  local os=CreateFrame('Slider','RaidPokerThemeOpacity',backgroundPanel,'OptionsSliderTemplate')
  os:SetWidth(260);os:SetHeight(16);os:SetPoint('TOP',0,-302)
  os:SetMinMaxValues(0,1);os:SetValueStep(0.05)
  getglobal(os:GetName()..'Low'):SetText('0%')
  getglobal(os:GetName()..'High'):SetText('100%')
  os:SetValue(RaidPokerWotLKDB.themeOpacity or 0.58)
  os:SetScript('OnValueChanged',function(self,v)
   v=math.floor(v*20+0.5)/20;RaidPokerWotLKDB.themeOpacity=v
   getglobal(self:GetName()..'Text'):SetText(math.floor(v*100+0.5)..'%')
   R.ApplyTheme()
  end)
  getglobal(os:GetName()..'Text'):SetText(math.floor((RaidPokerWotLKDB.themeOpacity or 0.58)*100+0.5)..'%')
  local brightness=backgroundPanel:CreateFontString(nil,'OVERLAY','GameFontNormal')
  brightness:SetPoint('TOP',0,-336);brightness:SetText('Theme Brightness')
  local bs=CreateFrame('Slider','RaidPokerThemeBrightness',backgroundPanel,'OptionsSliderTemplate')
  bs:SetWidth(260);bs:SetHeight(16);bs:SetPoint('TOP',0,-363)
  bs:SetMinMaxValues(0.2,1);bs:SetValueStep(0.05)
  getglobal(bs:GetName()..'Low'):SetText('20%')
  getglobal(bs:GetName()..'High'):SetText('100%')
  bs:SetValue(RaidPokerWotLKDB.themeBrightness or 0.7)
  bs:SetScript('OnValueChanged',function(self,v)
   v=math.floor(v*20+0.5)/20;RaidPokerWotLKDB.themeBrightness=v
   getglobal(self:GetName()..'Text'):SetText(math.floor(v*100+0.5)..'%')
   R.ApplyTheme()
  end)
  getglobal(bs:GetName()..'Text'):SetText(math.floor((RaidPokerWotLKDB.themeBrightness or 0.7)*100+0.5)..'%')
  button(backgroundPanel,'Reset Background',150,25,24,-409,function()
   RaidPokerWotLKDB.backgroundTheme=1
   RaidPokerWotLKDB.themeOpacity=0.85
   RaidPokerWotLKDB.themeBrightness=0.95
   os:SetValue(0.85);bs:SetValue(0.95);R.ApplyTheme()
  end)
  button(backgroundPanel,'Close',95,25,275,-409,function()backgroundPanel:Hide()end)
  R.ApplyTheme()
 end
 button(settings,'Background Themes',180,26,90,-485,openBackgroundPanel)
 button(settings,'Sound Options',180,26,90,-527,function() if R.ToggleSoundOptions then R.ToggleSoundOptions() end end)
 -- Optional winner announcement popup (enabled for existing and new users).
 local winnerToggle=CreateFrame('CheckButton','RaidFivePokerWinnerPopupToggle',settings,'UICheckButtonTemplate')
 winnerToggle:SetWidth(24);winnerToggle:SetHeight(24)
 winnerToggle:SetPoint('TOPLEFT',settings,'TOPLEFT',72,-570)
 winnerToggle:SetChecked(RaidPokerWotLKDB.showWinnerPopup==true)
 local winnerLabel=settings:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 winnerLabel:SetPoint('LEFT',winnerToggle,'RIGHT',3,0)
 winnerLabel:SetText('Show Winner Popup')
 winnerToggle:SetScript('OnClick',function(self)
  RaidPokerWotLKDB.showWinnerPopup=self:GetChecked() and true or false
  if not RaidPokerWotLKDB.showWinnerPopup and R.HideWinnerPopup then R.HideWinnerPopup() end
 end)
  local versionLabel=settings:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  versionLabel:SetPoint('BOTTOM',settings,'BOTTOM',0,36)
  versionLabel:SetText('EpokerWoW Raid - Version: '..(GetAddOnMetadata('RaidPoker_WotLK','Version') or 'Unknown'))
 local note=settings:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');note:SetPoint('TOP',settings,'TOP',0,-660);note:SetText('Changes are saved automatically.')
 local slider=CreateFrame('Slider','RaidFivePokerScale',settings,'OptionsSliderTemplate');slider:SetWidth(230);slider:SetHeight(17);slider:SetPoint('TOP',settings,'TOP',0,-91);slider:SetMinMaxValues(0.7,1.3);slider:SetValueStep(0.05)
 getglobal(slider:GetName()..'Low'):SetText('70%');getglobal(slider:GetName()..'High'):SetText('130%');getglobal(slider:GetName()..'Text'):SetText('Window Scale')
 slider:SetValue(RaidPokerWotLKDB.scale or 1);slider:SetScript('OnValueChanged',function(self,v) v=math.floor(v*20+0.5)/20;RaidPokerWotLKDB.scale=v;main:SetScale(v) end)
 button(settings,'Reset Layout',125,26,115,-121,function() RaidPokerWotLKDB.x=0;RaidPokerWotLKDB.y=0;RaidPokerWotLKDB.scale=1;RaidPokerWotLKDB.settingsX=290;RaidPokerWotLKDB.settingsY=0;position();settings:ClearAllPoints();settings:SetPoint('CENTER',UIParent,'CENTER',290,0);slider:SetValue(1) end)
 settings:Hide()
 mini=CreateFrame('Button','RaidFivePokerMinimap',Minimap);mini:SetWidth(32);mini:SetHeight(32);mini:SetFrameStrata('HIGH');mini:SetFrameLevel(12)
 local ico=mini:CreateTexture(nil,'ARTWORK');ico:SetTexture('Interface\\Icons\\INV_Misc_Coin_01');ico:SetWidth(22);ico:SetHeight(22);ico:SetPoint('CENTER')
 local border=mini:CreateTexture(nil,'OVERLAY');border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder');border:SetWidth(54);border:SetHeight(54);border:SetPoint('TOPLEFT')
 mini:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
 mini:RegisterForClicks('LeftButtonUp','RightButtonUp');mini:SetScript('OnClick',function(self,b) if b=='RightButton' then R.Settings() else R.Toggle() end end)
 mini:RegisterForDrag('LeftButton');mini:SetScript('OnDragStart',function(self)
  self:SetScript('OnUpdate',function()
   local x,y=GetCursorPosition();local mx,my=Minimap:GetCenter();local s=UIParent:GetEffectiveScale()
   RaidPokerWotLKDB.miniAngle=math.deg(math.atan2(y/s-my,x/s-mx));miniPosition()
  end)
 end)
 mini:SetScript('OnDragStop',function(self)self:SetScript('OnUpdate',nil)end)
 mini:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:AddLine('Raid 5-Card Poker WotLK');GameTooltip:AddLine('Left click: Table / Right click: Settings',1,1,1);GameTooltip:AddLine('Drag: Move icon',1,1,1);GameTooltip:Show()end)
 mini:SetScript('OnLeave',function()GameTooltip:Hide()end);miniPosition()
 R.BuildGame(main)
 if R.BuildManagement then R.BuildManagement(main) end
 local gear=CreateFrame('Button','RaidFivePokerSettingsGear',main)
 gear:SetWidth(30);gear:SetHeight(30);gear:SetPoint('TOPRIGHT',main,'TOPRIGHT',-48,-12)
 local gearIcon=gear:CreateTexture(nil,'ARTWORK');gearIcon:SetTexture('Interface\\Icons\\INV_Misc_Gear_01');gearIcon:SetAllPoints(gear)
 gear:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
 gear:SetScript('OnClick',function()R.Settings()end)
 gear:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine('Poker Settings');GameTooltip:Show()end)
 gear:SetScript('OnLeave',function()GameTooltip:Hide()end)
 -- Force Synchronization belongs to the main toolbar, next to Help.
 local syncButton=CreateFrame('Button','RaidFivePokerForceSync',main)
 syncButton:SetWidth(30);syncButton:SetHeight(30)
 syncButton:SetPoint('TOPRIGHT',main,'TOPRIGHT',-228,-12)
 local syncIcon=syncButton:CreateTexture(nil,'ARTWORK')
 syncIcon:SetTexture('Interface\\Icons\\Spell_Nature_EarthBind')
 syncIcon:SetAllPoints(syncButton)
 local syncBorder=syncButton:CreateTexture(nil,'OVERLAY')
 syncBorder:SetAllPoints(syncButton)
 syncButton:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
 syncButton:SetScript('OnClick',function()if R.RequestSync then R.RequestSync()end end)
 syncButton:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
  GameTooltip:AddLine('Force Synchronization')
  GameTooltip:AddLine('Request current state from your table Game Master.',1,1,1)
  GameTooltip:Show()
 end)
 syncButton:SetScript('OnLeave',function()GameTooltip:Hide()end)

 -- Square WoW-themed Solo Debug button, immediately to the left of Settings.
 local debugButton=CreateFrame('Button','RaidFivePokerDebugButton',main)
 debugButton:SetWidth(30);debugButton:SetHeight(30)
 debugButton:SetPoint('TOPRIGHT',main,'TOPRIGHT',-84,-12)
 local debugIcon=debugButton:CreateTexture(nil,'ARTWORK')
 debugIcon:SetTexture('Interface\\Icons\\INV_Misc_Dice_02')
 debugIcon:SetAllPoints(debugButton)
 local debugBorder=debugButton:CreateTexture(nil,'OVERLAY')
 debugBorder:SetAllPoints(debugButton)
 debugButton:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
 debugButton:SetScript('OnClick',function()if R.ToggleDebugPanel then R.ToggleDebugPanel() end end)
 debugButton:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
  GameTooltip:AddLine('Solo Debug Controls')
  GameTooltip:AddLine('Open or close the debug panel',1,1,1)
  GameTooltip:Show()
 end)
 debugButton:SetScript('OnLeave',function()GameTooltip:Hide()end)
 R.ApplyFonts()
 main:Hide()
end
SLASH_RAIDFIVEPOKER1='/poker';SLASH_RAIDFIVEPOKER2='/rpoker';SLASH_RAIDFIVEPOKER3='/raidpoker'
SlashCmdList.RAIDFIVEPOKER=function(s)
 s=string.lower(s or '')
 if s=='debug' or s=='debug status' then R.SoloStatus()
 elseif s=='debug off' then R.SoloStop()
 elseif string.find(s,'^debug%s+%d+$') then R.SoloStart(string.match(s,'%d+'))
 elseif string.find(s,'^portraitscale%s+%d+$') then if R.SetPortraitScale then R.SetPortraitScale(string.match(s,'%d+')) end
 elseif s=='settings' then R.Settings()
 elseif s=='rankings' then if R.ToggleRankings then R.ToggleRankings() end
 elseif s=='rules' then if R.ToggleRules then R.ToggleRules() end
 elseif s=='help' or s=='guide' then if R.ToggleHelp then R.ToggleHelp() end
 elseif s=='tables' or s=='browser' then if R.ToggleTableBrowser then R.ToggleTableBrowser() end
 elseif s=='table' then if R.ToggleTable then R.ToggleTable() end
 elseif s=='balances' then if R.TogglePlayerManagement then R.TogglePlayerManagement() end
 elseif s=='stats' then if R.ToggleStatistics then R.ToggleStatistics() end
 elseif string.find(s,'^botstyle%s+') then if R.DebugBotStyle then R.DebugBotStyle(string.match(s,'^botstyle%s+(%a+)')) end
 elseif s=='nettest' then if R.NetDiagnostics then R.NetDiagnostics() end
 elseif s=='sync' then if R.RequestSync then R.RequestSync() end
 elseif s=='debugpanel' then if R.ToggleDebugPanel then R.ToggleDebugPanel() end
 elseif s=='reseticon' then RaidPokerWotLKDB.showMini=true;RaidPokerWotLKDB.miniAngle=225;miniPosition();msg('Minimap icon restored.')
 elseif s=='hideicon' then RaidPokerWotLKDB.showMini=false;miniPosition()
 elseif s=='resetlayout' then RaidPokerWotLKDB.x=0;RaidPokerWotLKDB.y=0;RaidPokerWotLKDB.scale=1;position()
 elseif s=='help' then msg('/poker, /poker settings, /poker reseticon, /poker hideicon, /poker resetlayout, /poker debug 3, /poker debug off, /poker debugpanel, /poker table, /poker balances (opens Player Management), /poker stats, /poker sync, /poker nettest, /poker rankings, /poker rules, /poker botstyle aggressive, /poker help')
 else R.Toggle() end
end
A:RegisterEvent('ADDON_LOADED');A:SetScript('OnEvent',function(self,event,name)
 if name~='RaidPoker_WotLK' then return end
 if type(RaidPokerWotLKDB)~='table' then RaidPokerWotLKDB={} end
 local d=RaidPokerWotLKDB
 if d.scale==nil then d.scale=1 end;if d.x==nil then d.x=0 end;if d.y==nil then d.y=0 end
 if d.backgroundTheme==nil then d.backgroundTheme=1 end;if d.themeOpacity==nil then d.themeOpacity=0.58 end;if d.themeBrightness==nil then d.themeBrightness=0.7 end
 if d.backgroundAlpha==nil then d.backgroundAlpha=0.96 end;if d.fontIndex==nil then d.fontIndex=1 end
 if d.miniAngle==nil then d.miniAngle=225 end;if d.showMini==nil then d.showMini=true end
 if type(d.history)~='table' then d.history={} end
 init();R.InitGame();R.ApplyTheme();msg('v1.7.15 loaded. Type /poker to open. Virtual gold/silver accounting.')
 self:UnregisterEvent('ADDON_LOADED')
end)
