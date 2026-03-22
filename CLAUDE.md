# CLAUDE.md — mod-endless-storage

AzerothCore-Modul: Unbegrenzte Material-Lagerung für WoW 3.3.5a (WotLK) mit AIO-basierter Client-UI. Funktional ähnlich wie [mod-reagent-bank](https://github.com/Shoro2/mod-reagent-bank), aber mit vollwertiger WoW-UI statt Gossip-Menü und einem zusätzlichen Rezepte-Tab.

## Projekt-Kontext

Dieses Modul gehört zum Custom-WoW-Server-Projekt (AzerothCore-basiert). Siehe [share-public CLAUDE.md](https://github.com/Shoro2/share-public/blob/master/CLAUDE.md) für die Gesamtarchitektur, insbesondere die Abschnitte zu AIO Framework und Eluna.

## Konzept & Unterschiede zu mod-reagent-bank

| Eigenschaft | mod-reagent-bank | mod-endless-storage |
|-------------|-----------------|-------------------|
| **UI** | NPC-Gossip-Menü | AIO Client-UI (echte WoW-Frames) |
| **Zugang** | NPC ansprechen | Slash-Command, Keybind, oder AIO-Button |
| **Tabs** | Kategorien als Gossip-Optionen | Tab-System: Material-Kategorien + Rezepte |
| **Rezepte** | Nicht vorhanden | Eigener Tab für Rezepte (Recipe Items) |
| **Paginierung** | Gossip-basiert (23 pro Seite) | Scroll-Frame mit beliebig vielen Einträgen |
| **UX** | Menü schließt nach jeder Aktion | Frame bleibt offen, Live-Updates |
| **Technologie** | C++ CreatureScript | Eluna (Lua) + AIO Framework |

## Geplante Repository-Struktur

```
mod-endless-storage/
├── CLAUDE.md
├── README.md
├── lua_scripts/
│   ├── endless_storage_server.lua      # Eluna Server-Script: DB-Queries, Handler
│   └── endless_storage_client.lua      # AIO Client-Addon: UI-Frames, Tabs
└── data/
    └── sql/
        └── db-characters/
            └── base/
                └── create_tables.sql   # custom_endless_storage Tabelle
```

## Architektur

### Typ: AIO-Modul (Eluna/Lua + Client-UI)

Kein NPC, kein Gossip. Stattdessen vollständig AIO-basiert:

```
Spieler → Slash-Command / Keybind / Button
    ↓
AIO Client-Frame öffnet sich
    ├── Tab 1-N: Material-Kategorien (Trade Goods, Gems, ...)
    │   ├── ScrollFrame mit allen gelagerten Items
    │   ├── Item-Icon + Name + Menge
    │   ├── Withdraw-Button (pro Item)
    │   └── "Deposit All" Button
    └── Rezepte-Tab
        ├── ScrollFrame mit gelagerten Rezepten
        ├── Rezept-Icon + Name
        └── Withdraw-Button (pro Rezept)
```

### Kommunikationsfluss (AIO)

```
Server (Eluna)                          Client (WoW Addon via AIO)
    |                                        |
    +-- AIO.AddAddon("..._client.lua")      |
    |   → UI-Code an Client senden          |
    |                                        +-- Frame + Tabs erstellen
    +-- AIO.AddOnInit(func)                 |
    |   → Storage-Daten bei Login senden    |
    |                                        +-- Items in UI anzeigen
    +-- Handler: "Deposit"  <---------------+-- "Deposit All" geklickt
    |   → Inventar scannen, DB speichern    |
    |   → Aktualisierte Daten senden ------>+-- UI refreshen
    |                                        |
    +-- Handler: "Withdraw" <---------------+-- Item angeklickt
    |   → Item aus DB holen, an Spieler     |
    |   → Aktualisierte Daten senden ------>+-- UI refreshen
    |                                        |
    +-- Handler: "RequestData" <------------+-- Tab gewechselt / Frame geöffnet
        → Daten für Kategorie laden         |
        → An Client senden --------------->+-- ScrollFrame aktualisieren
```

### Datenbank

**Tabelle:** `custom_endless_storage` (acore_characters)

| Spalte | Typ | Beschreibung |
|--------|-----|-------------|
| `character_id` | int(11) | PK — Character GUID |
| `item_entry` | int(11) | PK — Item Template ID |
| `item_subclass` | int(11) | Subklasse für Tab-Kategorisierung |
| `item_class` | int(11) | Item-Klasse (TRADE_GOODS, GEM, RECIPE) |
| `amount` | int(11) | Gelagerte Menge |

### Tabs

#### Material-Tabs (wie reagent-bank)

| Tab | Subklasse | Beispiel-Items |
|-----|-----------|---------------|
| Parts | ITEM_SUBCLASS_PARTS | Eisenleiste, Kupferrohr |
| Explosives | ITEM_SUBCLASS_EXPLOSIVES | Dynamit, Bomben |
| Devices | ITEM_SUBCLASS_DEVICES | Gnomische Geräte |
| Jewelcrafting | ITEM_SUBCLASS_JEWELCRAFTING | Gems aller Art |
| Cloth | ITEM_SUBCLASS_CLOTH | Leinenstoff, Netherstoff |
| Leather | ITEM_SUBCLASS_LEATHER | Leder, Schweres Leder |
| Metal & Stone | ITEM_SUBCLASS_METAL_STONE | Erze, Steine |
| Meat | ITEM_SUBCLASS_MEAT | Fleisch, Fisch |
| Herb | ITEM_SUBCLASS_HERB | Kräuter |
| Elemental | ITEM_SUBCLASS_ELEMENTAL | Elementar-Essenzen |
| Enchanting | ITEM_SUBCLASS_ENCHANTING | Staub, Essenzen, Splitter |
| Nether Material | ITEM_SUBCLASS_MATERIAL | Urfeuer, Ueerde |
| Other | ITEM_SUBCLASS_TRADE_GOODS_OTHER | Sonstige |
| Armor Vellum | ITEM_SUBCLASS_ARMOR_ENCHANTMENT | Rüstungspergament |
| Weapon Vellum | ITEM_SUBCLASS_WEAPON_ENCHANTMENT | Waffenpergament |

#### Rezepte-Tab (NEU)

| Tab | Klasse | Beschreibung |
|-----|--------|-------------|
| Rezepte | ITEM_CLASS_RECIPE | Alle Rezept-Items (Schmiedekunst, Alchemie, Schneiderei, etc.) |

Rezepte werden über `ITEM_CLASS_RECIPE` (Klasse 9) identifiziert. Im Gegensatz zu Trade Goods sind Rezepte nicht stapelbar (MaxStackSize=1), daher wird jedes Rezept einzeln gespeichert (amount=1).

### Akzeptierte Item-Klassen

| Klasse | Bedingung | Tab-Zuordnung |
|--------|-----------|--------------|
| `ITEM_CLASS_TRADE_GOODS` (7) | MaxStackSize > 1 | Nach Subklasse |
| `ITEM_CLASS_GEM` (3) | MaxStackSize > 1 | Jewelcrafting |
| `ITEM_CLASS_RECIPE` (9) | Alle | Rezepte-Tab |

## AIO-Patterns (Referenz)

### Server-Script (endless_storage_server.lua)

```lua
-- AIO Client-Addon registrieren
local AIO = AIO or require("AIO")
AIO.AddAddon()  -- In Client-Datei

-- Handler registrieren
local ES_Handlers = {}

ES_Handlers.Deposit = function(player)
    -- Inventar scannen, Items in DB speichern
    -- Aktualisierte Daten an Client senden
end

ES_Handlers.Withdraw = function(player, itemEntry)
    -- Item aus DB laden, an Spieler geben
    -- Aktualisierte Daten an Client senden
end

ES_Handlers.RequestData = function(player, category)
    -- DB-Query für Kategorie
    -- Daten an Client senden: AIO.Msg():Add("EndlessStorage", "UpdateItems", ...):Send(player)
end

AIO.AddHandlers("EndlessStorage", ES_Handlers)

-- Login-Daten senden
AIO.AddOnInit(function(msg, player)
    -- Initial-Daten laden und an msg anhängen
    return msg
end)
```

### Client-Script (endless_storage_client.lua)

```lua
if AIO.AddAddon() then return end

local ES_Handlers = {}

-- Haupt-Frame erstellen
local mainFrame = CreateFrame("Frame", "EndlessStorageFrame", UIParent)
-- Tabs erstellen (Material-Kategorien + Rezepte)
-- ScrollFrame für Item-Liste

ES_Handlers.UpdateItems = function(player, ...)
    -- Items im ScrollFrame aktualisieren
end

if not AIO_BLOCKHANDLES["EndlessStorage"] then
    AIO.AddHandlers("EndlessStorage", ES_Handlers)
else
    -- Hot-Reload: Funktionen in bestehender Tabelle aktualisieren
    for k, v in pairs(ES_Handlers) do
        AIO_BLOCKHANDLES["EndlessStorage"][k] = v
    end
end
```

### Wichtige AIO-Regeln

- `player` ist IMMER erstes Argument in Handlern (Server: Eluna Player-Objekt, Client: Spielername-String)
- Max 15 Argumente pro `msg:Add()` Aufruf
- Hot-Reload-Guard gegen `AIO.AddHandlers` Assert (siehe share-public CLAUDE.md)
- Tab-Einrückung (Eluna/AIO Konvention)
- `AIO.AddAddon()` am Anfang der Client-Datei mit Early-Return

## Code-Konventionen

- Lua (Eluna auf Server, WoW Lua API auf Client)
- Tab-Einrückung
- Async-Pattern für DB-Queries (Eluna `CharDBQuery` mit Callbacks)
- AIO Handler-Namen: `"EndlessStorage"` als Namespace
- UI-Frame-Namen: `"EndlessStorageFrame"`, `"EndlessStorageTab1"`, etc.
- Für große Datenmengen: Daten pro Kategorie/Tab laden (nicht alles auf einmal)

## Build & Deployment

1. `lua_scripts/` Dateien in das Eluna `lua_scripts/` Verzeichnis kopieren
2. SQL aus `data/sql/` einspielen (Characters-DB)
3. AIO Framework muss installiert sein (siehe share-public/AIO_Server/)
4. AIO_Client Addon muss beim WoW-Client installiert sein
5. Server neustarten oder `.reload eluna` für Script-Änderungen
