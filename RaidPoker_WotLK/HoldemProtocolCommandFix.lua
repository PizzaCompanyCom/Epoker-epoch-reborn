-- v1.8.0-beta4c2a: slash command registration hotfix (WoW 3.3.5a / Lua 5.1).
-- Independent alias and late binding protect against slash handlers being replaced.
local function openDebug()
 if RPoker and type(RPoker.OpenHoldemProtocolDebug)=='function' then
  RPoker.OpenHoldemProtocolDebug()
 else
  DEFAULT_CHAT_FRAME:AddMessage('|cffff5555Raid Poker:|r Protocol Debug is unavailable. Verify HoldemProtocol.lua and all beta4a/b/c1 files are installed and enabled.')
 end
end
SLASH_RPHOLDEMDEBUG1='/holdemprotocol'
SLASH_RPHOLDEMDEBUG2='/holdemtest'
SlashCmdList.RPHOLDEMDEBUG=function() openDebug() end
local function install()
 if not SlashCmdList then return end
 local current=SlashCmdList.RAIDFIVEPOKER
 if type(current)~='function' then return end
 if current==RPokerProtocolSlashWrapper then return end
 local wrapper=function(input)
  local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
  if cmd=='holdemprotocol' or cmd=='holdemtest' then openDebug()
  else current(input) end
 end
 RPokerProtocolSlashWrapper=wrapper
 SlashCmdList.RAIDFIVEPOKER=wrapper
end
install()
local f=CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN')
f:SetScript('OnEvent',function(self) install();self:UnregisterEvent('PLAYER_LOGIN') end)
