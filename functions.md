# Funktionen & Mechaniken — mod-endless-storage

> Detaillierte Funktions- und Mechanik-Referenz. Inhalts-/Zweck-Doku siehe `CLAUDE.md`.

## Architektur (seit März 2026)

**Lua/AIO-only-Modul.** Der C++ Loader-Stub registriert nichts Wesentliches — die gesamte Logik läuft in Eluna (Server) und WoW-Addon-Code (Client, via AIO transportiert).

```
WoW Client                          Server (Eluna)
   │                                    │
   ├─ /es oder /storage  ────►  RequestData(catIndex)
   │                                    │
   │  Storage-Frame                     ├─ DB-Query custom_endless_storage
   │   ◄──── UpdateItems ───────────────┤  + WorldDB-Cache für item_template
   │                                    │
   ├─ "Deposit All"  ────►  Deposit(catIndex)
   │                                    ├─ Inventar (Slot 23-38 + Bags 19-22) scannen
   │                                    ├─ INSERT/UPDATE custom_endless_storage
   │   ◄──── Refresh ───────────────────┤
   │                                    │
   ├─ "Take" ────►  Withdraw(itemEntry, catIndex)
   │                                    ├─ DELETE/UPDATE Storage
   │                                    ├─ player:AddItem(entry, 1)
   │   ◄──── Refresh ───────────────────┤
   │                                    │
   ├─ TradeSkill öffnen  ─►  CheckCraftMaterials(recipeId)
   │                                    ├─ rechnet Inventar + Storage zusammen
   │   ◄── CraftCounts (per recipe) ────┤
   │                                    │
   └─ "Create (N)" Button ►  CraftFromStorage(recipeId, count)
                                        ├─ in-memory tracker subtrahiert
                                        ├─ async DB-UPDATE
                                        └─ kontrollierter UI-Refresh
```

## Server-AIO-Handler (`endless_storage_server.lua`)

Handler-Namespace: `"EndlessStorage"`. Alle Handler erhalten `player` als erstes Argument (Eluna Player-Userdata).

| Handler | Args | Wirkung |
|---------|------|---------|
| `RequestData` | `catIndex` | DB-Query für Kategorie → sendet `UpdateItems` (`{entry1, amount1, entry2, amount2, ...}`) zurück |
| `Withdraw` | `itemEntry, catIndex` | 1 Stack entnehmen → `player:AddItem(entry, 1)` → Refresh |
| `Deposit` | `catIndex` | Inventar-Slots 23-38 + Bags 19-22 scannen, eligible Items per `INSERT ... ON DUPLICATE KEY UPDATE amount = amount + N` einlagern, Items aus Inventar entfernen |
| `CheckCraftMaterials` | `recipeId, reagents[]` | für jede Recipe-Zutat: kombinierter Count (Inventar + Storage); berechnet `maxCrafts` |
| `CraftFromStorage` | `recipeId, count` | berechnet erforderliche Materialien × count, subtrahiert via in-memory tracker (siehe Hinweis), async DB-Update, sendet aktualisierte Counts an Client |

### In-Memory-Storage-Tracker

`CharDBExecute` ist asynchron. Wenn nach einem Verbrauch sofort wieder gelesen wird, kommen stale Werte zurück. Lösung: parallel zum DB-Update wird eine Lua-Tabelle (`storage[characterId][itemEntry] = amount`) im Server-Speicher fortgeschrieben. Beim Senden der UI-Updates werden diese In-Memory-Werte verwendet, um die `SELECT`-Ergebnisse zu **überschreiben**.

### Item-Template-Cache

Pro Item-Entry werden `class`, `subclass`, `MaxStackSize` einmal aus `acore_world.item_template` gelesen und in `itemInfoCache` gehalten. Vermeidet den DB-Roundtrip bei jeder Storage-Operation.

## Akzeptierte Item-Klassen für Storage

| Klasse | Bedingung | Tab-Zuordnung |
|--------|-----------|---------------|
| `ITEM_CLASS_TRADE_GOODS` (7) | `MaxStackSize > 1` | nach Subclass |
| `ITEM_CLASS_GEM` (3) | `MaxStackSize > 1` | Jewelcrafting |
| `ITEM_CLASS_RECIPE` (9) | alle | Rezepte-Tab |

Items mit `MaxStackSize = 1` aus TradeGoods/Gem werden nicht akzeptiert (außer Recipes, die per Definition nicht stackbar sind).

## Kategorie-Queries

| Kategorie | SQL WHERE |
|-----------|-----------|
| Standard (z.B. Cloth=5) | `item_class = 7 AND item_subclass = 5` |
| Gems & JC | `(item_class = 3) OR (item_class = 7 AND item_subclass = 4)` |
| Other | `item_class = 7 AND item_subclass IN (0, 11)` |
| Recipes | `item_class = 9` |

## Client-UI (`endless_storage_client.lua`)

### Frames

| Frame | Typ | Zweck |
|-------|-----|-------|
| `EndlessStorageFrame` | Frame | Hauptfenster (560×440, draggable, ESC-close) |
| `catFrame` | Frame | Linke Sidebar mit 16 Kategorie-Buttons |
| `EndlessStorageScrollFrame` | FauxScrollFrame | scrollbare Liste, 11 Zeilen sichtbar |
| `itemRows[1..11]` | Button | Icon + Name + Menge + Take-Button |
| `depositBtn` | Button | "Deposit All Materials" |

### Slash-Commands

```
/es        → Toggle Storage Frame
/storage   → Alias
```

### AIO-Spezifika

- **Globale Handler-Tabelle** (`MY_Handlers`-Pattern, siehe `share-public/docs/04-aio-framework.md`) wegen Re-Registrierungs-Beschränkung.
- **Item-Info-Retry-Timer**: alle 0.5 s prüfen, ob `GetItemInfo()` für sichtbare Items inzwischen gecacht ist.
- **Hot-Reload-Guard**: `ES_ClientInit`-Flag verhindert doppelte `AIO.AddHandlers`-Registrierung.

## Crafting-Integration (`endless_storage_crafting_client.lua`)

Der Crafting-Hook ist rein clientseitig — kein C++!

### Hook-Punkte (WoW Client UI)

| Hook | Wirkung |
|------|---------|
| `TradeSkillFrame_Update` | Recipe-Liste neu rendern, kombinierte Counts in Klammern (`Copper Bracers [2]`) |
| `BAG_UPDATE`-Event | Reagenz-Display refreshen, wenn Inventar sich ändert |
| `SetParent`-Trick für Buttons | Custom "Create (N)" / "Create All (N)" Buttons über die Original-Buttons gelegt; Original-Buttons mit `Hide()` ausgeblendet, damit Klicks beim Custom-Overlay landen |

### Custom Create-Buttons

| Button | Beschriftung | Aktion |
|--------|--------------|--------|
| Storage-Create | "Create (N)" | feuert `CraftFromStorage(recipeId, 1)` |
| Storage-Create-All | "Create All (N)" | feuert `CraftFromStorage(recipeId, maxCrafts)` |

`N` = max möglicher Craft-Count basierend auf Inventar + Storage. Wenn `maxCrafts == 0` werden Buttons verborgen.

### Recipe-Listen-Färbung

- normaler Eintrag: weiß
- Spieler hat Reagenzien **nur** aus Storage: gold (Inline-Color-Code, **nicht** `SetTextColor` — das funktioniert auf TradeSkillSkill-Buttons nicht, siehe `log.md` 2026-03-22).

### Wichtig: Frame Strata

Bei `SetParent` wird die Frame-Strata zurückgesetzt → Original-Buttons fangen Klicks ab. Daher in dieser Reihenfolge:
1. `customBtn:SetParent(originalBtn)`
2. `customBtn:SetFrameStrata("HIGH")`
3. `customBtn:SetFrameLevel(originalBtn:GetFrameLevel() + 5)`

## DB-Schema

```sql
CREATE TABLE custom_endless_storage (
  character_id   INT NOT NULL,
  item_entry     INT NOT NULL,
  item_subclass  INT NOT NULL,
  item_class     INT NOT NULL,
  amount         INT NOT NULL,
  PRIMARY KEY (character_id, item_entry)
);
```

Inserts immer per `INSERT ... ON DUPLICATE KEY UPDATE amount = amount + N`. Withdraw setzt `amount = amount - N`, bei `amount <= 0` → `DELETE`.

## Bekannte Einschränkungen

- **Eluna-DB-Calls** verwenden String-Concat (kein Prepared-Statement-Equivalent).
- **Crafting-Pfad benötigt Client-UI** — Crafting via Macro/Script ohne offenes TradeSkillFrame zieht nur aus Inventar, nicht aus Storage.
- **Kein Bulk-Withdraw via UI** — Spieler kann nur 1 Stack pro Take-Klick entnehmen (eine Quality-of-Life-Erweiterung wäre Shift+Click oder ein Mengen-Dialog).
- **Tab-Liste hartkodiert** — neue Subclass-Kategorien erfordern Lua-Edit.
