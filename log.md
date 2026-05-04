# Change Log — mod-endless-storage

> Minimal commit log. One line per change with a reference to the commit.

## 2026

- 2026-05-01 — fix(security): validate handler args (itemEntry, catIndex, spellId, reagents) ([89d28dc](https://github.com/Shoro2/mod-endless-storage/commit/89d28dc7510bab2d380075d9a759d0bf4943c43f)) — `endless_storage_server.lua` validates via Dep_Validation: `itemEntry`/`spellId` as positive ints, `catIndex` (1..NUM_CATEGORIES), `searchText` length limits, reagent pairs before use. Resolves M5 from `todo.md`.
- 2026-05-01 — feat(storage): UI Shift/Ctrl+Click multiplier on Take button + tooltip ([8c3496d](https://github.com/Shoro2/mod-endless-storage/commit/8c3496d03b00de9a4804059b2afa011ece099d14)) — Client side: modifier detection on the Take button, multiplier (1/10/100) is forwarded to the server handler; tooltip explains the shortcuts.
- 2026-05-01 — feat(storage): bulk-withdraw multiplier (Shift=10, Ctrl=100 stacks) ([ac8b3b3](https://github.com/Shoro2/mod-endless-storage/commit/ac8b3b35af1d665cb1e901878d9410db023418c5)) — Server side: `ES.Withdraw` accepts an optional `multiplier` parameter with whitelist `{1, 10, 100}`; total amount = `min(stored, stackSize × multiplier)`. Resolves M6 from `todo.md`.
- 2026-03-22 — fix(Crafting): SetTextColor error on TradeSkill buttons ([9c89f3c](https://github.com/Shoro2/mod-endless-storage/commit/9c89f3c76a188e20f278ce59d37546b26b99d07b)) — inline color codes instead of the SetTextColor API on TradeSkillSkill buttons.
- 2026-03-22 — feat(Crafting): show craft count in recipe list with storage materials ([160da9d](https://github.com/Shoro2/mod-endless-storage/commit/160da9d8c092158cee94f293ed4b9fdec36247f5)) — recipe list shows combined craft counts (inventory + storage); gold coloring when only storage contributes.
- 2026-03-22 — fix(Crafting): show craft buttons whenever storage has reagents ([166d1c1](https://github.com/Shoro2/mod-endless-storage/commit/166d1c1fc0119323ba57ba9a60f4b95fa25600cc)).
- 2026-03-22 — fix(Crafting): in-memory storage values for post-craft UI update ([b5e6c09](https://github.com/Shoro2/mod-endless-storage/commit/b5e6c09e9358cca38150157d125e9b14dba20af8)) — `CharDBExecute` is async; after consumption, in-memory values are used to avoid stale DB reads.
- 2026-03-22 — feat(Crafting): craft count on buttons + UI refresh after Withdraw/Deposit ([36f8499](https://github.com/Shoro2/mod-endless-storage/commit/36f84991b56514ee08e7667092b2320b4ab081d4)) — `ES_RefreshCurrentView` + BAG_UPDATE event.
- 2026-03-22 — fix(Crafting): storage craft buttons not clickable ([7ad9201](https://github.com/Shoro2/mod-endless-storage/commit/7ad92017d172a48d504afe5749356b8b3b25ecac)) — SetParent resets the strata, therefore SetFrameStrata/Level go **after** SetParent.
- 2026-03-22 — feat: rewrite crafting integration as Lua/AIO instead of C++ hooks ([Merge #12](https://github.com/Shoro2/mod-endless-storage/commit/691ffaf051975eefc43e06bc9b66ed36e456b39e)) — **architectural step**: replaced the old C++ hooks `OnPlayerCheckReagent`/`OnPlayerConsumeReagent` with pure Lua/AIO; the UI scans reagent demand client-side and calls server handlers.

## Convention

Append new entries at the top. Detailed descriptions belong in the commit body or in `share-public/claude_log.md`.
