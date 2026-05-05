# INDEX — mod-endless-storage

Entry point for AI tools.

## Files in this repo

| File | Size | Purpose |
|-------|------:|-------|
| `INDEX.md` | <1 KB | this file — navigation |
| `CLAUDE.md` | ~5 KB | **What** this module is, what role, which IDs/DB tables |
| `data_structure.md` | ~4 KB | Folder/file listing |
| `functions.md` | ~8 KB | **How** the module works: AIO handlers, DB queries, UI layout, crafting hooks |
| `log.md` | ~2 KB | Commit log (one line per commit) |
| `todo.md` | ~1 KB | open tasks |

## Cross-Repo

- Project overview: [`share-public/AI_GUIDE.md`](https://github.com/Shoro2/share-public/blob/main/AI_GUIDE.md)
- Cross-repo history: [`share-public/claude_log.md`](https://github.com/Shoro2/share-public/blob/main/claude_log.md)
- AIO framework: [`share-public/docs/04-aio-framework.md`](https://github.com/Shoro2/share-public/blob/main/docs/04-aio-framework.md)
- Architecture: [`share-public/docs/02-architecture.md`](https://github.com/Shoro2/share-public/blob/main/docs/02-architecture.md)

## Quick Facts

- AzerothCore module for **WoW 3.3.5a**
- Function: server-side, unlimited material storage (Trade Goods, gems, recipes) with an AIO UI
- **No NPC, no gossip** — entirely via slash `/es` or `/storage`
- Pure Eluna/Lua + AIO. Optional C++ layer for crafting reagent hooks (see `functions.md`)
- DB: 1 table (`custom_endless_storage` in `acore_characters`)
- Sibling module (same concept, different UI style): `mod-reagent-bank`
