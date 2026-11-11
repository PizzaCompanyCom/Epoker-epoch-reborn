-- v1.7.34e: use native WotLK sound files; force-enable sound preview buttons.
local R=RPoker
local paths={
 bet='Sound\\Interface\\LootCoinLarge.wav',
 turn='Sound\\Interface\\LootCoinSmall.wav',
 draw='Interface\\AddOns\\RaidPoker_WotLK\\Sounds\\CardExchange.wav',
 deal='Sound\\Interface\\AuctionWindowOpen.wav',
 win='Sound\\Interface\\AuctionWindowOpen.wav',
 loss='Sound\\Interface\\LootCoinLarge.wav',
}
local names={bet='Coin bet',turn='Your turn',draw='Card exchange',deal='New hand',win='Hand won',loss='Hand lost'}
local order={'bet','turn','draw','deal','win','loss'}
local function enabled(key)
 local db=RaidPokerWotLKDB
 return db and db.uiSound~=false and (not db.pokerSoundEvents or db.pokerSoundEvents[key]~=false)
end
function R.PokerSound(key,force)
 if not force and not enabled(key) then return end
 if key=='deal' then
  if PlaySound then PlaySound('igCharacterInfoTab') end
 elseif PlaySoundFile and paths[key] then PlaySoundFile(paths[key]) end
end
local f=CreateFrame('Frame','RaidPokerSoundOptions',UIParent)
f:SetWidth(360);f:SetHeight(390);f:SetPoint('CENTER',UIParent,'CENTER',250,0)
f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetMovable(true);f:EnableMouse(true);f:SetClampedToScreen(true)
R.Backdrop(f)
f:RegisterForDrag('LeftButton')
f:SetScript('OnDragStart',function(self)self:StartMoving()end)
f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
title:SetPoint('TOP',f,'TOP',0,-22);title:SetText('POKER SOUND OPTIONS')
R.Button(f,'X',25,22,318,-13,function()f:Hide()end)
local checks={}
local function addCheck(key,text,y)
 local c=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
 c:SetPoint('TOPLEFT',f,'TOPLEFT',24,y)
 local label=f:CreateFontString(nil,'OVERLAY','GameFontHighlight')
 label:SetPoint('LEFT',c,'RIGHT',5,0);label:SetText(text)
 c:SetScript('OnClick',function(self)
  if key=='all' then RaidPokerWotLKDB.uiSound=self:GetChecked() and true or false
  else RaidPokerWotLKDB.pokerSoundEvents=RaidPokerWotLKDB.pokerSoundEvents or {};RaidPokerWotLKDB.pokerSoundEvents[key]=self:GetChecked() and true or false end
 end)
 checks[key]=c
end
addCheck('all','Enable poker sounds',-62)
for i,key in ipairs(order) do addCheck(key,names[key],-97-(i-1)*37) end
R.Button(f,'Test Coins',115,25,24,-330,function()R.PokerSound('bet',true)end)
R.Button(f,'Test Turn',115,25,145,-330,function()R.PokerSound('turn',true)end)
R.Button(f,'Test Win',95,23,24,-360,function()R.PokerSound('win',true)end)
R.Button(f,'Test Loss',95,23,145,-360,function()R.PokerSound('loss',true)end)
function R.ToggleSoundOptions()
 if f:IsShown() then f:Hide();return end
 checks.all:SetChecked(RaidPokerWotLKDB.uiSound~=false)
 for _,key in ipairs(order) do checks[key]:SetChecked(not RaidPokerWotLKDB.pokerSoundEvents or RaidPokerWotLKDB.pokerSoundEvents[key]~=false) end
 f:Show()
end
f:Hide()
