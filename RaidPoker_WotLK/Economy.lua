-- Raid Poker Economy display helpers. All state, packets and accounting stay in SILVER.
local R=RPoker
function R.Money(value)
 local n=math.floor(tonumber(value) or 0)
 local sign=n<0 and '-' or ''
 n=math.abs(n)
 local g=math.floor(n/100);local s=n%100
 if g==0 then return sign..s..'s' end
 if s==0 then return sign..g..'g' end
 return sign..g..'g '..s..'s'
end
function R.ToSilver(gold,silver)
 local g=tonumber(gold);local s=tonumber(silver)
 if not g or not s or g<0 or s<0 or g~=math.floor(g) or s~=math.floor(s) or s>=100 then return nil end
 if g>1000000 then return nil end
 return g*100+s
end
function R.ReadMoney(goldBox,silverBox)
 return R.ToSilver(goldBox:GetText(),silverBox:GetText())
end
function R.SetMoneyBoxes(goldBox,silverBox,value)
 local n=math.max(0,math.floor(tonumber(value) or 0))
 goldBox:SetText(tostring(math.floor(n/100)))
 silverBox:SetText(tostring(n%100))
end

-- Convert silver-denominated winnings in presentation text, never in network data.
function R.MoneyText(value)
 return (tostring(value or ''):gsub('([%+%-]?%d+)s',function(n)
  return R.Money(tonumber(n))
 end))
end
