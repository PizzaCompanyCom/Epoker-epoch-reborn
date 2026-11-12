-- EpokerWoW Raid RC1 Hotfix 20: version compatibility notice (WoW 3.3.5a).
local R=RPoker
if not R then return end
local function compare(a,b)
 local function parts(v)
  local h=tonumber(tostring(v or ''):match('HF(%d+)')) or 0
  return h
 end
 return parts(a),parts(b)
end
StaticPopupDialogs['EPOKER_VERSION_INCOMPATIBLE']={
 text='%s',button1='OK',timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
}
function R.PokerShowVersionWarning(hostName,hostVersion)
 local mine=R.PokerLocalVersion and R.PokerLocalVersion() or 'Unknown'
 local hostHF,myHF=compare(hostVersion,mine)
 local advice
 if hostHF<myHF then advice='Please ask the Game Master to update their addon.'
 elseif hostHF>myHF then advice='Please update your addon and restart World of Warcraft.'
 else advice='Please use the same compatible addon build as the Game Master.' end
 local msg='Incompatible Addon Version\n\nYour version: '..mine..'\nGame Master ('..tostring(hostName or '?')..'): '..tostring(hostVersion or 'Unknown')..'\n\n'..advice
 if StaticPopup_Show then StaticPopup_Show('EPOKER_VERSION_INCOMPATIBLE',msg) end
 if R.Print then R.Print(advice) end
end
