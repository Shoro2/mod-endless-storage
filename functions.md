# Functions & mechanics — mod-endless-storage

> Detailed function and mechanics reference. For content/purpose docs see `CLAUDE.md`.

## Architecture (since March 2026)

**Lua/AIO-only module.** The C++ loader stub registers nothing essential — the entire logic runs in Eluna (server) and WoW addon code (client, transported via AIO).

```
WoW Client                          Server (Eluna)
   │                                    │
   ├─ /es or /storage  ────►  RequestData(catIndex)
   │                                    │
   │  Storage frame                     ├─ DB query custom_endless_storage
   │   ◄──── UpdateItems ───────────────┤  + WorldDB cache for item_template
   │                                    │
   ├─ "Deposit All"  ────►  Deposit(catIndex)
   │                                    ├─ scan inventory (slots 23-38 + bags 19-22)
   │                                    ├─ INSERT/UPDATE custom_endless_storage
   │   ◄──── Refresh ───────────────────┤
   │                                    │
   ├─ "Take" ────►  Withdraw(itemEntry, catIndex)
   │                                    ├─ DELETE/UPDATE storage
   │                                    ├─ player:AddItem(entry, 1)
   │   ◄──── Refresh ───────────────────┤
   │                                    │
   ├─ open TradeSkill  ─►  CheckCraftMaterials(recipeId)
   │                                    ├─ adds inventory + storage together
   │   ◄── CraftCounts (per recipe) ────┤
   │                                    │
   └─ "Create (N)" button ►  CraftFromStorage(recipeId, count)
                                        ├─ in-memory tracker subtracts
                                        ├─ async DB update
                                        └─ controlled UI refresh
```

## Server AIO handlers (`endless_storage_server.lua`)

Handler namespace: `"EndlessStorage"`. All handlers receive `player` as the first argument (Eluna player userdata).

| Handler | Args | Effect |
|---------|------|---------|
| `RequestData` | `catIndex` | DB query for the category → sends `UpdateItems` (`{entry1, amount1, entry2, amount2, ...}`) back |
| `Withdraw` | `itemEntry, catIndex` | take 1 stack → `player:AddItem(entry, 1)` → refresh |
| `Deposit` | `catIndex` | scan inventory slots 23-38 + bags 19-22, deposit eligible items with `INSERT ... ON DUPLICATE KEY UPDATE amount = amount + N`, remove items from inventory |
| `CheckCraftMaterials` | `recipeId, reagents[]` | for each recipe ingredient: combined count (inventory + storage); calculates `maxCrafts` |
| `CraftFromStorage` | `recipeId, count` | calculates required materials × count, subtracts via the in-memory tracker (see note), async DB update, sends updated counts to client |

### In-memory storage tracker

`CharDBExecute` is asynchronous. If a read happens immediately after consumption, stale values come back. Solution: in parallel with the DB update, a Lua table (`storage[characterId][itemEntry] = amount`) is updated in server memory. When sending UI updates, these in-memory values are used to **override** the `SELECT` results.

### Item template cache

For each item entry, `class`, `subclass`, `MaxStackSize` are read once from `acore_world.item_template` and held in `itemInfoCache`. Avoids the DB round trip on every storage operation.

## Accepted item classes for storage

| Class | Condition | Tab assignment |
|--------|-----------|---------------|
| `ITEM_CLASS_TRADE_GOODS` (7) | `MaxStackSize > 1` | by subclass |
| `ITEM_CLASS_GEM` (3) | `MaxStackSize > 1` | Jewelcrafting |
| `ITEM_CLASS_RECIPE` (9) | all | recipes tab |

Items with `MaxStackSize = 1` from TradeGoods/gem are not accepted (except recipes, which are by definition not stackable).

## Category queries

| Category | SQL WHERE |
|-----------|-----------|
| Standard (e.g. Cloth=5) | `item_class = 7 AND item_subclass = 5` |
| Gems & JC | `(item_class = 3) OR (item_class = 7 AND item_subclass = 4)` |
| Other | `item_class = 7 AND item_subclass IN (0, 11)` |
| Recipes | `item_class = 9` |

## Client UI (`endless_storage_client.lua`)

### Frames

| Frame | Type | Purpose |
|-------|-----|-------|
| `EndlessStorageFrame` | Frame | Main window (560×440, draggable, ESC-close) |
| `catFrame` | Frame | Left sidebar with 16 category buttons |
| `EndlessStorageScrollFrame` | FauxScrollFrame | scrollable list, 11 rows visible |
| `itemRows[1..11]` | Button | Icon + name + amount + Take button |
| `depositBtn` | Button | "Deposit All Materials" |

### Slash commands

```
/es        → toggle storage frame
/storage   → alias
```

### AIO specifics

- **Global handler table** (`MY_Handlers` pattern, see `share-public/docs/04-aio-framework.md`) due to re-registration restrictions.
- **Item info retry timer**: every 0.5 s, check whether `GetItemInfo()` for visible items has been cached.
- **Hot-reload guard**: the `ES_ClientInit` flag prevents duplicate `AIO.AddHandlers` registration.

## Crafting integration (`endless_storage_crafting_client.lua`)

The crafting hook is purely client-side — no C++!

### Hook points (WoW client UI)

| Hook | Effect |
|------|---------|
| `TradeSkillFrame_Update` | re-render the recipe list, combined counts in brackets (`Copper Bracers [2]`) |
| `BAG_UPDATE` event | refresh the reagent display when the inventory changes |
| `SetParent` trick for buttons | custom "Create (N)" / "Create All (N)" buttons are layered on top of the original buttons; original buttons hidden via `Hide()` so clicks land on the custom overlay |

### Custom Create buttons

| Button | Label | Action |
|--------|--------------|--------|
| Storage Create | "Create (N)" | fires `CraftFromStorage(recipeId, 1)` |
| Storage Create All | "Create All (N)" | fires `CraftFromStorage(recipeId, maxCrafts)` |

`N` = max possible craft count based on inventory + storage. If `maxCrafts == 0`, the buttons are hidden.

### Recipe list coloring

- normal entry: white
- player has reagents **only** from storage: gold (inline color code, **not** `SetTextColor` — that does not work on TradeSkillSkill buttons, see `log.md` 2026-03-22).

### Important: frame strata

`SetParent` resets the frame strata → original buttons capture clicks. So in this order:
1. `customBtn:SetParent(originalBtn)`
2. `customBtn:SetFrameStrata("HIGH")`
3. `customBtn:SetFrameLevel(originalBtn:GetFrameLevel() + 5)`

## DB schema

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

Inserts are always done via `INSERT ... ON DUPLICATE KEY UPDATE amount = amount + N`. Withdraw sets `amount = amount - N`; on `amount <= 0` → `DELETE`.

## Known limitations

- **Eluna DB calls** use string concatenation (no prepared statement equivalent).
- **Crafting path requires the client UI** — crafting via macro/script without an open TradeSkillFrame only pulls from the inventory, not from storage.
- **No bulk withdraw via the UI** — the player can only take 1 stack per Take click (a quality-of-life extension would be Shift+click or a quantity dialog).
- **Tab list hard-coded** — new subclass categories require a Lua edit.
