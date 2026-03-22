--
-- mod-endless-storage: Crafting Integration (AIO Client Addon)
-- Hooks the TradeSkillFrame to show storage counts and enables
-- crafting with reagents from Endless Storage.
--
if AIO.AddAddon() then return end

local storageCounts = {} -- [itemEntry] = amount
local craftingHooked = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Extract item ID from an item link
local function LinkToId(link)
	if not link then return nil end
	return tonumber(link:match("item:(%d+)"))
end

-- Check if a recipe at the given trade skill index needs storage reagents
local function NeedsStorageReagents(index)
	local numReagents = GetTradeSkillNumReagents(index)
	for i = 1, numReagents do
		local _, _, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, i)
		if playerReagentCount < reagentCount then
			local link = GetTradeSkillReagentItemLink(index, i)
			local itemId = LinkToId(link)
			if itemId and (storageCounts[itemId] or 0) > 0 then
				return true
			end
		end
	end
	return false
end

-- Build flat reagent table {entry1, countPerCraft1, entry2, countPerCraft2, ...}
local function GetReagentTable(index)
	local reagents = {}
	local numReagents = GetTradeSkillNumReagents(index)
	for i = 1, numReagents do
		local _, _, reagentCount = GetTradeSkillReagentInfo(index, i)
		local link = GetTradeSkillReagentItemLink(index, i)
		local itemId = LinkToId(link)
		if itemId then
			table.insert(reagents, itemId)
			table.insert(reagents, reagentCount)
		end
	end
	return reagents
end

-- Calculate max crafts possible with combined inventory + storage
local function GetMaxCraftsWithStorage(index)
	local maxCrafts = 999
	local numReagents = GetTradeSkillNumReagents(index)
	for i = 1, numReagents do
		local _, _, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, i)
		local link = GetTradeSkillReagentItemLink(index, i)
		local itemId = LinkToId(link)
		local storageAmt = itemId and (storageCounts[itemId] or 0) or 0
		local total = playerReagentCount + storageAmt
		local possible = math.floor(total / reagentCount)
		maxCrafts = math.min(maxCrafts, possible)
	end
	return maxCrafts
end

-- Get spell ID from recipe link
local function GetSpellIdFromIndex(index)
	local link = GetTradeSkillRecipeLink(index)
	if not link then return nil end
	return tonumber(link:match("enchant:(%d+)"))
end

---------------------------------------------------------------------------
-- "Craft (Storage)" Button — overlays the Create button when needed
---------------------------------------------------------------------------

local craftStorageBtn, craftAllStorageBtn

local function CreateStorageButtons()
	if craftStorageBtn then return end

	-- Single craft button
	craftStorageBtn = CreateFrame("Button", "ES_CraftStorageBtn", UIParent, "UIPanelButtonTemplate")
	craftStorageBtn:SetWidth(80)
	craftStorageBtn:SetHeight(22)
	craftStorageBtn:SetText("Create")
	craftStorageBtn:SetFrameStrata("DIALOG")
	craftStorageBtn:Hide()

	-- Gold text to indicate storage usage
	craftStorageBtn:GetFontString():SetTextColor(1, 0.82, 0)

	craftStorageBtn:SetScript("OnClick", function()
		local index = GetTradeSkillSelectionIndex()
		if not index or index == 0 then return end
		local spellId = GetSpellIdFromIndex(index)
		if not spellId then return end
		local reagents = GetReagentTable(index)
		AIO.Handle("EndlessStorage", "CraftFromStorage", spellId, 1, reagents)
	end)

	-- Tooltip
	craftStorageBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Craft using Endless Storage", 1, 0.82, 0)
		GameTooltip:AddLine("Reagents will be taken from storage", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	craftStorageBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- "Create All" from storage button
	craftAllStorageBtn = CreateFrame("Button", "ES_CraftAllStorageBtn", UIParent, "UIPanelButtonTemplate")
	craftAllStorageBtn:SetWidth(80)
	craftAllStorageBtn:SetHeight(22)
	craftAllStorageBtn:SetText("Create All")
	craftAllStorageBtn:SetFrameStrata("DIALOG")
	craftAllStorageBtn:Hide()

	craftAllStorageBtn:GetFontString():SetTextColor(1, 0.82, 0)

	craftAllStorageBtn:SetScript("OnClick", function()
		local index = GetTradeSkillSelectionIndex()
		if not index or index == 0 then return end
		local spellId = GetSpellIdFromIndex(index)
		if not spellId then return end
		local maxCrafts = GetMaxCraftsWithStorage(index)
		if maxCrafts <= 0 then return end
		local reagents = GetReagentTable(index)
		AIO.Handle("EndlessStorage", "CraftFromStorage", spellId, maxCrafts, reagents)
	end)

	craftAllStorageBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Craft All using Endless Storage", 1, 0.82, 0)
		local index = GetTradeSkillSelectionIndex()
		if index and index > 0 then
			local maxCrafts = GetMaxCraftsWithStorage(index)
			GameTooltip:AddLine("Can craft " .. maxCrafts .. "x with storage", 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	craftAllStorageBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Update reagent display and button visibility
---------------------------------------------------------------------------

local function UpdateReagentDisplay()
	if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end

	local selectedSkill = GetTradeSkillSelectionIndex()
	if not selectedSkill or selectedSkill == 0 then return end

	local skillName, skillType = GetTradeSkillInfo(selectedSkill)
	if not skillName or skillType == "header" then return end

	local numReagents = GetTradeSkillNumReagents(selectedSkill)
	local needsStorage = false

	for i = 1, numReagents do
		local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(selectedSkill, i)
		local link = GetTradeSkillReagentItemLink(selectedSkill, i)
		local itemId = LinkToId(link)

		if itemId and (storageCounts[itemId] or 0) > 0 then
			local storageAmt = storageCounts[itemId]
			local combinedCount = playerReagentCount + storageAmt

			-- Update the count text on the reagent frame
			local countFrame = _G["TradeSkillReagent" .. i .. "Count"]
			if countFrame then
				countFrame:SetText(" " .. combinedCount .. "/" .. reagentCount)
				if playerReagentCount < reagentCount and combinedCount >= reagentCount then
					-- Gold = enough only with storage
					countFrame:SetTextColor(1, 0.82, 0)
				end
			end

			-- Update reagent name color
			local nameFrame = _G["TradeSkillReagent" .. i .. "Name"]
			if nameFrame and playerReagentCount < reagentCount and combinedCount >= reagentCount then
				nameFrame:SetTextColor(1, 0.82, 0)
			end

			if playerReagentCount < reagentCount then
				needsStorage = true
			end
		end
	end

	-- Show/hide storage craft buttons
	CreateStorageButtons()
	local maxCrafts = GetMaxCraftsWithStorage(selectedSkill)
	-- Check if any reagent for this recipe exists in storage
	local hasStorageReagents = false
	for i = 1, numReagents do
		local link = GetTradeSkillReagentItemLink(selectedSkill, i)
		local itemId = LinkToId(link)
		if itemId and (storageCounts[itemId] or 0) > 0 then
			hasStorageReagents = true
			break
		end
	end
	if hasStorageReagents and maxCrafts > 0 then
		-- Position over the original Create/CreateAll buttons
		if TradeSkillCreateButton then
			craftStorageBtn:SetParent(TradeSkillFrame)
			craftStorageBtn:ClearAllPoints()
			craftStorageBtn:SetPoint("CENTER", TradeSkillCreateButton, "CENTER", 0, 0)
			craftStorageBtn:SetWidth(TradeSkillCreateButton:GetWidth())
			craftStorageBtn:SetHeight(TradeSkillCreateButton:GetHeight())
			craftStorageBtn:SetFrameStrata("DIALOG")
			craftStorageBtn:SetFrameLevel(TradeSkillCreateButton:GetFrameLevel() + 10)
			craftStorageBtn:SetText("Create (1)")
			craftStorageBtn:Show()
			TradeSkillCreateButton:Hide()
		end
		if TradeSkillCreateAllButton then
			craftAllStorageBtn:SetParent(TradeSkillFrame)
			craftAllStorageBtn:ClearAllPoints()
			craftAllStorageBtn:SetPoint("CENTER", TradeSkillCreateAllButton, "CENTER", 0, 0)
			craftAllStorageBtn:SetWidth(TradeSkillCreateAllButton:GetWidth())
			craftAllStorageBtn:SetHeight(TradeSkillCreateAllButton:GetHeight())
			craftAllStorageBtn:SetFrameStrata("DIALOG")
			craftAllStorageBtn:SetFrameLevel(TradeSkillCreateAllButton:GetFrameLevel() + 10)
			craftAllStorageBtn:SetText("Create All (" .. maxCrafts .. ")")
			craftAllStorageBtn:Show()
			TradeSkillCreateAllButton:Hide()
		end
	else
		craftStorageBtn:Hide()
		craftAllStorageBtn:Hide()
		-- Restore original buttons
		if TradeSkillCreateButton then TradeSkillCreateButton:Show() end
		if TradeSkillCreateAllButton then TradeSkillCreateAllButton:Show() end
	end
end

---------------------------------------------------------------------------
-- Hook the TradeSkill frame
---------------------------------------------------------------------------

local function HookTradeSkillFrame()
	if craftingHooked then return end
	craftingHooked = true

	-- Post-hook recipe selection to update reagent display
	hooksecurefunc("TradeSkillFrame_SetSelection", function(id)
		UpdateReagentDisplay()
	end)

	-- Hide storage buttons and restore originals when tradeskill closes
	TradeSkillFrame:HookScript("OnHide", function()
		if craftStorageBtn then craftStorageBtn:Hide() end
		if craftAllStorageBtn then craftAllStorageBtn:Hide() end
		if TradeSkillCreateButton then TradeSkillCreateButton:Show() end
		if TradeSkillCreateAllButton then TradeSkillCreateAllButton:Show() end
	end)
end

---------------------------------------------------------------------------
-- Event handling: request storage counts when tradeskill opens
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event)
	if event == "TRADE_SKILL_SHOW" then
		AIO.Handle("EndlessStorage", "RequestStorageCounts")
		HookTradeSkillFrame()
	elseif event == "BAG_UPDATE" then
		UpdateReagentDisplay()
	end
end)

---------------------------------------------------------------------------
-- AIO Handlers (Client-side)
---------------------------------------------------------------------------

local ESC_Client = {}

ESC_Client.UpdateStorageCounts = function(player, counts)
	storageCounts = {}
	if type(counts) == "table" then
		for i = 1, #counts, 2 do
			storageCounts[counts[i]] = counts[i + 1]
		end
	end
	-- Refresh tradeskill display if open
	UpdateReagentDisplay()
	-- Refresh storage window if open
	if ES_RefreshCurrentView then ES_RefreshCurrentView() end
end

-- Hot-reload safe handler registration
if not ESC_CraftingInit then
	AIO.AddHandlers("EndlessStorageCrafting", ESC_Client)
	ESC_CraftingInit = true
else
	local existing = ESC_Client
	for k, v in pairs(ESC_Client) do
		existing[k] = v
	end
end
