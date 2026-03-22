/*
 * mod-endless-storage: Crafting Integration
 *
 * Allows players to craft using reagents stored in the
 * custom_endless_storage table.
 *
 * Uses the OnPlayerCheckReagent / OnPlayerConsumeReagent hooks
 * added to PlayerScript in Spell::CheckItems() and Spell::TakeReagents().
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Log.h"

class CraftingFromStoragePlayerScript : public PlayerScript
{
public:
    CraftingFromStoragePlayerScript()
        : PlayerScript("CraftingFromStoragePlayerScript",
            {PLAYERHOOK_ON_CHECK_REAGENT, PLAYERHOOK_ON_CONSUME_REAGENT}) {}

    // Called when a player does not have enough of a reagent in inventory.
    // Query custom_endless_storage to see if the combined count is sufficient.
    void OnPlayerCheckReagent(Player* player, uint32 itemId, uint32 itemCount, bool& hasEnough) override
    {
        if (hasEnough)
            return;

        uint32 guid = player->GetGUID().GetCounter();
        uint32 inventoryCount = player->GetItemCount(itemId);
        uint32 deficit = itemCount - inventoryCount;

        uint32 storedAmount = GetStoredAmount(guid, itemId);
        if (storedAmount >= deficit)
            hasEnough = true;
    }

    // Called before DestroyItemCount for each reagent.
    // Consume from storage first, reduce itemCount so only the remainder
    // (if any) is destroyed from inventory.
    void OnPlayerConsumeReagent(Player* player, uint32 itemId, uint32& itemCount) override
    {
        if (itemCount == 0)
            return;

        uint32 guid = player->GetGUID().GetCounter();
        uint32 inventoryCount = player->GetItemCount(itemId);

        // Only use storage if inventory doesn't have enough
        if (inventoryCount >= itemCount)
            return;

        uint32 fromStorage = itemCount - inventoryCount;
        uint32 storedAmount = GetStoredAmount(guid, itemId);

        if (storedAmount == 0)
            return;

        // Consume min(fromStorage, storedAmount) from storage
        uint32 consume = std::min(fromStorage, storedAmount);
        uint32 newAmount = storedAmount - consume;

        if (newAmount > 0)
        {
            CharacterDatabase.Execute("UPDATE `custom_endless_storage` SET `amount` = {} WHERE `character_id` = {} AND `item_entry` = {}",
                newAmount, guid, itemId);
        }
        else
        {
            CharacterDatabase.Execute("DELETE FROM `custom_endless_storage` WHERE `character_id` = {} AND `item_entry` = {}",
                guid, itemId);
        }

        // Reduce the amount that needs to be destroyed from inventory
        itemCount -= consume;

        LOG_DEBUG("module", "mod-endless-storage: Player {} consumed {} of item {} from storage ({} remain in storage, {} from inventory)",
            player->GetName(), consume, itemId, newAmount, itemCount);
    }

private:
    static uint32 GetStoredAmount(uint32 characterId, uint32 itemId)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT `amount` FROM `custom_endless_storage` WHERE `character_id` = {} AND `item_entry` = {}",
            characterId, itemId);

        if (!result)
            return 0;

        Field* fields = result->Fetch();
        return fields[0].Get<uint32>();
    }
};

void AddCraftingFromStorageScript()
{
    new CraftingFromStoragePlayerScript();
}
