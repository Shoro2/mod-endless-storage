# Change Log — mod-endless-storage

> Minimaler Commit-Log. Eine Zeile pro Änderung mit Verweis auf den Commit.

## 2026

- 2026-05-01 — feat(storage): UI Shift/Ctrl+Click multiplier on Take button + tooltip ([8c3496d](https://github.com/Shoro2/mod-endless-storage/commit/8c3496d03b00de9a4804059b2afa011ece099d14)) — Client-Seite: Modifier-Detection im Take-Button, Multiplier (1/10/100) wird an Server-Handler weitergegeben; Tooltip mit Erklärung der Shortcuts.
- 2026-05-01 — feat(storage): bulk-withdraw multiplier (Shift=10, Ctrl=100 stacks) ([ac8b3b3](https://github.com/Shoro2/mod-endless-storage/commit/ac8b3b35af1d665cb1e901878d9410db023418c5)) — Server-Seite: `ES.Withdraw` akzeptiert optionalen `multiplier`-Parameter mit Whitelist `{1, 10, 100}`; total amount = `min(stored, stackSize × multiplier)`. Erledigt M6 aus `todo.md`.
- 2026-03-22 — fix(Crafting): SetTextColor error on TradeSkill buttons ([9c89f3c](https://github.com/Shoro2/mod-endless-storage/commit/9c89f3c76a188e20f278ce59d37546b26b99d07b)) — Inline-Color-Codes statt SetTextColor-API auf TradeSkillSkill-Buttons.
- 2026-03-22 — feat(Crafting): show craft count in recipe list with storage materials ([160da9d](https://github.com/Shoro2/mod-endless-storage/commit/160da9d8c092158cee94f293ed4b9fdec36247f5)) — Recipe-List zeigt kombinierte Craft-Counts (Inventar + Storage); Goldfärbung wenn nur Storage beiträgt.
- 2026-03-22 — fix(Crafting): show craft buttons whenever storage has reagents ([166d1c1](https://github.com/Shoro2/mod-endless-storage/commit/166d1c1fc0119323ba57ba9a60f4b95fa25600cc)).
- 2026-03-22 — fix(Crafting): in-memory storage values for post-craft UI update ([b5e6c09](https://github.com/Shoro2/mod-endless-storage/commit/b5e6c09e9358cca38150157d125e9b14dba20af8)) — `CharDBExecute` ist async; nach Verbrauch werden In-Memory-Werte verwendet, um stale DB-Reads zu vermeiden.
- 2026-03-22 — feat(Crafting): craft count on buttons + UI refresh after Withdraw/Deposit ([36f8499](https://github.com/Shoro2/mod-endless-storage/commit/36f84991b56514ee08e7667092b2320b4ab081d4)) — `ES_RefreshCurrentView` + BAG_UPDATE-Event.
- 2026-03-22 — fix(Crafting): storage craft buttons not clickable ([7ad9201](https://github.com/Shoro2/mod-endless-storage/commit/7ad92017d172a48d504afe5749356b8b3b25ecac)) — SetParent setzt Strata zurück, daher SetFrameStrata/Level **nach** SetParent.
- 2026-03-22 — feat: rewrite crafting integration as Lua/AIO instead of C++ hooks ([Merge #12](https://github.com/Shoro2/mod-endless-storage/commit/691ffaf051975eefc43e06bc9b66ed36e456b39e)) — **architektonischer Schritt**: alte C++-Hooks `OnPlayerCheckReagent`/`OnPlayerConsumeReagent` durch reines Lua/AIO ersetzt; UI scant Reagenz-Bedarf clientseitig und ruft Server-Handler auf.

## Konvention

Neue Einträge oben anhängen. Detail-Beschreibungen gehören in den Commit-Body bzw. `share-public/claude_log.md`.
