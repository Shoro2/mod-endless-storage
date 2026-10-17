# mod-endless-storage

Unlimited per-character material, gem and recipe storage for an [AzerothCore](https://www.azerothcore.org/) **WoW 3.3.5a (WotLK)** server. Part of the Forgotten Land server project.

The module adds a server-side **bottomless storage** for crafting consumables. Players deposit their Trade Goods, gems and recipes from their bags with one click and take them out again from a tabbed in-game window: no NPC, no gossip menu, no bag-space pressure. The module is Lua-only (Lua engine + AIO); the C++ part is an empty loader stub that just registers the module with the build system.

## Features

- **One-click deposit** of eligible items from the bags.
- **Tabbed window** with material categories (Parts, Explosives, Devices, Gems & JC, Cloth, Leather, Metal & Stone, Meat, Herb, Elemental, Other, Enchanting, Materials, Armor/Weapon Vellum), a Recipes tab and a Food & Drinks tab.
- Scrollable lists with item icon, name, stack count and a "Take" button per row; Shift/Ctrl-click withdraws 10 / 100 stacks at once.
- Item search and an activity log.
- **Crafting integration**: the profession window shows how many crafts are possible from bags plus storage, and "Create" / "Create All" buttons craft from storage.
- No NPC needed: the window opens with `/es` or `/storage`.
- State in `acore_characters.custom_endless_storage` (key `character_id` + `item_entry`); storage is per character.
- The UI is delivered to the client by [AIO](https://github.com/Rochet2/AIO), no manual addon installation.

Accepted items: Trade Goods and gems with a stack size above 1, all recipes, and stackable food and drinks.

## Requirements

- AzerothCore WotLK (upstream is sufficient; the module has no C++ logic).
- A Lua engine module ([mod-ale](https://github.com/azerothcore/mod-ale), Eluna-compatible) and the [AIO framework](https://github.com/Rochet2/AIO) (server side and client addon).

## Installation

1. Clone the module into the `modules/` directory of the server source:
   ```bash
   cd azerothcore-wotlk/modules
   git clone https://github.com/Shoro2/mod-endless-storage.git
   ```
2. Re-run CMake and rebuild the server.
3. SQL: `data/sql/db-characters/base/create_tables.sql` creates the storage table; the AzerothCore DB updater applies it on the next server start.
4. Copy the `lua_scripts/Storage/` folder (`endless_storage_server.lua`, `endless_storage_client.lua`, `endless_storage_crafting_client.lua`) into the server's `lua_scripts/` folder. AIO sends the client files to players, who need the AIO client addon.
5. Optional: copy `conf/endless_storage.conf.dist` to your server's module config folder as `endless_storage.conf`.
6. Restart the world server. In game, type `/es` or `/storage`.

## Configuration

`conf/endless_storage.conf.dist` ships one key, `EndlessStorage.Enable` (default `1`). The Lua-only implementation does not read it; to switch the module off, remove the `Storage` folder from `lua_scripts/`.

## Usage

- `/es` or `/storage` - open the storage window.
- **Deposit All Materials** moves eligible items from the bags into storage.
- **Take** on a row withdraws a stack (Shift: 10 stacks, Ctrl: 100 stacks, capped by the stored amount).
- Left-hand tabs switch between material categories, recipes and food & drinks.
- With a profession window open, the "Create" buttons craft using reagents from storage; this path needs the open profession window.

## Limitations

- Only the item classes above are accepted (no equipment, gold or other consumables).
- Storage is per character, not shared across the account.
- No auction house forwarding.
