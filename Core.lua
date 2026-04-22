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

local function MergeDB(...)
    local merged = {
        characters = {},
        auctions = {},
    }

    for i = 1, select("#", ...) do
        local db = select(i, ...)
        if type(db) == "table" then
            if type(db.characters) == "table" then
                for k, v in pairs(db.characters) do
                    if type(v) == "table" then
                        local existing = merged.characters[k]
                        if type(existing) ~= "table" then
                            existing = {}
                        end
                        for field, value in pairs(v) do
                            existing[field] = value
                        end
                        merged.characters[k] = existing
                    else
                        merged.characters[k] = v
                    end
                end
            end
            if type(db.auctions) == "table" then
                for k, v in pairs(db.auctions) do
                    merged.auctions[k] = v
                end
            end
        end
    end

    return merged
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end

        -- Merge backup + current so an incomplete DB can be healed.
        PocketLedgerDB = MergeDB(PocketLedgerBackupDB, PocketLedgerDB)
        PocketLedgerBackupDB = MergeDB(PocketLedgerBackupDB, PocketLedgerDB)
        PocketLedgerChar = PocketLedgerChar or {}

        -- Initialize account-wide DB.
        PocketLedgerDB.characters = PocketLedgerDB.characters or {}
        PocketLedgerDB.auctions   = PocketLedgerDB.auctions   or {}
        PocketLedgerBackupDB.characters = PocketLedgerBackupDB.characters or {}
        PocketLedgerBackupDB.auctions   = PocketLedgerBackupDB.auctions   or {}

        -- Initialize per-character DB.
        PocketLedgerChar.sessionStartGold = PocketLedgerChar.sessionStartGold or 0

    elseif event == "PLAYER_LOGIN" then
        -- Character is fully loaded; safe to read GetMoney() and register modules.
        ns.GoldTracker:OnLogin()
        ns.AuctionTracker:OnLogin()
        ns.UI:OnLogin()
        print("|cff00ccff[Pocket Ledger]|r loaded. Type |cffffd700/pl|r to open.")

    elseif event == "PLAYER_LOGOUT" then
        -- Save current gold before the session ends.
        ns.GoldTracker:OnLogout()
        ns.AuctionTracker:OnLogout()

        -- Keep backup in sync before SavedVariables are written.
        PocketLedgerBackupDB = MergeDB(PocketLedgerBackupDB, PocketLedgerDB)
    end
end)
