-- GoldTracker.lua
-- Tracks gold for the current character and stores it account-wide.
local addonName, ns = ...

ns.GoldTracker = {}
local GT = ns.GoldTracker

-- Store the money event frame so it can be cleaned up on logout.
local moneyFrame = nil

local function SaveCurrentGold()
    local key  = ns.GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    local _, classFile = UnitClass("player")

    local entry = PocketLedgerDB.characters[key] or {}
    entry.name     = name
    entry.realm    = realm
    entry.class    = classFile
    entry.gold     = GetMoney()
    entry.lastSeen = time()
    PocketLedgerDB.characters[key] = entry
end

function GT:OnLogin()
    -- Snapshot session-start gold before any changes this session.
    PocketLedgerChar.sessionStartGold = GetMoney()

    -- Persist current gold into the account-wide DB.
    SaveCurrentGold()

    -- Update gold whenever money changes.
    if moneyFrame then
        moneyFrame:UnregisterAllEvents()
    end
    moneyFrame = CreateFrame("Frame")
    moneyFrame:RegisterEvent("PLAYER_MONEY")
    moneyFrame:SetScript("OnEvent", function()
        SaveCurrentGold()
    end)
end

function GT:OnLogout()
    local gold = GetMoney()
    -- Only save if GetMoney() is valid (non-zero), since the character may be unloading.
    if gold > 0 then
        SaveCurrentGold()
    end
    if moneyFrame then
        moneyFrame:UnregisterAllEvents()
        moneyFrame = nil
    end
end

-- Returns the net gold change since the session started (may be negative).
function GT:GetSessionChange()
    return GetMoney() - (PocketLedgerChar.sessionStartGold or GetMoney())
end

-- Returns a sorted list of all known character entries.
function GT:GetAllCharacters()
    local list = {}
    for key, data in pairs(PocketLedgerDB.characters) do
        list[#list + 1] = { key = key, data = data }
    end
    table.sort(list, function(a, b)
        -- Current character first, then alphabetical.
        local myKey = ns.GetCharKey()
        if a.key == myKey then return true end
        if b.key == myKey then return false end
        return (a.data.name or "") < (b.data.name or "")
    end)
    return list
end
