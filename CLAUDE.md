# mod-endless-storage

> Lies zuerst [`INDEX.md`](./INDEX.md). Mechanik & AIO-Handler: [`functions.md`](./functions.md). Folder-Layout: [`data_structure.md`](./data_structure.md). Offenes: [`todo.md`](./todo.md). Commit-Spur: [`log.md`](./log.md).

## Was ist das Modul?

AzerothCore-Modul für **WoW 3.3.5a (WotLK)**. Bietet ein server-seitiges, **unbegrenztes Materiallager** für Crafting-Verbrauchsgüter, Gems und Rezepte. Spieler hinterlegen ihre Trade-Goods/Gems/Recipes per Klick, rufen sie tab-weise wieder ab — alles über eine vollwertige WoW-AIO-UI (kein NPC, kein Gossip-Menü).

Funktional verwandt mit [`mod-reagent-bank`](https://github.com/Shoro2/mod-reagent-bank), aber mit echter Frame-UI statt Gossip und einem zusätzlichen Rezepte-Tab.

## Rolle im Gesamtprojekt

Dieses Modul ist eigenständig — es hat **keine** harten Abhängigkeiten zu anderen Custom-Modulen. Beziehungen:

| Modul | Beziehung |
|-------|-----------|
| `mod-auto-loot` | wenn aktiv: gelootete Trade-Goods landen im Inventar; der Spieler deponiert sie dann manuell per "Deposit All" in den Storage |
| `mod-loot-filter` | optional: kann eine Filter-Regel "Keep" auf Trade-Goods setzen, damit sie nicht versehentlich gesellt werden, und dann manuell in den Storage gehen |

Das Modul **eskaliert** das Reagenz-Inventar: wenn der Player eine Crafting-Aktion durchführt, kann die UI-Seite Reagenzien transparent aus dem Storage ziehen (Details: [`functions.md`](./functions.md)).

## Custom-Daten

| Typ | Eintrag | Bemerkung |
|-----|--------|-----------|
| **DB-Tabelle (acore_characters)** | `custom_endless_storage` | PK `(character_id, item_entry)`, plus `item_subclass`, `item_class`, `amount` |
| **DBC-Patches** | keine | |
| **Custom-Spells/NPCs/Items** | keine | |
| **AIO-Handler-Namen** | `EndlessStorage` (Server) / `ES_Client` (Client) | Details: [`functions.md`](./functions.md#aio-handler) |
| **Slash-Commands** | `/es`, `/storage` | öffnen die Storage-UI |
| **GM-Commands** | keine | |

## Akzeptierte Item-Klassen

| Klasse | Bedingung | Tab |
|--------|-----------|-----|
| `ITEM_CLASS_TRADE_GOODS` (7) | `MaxStackSize > 1` | nach Subclass (15 Material-Tabs) |
| `ITEM_CLASS_GEM` (3) | `MaxStackSize > 1` | Jewelcrafting-Tab |
| `ITEM_CLASS_RECIPE` (9) | alle | Rezepte-Tab |

## UI-Layout (Top-Level)

```
+--------------------------------------------------+
| Endless Storage                            [X]   |
+----------+---------------------------------------+
| Parts    | [icon] Item Name           x100 [Take]|
| Cloth    | [icon] Item Name            x50 [Take]|
| Leather  | [icon] Item Name           x200 [Take]|
| ...      | (FauxScrollFrame, 11 sichtbare Zeilen)|
| Recipes  |                                       |
+----------+---------------------------------------+
|          [ Deposit All Materials ]               |
+--------------------------------------------------+
```

Frame ist 560×440, draggable, ESC-close. Position ist account-weit gespeichert (LibWindow).

## Was das Modul **nicht** tut

- **kein** Equipment-Storage, kein Gold-Storage — nur die oben gelisteten Item-Klassen
- **kein** Auction-House-Forwarding
- **kein** Storage-Sharing zwischen Charakteren des selben Accounts (aktuell strikt per Character)
- **kein** Bulk-Withdraw via UI (Shift+Click etc.) — siehe [`todo.md`](./todo.md)

## Hinweise zur aktuellen Architektur

Das Modul lief in einer früheren Phase (vor März 2026) mit einem zusätzlichen C++-Layer (`mod_endless_storage_crafting.cpp`) für die Crafting-Reagenz-Integration über `OnPlayerCheckReagent` / `OnPlayerConsumeReagent`. Diese Hooks **existieren weiterhin im Core** (`azerothcore-wotlk`), das Modul nutzt sie aber aktuell **nicht aktiv** — die Crafting-Anbindung läuft über einen Lua-/Client-Pfad. Konsultiere [`functions.md`](./functions.md) für den verbindlich aktuellen Stand.

## Lizenz

GPL v2.
