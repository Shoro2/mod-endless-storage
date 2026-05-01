--
-- mod-endless-storage: Server Script (Eluna)
-- Unbegrenzte Material-Lagerung mit AIO Client-UI
--

local AIO = AIO or require("AIO")

-- Optional dependency: shared validation lib (share-public/AIO_Server/Dep_Validation/).
-- Eluna lädt scripts alphabetisch, `Dep_*` kommt vor `Storage/` → Lib ist
-- zur Loadzeit da. Ohne Lib läuft das Modul mit permissiven Shims weiter,
-- gibt aber eine Warning aus.
local Validate = _G.Validate
if not Validate then
	print("[EndlessStorage] WARNING: Dep_Validation/validation.lua nicht geladen — input validation läuft permissiv. Bitte share-public/AIO_Server/Dep_Validation/ nach lua_scripts/ deployen.")
	Validate = {
		IsInt = function(v) return type(v) == "number" and v == math.floor(v) end,
		IsIntInRange = function(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end,
		IsPositiveInt = function(v, cap) return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= (cap or 2147483647) end,
		IsStringInRange = function(s, lo, hi) return type(s) == "string" and #s >= lo and #s <= hi end,
		Reject = function(player, handler, reason)
			print(string.format("[Validate] reject handler=%s reason=%s", tostring(handler), tostring(reason)))
			return false
		end,
	}
end

-- Register client addon file to be sent to players
-- Resolve path relative to this script's location
local scriptPath = debug.getinfo(1, 'S').source:sub(2)
local scriptDir = scriptPath:match("(.*[/\\])") or ""
AIO.AddAddon(scriptDir .. "endless_storage_client.lua")
AIO.AddAddon(scriptDir .. "endless_storage_crafting_client.lua")

-- Constants
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_CLASS_GEM = 3
local ITEM_CLASS_TRADE_GOODS = 7
local ITEM_CLASS_RECIPE = 9

-- Withdraw multipliers (stacks per click). Whitelist enforces server-side
-- validation against client-spoofed values (Eluna has no prepared statements,
-- but we use this only for arithmetic, not SQL — still clamp to known set).
--   1   = normal click          (1 stack)
--   10  = Shift+Click           (10 stacks)
--   100 = Ctrl+Click / max-take (100 stacks — capped by stored amount)
local VALID_MULTIPLIERS = {[1] = true, [10] = true, [100] = true}

-- Search-Text-Limits.
local SEARCH_MIN_LEN = 2
local SEARCH_MAX_LEN = 40

-- Category definitions (must match client-side CATEGORIES)
-- Each category: {name, class, subclass}
-- subclass = -1 means "all subclasses for this class"
-- subclass = -2 means special query (gems + jewelcrafting combined)
local CATEGORIES = {
	{name = "Parts",         class = 7, subclass = 1},
	{name = "Explosives",    class = 7, subclass = 2},
	{name = "Devices",       class = 7, subclass = 3},
	{name = "Gems & JC",     class = -1, subclass = -2},  -- special: gems + JC trade goods
	{name = "Cloth",         class = 7, subclass = 5},
	{name = "Leather",       class = 7, subclass = 6},
	{name = "Metal & Stone", class = 7, subclass = 7},
	{name = "Meat",          class = 7, subclass = 8},
	{name = "Herb",          class = 7, subclass = 9},
	{name = "Elemental",     class = 7, subclass = 10},
	{name = "Other",         class = 7, subclass = -3},   -- special: subclass 0 + 11
	{name = "Enchanting",    class = 7, subclass = 12},
	{name = "Materials",     class = 7, subclass = 13},
	{name = "Armor Vellum",  class = 7, subclass = 14},
	{name = "Weapon Vellum", class = 7, subclass = 15},
	{name = "Recipes",       class = 9, subclass = -1},
	{name = "Food & Drinks", class = 0, subclass = 5},
}
local NUM_CATEGORIES = #CATEGORIES

-- Item template cache (WorldDBQuery results)
local itemInfoCache = {}

local function GetItemTemplateInfo(entry)
	if itemInfoCache[entry] then
		return itemInfoCache[entry]
	end
	local q = WorldDBQuery("SELECT class, subclass, stackable, name FROM item_template WHERE entry = "..entry)
	if q then
		local info = {
			class = q:GetUInt32(0),
			subclass = q:GetUInt32(1),
			stackable = q:GetInt32(2),
			name = q:GetString(3),
		}
		itemInfoCache[entry] = info
		return info
	end
	return nil
end

-- Build SQL WHERE clause for a category
local function BuildCategoryWhere(guid, catIndex)
	local cat = CATEGORIES[catIndex]
	if not cat then return nil end

	local base = "character_id = "..guid

	if cat.subclass == -2 then
		-- Gems (class 3) + Jewelcrafting trade goods (class 7, subclass 4)
		return base.." AND ((item_class = 3) OR (item_class = 7 AND item_subclass = 4))"
	elseif cat.subclass == -3 then
		-- Other: subclass 0 and 11
		return base.." AND item_class = 7 AND item_subclass IN (0, 11)"
	elseif cat.subclass == -1 then
		-- All subclasses for this class
		return base.." AND item_class = "..cat.class
	else
		return base.." AND item_class = "..cat.class.." AND item_subclass = "..cat.subclass
	end
end

-- Check if an item is eligible for storage
local function IsEligible(class, subclass, stackable)
	if class == ITEM_CLASS_RECIPE then
		return true
	end
	if class == ITEM_CLASS_CONSUMABLE and subclass == 5 and stackable > 1 then
		return true
	end
	if (class == ITEM_CLASS_TRADE_GOODS or class == ITEM_CLASS_GEM) and stackable > 1 then
		return true
	end
	return false
end

-- Handlers
local ES = {}

ES.RequestData = function(player, catIndex)
	if not Validate.IsIntInRange(catIndex, 1, NUM_CATEGORIES) then
		return Validate.Reject(player, "RequestData", "catIndex out of range")
	end

	local guid = player:GetGUIDLow()
	local where = BuildCategoryWhere(guid, catIndex)
	if not where then return end

	local query = "SELECT item_entry, amount FROM custom_endless_storage WHERE "..where.." ORDER BY item_entry"
	local result = CharDBQuery(query)

	local items = {}
	if result then
		repeat
			table.insert(items, result:GetUInt32(0))
			table.insert(items, result:GetUInt32(1))
		until not result:NextRow()
	end

	AIO.Msg():Add("EndlessStorage", "UpdateItems", catIndex, items):Send(player)
end

-- Withdraw N stacks of an item (multiplier ∈ {1, 10, 100}, default 1).
-- Total amount = min(storedAmount, stackSize * multiplier).
ES.Withdraw = function(player, itemEntry, catIndex, searchText, multiplier)
	-- itemEntry geht direkt in die WHERE-Klausel — MUSS ein positiver Int sein,
	-- sonst SQL-Injection-Vektor. WoW-Item-Entries sind uint32, fit sich gut in 31 bit.
	if not Validate.IsPositiveInt(itemEntry, 2147483647) then
		return Validate.Reject(player, "Withdraw", "itemEntry not a positive int")
	end
	if not Validate.IsIntInRange(catIndex, 1, NUM_CATEGORIES) then
		return Validate.Reject(player, "Withdraw", "catIndex out of range")
	end

	-- Multiplier whitelist (defends against client-spoofed values).
	if not VALID_MULTIPLIERS[multiplier] then
		multiplier = 1
	end

	-- searchText optional — wenn vorhanden, Length-Limit erzwingen.
	if searchText ~= nil and not Validate.IsStringInRange(searchText, 0, SEARCH_MAX_LEN) then
		searchText = nil
	end

	local guid = player:GetGUIDLow()

	local result = CharDBQuery("SELECT amount FROM custom_endless_storage WHERE character_id = "..guid.." AND item_entry = "..itemEntry)
	if not result then return end

	local storedAmount = result:GetUInt32(0)
	local templateInfo = GetItemTemplateInfo(itemEntry)
	if not templateInfo then return end

	local stackSize = templateInfo.stackable
	if stackSize < 1 then stackSize = 1 end

	local withdrawAmount = math.min(storedAmount, stackSize * multiplier)

	-- Try to add item to player inventory
	local added = player:AddItem(itemEntry, withdrawAmount)
	if added then
		local remaining = storedAmount - withdrawAmount
		if remaining <= 0 then
			CharDBExecute("DELETE FROM custom_endless_storage WHERE character_id = "..guid.." AND item_entry = "..itemEntry)
		else
			CharDBExecute("UPDATE custom_endless_storage SET amount = "..remaining.." WHERE character_id = "..guid.." AND item_entry = "..itemEntry)
		end
		-- Log entry
		local itemName = templateInfo.name or ("Item #"..itemEntry)
		AIO.Msg():Add("EndlessStorage", "LogEntry",
			"|cffff6600-|r " .. itemName .. " x" .. withdrawAmount):Send(player)
	else
		player:SendBroadcastMessage("|cffff0000Not enough bag space!|r")
	end

	-- Refresh: search results or category view
	if searchText and searchText ~= "" then
		ES.Search(player, searchText)
	else
		ES.RequestData(player, catIndex)
	end
	-- Refresh tradeskill crafting UI if open
	ES.RequestStorageCounts(player)
end

ES.Deposit = function(player, catIndex)
	if not Validate.IsIntInRange(catIndex, 1, NUM_CATEGORIES) then
		return Validate.Reject(player, "Deposit", "catIndex out of range")
	end

	local guid = player:GetGUIDLow()
	local deposited = {} -- {entry -> {class, subclass, amount}}

	-- Scan main backpack (slots 23-38)
	for slot = 23, 38 do
		local item = player:GetItemByPos(255, slot)
		if item then
			local entry = item:GetEntry()
			local count = item:GetCount()
			local info = GetItemTemplateInfo(entry)
			if info and IsEligible(info.class, info.subclass, info.stackable) then
				if not deposited[entry] then
					deposited[entry] = {class = info.class, subclass = info.subclass, amount = 0}
				end
				deposited[entry].amount = deposited[entry].amount + count
			end
		end
	end

	-- Scan bags (bag slots 19-22)
	for bag = 19, 22 do
		local bagItem = player:GetItemByPos(255, bag)
		if bagItem then
			for slot = 0, 35 do
				local item = player:GetItemByPos(bag, slot)
				if item then
					local entry = item:GetEntry()
					local count = item:GetCount()
					local info = GetItemTemplateInfo(entry)
					if info and IsEligible(info.class, info.subclass, info.stackable) then
						if not deposited[entry] then
							deposited[entry] = {class = info.class, subclass = info.subclass, amount = 0}
						end
						deposited[entry].amount = deposited[entry].amount + count
					end
				end
			end
		end
	end

	-- Nothing to deposit?
	local hasItems = false
	for _ in pairs(deposited) do hasItems = true; break end
	if not hasItems then
		player:SendBroadcastMessage("|cffff0000No eligible items found in inventory.|r")
		ES.RequestData(player, catIndex)
		return
	end

	-- Load existing amounts and merge
	local logMsg = AIO.Msg()
	for entry, info in pairs(deposited) do
		local existing = CharDBQuery("SELECT amount FROM custom_endless_storage WHERE character_id = "..guid.." AND item_entry = "..entry)
		local totalAmount = info.amount
		if existing then
			totalAmount = totalAmount + existing:GetUInt32(0)
		end

		CharDBExecute("REPLACE INTO custom_endless_storage (character_id, item_entry, item_subclass, item_class, amount) VALUES ("
			..guid..", "..entry..", "..info.subclass..", "..info.class..", "..totalAmount..")")

		-- Remove items from player
		player:RemoveItem(entry, info.amount)

		-- Log entry per item
		local templateInfo = GetItemTemplateInfo(entry)
		local itemName = (templateInfo and templateInfo.name) or ("Item #"..entry)
		logMsg:Add("EndlessStorage", "LogEntry",
			"|cff00cc00+|r " .. itemName .. " x" .. info.amount)
	end
	logMsg:Send(player)

	player:SendBroadcastMessage("|cff00ff00All materials deposited successfully.|r")
	ES.RequestData(player, catIndex)
	-- Refresh tradeskill crafting UI if open
	ES.RequestStorageCounts(player)
end

ES.Search = function(player, searchText)
	-- Min-Länge 2 (kurze Suchen wären zu unspezifisch), Max-Länge SEARCH_MAX_LEN
	-- (Schutz gegen Memory-/CPU-Floods).
	if not Validate.IsStringInRange(searchText, SEARCH_MIN_LEN, SEARCH_MAX_LEN) then
		return
	end

	local guid = player:GetGUIDLow()

	-- Load all stored items for this character
	local result = CharDBQuery("SELECT item_entry, amount FROM custom_endless_storage WHERE character_id = "..guid)
	if not result then
		AIO.Msg():Add("EndlessStorage", "UpdateItems", 0, {}):Send(player)
		return
	end

	local search = string.lower(searchText)
	local items = {}
	repeat
		local entry = result:GetUInt32(0)
		local amount = result:GetUInt32(1)
		-- Use cached item info (includes name)
		local info = GetItemTemplateInfo(entry)
		if info and info.name and string.find(string.lower(info.name), search, 1, true) then
			table.insert(items, entry)
			table.insert(items, amount)
		end
	until not result:NextRow()

	AIO.Msg():Add("EndlessStorage", "UpdateItems", 0, items):Send(player)
end

---------------------------------------------------------------------------
-- Crafting from Storage
---------------------------------------------------------------------------

-- Send all storage item counts to client (for tradeskill UI overlay)
ES.RequestStorageCounts = function(player)
	local guid = player:GetGUIDLow()
	local result = CharDBQuery("SELECT item_entry, amount FROM custom_endless_storage WHERE character_id = "..guid)
	local counts = {}
	if result then
		repeat
			table.insert(counts, result:GetUInt32(0))
			table.insert(counts, result:GetUInt32(1))
		until not result:NextRow()
	end
	AIO.Msg():Add("EndlessStorageCrafting", "UpdateStorageCounts", counts):Send(player)
end

-- Handle craft request from client
-- reagents = {entry1, countPerCraft1, entry2, countPerCraft2, ...}
ES.CraftFromStorage = function(player, spellId, numRepeats, reagents)
	-- spellId geht direkt in CastSpell — als positiver Int validieren.
	if not Validate.IsPositiveInt(spellId, 2147483647) then
		return Validate.Reject(player, "CraftFromStorage", "spellId not a positive int")
	end
	if not player:HasSpell(spellId) then
		player:SendBroadcastMessage("|cffff0000You don't know this recipe!|r")
		return
	end

	if not Validate.IsIntInRange(numRepeats, 1, 20) then numRepeats = 1 end
	if type(reagents) ~= "table" or #reagents < 2 or #reagents % 2 ~= 0 then return end

	-- Reagents-Validation: jedes Paar (entry, perCraft) muss aus positiven Ints bestehen,
	-- da `entry` direkt in WHERE-Klauseln und CastSpell-Logik verwendet wird.
	for i = 1, #reagents, 2 do
		if not Validate.IsPositiveInt(reagents[i], 2147483647) then
			return Validate.Reject(player, "CraftFromStorage", "reagent entry["..i.."] not a positive int")
		end
		if not Validate.IsPositiveInt(reagents[i + 1], 1000) then
			return Validate.Reject(player, "CraftFromStorage", "reagent perCraft["..(i+1).."] out of range")
		end
	end

	local guid = player:GetGUIDLow()

	-- Pre-read storage amounts for all reagents
	local storage = {}
	for i = 1, #reagents, 2 do
		local entry = reagents[i]
		local r = CharDBQuery("SELECT amount FROM custom_endless_storage WHERE character_id = "..guid.." AND item_entry = "..entry)
		storage[entry] = r and r:GetUInt32(0) or 0
	end

	-- Calculate max possible crafts
	local maxPossible = numRepeats
	for i = 1, #reagents, 2 do
		local entry = reagents[i]
		local perCraft = reagents[i + 1]
		local total = player:GetItemCount(entry) + (storage[entry] or 0)
		local possible = math.floor(total / perCraft)
		maxPossible = math.min(maxPossible, possible)
	end

	if maxPossible <= 0 then
		player:SendBroadcastMessage("|cffff0000Not enough materials!|r")
		ES.RequestStorageCounts(player)
		return
	end

	-- Consume reagents for all crafts
	local logMsg = AIO.Msg()
	for i = 1, #reagents, 2 do
		local entry = reagents[i]
		local totalNeeded = reagents[i + 1] * maxPossible

		-- First consume from inventory
		local inventoryCount = player:GetItemCount(entry)
		local fromInventory = math.min(inventoryCount, totalNeeded)
		if fromInventory > 0 then
			player:RemoveItem(entry, fromInventory)
		end

		-- Then from storage
		local fromStorage = totalNeeded - fromInventory
		if fromStorage > 0 then
			local remaining = (storage[entry] or 0) - fromStorage
			storage[entry] = math.max(remaining, 0)
			if remaining <= 0 then
				CharDBExecute("DELETE FROM custom_endless_storage WHERE character_id = "..guid.." AND item_entry = "..entry)
			else
				CharDBExecute("UPDATE custom_endless_storage SET amount = "..remaining.." WHERE character_id = "..guid.." AND item_entry = "..entry)
			end

			local templateInfo = GetItemTemplateInfo(entry)
			local itemName = (templateInfo and templateInfo.name) or ("Item #"..entry)
			logMsg:Add("EndlessStorage", "LogEntry",
				"|cffff6600-|r " .. itemName .. " x" .. fromStorage .. " (crafting)")
		end
	end
	logMsg:Send(player)

	-- Cast the spell (triggered=true: bypasses reagent check since we consumed manually)
	for i = 1, maxPossible do
		player:CastSpell(player, spellId, true)
	end

	player:SendBroadcastMessage("|cff00ff00Crafted " .. maxPossible .. "x successfully.|r")

	-- Send updated counts directly from memory (CharDBExecute is async,
	-- so reading back from DB would return stale data)
	local result = CharDBQuery("SELECT item_entry, amount FROM custom_endless_storage WHERE character_id = "..guid)
	local counts = {}
	if result then
		repeat
			local e = result:GetUInt32(0)
			local a = result:GetUInt32(1)
			-- Override with in-memory value for reagents we just consumed
			if storage[e] ~= nil then
				a = storage[e]
			end
			if a > 0 then
				table.insert(counts, e)
				table.insert(counts, a)
			end
		until not result:NextRow()
	end
	AIO.Msg():Add("EndlessStorageCrafting", "UpdateStorageCounts", counts):Send(player)
end

AIO.AddHandlers("EndlessStorage", ES)
