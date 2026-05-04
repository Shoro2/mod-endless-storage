# File and directory structure — mod-endless-storage

> Static inventory. Maintain this when adding/removing files.

## Tree

```
mod-endless-storage/
├── conf/
│   └── (config templates if present)
├── data/sql/
│   └── db-characters/
│       └── base/
│           └── create_tables.sql              # Schema: custom_endless_storage
├── lua_scripts/
│   └── Storage/
│       ├── endless_storage_server.lua         # Eluna server: handlers + DB queries (~13 KB)
│       ├── endless_storage_client.lua         # AIO client: storage frame + tabs (~17.5 KB)
│       └── endless_storage_crafting_client.lua # AIO client: TradeSkill UI hook for crafting (~12.5 KB)
├── src/
│   └── mod_endless_storage_loader.cpp         # Mini loader stub (~300 B, almost empty — module is Lua-only)
├── include.sh                                  # Build integration
├── CLAUDE.md                                   # Detailed content doc
├── README.md                                   # GitHub readme (short)
├── log.md                                      # Commit log (modular)
├── data_structure.md                           # This file
└── functions.md                                # Mechanics and function reference
```

## File purposes

| File | Purpose |
|-------|-------|
| `data/sql/.../create_tables.sql` | Creates `custom_endless_storage` (PK: character_id + item_entry) |
| `lua_scripts/Storage/endless_storage_server.lua` | Eluna script. Registers server AIO handlers (`Deposit`, `Withdraw`, `RequestData`, `CheckCraftMaterials`, `CraftFromStorage`); caches item templates from WorldDB |
| `lua_scripts/Storage/endless_storage_client.lua` | Storage main window: 16 tabs (15 material subclasses + recipe tab), ScrollFrame, Take buttons, "Deposit All Materials" |
| `lua_scripts/Storage/endless_storage_crafting_client.lua` | Hooks `TradeSkillFrame_Update`: shows recipe lists with combined inventory+storage counts, replaces Create buttons with storage-aware versions |
| `src/mod_endless_storage_loader.cpp` | Loader stub. Since March 2026 the module is a pure Lua/AIO module; C++ crafting hooks have been removed |
| `include.sh` | Registers SQL path (`data/sql/db-characters/base/`) for auto-update |

## Important architecture note

Since commit `691ffaf` (2026-03-22) there are **no C++ hooks** for crafting anymore. The previously used core hooks `OnPlayerCheckReagent` / `OnPlayerConsumeReagent` (defined in azerothcore-wotlk) are **no longer used** by mod-endless-storage. Crafting runs entirely client-side via the TradeSkill UI hook + AIO round trip to the server.

→ Consequence: the loader stub (`src/mod_endless_storage_loader.cpp`) is trivial, and there is **no `.cpp` file with logic** anymore. If you want to change crafting behavior, it is exclusively Lua.

## Size notes (as of 2026-05-01)

- `endless_storage_client.lua` ~17.5 KB — readable in one piece, close to the limit
- `endless_storage_crafting_client.lua` ~12.5 KB — readable in one piece
- `endless_storage_server.lua` ~13 KB — readable in one piece
- `mod_endless_storage_loader.cpp` ~300 B
- SQL ~1 KB

## External dependencies

- **azerothcore-wotlk** (core): minimal — only the loader plumbing. Eluna plugin must be active.
- **AIO framework**: `lua_scripts/AIO.lua` + dependencies (from `share-public/AIO_Server/`).
- **mod-loot-filter** (optional): can deposit items directly into `custom_endless_storage` via the Keep action, instead of leaving them in the inventory.

## DB tables (`acore_characters`)

| Table | PK | Contents |
|---------|----|--------|
| `custom_endless_storage` | `(character_id, item_entry)` | item_subclass, item_class, amount |

## What is not where?

- **No own NPCs / gossip menus** — the UI is AIO-only.
- **No own spells/items/DBC overrides**.
- **No worlddb schema** — only reads via `WorldDBQuery` (item_template cache).
- **No more C++ logic** since March 2026.
