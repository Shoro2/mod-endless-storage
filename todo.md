# TODOs — mod-endless-storage

> Offene Aufgaben für dieses Modul. Erledigte TODOs in `log.md` festhalten und hier entfernen.

## Doku-Drift (in Phase B beheben)

- [ ] **(hoch)** `CLAUDE.md` ist gegenüber dem März-2026-Rewrite **veraltet**: beschreibt entfernte C++-Crafting-Hooks (`mod_endless_storage_crafting.cpp` existiert nicht mehr; Crafting läuft komplett über Lua/AIO). Wird im Rahmen der projekt-weiten Phase B (CLAUDE.md-Schlankheitskur) korrigiert.

## Funktionale Verbesserungen

- [ ] **(niedrig)** Tab-Liste hartkodiert in `endless_storage_client.lua`: neue Subclass-Kategorien erfordern Lua-Edit. Ein server-getriebenes Tab-Layout wäre flexibler.
- [ ] **(niedrig)** Crafting via Macro/Script ohne offenes TradeSkillFrame greift nicht auf Storage zu — Reagenz-Hook ist clientseitig. Lösungsansatz: optionalen Server-side `OnPlayerCheckReagent`-Hook (im Core bereits verfügbar) wieder aktivieren als Fallback.

## Konvention

Erledigte Items NICHT durchstreichen — entfernen und in `log.md` dokumentieren.
