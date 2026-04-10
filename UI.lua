-- UI.lua
-- Slash command and main display frame.
local addonName, ns = ...

ns.UI = {}
local UI = ns.UI

local FRAME_W  = 420
local FRAME_H  = 520
local PADDING  = 10

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function ClassColor(classFile)
    local c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x",
        math.floor(c.r * 255),
        math.floor(c.g * 255),
        math.floor(c.b * 255))
end

local function FormatDate(ts)
    if not ts then return "never" end
    return date("%Y-%m-%d %H:%M", ts)
end

-- ── Frame construction ────────────────────────────────────────────────────────

local function CreateMainFrame()
    local f = CreateFrame("Frame", "InfoBotWoWMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    f:Hide()

    -- Allow ESC to close the window.
    tinsert(UISpecialFrames, "InfoBotWoWMainFrame")

    f:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.12, 0.96)
    f:SetBackdropBorderColor(0.35, 0.35, 0.50, 1)

    -- Title bar texture
    local bar = f:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(0.15, 0.15, 0.30, 1)
    bar:SetPoint("TOPLEFT",  f, "TOPLEFT",  5, -5)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    bar:SetHeight(26)

    -- Title text
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
    title:SetText("|cff00ccffInfoBot|r |cffffd700WoW|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 20)
    refreshBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -8)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() UI:Refresh() end)

    -- Scroll frame (leaves room for title bar + close button)
    local sf = CreateFrame("ScrollFrame", "InfoBotWoWScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",   5, -36)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 5)

    -- Scroll child (content)
    local content = CreateFrame("Frame", "InfoBotWoWContent", sf)
    content:SetWidth(FRAME_W - 45)
    content:SetHeight(1)  -- dynamically resized in Refresh()
    sf:SetScrollChild(content)

    -- Single FontString for all content
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", PADDING, -PADDING)
    text:SetWidth(content:GetWidth() - PADDING * 2)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)

    UI.mainFrame  = f
    UI.scrollFrame = sf
    UI.content    = content
    UI.textDisplay = text

    f:SetScript("OnShow", function() UI:Refresh() end)
end

-- ── Refresh ───────────────────────────────────────────────────────────────────

function UI:Refresh()
    local GT = ns.GoldTracker
    local AT = ns.AuctionTracker
    local lines = {}

    -- ── Section 1: Character Gold ─────────────────────────────────────────────
    lines[#lines + 1] = "|cff00ccff-- Character Gold ----------------------------|r"

    local myKey    = ns.GetCharKey()
    local charList = GT:GetAllCharacters()
    local total    = 0

    if #charList == 0 then
        lines[#lines + 1] = "  |cff888888No character data yet.|r"
    else
        for _, entry in ipairs(charList) do
            local d   = entry.data
            local tag = entry.key == myKey and " |cff00ff00(you)|r" or ""
            local cc  = ClassColor(d.class)
            lines[#lines + 1] = string.format("  %s%s|r%s — %s",
                cc, d.name or "?", tag, ns.FormatGold(d.gold))
            total = total + (d.gold or 0)
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("  |cffffd700Total across %d character(s): %s|r",
            #charList, ns.FormatGold(total))
    end

    -- ── Section 2: Session Summary ────────────────────────────────────────────
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cff00ccff-- Session Summary ---------------------------|r"

    local startGold = InfoBotWoWChar.sessionStartGold or 0
    local curGold   = GetMoney()
    local change    = GT:GetSessionChange()

    local changeStr
    if change > 0 then
        changeStr = "|cff00ff00+" .. ns.FormatGold(change) .. "|r"
    elseif change < 0 then
        changeStr = "|cffff4444-" .. ns.FormatGold(math.abs(change)) .. "|r"
    else
        changeStr = "|cff888888no change|r"
    end

    lines[#lines + 1] = "  Started with : " .. ns.FormatGold(startGold)
    lines[#lines + 1] = "  Current      : " .. ns.FormatGold(curGold)
    lines[#lines + 1] = "  Session net  : " .. changeStr

    -- ── Section 3: Active Auctions ────────────────────────────────────────────
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cff00ccff-- Active Auctions ---------------------------|r"

    local auctions  = AT:GetAuctions()
    local lastScan  = AT:GetLastScanTime()

    if lastScan then
        lines[#lines + 1] = string.format("  |cff888888Last scanned: %s|r", FormatDate(lastScan))
    else
        lines[#lines + 1] = "  |cff888888Open the Auction House to scan.|r"
    end

    if #auctions == 0 then
        lines[#lines + 1] = "  |cff888888No active auctions found.|r"
    else
        lines[#lines + 1] = ""
        local auctionTotal = 0
        for _, a in ipairs(auctions) do
            local timeStr   = AT:GetTimeLeftText(a.timeLeftSeconds)
            local statusStr = AT:GetStatusText(a.status)
            local buyoutPer = a.buyoutAmount or 0
            -- For commodities buyoutAmount is per-unit; for items it's the full price.
            local totalVal  = a.isCommodity and (buyoutPer * (a.quantity or 1)) or buyoutPer
            auctionTotal    = auctionTotal + (a.status == 0 and totalVal or 0)

            -- Show: [item link] xN — buyout ea — time left [status]
            local qtyStr = a.quantity > 1
                and string.format(" x|cffffd700%d|r", a.quantity)
                or ""
            lines[#lines + 1] = string.format("  %s%s",
                a.itemLink or a.itemName or "Unknown", qtyStr)
            lines[#lines + 1] = string.format("    Buyout: %s  |  %s%s",
                ns.FormatGold(buyoutPer), timeStr, statusStr)
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("  |cffffd700%d auction(s) — Total value: %s|r",
            #auctions, ns.FormatGold(auctionTotal))
    end

    self.textDisplay:SetText(table.concat(lines, "\n"))

    -- Fit content frame to text height so scrolling works correctly.
    local textH = self.textDisplay:GetHeight()
    self.content:SetHeight(math.max(textH + PADDING * 2, FRAME_H))
end

-- ── Slash commands ────────────────────────────────────────────────────────────

local function RegisterSlash()
    SLASH_INFOBOTWOW1 = "/ibot"
    SLASH_INFOBOTWOW2 = "/infobot"
    SlashCmdList["INFOBOTWOW"] = function(msg)
        msg = strtrim(msg):lower()
        if msg == "help" then
            print("|cff00ccff[InfoBot]|r commands:")
            print("  |cffffd700/ibot|r         — open / close the window")
            print("  |cffffd700/ibot help|r     — show this help")
            print("  |cffffd700/ibot reset|r    — reset session gold baseline to current gold")
        elseif msg == "reset" then
            InfoBotWoWChar.sessionStartGold = GetMoney()
            print("|cff00ccff[InfoBot]|r Session baseline reset to " .. ns.FormatGold(GetMoney()))
        else
            if UI.mainFrame:IsShown() then
                UI.mainFrame:Hide()
            else
                UI:Refresh()
                UI.mainFrame:Show()
            end
        end
    end
end

-- ── Mini gold tracker ─────────────────────────────────────────────────────────

local function CreateMiniTracker()
    local btn = CreateFrame("Button", "InfoBotWoWMini", UIParent, "BackdropTemplate")
    btn:SetSize(160, 28)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", function()
        btn:StopMovingOrSizing()
        -- Save position to saved variables.
        InfoBotWoWChar.miniTrackerPosition = {
            point = "TOPRIGHT",
            relativeTo = "UIParent",
            relativePoint = "TOPRIGHT",
            xOffset = btn:GetRect() and (btn:GetRight() - UIParent:GetRight()) or -220,
            yOffset = btn:GetRect() and (btn:GetTop() - UIParent:GetTop()) or -4,
        }
    end)
    btn:SetFrameStrata("HIGH")

    btn:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.12, 0.85)
    btn:SetBackdropBorderColor(0.35, 0.35, 0.50, 1)

    -- Addon icon on the left side of the mini tracker.
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
    icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetText(ns.FormatGold(GetMoney()))

    btn:SetScript("OnClick", function()
        if UI.mainFrame:IsShown() then
            UI.mainFrame:Hide()
        else
            UI:Refresh()
            UI.mainFrame:Show()
        end
    end)

    -- Update the mini display when gold changes.
    local updater = CreateFrame("Frame")
    updater:RegisterEvent("PLAYER_MONEY")
    updater:SetScript("OnEvent", function()
        text:SetText(ns.FormatGold(GetMoney()))
        -- Auto-resize to fit the icon + gold text.
        btn:SetWidth(math.max(icon:GetWidth() + text:GetStringWidth() + 16, 100))
    end)

    -- Initial sizing.
    btn:SetWidth(math.max(icon:GetWidth() + text:GetStringWidth() + 16, 100))

    -- Restore saved position or use default.
    local pos = InfoBotWoWChar.miniTrackerPosition
    if pos then
        btn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", pos.xOffset, pos.yOffset)
    else
        btn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -4)
    end

    UI.miniTracker = btn
    UI.miniText    = text
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function UI:OnLogin()
    CreateMainFrame()
    CreateMiniTracker()
    RegisterSlash()
end
