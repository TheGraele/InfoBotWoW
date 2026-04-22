# Pocket Ledger

A lightweight World of Warcraft addon that tracks gold across all your characters, monitors session earnings, and keeps tabs on your active auctions.

## Features

- **Account-Wide Gold Tracking** — See gold totals for every character on your account in one place, color-coded by class.
- **Session Summary** — Tracks how much gold you've earned or spent since logging in.
- **Auction House Tracking** — Automatically scans your active auctions when you visit the AH, showing item details, buyout prices, and color-coded time remaining.
- **Mini Gold Tracker** — A small, draggable on-screen display showing your current gold. Click it to open the full Pocket Ledger window.
- **Slash Commands** — `/pl` or `/pocketledger` to toggle the window, `/pl reset` to reset your session baseline, `/pl help` for usage info.

## Installation

1. Download or clone this repository:
   ```bash
   git clone git@github.com:TheGraele/PocketLedger.git
   ```
2. Copy (or symlink) the folder into your WoW addons directory and **rename it to `PocketLedger`**:
   ```
   /Applications/World of Warcraft/_retail_/Interface/AddOns/PocketLedger/
   ```
   The folder name must match the `.toc` filename exactly.
3. Restart WoW or return to the character select screen. The addon will appear in your AddOns list.

## Usage

| Command | Description |
|---|---|
| `/pl` | Toggle the Pocket Ledger window |
| `/pl help` | Show available commands |
| `/pl reset` | Reset session gold baseline to current gold |

You can also click the mini gold tracker bar (top-right of screen) to toggle the window. The bar is draggable.

Auction data updates automatically whenever you open the Auction House.

## File Structure

| File | Purpose |
|---|---|
| `PocketLedger.toc` | Addon manifest (interface version, saved variables) |
| `Core.lua` | Addon initialization, event routing, shared utilities |
| `GoldTracker.lua` | Per-character gold tracking, account-wide storage |
| `AuctionTracker.lua` | Owned auction scanning and persistence |
| `UI.lua` | Main display frame, mini tracker, slash commands |

## Requirements

- World of Warcraft Retail (Midnight — patch 12.0.5+)

## License

MIT
