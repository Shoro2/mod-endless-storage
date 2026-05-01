# Datei- und Verzeichnisstruktur — mod-endless-storage

> Statisches Inventar. Bei Hinzufügen/Löschen von Files hier mitpflegen.

## Tree

```
mod-endless-storage/
├── conf/
│   └── (Konfig-Templates falls vorhanden)
├── data/sql/
│   └── db-characters/
│       └── base/
│           └── create_tables.sql              # Schema: custom_endless_storage
├── lua_scripts/
│   └── Storage/
│       ├── endless_storage_server.lua         # Eluna-Server: Handler + DB-Queries (~13 KB)
│       ├── endless_storage_client.lua         # AIO-Client: Storage-Frame + Tabs (~17.5 KB)
│       └── endless_storage_crafting_client.lua # AIO-Client: TradeSkill-UI-Hook für Crafting (~12.5 KB)
├── src/
│   └── mod_endless_storage_loader.cpp         # Mini-Loader-Stub (~300 B, fast leer — Modul ist Lua-only)
├── include.sh                                  # Build-Integration
├── CLAUDE.md                                   # Detaillierte Inhalts-Doku
├── README.md                                   # GitHub-Readme (kurz)
├── log.md                                      # Commit-Log (modular)
├── data_structure.md                           # Diese Datei
└── functions.md                                # Mechanik- und Funktions-Referenz
```

## Datei-Zwecke

| Datei | Zweck |
|-------|-------|
| `data/sql/.../create_tables.sql` | Erstellt `custom_endless_storage` (PK: character_id + item_entry) |
| `lua_scripts/Storage/endless_storage_server.lua` | Eluna-Script. Registriert Server-AIO-Handler (`Deposit`, `Withdraw`, `RequestData`, `CheckCraftMaterials`, `CraftFromStorage`); cached Item-Templates aus WorldDB |
| `lua_scripts/Storage/endless_storage_client.lua` | Storage-Hauptfenster: 16 Tabs (15 Material-Subclasses + Recipe-Tab), ScrollFrame, Take-Buttons, "Deposit All Materials" |
| `lua_scripts/Storage/endless_storage_crafting_client.lua` | Hookt `TradeSkillFrame_Update`: zeigt Recipe-Listen mit kombinierten Inventar+Storage-Counts, ersetzt Create-Buttons durch Storage-aware Versionen |
| `src/mod_endless_storage_loader.cpp` | Loader-Stub. Modul ist seit März 2026 reines Lua/AIO-Modul; C++-Hooks für Crafting wurden entfernt |
| `include.sh` | registriert SQL-Pfad (`data/sql/db-characters/base/`) für Auto-Update |

## Wichtiger Architektur-Hinweis

Seit Commit `691ffaf` (2026-03-22) gibt es **keine C++ Hooks** mehr für Crafting. Die früher genutzten Core-Hooks `OnPlayerCheckReagent` / `OnPlayerConsumeReagent` (definiert in azerothcore-wotlk) sind aus mod-endless-storage **nicht** mehr genutzt. Crafting läuft komplett clientseitig via TradeSkill-UI-Hook + AIO-Roundtrip zum Server.

→ Folge: Der Loader-Stub (`src/mod_endless_storage_loader.cpp`) ist trivial, und es gibt **keine `.cpp`-Datei mit Logik** mehr. Wenn du Crafting-Verhalten ändern willst, ist es ausschließlich Lua.

## Größenhinweise (Stand: 2026-05-01)

- `endless_storage_client.lua` ~17.5 KB — am Stück lesbar, knapp am Limit
- `endless_storage_crafting_client.lua` ~12.5 KB — am Stück lesbar
- `endless_storage_server.lua` ~13 KB — am Stück lesbar
- `mod_endless_storage_loader.cpp` ~300 B
- SQL ~1 KB

## Externe Abhängigkeiten

- **azerothcore-wotlk** (Core): minimal — nur Loader-Mechanik. Eluna-Plugin muss aktiv sein.
- **AIO Framework**: `lua_scripts/AIO.lua` + Dependencies (aus `share-public/AIO_Server/`).
- **mod-loot-filter** (optional): kann via Keep-Action Items direkt in `custom_endless_storage` deponieren statt im Inventar zu lassen.

## DB-Tabellen (`acore_characters`)

| Tabelle | PK | Inhalt |
|---------|----|--------|
| `custom_endless_storage` | `(character_id, item_entry)` | item_subclass, item_class, amount |

## Wo ist was nicht?

- **Keine eigenen NPCs / Gossip-Menüs** — UI ist AIO-only.
- **Keine eigenen Spells/Items/DBC-Overrides**.
- **Kein Worlddb-Schema** — nur Reads via `WorldDBQuery` (item_template-Cache).
- **Keine C++-Logik mehr** seit März 2026.
