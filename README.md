# mod-endless-storage

Unlimited per-character material, gem, and recipe storage for an [AzerothCore](https://www.azerothcore.org/) **WoW 3.3.5a (WotLK)** server.

## What it does

Adds a server-side **bottomless storage** for crafting consumables. Players deposit all of their Trade Goods, gems, and recipes from their bags with a single click, and retrieve them later from a tabbed in-game UI — no NPC, no gossip menu, no bag-space pressure.

Items are organized automatically:

| Item class | Condition | Storage tab |
|------------|-----------|-------------|
| Trade Goods (`ITEM_CLASS_TRADE_GOODS`) | `MaxStackSize > 1` | one of 15 material tabs (by subclass: Cloth, Leather, Metal & Stone, Herb, …) |
| Gems (`ITEM_CLASS_GEM`) | `MaxStackSize > 1` | Jewelcrafting tab |
| Recipes (`ITEM_CLASS_RECIPE`) | all | Recipes tab |

Stored amounts are per character.

## Key features

- **One-click deposit** of all eligible items currently in the player's bags
- **Tabbed UI** with 15 material categories + a jewelcrafting tab + a recipes tab
- **Scrollable lists** with item icon, name, stack count, and a "Take" button per row
- **Draggable, ESC-closeable frame** (560×440), position stored account-wide via LibWindow
- **No NPC required** — the UI opens via the `/es` or `/storage` slash command
- **Database-backed** in `acore_characters.custom_endless_storage` (PK `(character_id, item_entry)`)
- Fully delivered to the client via the [AIO framework](https://github.com/Rochet2/AIO) — no manual addon installation per item

## Installation

1. Place this module inside the AzerothCore `modules/` directory:
   ```bash
   cd azerothcore-wotlk/modules
   git clone https://github.com/Shoro2/mod-endless-storage.git
   ```
2. Re-run CMake and build the server:
   ```bash
   cd ../build
   cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DSCRIPTS=static -DMODULES=static
   make -j$(nproc) && make install
   ```
3. Apply the SQL files shipped under `data/sql/db-characters/` (the AzerothCore SQL updater picks them up automatically).
4. The client side requires the [AIO addon](https://github.com/Rochet2/AIO) installed in `Interface/AddOns/`. The storage UI ships with this module's Lua sources and is delivered to the client by AIO automatically.
5. Restart the world server. In-game, type `/es` or `/storage` to open the UI.

## Usage

- `/es` or `/storage` — open the storage frame
- Click **Deposit All Materials** to move every eligible stack from your bags into storage
- Click **Take** on any row to retrieve the full stack into your inventory
- Use the left-side tabs to navigate between materials, gems, and recipes

## Limitations

- Only the listed item classes are accepted (no equipment, no gold, no consumables outside Trade Goods/gems/recipes)
- Storage is strictly per character — no account-wide sharing
- No bulk withdraw via Shift+click (planned)
- No auction house forwarding

## Requirements

- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) (WoW 3.3.5a / WotLK)
- [AIO framework](https://github.com/Rochet2/AIO) — for the in-game UI

## Optional integrations

- [mod-auto-loot](https://github.com/Shoro2/mod-auto-loot) — Trade Goods land in the inventory; deposit them in one click via "Deposit All"
- [mod-loot-filter](https://github.com/Shoro2/mod-loot-filter) — apply a "Keep" rule on Trade Goods so they aren't accidentally sold

## License

GPL v2 (see `LICENSE`).
