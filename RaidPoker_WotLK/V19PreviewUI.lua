-- v1.9.0 development checkpoint: interface warnings only, no GM state mutation.
local R=RPoker
if not R then return end
StaticPopupDialogs['EPOKER_GM_START_WARNING']={
 text='You are not the Game Master.\nCurrent Game Master: %s\nOnly the Game Master can start a hand.',
 button1=OKAY,timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}
-- Three choices, with a second confirmation before closing for everyone.
StaticPopupDialogs['EPOKER_GM_LEAVE_WARNING']={
 text='You are the Game Master. Transfer management or close the current table before leaving.',
 button1='Transfer GM',button2='Close Table',button3=CANCEL,
 OnAccept=function()if R.TogglePlayerManagement then R.TogglePlayerManagement() end end,
 OnCancel=function(self,data,reason)
  if reason=='clicked' then StaticPopup_Show('EPOKER_DRAW_CLOSE_CONFIRM') end
 end,
 timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}
StaticPopupDialogs['EPOKER_DRAW_CLOSE_CONFIRM']={
 text='Close this 5-Card Draw table for EVERYONE? This cannot be undone.',
 button1='Close Table',button2=CANCEL,
 OnAccept=function()
  if R.Game and (R.Game.phase=='LOBBY' or R.Game.phase=='SHOWDOWN') and R.CloseNamedTable then R.CloseNamedTable()
  elseif R.Print then R.Print('Finish the current hand before closing the table.') end
 end,
 timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}
StaticPopupDialogs['EPOKER_HOLDEM_GM_LEAVE_WARNING']={
 text='You are the Game Master. Transfer management or close the current table before leaving.',
 button1='Transfer GM',button2='Close Table',button3=CANCEL,
 OnAccept=function()if R.OpenBarrensGMTransfer then R.OpenBarrensGMTransfer() end end,
 OnCancel=function(self,data,reason)
  if reason=='clicked' then StaticPopup_Show('EPOKER_HOLDEM_CLOSE_CONFIRM') end
 end,
 timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}
StaticPopupDialogs['EPOKER_HOLDEM_CLOSE_CONFIRM']={
 text='Close this Holdem table for EVERYONE? This cannot be undone.',
 button1='Close Table',button2=CANCEL,
 OnAccept=function()
  if R.BarrensNetworkCloseByGM then
   local ok,why=R.BarrensNetworkCloseByGM()
   if not ok and R.Print then R.Print(why or 'Unable to close the table.') end
  end
 end,
 timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}

-- Stage 4: cross-mode membership guard. Never silently close or transfer an active table.
StaticPopupDialogs['EPOKER_OTHER_MODE_ACTIVE']={
 text='You are still at a %s table. Leave that table before joining or creating a %s table.',
 button1=OKAY,timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}
StaticPopupDialogs['EPOKER_OTHER_MODE_GM']={
 text='You are Game Master of a %s table. Transfer management or close it before entering %s.',
 button1=OKAY,timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}
function R.PokerWarnOtherMode(target,current,isGM)
 local key=isGM and 'EPOKER_OTHER_MODE_GM' or 'EPOKER_OTHER_MODE_ACTIVE'
 if StaticPopup_Show then StaticPopup_Show(key,current or 'current',target or 'another') end
 if R.Print then R.Print('Leave the current table before switching modes.') end
end
