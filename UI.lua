-- UI.lua
-- Slash command and main display frame.
local addonName, ns = ...

ns.UI = {}
local UI = ns.UI

local FRAME_W  = 420
local FRAME_H  = 520
local PADDING  = 10

local DEFAULT_OPTIONS = {
    enabled = true,
    lockMiniBar = false,
    showMiniBar = true,
    showGold = true,
    showFPS = false,
    showXP = false,
    showLocation = false,
    barOrientation = "horizontal",
    barScale = 1.0,
    xpDisplayMode = "left",
    barUpdateInterval = 0.5,
    coordPrecision = 1,
    openMainOnLogin = false,
    autoRefreshOnOpen = true,
    showCharacterGoldSection = true,
    showSessionSummarySection = true,
    showAuctionsSection = true,
    show24HourTime = true,
    enableChatNotifications = true,
    notifyXPETAAvailable = true,
}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function ClassColor(classFile)
    local c
    if classFile and C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then
            c = {
                r = color.r,
                g = color.g,
                b = color.b,
            }
        end
    end
    if not c then
        c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    end
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x",
        math.floor(c.r * 255),
        math.floor(c.g * 255),
        math.floor(c.b * 255))
end

local function FormatDate(ts, use24h)
    if not ts then return "never" end
    if use24h then
        return date("%Y-%m-%d %H:%M", ts)
    end
    return date("%Y-%m-%d %I:%M %p", ts)
end

local function FormatDuration(seconds)
    if not seconds or seconds <= 0 then
        return "0m"
    end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return string.format("%dh %dm", h, m)
    end
    return string.format("%dm", m)
end

function UI:GetBarOptions()
    return self:GetOptions()
end

function UI:GetOptions()
    PocketLedgerChar = PocketLedgerChar or {}

    -- Migrate legacy barOptions keys into the unified options table.
    if PocketLedgerChar.barOptions and not PocketLedgerChar.uiOptions then
        PocketLedgerChar.uiOptions = {
            showFPS = PocketLedgerChar.barOptions.showFPS,
            showXP = PocketLedgerChar.barOptions.showXP,
            showLocation = PocketLedgerChar.barOptions.showLocation,
        }
    end

    PocketLedgerChar.uiOptions = PocketLedgerChar.uiOptions or {}
    local o = PocketLedgerChar.uiOptions
    for k, v in pairs(DEFAULT_OPTIONS) do
        if o[k] == nil then
            o[k] = v
        end
    end
    return o
end

function UI:ResetOptionsToDefaults()
    PocketLedgerChar.uiOptions = nil
    self:GetOptions()
end

function UI:Notify(msg)
    if self:GetOptions().enableChatNotifications then
        print("|cff00ccff[Pocket Ledger]|r " .. msg)
    end
end

function UI:GetBarUpdateInterval()
    local interval = tonumber(self:GetOptions().barUpdateInterval) or 0.5
    return math.max(0.2, math.min(2.0, interval))
end

function UI:InitXPSession()
    self.xpSession = {
        startTime = time(),
        level = UnitLevel("player"),
        xp = UnitXP("player"),
        xpMax = UnitXPMax("player"),
        totalGained = 0,
    }
end

function UI:UpdateXPSession()
    if not self.xpSession then
        self:InitXPSession()
        return
    end

    local state = self.xpSession
    local level = UnitLevel("player")
    local xp = UnitXP("player")
    local xpMax = UnitXPMax("player")

    if level > state.level then
        local rolloverGain = math.max((state.xpMax or xpMax) - (state.xp or 0), 0) + xp
        state.totalGained = state.totalGained + rolloverGain
    elseif level == state.level then
        local delta = xp - (state.xp or 0)
        if delta > 0 then
            state.totalGained = state.totalGained + delta
        end
    end

    state.level = level
    state.xp = xp
    state.xpMax = xpMax
end

function UI:GetXPBarText()
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL
    local level = UnitLevel("player")
    if maxLevel and level >= maxLevel then
        return "|cff88ff88XP: max|r"
    end

    if not self.xpSession then
        self:InitXPSession()
    end

    local curXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local needed = math.max(maxXP - curXP, 0)
    local elapsed = math.max(time() - self.xpSession.startTime, 1)
    local rate = self.xpSession.totalGained / elapsed

    if rate <= 0 then
        return string.format("|cff88ff88XP: %d left (ETA n/a)|r", needed)
    end

    local eta = needed / rate
    if self:GetOptions().notifyXPETAAvailable and not self.xpSession.etaNotified then
        self.xpSession.etaNotified = true
        self:Notify("XP ETA now available.")
    end
    return string.format("|cff88ff88XP: %d left (%s)|r", needed, FormatDuration(eta))
end

function UI:GetXPCurrentText()
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL
    local level = UnitLevel("player")
    if maxLevel and level >= maxLevel then
        return "|cff88ff88XP: max|r"
    end

    if not self.xpSession then
        self:InitXPSession()
    end

    local curXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local needed = math.max(maxXP - curXP, 0)
    local elapsed = math.max(time() - self.xpSession.startTime, 1)
    local rate = self.xpSession.totalGained / elapsed
    if rate <= 0 then
        return string.format("|cff88ff88XP: %d/%d (ETA n/a)|r", curXP, maxXP)
    end

    local eta = needed / rate
    if self:GetOptions().notifyXPETAAvailable and not self.xpSession.etaNotified then
        self.xpSession.etaNotified = true
        self:Notify("XP ETA now available.")
    end
    return string.format("|cff88ff88XP: %d/%d (%s)|r", curXP, maxXP, FormatDuration(eta))
end

function UI:GetLocationBarText()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return "|cffccccccLoc: Unknown|r"
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name or "Unknown"
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        return string.format("|cffccccccLoc: %s|r", zoneName)
    end

    local precision = (self:GetOptions().coordPrecision == 0) and 0 or 1
    local x = pos.x * 100
    local y = pos.y * 100
    local fmt = precision == 0 and "|cffccccccLoc: %s %.0f, %.0f|r" or "|cffccccccLoc: %s %.1f, %.1f|r"
    return string.format(fmt, zoneName, x, y)
end

function UI:UpdateMiniTrackerDisplay()
    if not self.miniTracker or not self.miniText then return end

    local options = self:GetBarOptions()
    local parts = {}

    if options.showGold then
        parts[#parts + 1] = ns.FormatGold(GetMoney())
    end

    if options.showFPS then
        local fps = math.floor(GetFramerate() + 0.5)
        local padded = string.format("%03d", fps)
        local fpsText
        if fps < 100 then
            -- Keep layout width stable but hide only the first padded digit.
            fpsText = "|c00000000" .. padded:sub(1, 1) .. "|r|cff80d4ff" .. padded:sub(2)
        else
            fpsText = padded
        end
        parts[#parts + 1] = "|cff80d4ffFPS: " .. fpsText .. "|r"
    end
    if options.showXP and options.xpDisplayMode ~= "bar" then
        if options.xpDisplayMode == "current" then
            parts[#parts + 1] = self:GetXPCurrentText()
        else
            parts[#parts + 1] = self:GetXPBarText()
        end
    end
    if options.showLocation then
        parts[#parts + 1] = self:GetLocationBarText()
    end

    if #parts == 0 then
        parts[1] = "|cffbbbbbbPocket Ledger|r"
    end

    local delimiter = options.barOrientation == "vertical" and "\n" or "   |   "
    self.miniText:SetText(table.concat(parts, delimiter))

    if options.showXP and options.xpDisplayMode == "bar" and self.miniXPBar then
        local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL
        local level = UnitLevel("player")
        if maxLevel and level >= maxLevel then
            self.miniXPBar:SetMinMaxValues(0, 1)
            self.miniXPBar:SetValue(1)
            self.miniXPBar:Show()
        else
            local curXP = UnitXP("player")
            local maxXP = math.max(UnitXPMax("player"), 1)
            self.miniXPBar:SetMinMaxValues(0, maxXP)
            self.miniXPBar:SetValue(curXP)
            self.miniXPBar:Show()
        end
    elseif self.miniXPBar then
        self.miniXPBar:Hide()
    end

    self:UpdateMiniTrackerLayout()
end

function UI:UpdateMiniTrackerLayout()
    if not self.miniTracker or not self.miniText or not self.miniIcon then return end

    local options = self:GetOptions()

    self.miniTracker:SetScale(options.barScale or 1.0)

    self.miniIcon:ClearAllPoints()
    self.miniText:ClearAllPoints()
    if self.miniXPBar then
        self.miniXPBar:ClearAllPoints()
    end

    if options.barOrientation == "vertical" then
        local baseWidth = 170
        self.miniTracker:SetWidth(baseWidth)
        self.miniIcon:SetPoint("TOP", self.miniTracker, "TOP", 0, -8)
        self.miniText:SetPoint("TOP", self.miniIcon, "BOTTOM", 0, -4)
        self.miniText:SetJustifyH("CENTER")
        self.miniText:SetWordWrap(true)
        self.miniText:SetWidth(baseWidth - 16)

        local textH = math.max(self.miniText:GetStringHeight(), 12)
        local totalH = 8 + self.miniIcon:GetHeight() + 4 + textH + 8
        if self.miniXPBar and self.miniXPBar:IsShown() then
            self.miniXPBar:SetPoint("BOTTOM", self.miniTracker, "BOTTOM", 0, 8)
            self.miniXPBar:SetSize(132, 12)
            totalH = totalH + 18
        end
        self.miniTracker:SetHeight(math.max(totalH, 96))
    else
        local hasXPBar = self.miniXPBar and self.miniXPBar:IsShown()
        self.miniTracker:SetHeight(hasXPBar and 42 or 30)
        self.miniIcon:SetPoint("LEFT", self.miniTracker, "LEFT", 6, hasXPBar and 4 or 0)
        self.miniText:SetPoint("LEFT", self.miniIcon, "RIGHT", 4, hasXPBar and 4 or 0)
        self.miniText:SetJustifyH("LEFT")
        self.miniText:SetWordWrap(false)
        self.miniText:SetWidth(1200)
        local width = math.max(self.miniIcon:GetWidth() + self.miniText:GetStringWidth() + 18, 160)
        if hasXPBar then
            width = math.max(width, 260)
            self.miniXPBar:SetPoint("BOTTOM", self.miniTracker, "BOTTOM", 0, 6)
            self.miniXPBar:SetSize(width - 36, 12)
        end
        self.miniTracker:SetWidth(width)
    end

end

function UI:ApplyOptions()
    local options = self:GetOptions()

    if self.miniTracker then
        if options.enabled and options.showMiniBar then
            self.miniTracker:Show()
        else
            self.miniTracker:Hide()
        end
    end

    if self.mainFrame and not options.enabled and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    end

    self:UpdateMiniTrackerDisplay()
end

-- ── Frame construction ────────────────────────────────────────────────────────

local function CreateMainFrame()
    local f = CreateFrame("Frame", "PocketLedgerMainFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    f:Hide()

    -- Allow ESC to close the window.
    tinsert(UISpecialFrames, "PocketLedgerMainFrame")

    f.TitleText:SetText("Pocket Ledger")

    -- Reset Bar button (re-centers the mini tracker)
    local resetBarBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBarBtn:SetSize(80, 20)
    resetBarBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -90, -30)
    resetBarBtn:SetText("Reset Bar")
    resetBarBtn:SetScript("OnClick", function()
        if UI.miniTracker then
            UI.miniTracker:ClearAllPoints()
            UI.miniTracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            PocketLedgerChar.miniTrackerPosition = nil
            print("|cff00ccff[Pocket Ledger]|r Mini tracker reset to center.")
        end
    end)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 20)
    refreshBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -30)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() UI:Refresh() end)

    local optionsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    optionsBtn:SetSize(70, 20)
    optionsBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -176, -30)
    optionsBtn:SetText("Options")
    optionsBtn:SetScript("OnClick", function() UI:OpenOptions() end)

    -- Bar display toggles
    local function CreateOptionCheck(x, y, label, key)
        local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)

        local txt = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", check, "RIGHT", 1, 0)
        txt:SetText(label)

        check:SetScript("OnClick", function(selfBtn)
            UI:GetBarOptions()[key] = selfBtn:GetChecked() and true or false
            UI:ApplyOptions()
        end)

        return check
    end

    local fpsCheck = CreateOptionCheck(88, -58, "FPS", "showFPS")
    local xpCheck = CreateOptionCheck(164, -58, "XP / ETA", "showXP")
    local locCheck = CreateOptionCheck(282, -58, "Location", "showLocation")

    local opts = UI:GetBarOptions()
    fpsCheck:SetChecked(opts.showFPS)
    xpCheck:SetChecked(opts.showXP)
    locCheck:SetChecked(opts.showLocation)

    -- Scroll frame (leaves room for title bar + close button)
    local sf = CreateFrame("ScrollFrame", "PocketLedgerScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",   8, -84)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 5)

    -- Scroll child (content)
    local content = CreateFrame("Frame", "PocketLedgerContent", sf)
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

    f:SetScript("OnShow", function()
        if UI:GetOptions().autoRefreshOnOpen then
            UI:Refresh()
        end
    end)
end

-- ── Refresh ───────────────────────────────────────────────────────────────────

function UI:Refresh()
    local GT = ns.GoldTracker
    local AT = ns.AuctionTracker
    local lines = {}

    local options = self:GetOptions()

    -- ── Section 1: Character Gold ─────────────────────────────────────────────
    if options.showCharacterGoldSection then
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
    end

    -- ── Section 2: Session Summary ────────────────────────────────────────────
    if options.showSessionSummarySection then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cff00ccff-- Session Summary ---------------------------|r"

    local startGold = PocketLedgerChar.sessionStartGold or 0
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
    end

    -- ── Section 3: Active Auctions ────────────────────────────────────────────
    if options.showAuctionsSection then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cff00ccff-- Active Auctions ---------------------------|r"

    local auctions  = AT:GetAuctions()
    local lastScan  = AT:GetLastScanTime()

        if lastScan then
            lines[#lines + 1] = string.format("  |cff888888Last scanned: %s|r", FormatDate(lastScan, options.show24HourTime))
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
    end

    if #lines == 0 then
        lines[1] = "|cff888888All sections are hidden in options.|r"
    end

    self.textDisplay:SetText(table.concat(lines, "\n"))

    -- Fit content frame to text height so scrolling works correctly.
    local textH = self.textDisplay:GetHeight()
    self.content:SetHeight(math.max(textH + PADDING * 2, FRAME_H))
end

-- ── Slash commands ────────────────────────────────────────────────────────────

local function RegisterSlash()
    SLASH_POCKETLEDGER1 = "/pl"
    SLASH_POCKETLEDGER2 = "/pocketledger"
    SlashCmdList["POCKETLEDGER"] = function(msg)
        local function CountChars(db)
            if type(db) ~= "table" or type(db.characters) ~= "table" then
                return 0
            end
            local n = 0
            for _ in pairs(db.characters) do
                n = n + 1
            end
            return n
        end

        msg = strtrim(msg):lower()
        if msg == "help" then
            print("|cff00ccff[Pocket Ledger]|r commands:")
            print("  |cffffd700/pl|r            — open / close the window")
            print("  |cffffd700/pl help|r       — show this help")
            print("  |cffffd700/pl reset|r      — reset session gold baseline to current gold")
            print("  |cffffd700/pl options|r    — open Pocket Ledger options")
            print("  |cffffd700/pl defaults|r   — reset options to defaults")
            print("  |cffffd700/pl diag|r       — print DB diagnostics")
        elseif msg == "diag" then
            local p = CountChars(PocketLedgerDB)
            local b = CountChars(PocketLedgerBackupDB)
            print(string.format("|cff00ccff[Pocket Ledger]|r DB chars: Primary=%d Backup=%d", p, b))
        elseif msg == "reset" then
            PocketLedgerChar.sessionStartGold = GetMoney()
            print("|cff00ccff[Pocket Ledger]|r Session baseline reset to " .. ns.FormatGold(GetMoney()))
        elseif msg == "options" or msg == "settings" then
            UI:OpenOptions()
        elseif msg == "defaults" then
            UI:ResetOptionsToDefaults()
            UI:ApplyOptions()
            UI:Refresh()
            UI:Notify("Options reset to defaults.")
        else
            if not UI:GetOptions().enabled then
                UI:Notify("Addon display is disabled. Use /pl options to re-enable.")
                return
            end
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
    local btn = CreateFrame("Button", "PocketLedgerMini", UIParent, "BackdropTemplate")
    btn:SetSize(220, 28)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        if UI:GetOptions().lockMiniBar then
            return
        end
        btn:StartMoving()
    end)
    btn:SetScript("OnDragStop", function()
        btn:StopMovingOrSizing()
        if UI:GetOptions().lockMiniBar then
            return
        end
        -- Save position to saved variables.
        PocketLedgerChar.miniTrackerPosition = {
            point = "TOPRIGHT",
            relativeTo = "UIParent",
            relativePoint = "TOPRIGHT",
            xOffset = btn:GetRect() and (btn:GetRight() - UIParent:GetRight()) or -220,
            yOffset = btn:GetRect() and (btn:GetTop() - UIParent:GetTop()) or -4,
        }
    end)
    btn:SetFrameStrata("HIGH")

    btn:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile     = true,
        tileSize = 32,
        edgeSize = 16,
        insets   = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    btn:SetBackdropColor(0.15, 0.15, 0.18, 0.95)
    btn:SetBackdropBorderColor(0.7, 0.7, 0.75, 1)

    -- Addon icon on the left side of the mini tracker.
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
    icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetWordWrap(false)
    text:SetText("")

    local xpBar = CreateFrame("StatusBar", nil, btn)
    xpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    xpBar:GetStatusBarTexture():SetHorizTile(false)
    xpBar:SetStatusBarColor(0.45, 0.2, 0.95, 1)
    xpBar:SetMinMaxValues(0, 1)
    xpBar:SetValue(0)
    xpBar:Hide()

    local xpBg = xpBar:CreateTexture(nil, "BACKGROUND")
    xpBg:SetAllPoints()
    xpBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    xpBg:SetColorTexture(0.05, 0.05, 0.05, 0.9)

    local xpBorder = CreateFrame("Frame", nil, xpBar, "BackdropTemplate")
    xpBorder:SetAllPoints()
    xpBorder:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    xpBorder:SetBackdropColor(0, 0, 0, 0)
    xpBorder:SetBackdropBorderColor(0.55, 0.45, 0.08, 1)

    btn:SetScript("OnClick", function()
        if not UI:GetOptions().enabled then
            return
        end
        if UI.mainFrame:IsShown() then
            UI.mainFrame:Hide()
        else
            UI:Refresh()
            UI.mainFrame:Show()
        end
    end)

    -- Update the mini display for money/xp/location/fps.
    local updater = CreateFrame("Frame")
    updater:RegisterEvent("PLAYER_MONEY")
    updater:RegisterEvent("PLAYER_XP_UPDATE")
    updater:RegisterEvent("PLAYER_LEVEL_UP")
    updater:RegisterEvent("PLAYER_ENTERING_WORLD")
    updater:RegisterEvent("ZONE_CHANGED")
    updater:RegisterEvent("ZONE_CHANGED_INDOORS")
    updater:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    updater.elapsed = 0
    updater:SetScript("OnEvent", function()
        UI:UpdateXPSession()
        UI:UpdateMiniTrackerDisplay()
    end)
    updater:SetScript("OnUpdate", function(_, elapsed)
        updater.elapsed = updater.elapsed + elapsed
        if updater.elapsed < UI:GetBarUpdateInterval() then
            return
        end
        updater.elapsed = 0
        UI:UpdateMiniTrackerDisplay()
    end)

    -- Initial sizing.
    UI.miniTracker = btn
    UI.miniText    = text
    UI.miniIcon    = icon
    UI.miniXPBar   = xpBar
    UI:InitXPSession()
    UI:UpdateMiniTrackerDisplay()

    -- Restore saved position or use default.
    local pos = PocketLedgerChar.miniTrackerPosition
    btn:ClearAllPoints()
    if pos then
        btn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", pos.xOffset, pos.yOffset)
    else
        btn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -4)
    end
    UI:UpdateMiniTrackerLayout()

end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "PocketLedgerOptionsPanel")
    panel.name = "Pocket Ledger"
    panel.OnCommit = function() end
    panel.OnDefault = function()
        UI:ResetOptionsToDefaults()
        if panel.RefreshControls then
            panel:RefreshControls()
        end
        UI:ApplyOptions()
        UI:Refresh()
    end
    panel.OnRefresh = function()
        if panel.RefreshControls then
            panel:RefreshControls()
        end
    end

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -26, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetWidth(700)
    content:SetHeight(1400)
    scroll:SetScrollChild(content)

    panel:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth((w or 700) - 40)
    end)

    local controls = {}
    local y = -16

    local function AddHeader(text)
        local h = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        h:SetPoint("TOPLEFT", 16, y)
        h:SetText(text)
        y = y - 26
        return h
    end

    local function AddDesc(text)
        local d = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        d:SetPoint("TOPLEFT", 16, y)
        d:SetText(text)
        y = y - 22
        return d
    end

    local function AddCheckbox(label, key)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(600, 24)
        row:SetPoint("TOPLEFT", 16, y)

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetPoint("LEFT", 0, 0)

        local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        txt:SetText(label)

        cb:SetScript("OnClick", function(selfBtn)
            UI:GetOptions()[key] = selfBtn:GetChecked() and true or false
            UI:ApplyOptions()
            if UI.mainFrame and UI.mainFrame:IsShown() then
                UI:Refresh()
            end
        end)

        controls[#controls + 1] = function()
            cb:SetChecked(UI:GetOptions()[key])
        end

        y = y - 26
        return row
    end

    local function AddSlider(label, key, minVal, maxVal, step)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(680, 56)
        row:SetPoint("TOPLEFT", 16, y)

        local title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        title:SetPoint("TOPLEFT", 4, 0)
        title:SetText(label)

        local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 4, -18)
        slider:SetWidth(240)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider.Low:SetText(tostring(minVal))
        slider.High:SetText(tostring(maxVal))

        local valueText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        valueText:SetPoint("LEFT", slider, "RIGHT", 12, 0)
        valueText:SetText("")

        slider:SetScript("OnValueChanged", function(selfSlider, v)
            local rounded = math.floor((v / step) + 0.5) * step
            if step >= 1 then
                rounded = math.floor(rounded + 0.5)
            else
                rounded = math.floor(rounded * 10 + 0.5) / 10
            end
            UI:GetOptions()[key] = rounded
            if step >= 1 then
                valueText:SetText(tostring(rounded))
            else
                valueText:SetText(string.format("%.1f", rounded))
            end
            UI:ApplyOptions()
        end)

        controls[#controls + 1] = function()
            local v = UI:GetOptions()[key]
            slider:SetValue(v)
            if step >= 1 then
                valueText:SetText(tostring(v))
            else
                valueText:SetText(string.format("%.1f", v))
            end
        end

        y = y - 58
        return row
    end

    local function AddButton(label, onClick)
        local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btn:SetSize(220, 24)
        btn:SetPoint("TOPLEFT", 16, y)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)
        y = y - 30
        return btn
    end

    local function AddRadioGroup(label, key, values)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(680, 56)
        row:SetPoint("TOPLEFT", 16, y)

        local title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        title:SetPoint("TOPLEFT", 4, 0)
        title:SetText(label)

        local buttons = {}
        local x = 8
        for i = 1, #values do
            local opt = values[i]
            local btn = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            btn:SetPoint("TOPLEFT", x, -20)

            local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", btn, "RIGHT", 2, 0)
            txt:SetText(opt.label)

            btn.value = opt.value
            btn:SetScript("OnClick", function(selfBtn)
                for _, b in ipairs(buttons) do
                    b:SetChecked(false)
                end
                selfBtn:SetChecked(true)
                UI:GetOptions()[key] = selfBtn.value
                UI:ApplyOptions()
                if UI.mainFrame and UI.mainFrame:IsShown() then
                    UI:Refresh()
                end
            end)

            buttons[#buttons + 1] = btn
            x = x + 170
        end

        controls[#controls + 1] = function()
            local cur = UI:GetOptions()[key]
            for _, b in ipairs(buttons) do
                b:SetChecked(b.value == cur)
            end
        end

        y = y - 58
        return row
    end

    AddHeader("Pocket Ledger")
    AddDesc("Configure display behavior, bar details, and section visibility.")

    AddHeader("General")
    AddCheckbox("Enable Pocket Ledger", "enabled")
    AddCheckbox("Lock mini bar position", "lockMiniBar")
    AddCheckbox("Show mini bar", "showMiniBar")
    AddButton("Reset mini bar to center", function()
        if UI.miniTracker then
            UI.miniTracker:ClearAllPoints()
            UI.miniTracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            PocketLedgerChar.miniTrackerPosition = nil
            UI:Notify("Mini tracker reset to center.")
        end
    end)

    AddHeader("Mini Bar Stats")
    AddCheckbox("Show gold on mini bar", "showGold")
    AddCheckbox("Show FPS on mini bar", "showFPS")
    AddCheckbox("Show location + coordinates on mini bar", "showLocation")
    AddCheckbox("Show XP needed + ETA on mini bar", "showXP")
    AddRadioGroup("XP display mode", "xpDisplayMode", {
        { label = "Left + ETA", value = "left" },
        { label = "Current/Total + ETA", value = "current" },
        { label = "Mini XP Bar", value = "bar" },
    })
    AddRadioGroup("Bar orientation", "barOrientation", {
        { label = "Horizontal", value = "horizontal" },
        { label = "Vertical", value = "vertical" },
    })
    AddSlider("Bar scale", "barScale", 0.7, 1.8, 0.1)
    AddSlider("Mini bar update interval (seconds)", "barUpdateInterval", 0.2, 2.0, 0.1)
    AddSlider("Coordinate precision (0 or 1 decimal)", "coordPrecision", 0, 1, 1)

    AddHeader("Window Behavior")
    AddCheckbox("Open main window on login", "openMainOnLogin")
    AddCheckbox("Auto-refresh main window when opened", "autoRefreshOnOpen")

    AddHeader("Main Window Sections")
    AddCheckbox("Show Character Gold section", "showCharacterGoldSection")
    AddCheckbox("Show Session Summary section", "showSessionSummarySection")
    AddCheckbox("Show Active Auctions section", "showAuctionsSection")
    AddCheckbox("Show timestamps in 24-hour format", "show24HourTime")

    AddHeader("Notifications")
    AddCheckbox("Enable chat notifications", "enableChatNotifications")
    AddCheckbox("Notify when XP ETA becomes available", "notifyXPETAAvailable")

    AddButton("Reset all options to defaults", function()
        UI:ResetOptionsToDefaults()
        panel:RefreshControls()
        UI:ApplyOptions()
        UI:Refresh()
        UI:Notify("Options reset to defaults.")
    end)

    function panel:RefreshControls()
        for _, fn in ipairs(controls) do
            fn()
        end
    end
    panel:RefreshControls()

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    Settings.RegisterAddOnCategory(category)
    UI.optionsCategoryID = category:GetID()
end

function UI:OpenOptions()
    if not self.optionsCategoryID then
        return
    end
    Settings.OpenToCategory(self.optionsCategoryID)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function UI:OnLogin()
    CreateMainFrame()
    CreateMiniTracker()
    CreateOptionsPanel()
    RegisterSlash()
    self:ApplyOptions()

    if self:GetOptions().openMainOnLogin and self:GetOptions().enabled then
        self.mainFrame:Show()
        if not self:GetOptions().autoRefreshOnOpen then
            self:Refresh()
        end
    end
end
