-- Core.lua
-- Initializes the addon namespace and event routing.
local addonName, ns = ...

-- Shared utility: format a copper amount as colored gold/silver/copper text.
function ns.FormatGold(copper)
    if not copper then copper = 0 end
    local negative = copper < 0
    copper = math.abs(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local str = string.format("|cffffd700%dg|r |cffc0c0c0%ds|r |cffb87333%dc|r", g, s, c)
    return negative and ("|cffff4444-|r" .. str) or str
end

-- Shared utility: return a character key string "Name-Realm".
function ns.GetCharKey()
    local name, realm = UnitName("player")
    realm = realm and realm ~= "" and realm or GetRealmName()
    return name .. "-" .. realm
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end

        -- Initialize account-wide DB.
        InfoBotWoWDB = InfoBotWoWDB or {}
        InfoBotWoWDB.characters = InfoBotWoWDB.characters or {}
        InfoBotWoWDB.auctions   = InfoBotWoWDB.auctions   or {}

        -- Initialize per-character DB.
        InfoBotWoWChar = InfoBotWoWChar or {}
        InfoBotWoWChar.sessionStartGold = InfoBotWoWChar.sessionStartGold or 0

    elseif event == "PLAYER_LOGIN" then
        -- Character is fully loaded; safe to read GetMoney() and register modules.
        ns.GoldTracker:OnLogin()
        ns.AuctionTracker:OnLogin()
        ns.UI:OnLogin()
        print("|cff00ccff[InfoBot]|r loaded. Type |cffffd700/ibot|r to open.")

    elseif event == "PLAYER_LOGOUT" then
        -- Save current gold before the session ends.
        ns.GoldTracker:OnLogout()
        ns.AuctionTracker:OnLogout()
    end
end)
