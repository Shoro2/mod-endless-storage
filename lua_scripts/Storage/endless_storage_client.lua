--
-- mod-endless-storage: Client Script (AIO Addon)
-- WoW UI for unlimited material storage
--
if AIO.AddAddon() then return end

-- FLUI (fl-lua-scripts AIO_UI/, the Forgotten Land window kit) draws the
-- window in the player's theme.
local FLUI = assert(FLUI, "Endless Storage needs AIO_UI/FLUI_Client.lua loaded first")

-- Category definitions (must match server-side CATEGORIES order)
local CATEGORIES = {
	"Parts",
	"Explosives",
	"Devices",
	"Gems & JC",
	"Cloth",
	"Leather",
	"Metal & Stone",
	"Meat",
	"Herb",
	"Elemental",
	"Other",
	"Enchanting",
	"Materials",
	"Armor Vellum",
	"Weapon Vellum",
	"Recipes",
	"Food & Drinks",
}

-- State
local currentCategory = 1
local currentItems = {} -- flat: {entry1, amt1, entry2, amt2, ...}
local searchActive = false
local sessionLog = {} -- text entries for current session

-- Forward declarations
local logBtn, depositBtn, searchBox
local logShown = false

-- Layout constants
local FRAME_WIDTH = 560
local FRAME_HEIGHT = 484
local CAT_WIDTH = 120
local CAT_BTN_HEIGHT = 22
local CAT_BTN_SPACING = 2
local ITEM_ROW_HEIGHT = 30
local MAX_VISIBLE_ROWS = 11
local CONTENT_TOP = -(FLUI.HEADER + 4)
local CONTENT_BOTTOM = 40

-- Item quality colors
local QUALITY_COLORS = {
	[0] = {0.62, 0.62, 0.62},
	[1] = {1, 1, 1},
	[2] = {0.12, 1, 0},
	[3] = {0, 0.44, 0.87},
	[4] = {0.64, 0.21, 0.93},
	[5] = {1, 0.5, 0},
	[6] = {0.9, 0.8, 0.5},
}

---------------------------------------------------------------------------
-- Main Frame
---------------------------------------------------------------------------
-- Movable, ESC closes, no saved position (as before)
local mainFrame = FLUI.Window("EndlessStorageFrame", {
	width = FRAME_WIDTH, height = FRAME_HEIGHT, point = { "CENTER", 0, 0 },
	title = "Endless Storage", icon = "Interface/Icons/INV_Crate_04",
	savePosition = false,
})
local closeBtn = mainFrame.close

---------------------------------------------------------------------------
-- Category Panel (Left Side)
---------------------------------------------------------------------------
local catFrame = CreateFrame("Frame", nil, mainFrame)
catFrame:SetPoint("TOPLEFT", 16, CONTENT_TOP)
catFrame:SetPoint("BOTTOMLEFT", 16, CONTENT_BOTTOM)
catFrame:SetWidth(CAT_WIDTH)

local categoryButtons = {}

local HideLog -- forward declaration

-- Marks the category index (nil: none) as the chosen one.
local function MarkCategory(index)
	for i, btn in ipairs(categoryButtons) do
		if i == index then
			btn.sel:Show()
			btn.text:SetTextColor(1, 1, 1)
		else
			btn.sel:Hide()
			btn.text:SetTextColor(0.8, 0.8, 0.8)
		end
	end
end

local function SelectCategory(index)
	currentCategory = index
	searchActive = false
	if HideLog then HideLog() end
	searchBox:SetText("")
	searchBox:ClearFocus()
	MarkCategory(index)
	-- Request data from server
	AIO.Handle("EndlessStorage", "RequestData", index)
end

-- Global refresh function for cross-addon communication (used by crafting client)
function ES_RefreshCurrentView()
	if EndlessStorageFrame and EndlessStorageFrame:IsShown() then
		AIO.Handle("EndlessStorage", "RequestData", currentCategory)
	end
end

for i, catName in ipairs(CATEGORIES) do
	local btn = CreateFrame("Button", nil, catFrame)
	btn:SetWidth(CAT_WIDTH)
	btn:SetHeight(CAT_BTN_HEIGHT)
	btn:SetPoint("TOPLEFT", 0, -((i - 1) * (CAT_BTN_HEIGHT + CAT_BTN_SPACING)))
	btn.sel = FLUI.Selection(btn)
	btn.sel:Hide()
	FLUI.Hover(btn)

	local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("LEFT", 6, 0)
	text:SetText(catName)
	text:SetTextColor(0.8, 0.8, 0.8)
	btn.text = text

	btn:SetScript("OnClick", function()
		SelectCategory(i)
	end)

	categoryButtons[i] = btn
end

---------------------------------------------------------------------------
-- Search Box (above item list)
---------------------------------------------------------------------------
searchBox = CreateFrame("EditBox", "EndlessStorageSearchBox", mainFrame, "InputBoxTemplate")
searchBox:SetWidth(260)
searchBox:SetHeight(20)
searchBox:SetPoint("TOPLEFT", catFrame, "TOPRIGHT", 14, 2)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(40)

local searchLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchLabel:SetPoint("LEFT", 6, 0)
searchLabel:SetText("Search...")
searchLabel:SetTextColor(0.5, 0.5, 0.5)

searchBox:SetScript("OnTextChanged", function(self)
	local text = self:GetText()
	if text == "" then
		searchLabel:Show()
		if searchActive then
			searchActive = false
			-- Restore category highlight and reload
			SelectCategory(currentCategory)
		end
	else
		searchLabel:Hide()
		if string.len(text) >= 2 then
			searchActive = true
			-- Deselect all category buttons
			MarkCategory(nil)
			AIO.Handle("EndlessStorage", "Search", text)
		end
	end
end)

searchBox:SetScript("OnEscapePressed", function(self)
	self:SetText("")
	self:ClearFocus()
end)

searchBox:SetScript("OnEditFocusGained", function(self)
	if self:GetText() == "" then
		searchLabel:Show()
	end
end)

---------------------------------------------------------------------------
-- Item List Panel (Right Side)
---------------------------------------------------------------------------
local listFrame = FLUI.Panel(mainFrame)
listFrame:SetPoint("TOPLEFT", catFrame, "TOPRIGHT", 8, -24)
listFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -16, CONTENT_BOTTOM)

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", "EndlessStorageScrollFrame", listFrame, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 4, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

-- "No items" text
local emptyText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("CENTER", 0, 0)
emptyText:SetText("No items stored")

-- Create item rows
local itemRows = {}

local function CreateItemRow(index)
	local row = CreateFrame("Button", nil, listFrame)
	row:SetHeight(ITEM_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((index - 1) * ITEM_ROW_HEIGHT))
	row:SetPoint("RIGHT", scrollFrame, "RIGHT", 0, 0)

	-- Highlight on hover
	FLUI.Hover(row)

	-- Item icon
	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(26)
	icon:SetHeight(26)
	icon:SetPoint("LEFT", 4, 0)
	icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
	row.icon = icon

	-- Item name
	local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	nameText:SetPoint("RIGHT", row, "RIGHT", -120, 0)
	nameText:SetJustifyH("LEFT")
	nameText:SetWordWrap(false)
	row.nameText = nameText

	-- Amount
	local amountText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	amountText:SetPoint("RIGHT", row, "RIGHT", -65, 0)
	amountText:SetWidth(50)
	amountText:SetJustifyH("RIGHT")
	row.amountText = amountText

	-- Withdraw button
	local withdrawBtn = FLUI.Button(row, "Take", 55, 22)
	withdrawBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	withdrawBtn:SetScript("OnClick", function()
		if row.itemEntry then
			local search = searchActive and searchBox:GetText() or nil
			-- Multiplier: Ctrl > Shift > none. Server-side whitelist enforces {1, 10, 100}.
			local multiplier = 1
			if IsControlKeyDown() then
				multiplier = 100
			elseif IsShiftKeyDown() then
				multiplier = 10
			end
			AIO.Handle("EndlessStorage", "Withdraw", row.itemEntry, currentCategory, search, multiplier)
		end
	end)
	-- Tooltip explaining the modifier shortcuts.
	withdrawBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Withdraw 1 stack")
		GameTooltip:AddLine("|cff00ff00Shift|r+Click: 10 stacks", 1, 1, 1)
		GameTooltip:AddLine("|cff00ff00Ctrl|r+Click: 100 stacks (max)", 1, 1, 1)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Capped at the available stored amount.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	withdrawBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row.withdrawBtn = withdrawBtn

	-- Tooltip on hover (item info)
	row:SetScript("OnEnter", function(self)
		if self.itemEntry then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink("item:"..self.itemEntry)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row.itemEntry = nil
	row:Hide()

	return row
end

for i = 1, MAX_VISIBLE_ROWS do
	itemRows[i] = CreateItemRow(i)
end

---------------------------------------------------------------------------
-- Refresh item list display
---------------------------------------------------------------------------
local function RefreshItemList()
	local numItems = math.floor(#currentItems / 2)

	if numItems == 0 then emptyText:Show() else emptyText:Hide() end

	FauxScrollFrame_Update(scrollFrame, numItems, MAX_VISIBLE_ROWS, ITEM_ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(scrollFrame)

	for i = 1, MAX_VISIBLE_ROWS do
		local row = itemRows[i]
		local dataIndex = offset + i

		if dataIndex <= numItems then
			local entry = currentItems[(dataIndex - 1) * 2 + 1]
			local amount = currentItems[(dataIndex - 1) * 2 + 2]

			local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(entry)

			row.icon:SetTexture(texture or "Interface/Icons/INV_Misc_QuestionMark")

			if name then
				row.nameText:SetText(name)
				local color = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
				row.nameText:SetTextColor(color[1], color[2], color[3])
			else
				row.nameText:SetText("Item #"..entry)
				row.nameText:SetTextColor(0.7, 0.7, 0.7)
			end

			row.amountText:SetText("x"..amount)
			row.itemEntry = entry
			row:Show()
		else
			row:Hide()
		end
	end
end

-- Scroll handler
scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, ITEM_ROW_HEIGHT, RefreshItemList)
end)

---------------------------------------------------------------------------
-- Session Log Panel (overlays item list when active)
---------------------------------------------------------------------------

local logFrame = FLUI.Panel(mainFrame)
logFrame:SetPoint("TOPLEFT", catFrame, "TOPRIGHT", 8, 0)
logFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -16, CONTENT_BOTTOM)
logFrame:Hide()

local logScrollFrame = CreateFrame("ScrollFrame", "EndlessStorageLogScroll", logFrame, "UIPanelScrollFrameTemplate")
logScrollFrame:SetPoint("TOPLEFT", 6, -6)
logScrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

local logContent = CreateFrame("Frame", nil, logScrollFrame)
logContent:SetWidth(1)
logContent:SetHeight(1)
logScrollFrame:SetScrollChild(logContent)

local logText = logContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
logText:SetPoint("TOPLEFT", 0, 0)
logText:SetWidth(370)
logText:SetJustifyH("LEFT")
logText:SetJustifyV("TOP")
logText:SetTextColor(0.8, 0.8, 0.8)
logText:SetText("")

local logEmptyText = logFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
logEmptyText:SetPoint("CENTER", 0, 0)
logEmptyText:SetText("No activity this session")

local function RefreshLog()
	if #sessionLog == 0 then
		logEmptyText:Show()
		logText:SetText("")
		logContent:SetHeight(1)
		return
	end
	logEmptyText:Hide()
	-- Build log text (newest first)
	local lines = {}
	for i = #sessionLog, 1, -1 do
		table.insert(lines, sessionLog[i])
	end
	local str = table.concat(lines, "\n")
	logText:SetText(str)
	-- Update scroll child height
	logContent:SetHeight(logText:GetStringHeight() + 10)
end

local function ShowLog()
	logShown = true
	listFrame:Hide()
	searchBox:Hide()
	logFrame:Show()
	depositBtn:Hide()
	-- Deselect all category buttons, highlight log
	MarkCategory(nil)
	logBtn:SetSelected(true)
	RefreshLog()
end

HideLog = function()
	logShown = false
	logFrame:Hide()
	listFrame:Show()
	searchBox:Show()
	depositBtn:Show()
	logBtn:SetSelected(false)
end

-- Session log button (beside the close button)
logBtn = FLUI.Button(mainFrame, "Log", 80, 20, nil, { small = true })
logBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)

logBtn:SetScript("OnClick", function()
	if logShown then
		HideLog()
		SelectCategory(currentCategory)
	else
		ShowLog()
	end
end)

local function AddLogEntry(text)
	local t = date("%H:%M:%S")
	table.insert(sessionLog, "|cff888888" .. t .. "|r " .. text)
	if logShown then
		RefreshLog()
	end
end

---------------------------------------------------------------------------
-- Deposit Button
---------------------------------------------------------------------------
depositBtn = FLUI.Button(mainFrame, "Deposit All Materials", 200, 28)
depositBtn:SetPoint("BOTTOM", 0, 14)
depositBtn:SetScript("OnClick", function()
	AIO.Handle("EndlessStorage", "Deposit", currentCategory)
end)

---------------------------------------------------------------------------
-- Item info retry timer (for uncached items)
---------------------------------------------------------------------------
local retryFrame = CreateFrame("Frame")
local retryTimer = 0
retryFrame:SetScript("OnUpdate", function(self, elapsed)
	if not mainFrame:IsShown() then return end
	retryTimer = retryTimer + elapsed
	if retryTimer >= 0.5 then
		retryTimer = 0
		-- Check if any visible rows have missing item info
		local needRefresh = false
		local offset = FauxScrollFrame_GetOffset(scrollFrame)
		for i = 1, MAX_VISIBLE_ROWS do
			local dataIndex = offset + i
			local numItems = math.floor(#currentItems / 2)
			if dataIndex <= numItems then
				local entry = currentItems[(dataIndex - 1) * 2 + 1]
				local name = GetItemInfo(entry)
				if not name then
					needRefresh = true
					-- Trigger cache by tooltip query
					GameTooltip:SetHyperlink("item:"..entry)
					GameTooltip:Hide()
				end
			end
		end
		if needRefresh then
			RefreshItemList()
		end
	end
end)

---------------------------------------------------------------------------
-- On show: select current category
---------------------------------------------------------------------------
mainFrame:SetScript("OnShow", function()
	SelectCategory(currentCategory)
end)

---------------------------------------------------------------------------
-- AIO Handlers (Client-side)
---------------------------------------------------------------------------
local ES_Client = {}

ES_Client.LogEntry = function(player, text)
	AddLogEntry(text)
end

ES_Client.UpdateItems = function(player, catIndex, items)
	currentItems = items or {}
	if not searchActive then
		currentCategory = catIndex
		-- Update category button highlight
		MarkCategory(catIndex)
	end
	RefreshItemList()
end

-- Hot-reload safe handler registration
if not ES_ClientInit then
	AIO.AddHandlers("EndlessStorage", ES_Client)
	ES_ClientInit = true
else
	-- Update handler functions in-place
	local existing = ES_Client
	for k, v in pairs(ES_Client) do
		existing[k] = v
	end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_ENDLESSSTORAGE1 = "/es"
SLASH_ENDLESSSTORAGE2 = "/storage"
SlashCmdList["ENDLESSSTORAGE"] = function()
	if EndlessStorageFrame:IsShown() then
		EndlessStorageFrame:Hide()
	else
		EndlessStorageFrame:Show()
	end
end
