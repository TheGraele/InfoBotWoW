-- AuctionTracker.lua
-- Scans owned auctions when the Auction House is open and persists them.
local addonName, ns = ...

ns.AuctionTracker = {}
local AT = ns.AuctionTracker

local STATUS_TEXT = {
    [0] = "",                              -- active
    [1] = " |cff00ff00[SOLD]|r",
    [2] = " |cffaaaaaa[EXPIRED]|r",
}

-- Store the auction event frame so it can be cleaned up on logout.
local auctionFrame = nil

local function ScanOwnedAuctions()
    local key     = ns.GetCharKey()
    local count   = C_AuctionHouse.GetNumOwnedAuctions()
    local results = {}

    for i = 1, count do
        local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if info then
            -- Try to resolve an item link from the item cache.
            local itemName, itemLink
            if info.itemKey then
                itemName, itemLink = GetItemInfo(info.itemKey.itemID)
            end
            itemName = itemName or ("Item #" .. (info.itemKey and info.itemKey.itemID or "?"))
            itemLink = itemLink or itemName

            local isCommodity = false
            if info.itemKey and info.itemKey.itemID then
                local ok, status = pcall(C_AuctionHouse.GetItemCommodityStatus, info.itemKey.itemID)
                if ok and status == Enum.ItemCommodityStatus.Item_Is_Commodity then
                    isCommodity = true
                end
            end

            results[#results + 1] = {
                auctionID     = info.auctionID,
                itemID        = info.itemKey and info.itemKey.itemID,
                itemLink      = itemLink,
                itemName      = itemName,
                quantity      = info.quantity or 1,
                buyoutAmount  = info.buyoutAmount or 0,
                bidAmount     = info.bidAmount or 0,
                timeLeftSeconds = info.timeLeftSeconds or 0,
                status        = info.status or 0,
                isCommodity   = isCommodity or false,
            }
        end
    end

    PocketLedgerDB.auctions[key]              = results
    PocketLedgerDB.auctions[key .. "_scanned"] = time()
end

function AT:GetAuctions(charKey)
    charKey = charKey or ns.GetCharKey()
    return PocketLedgerDB.auctions[charKey] or {}
end

function AT:GetLastScanTime(charKey)
    charKey = charKey or ns.GetCharKey()
    return PocketLedgerDB.auctions[charKey .. "_scanned"]
end

function AT:GetTimeLeftText(seconds)
    if not seconds or seconds <= 0 then return "|cff888888Expired|r" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local str
    if h > 0 then
        str = string.format("%dh %dm", h, m)
    else
        str = string.format("%dm", m)
    end
    -- Color based on urgency.
    if seconds < 1800 then
        return "|cffff4444" .. str .. "|r"
    elseif seconds < 7200 then
        return "|cffff8800" .. str .. "|r"
    elseif seconds < 43200 then
        return "|cffffff00" .. str .. "|r"
    else
        return "|cff00ff00" .. str .. "|r"
    end
end

function AT:GetStatusText(status)
    return STATUS_TEXT[status] or ""
end

function AT:OnLogin()
    if auctionFrame then
        auctionFrame:UnregisterAllEvents()
    end
    auctionFrame = CreateFrame("Frame")
    auctionFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    auctionFrame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
    auctionFrame:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then
            -- Request owned auctions; results arrive via OWNED_AUCTIONS_UPDATED.
            C_AuctionHouse.QueryOwnedAuctions({
                { sortOrder = Enum.AuctionHouseSortOrder.TimeRemaining, reverseSort = false },
            })
        elseif event == "OWNED_AUCTIONS_UPDATED" then
            ScanOwnedAuctions()
            -- Refresh UI if it's open.
            if ns.UI and ns.UI.mainFrame and ns.UI.mainFrame:IsShown() then
                ns.UI:Refresh()
            end
        end
    end)
end

function AT:OnLogout()
    if auctionFrame then
        auctionFrame:UnregisterAllEvents()
        auctionFrame = nil
    end
end
