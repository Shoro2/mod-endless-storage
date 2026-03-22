/*
 * mod-endless-storage: Script Loader
 *
 * Registers all C++ scripts for the module.
 * Lua logic (UI, deposit/withdraw) is handled via Eluna + AIO in lua_scripts/.
 */

void AddCraftingFromStorageScript();

void Addmod_endless_storageScripts()
{
    AddCraftingFromStorageScript();
}
