# INDEX — mod-endless-storage

Einstiegspunkt für KI-Tools.

## Files in diesem Repo

| Datei | Größe | Zweck |
|-------|------:|-------|
| `INDEX.md` | <1 KB | diese Datei — Navigation |
| `CLAUDE.md` | ~5 KB | **Was** ist dieses Modul, welche Rolle, welche IDs/DB-Tabellen |
| `data_structure.md` | ~4 KB | Folder/File-Auflistung |
| `functions.md` | ~8 KB | **Wie** funktioniert das Modul: AIO-Handler, DB-Queries, UI-Layout, Crafting-Hooks |
| `log.md` | ~2 KB | Commit-Log (eine Zeile pro Commit) |
| `todo.md` | ~1 KB | offene Aufgaben |

## Cross-Repo

- Projekt-Übersicht: [`share-public/AI_GUIDE.md`](https://github.com/Shoro2/share-public/blob/main/AI_GUIDE.md)
- Cross-Repo-Historie: [`share-public/claude_log.md`](https://github.com/Shoro2/share-public/blob/main/claude_log.md)
- AIO-Framework: [`share-public/docs/04-aio-framework.md`](https://github.com/Shoro2/share-public/blob/main/docs/04-aio-framework.md)
- Architektur: [`share-public/docs/02-architecture.md`](https://github.com/Shoro2/share-public/blob/main/docs/02-architecture.md)

## Quick Facts

- AzerothCore-Modul für **WoW 3.3.5a**
- Funktion: server-seitiges, unbegrenztes Material-Lager (Trade-Goods, Gems, Rezepte) mit AIO-UI
- **Kein NPC, kein Gossip** — komplett über Slash `/es` oder `/storage`
- Reines Eluna/Lua + AIO. Optionaler C++-Layer für Crafting-Reagenz-Hooks (siehe `functions.md`)
- DB: 1 Tabelle (`custom_endless_storage` in `acore_characters`)
- Geschwister-Modul (gleiches Konzept, anderer UI-Stil): `mod-reagent-bank`
