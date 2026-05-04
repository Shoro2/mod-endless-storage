# TODOs — mod-endless-storage

> Open tasks for this module. Record completed TODOs in `log.md` and remove them here.

## Doc drift (to be fixed in phase B)

- [ ] **(high)** `CLAUDE.md` is **out of date** compared to the March 2026 rewrite: it describes removed C++ crafting hooks (`mod_endless_storage_crafting.cpp` no longer exists; crafting runs entirely through Lua/AIO). Will be corrected as part of the project-wide phase B (CLAUDE.md slim-down).

## Functional improvements

- [ ] **(low)** Tab list hard-coded in `endless_storage_client.lua`: new subclass categories require a Lua edit. A server-driven tab layout would be more flexible.
- [ ] **(low)** Crafting via macro/script without an open TradeSkillFrame does not access storage — the reagent hook is client-side. Possible solution: re-enable the optional server-side `OnPlayerCheckReagent` hook (already available in the core) as a fallback.

## Convention

Do NOT cross out completed items — remove them and document them in `log.md`.
