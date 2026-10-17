# mod-endless-storage

> **Internal docs live in the vault, not here** (rule since 2026-10-18: this public repo keeps only
> README.md with the general info and installation, this CLAUDE.md, the license and the code).
> Index, data structure, functions, log and todo: share-public `docs/World of Warcraft/module-repos/mod-endless-storage/`
> (local checkout `C:\Users\Anwender\Documents\GitHub\share-public`). Update them there,
> in a vault worktree, in the same session as the code change.

> Read [`INDEX.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/00-index.md) first. Mechanics & AIO handlers: [`functions.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/functions.md). Folder layout: [`data_structure.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/data_structure.md). Open items: [`todo.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/todo.md). Commit trail: [`log.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/log.md).

## What is the module?

AzerothCore module for **WoW 3.3.5a (WotLK)**. Provides a server-side, **unlimited material storage** for crafting consumables, gems, and recipes. Players deposit their Trade Goods/gems/recipes with one click and retrieve them per-tab — all through a full WoW AIO UI (no NPC, no gossip menu).

Functionally related to [`mod-reagent-bank`](https://github.com/Shoro2/mod-reagent-bank), but with a real frame UI instead of a gossip and an additional recipes tab.

## Role in the overall project

The module is standalone — it has **no** hard dependencies on other custom modules. Relations:

| Module | Relation |
|-------|-----------|
| `mod-auto-loot` | when active: looted Trade Goods land in the inventory; the player then deposits them manually via "Deposit All" into storage |
| `mod-loot-filter` | optional: can apply a "Keep" filter rule to Trade Goods so they aren't accidentally sold, then move them to storage manually |

The module **expands** the reagent inventory: when the player performs a crafting action, the UI side can transparently pull reagents from storage (details: [`functions.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/functions.md)).

## Custom data

| Type | Entry | Note |
|-----|--------|-----------|
| **DB table (acore_characters)** | `custom_endless_storage` | PK `(character_id, item_entry)`, plus `item_subclass`, `item_class`, `amount` |
| **DBC patches** | none | |
| **Custom spells/NPCs/items** | none | |
| **AIO handler names** | `EndlessStorage` (server) / `ES_Client` (client) | Details: [`functions.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/functions.md#aio-handler) |
| **Slash commands** | `/es`, `/storage` | open the storage UI |
| **GM commands** | none | |

## Accepted item classes

| Class | Condition | Tab |
|--------|-----------|-----|
| `ITEM_CLASS_TRADE_GOODS` (7) | `MaxStackSize > 1` | by subclass (15 material tabs) |
| `ITEM_CLASS_GEM` (3) | `MaxStackSize > 1` | Jewelcrafting tab |
| `ITEM_CLASS_RECIPE` (9) | all | Recipes tab |

## UI layout (top level)

```
+--------------------------------------------------+
| Endless Storage                            [X]   |
+----------+---------------------------------------+
| Parts    | [icon] Item Name           x100 [Take]|
| Cloth    | [icon] Item Name            x50 [Take]|
| Leather  | [icon] Item Name           x200 [Take]|
| ...      | (FauxScrollFrame, 11 visible rows)    |
| Recipes  |                                       |
+----------+---------------------------------------+
|          [ Deposit All Materials ]               |
+--------------------------------------------------+
```

The frame is 560×440, draggable, ESC-close. Position is stored account-wide (LibWindow).

## What this module does **not** do

- **no** equipment storage, no gold storage — only the item classes listed above
- **no** auction house forwarding
- **no** storage sharing between characters of the same account (currently strictly per character)
- **no** bulk withdraw via the UI (Shift+click etc.) — see [`todo.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/todo.md)

## Notes on the current architecture

In an earlier phase (before March 2026) the module ran with an additional C++ layer (`mod_endless_storage_crafting.cpp`) for crafting reagent integration via `OnPlayerCheckReagent` / `OnPlayerConsumeReagent`. These hooks **still exist in the core** (`azerothcore-wotlk`), but the module **no longer uses them actively** — the crafting integration runs through a Lua/client path. Consult [`functions.md`](https://github.com/Shoro2/share-public/blob/main/docs/World%20of%20Warcraft/module-repos/mod-endless-storage/functions.md) for the authoritative current state.

## License

GPL v2.
