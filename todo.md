# TODOs — mod-endless-storage

> Offene Aufgaben für dieses Modul. Erledigte TODOs in `log.md` festhalten und hier entfernen.

## Doku-Drift (in Phase B beheben)

- [ ] **(hoch)** `CLAUDE.md` ist gegenüber dem März-2026-Rewrite **veraltet**: beschreibt entfernte C++-Crafting-Hooks (`mod_endless_storage_crafting.cpp` existiert nicht mehr; Crafting läuft komplett über Lua/AIO). Wird im Rahmen der projekt-weiten Phase B (CLAUDE.md-Schlankheitskur) korrigiert.

## Funktionale Verbesserungen

- [ ] **(mittel)** Bulk-Withdraw via UI: Spieler kann nur 1 Stack pro Take-Klick entnehmen. Shift+Click (×10) oder Mengen-Dialog wäre Quality-of-Life.
- [ ] **(niedrig)** Tab-Liste hartkodiert in `endless_storage_client.lua`: neue Subclass-Kategorien erfordern Lua-Edit. Ein server-getriebenes Tab-Layout wäre flexibler.
- [ ] **(niedrig)** Crafting via Macro/Script ohne offenes TradeSkillFrame greift nicht auf Storage zu — Reagenz-Hook ist clientseitig. Lösungsansatz: optionalen Server-side `OnPlayerCheckReagent`-Hook (im Core bereits verfügbar) wieder aktivieren als Fallback.

## Sicherheit

- [ ] **(mittel)** SQL-Injection-Risiko in Lua-Layer (gleiches Eluna-Limit wie überall): `endless_storage_server.lua` baut SQL aus character_id + item_entry zusammen. character_id ist vertrauenswürdig (Server-Seite), item_entry kommt vom Client → muss als Integer geprüft werden.

## Konvention

Erledigte Items NICHT durchstreichen — entfernen und in `log.md` dokumentieren.
