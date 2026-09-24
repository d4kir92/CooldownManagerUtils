local _, CooldownManagerUtils = ...

local GRID_COLUMNS = 7
local ITEM_SIZE = 38
local ITEM_SPACING = 8
local CATEGORY_WIDTH = 344
local CATEGORY_DEFINITIONS = {
	{key = "trackedBuff", titleGlobal = "COOLDOWN_VIEWER_SETTINGS_CATEGORY_TRACKED_BUFF", localeKey = "LID_BUFFREMINDERS_CATEGORY_BUFFS"},
	{key = "hidden", titleGlobal = "COOLDOWN_VIEWER_SETTINGS_CATEGORY_NOT_IN_BAR", localeKey = "LID_BUFFREMINDERS_CATEGORY_HIDDEN"}
}

local settingsFrame
local reminderTab
local reminderContent
local customMode = false
local stockControls = {}
local stockTabs = {}
local categoryFrames = {}
local categoryModels = {}
local categoryByKey = {}
local collapsed = {}
local draggedButton
local dropCategory
local dropEntry
local dragPreview

local function SetStockControlsShown(shown)
	for _, control in ipairs(stockControls) do
		if control then control:SetShown(shown) end
	end
end

local function IsValidCategory(key)
	for _, definition in ipairs(CATEGORY_DEFINITIONS) do
		if definition.key == key then return true end
	end
	return false
end

local function FindEntryIndex(entries, entry)
	for index, candidate in ipairs(entries) do
		if candidate == entry then return index end
	end
end

local function CreateDragPreview()
	if dragPreview then return dragPreview end
	local preview = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	preview:SetSize(ITEM_SIZE, ITEM_SIZE)
	preview:SetFrameStrata("TOOLTIP")
	preview:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
	preview:SetBackdropBorderColor(0.2, 0.75, 1, 1)
	preview.Icon = preview:CreateTexture(nil, "ARTWORK")
	preview.Icon:SetPoint("TOPLEFT", 2, -2)
	preview.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
	preview:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 18, y / scale - 18)
	end)
	preview:Hide()
	dragPreview = preview
	return preview
end

local function FinishDrag()
	if not draggedButton then return end
	local sourceButton = draggedButton
	local sourceEntry = sourceButton.entry
	local sourceCategory = sourceButton.category
	sourceButton:SetAlpha(1)
	draggedButton = nil
	CreateDragPreview():Hide()
	if sourceEntry and sourceCategory and dropCategory then
		local sourceIndex = FindEntryIndex(sourceCategory.entries, sourceEntry)
		local targetIndex = dropEntry and FindEntryIndex(dropCategory.entries, dropEntry) or #dropCategory.entries + 1
		if sourceIndex and targetIndex then
			table.remove(sourceCategory.entries, sourceIndex)
			if sourceCategory == dropCategory and sourceIndex < targetIndex then targetIndex = targetIndex - 1 end
			targetIndex = math.max(1, math.min(targetIndex, #dropCategory.entries + 1))
			table.insert(dropCategory.entries, targetIndex, sourceEntry)
			CooldownManagerUtils:SaveReminderLayout(categoryModels)
		end
	end
	dropCategory = nil
	dropEntry = nil
	CooldownManagerUtils:RefreshReminderSettings()
end

local function BeginDrag(button)
	if not button.entry then return end
	draggedButton = button
	dropCategory = button.category
	dropEntry = button.entry
	button:SetAlpha(0.35)
	local preview = CreateDragPreview()
	preview.Icon:SetTexture(button.entry.iconID)
	preview:Show()
	GameTooltip:Hide()
end

local function CreateItemButton(parent, index)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(ITEM_SIZE, ITEM_SIZE)
	button:RegisterForDrag("LeftButton")
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetAllPoints()
	button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.Highlight:SetAllPoints(button.Icon)
	button.Highlight:SetColorTexture(1, 1, 1, 0.18)
	button:SetScript("OnDragStart", BeginDrag)
	button:SetScript("OnDragStop", FinishDrag)
	button:SetScript("OnEnter", function(self)
		if not self.entry then return end
		dropCategory = self.category
		dropEntry = self.entry
		if draggedButton then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.entry.spellID)
		GameTooltip:AddLine(CooldownManagerUtils:Trans("LID_BUFFREMINDERS_TOOLTIP"), 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(CooldownManagerUtils:Trans("LID_BUFFREMINDERS_DRAG"), 0.5, 0.8, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	parent.buttons[index] = button
	return button
end

local function CreateCategoryFrame(parent, definition, index)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetWidth(CATEGORY_WIDTH)
	frame.Header = CreateFrame("Button", nil, frame, "BackdropTemplate")
	frame.Header:SetPoint("TOPLEFT")
	frame.Header:SetPoint("TOPRIGHT")
	frame.Header:SetHeight(22)
	frame.Header:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
	frame.Header:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
	frame.Header:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
	frame.Header.Text = frame.Header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.Header.Text:SetPoint("LEFT", 8, 0)
	frame.Header.Arrow = frame.Header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.Header.Arrow:SetPoint("RIGHT", -7, 0)
	frame.Header:SetScript("OnClick", function()
		collapsed[definition.key] = not collapsed[definition.key]
		CooldownManagerUtils:RefreshReminderSettings()
	end)
	frame.Header:SetScript("OnEnter", function()
		if draggedButton then
			dropCategory = categoryByKey[definition.key]
			dropEntry = nil
		end
	end)
	frame.Container = CreateFrame("Frame", nil, frame)
	frame.Container:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 13, -15)
	frame.Container:SetWidth(315)
	frame.Container:EnableMouse(true)
	frame.Container.buttons = {}
	frame.Container:SetScript("OnEnter", function()
		if draggedButton then
			dropCategory = categoryByKey[definition.key]
			dropEntry = nil
		end
	end)
	frame.definition = definition
	categoryFrames[index] = frame
	return frame
end

local function BuildCategoryModels()
	local models = {}
	local byKey = {}
	for _, definition in ipairs(CATEGORY_DEFINITIONS) do
		local model = {key = definition.key, entries = {}}
		table.insert(models, model)
		byKey[definition.key] = model
	end
	for _, entry in ipairs(CooldownManagerUtils:GetAvailableBuffs()) do
		local layout = CooldownManagerUtils:GetReminderLayout(entry.spellID)
		local categoryKey = layout and layout.category or "hidden"
		if not IsValidCategory(categoryKey) then categoryKey = "hidden" end
		table.insert(byKey[categoryKey].entries, entry)
	end
	for _, model in ipairs(models) do
		table.sort(model.entries, function(left, right)
			local leftLayout = CooldownManagerUtils:GetReminderLayout(left.spellID)
			local rightLayout = CooldownManagerUtils:GetReminderLayout(right.spellID)
			local leftOrder = leftLayout and leftLayout.order or math.huge
			local rightOrder = rightLayout and rightLayout.order or math.huge
			if leftOrder ~= rightOrder then return leftOrder < rightOrder end
			return left.name < right.name
		end)
	end
	categoryModels = models
	categoryByKey = byKey
end

function CooldownManagerUtils:RefreshReminderSettings()
	if not reminderContent then return end
	BuildCategoryModels()
	local filter = settingsFrame and settingsFrame.filterText or ""
	local yOffset = 0
	local visibleTotal = 0
	for index, definition in ipairs(CATEGORY_DEFINITIONS) do
		local model = categoryModels[index]
		local frame = categoryFrames[index]
		local visibleEntries = {}
		for _, entry in ipairs(model.entries) do
			if filter == "" or entry.name:lower():find(filter, 1, true) then table.insert(visibleEntries, entry) end
		end
		visibleTotal = visibleTotal + #visibleEntries
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", reminderContent.ScrollChild, "TOPLEFT", 0, -yOffset)
		local title = _G[definition.titleGlobal] or self:Trans(definition.localeKey)
		frame.Header.Text:SetText(title .. " (" .. #visibleEntries .. ")")
		frame.Header.Arrow:SetText(collapsed[definition.key] and "+" or "−")
		local isCollapsed = collapsed[definition.key] == true
		frame.Container:SetShown(not isCollapsed)
		for itemIndex, entry in ipairs(visibleEntries) do
			local button = frame.Container.buttons[itemIndex] or CreateItemButton(frame.Container, itemIndex)
			local column = (itemIndex - 1) % GRID_COLUMNS
			local row = math.floor((itemIndex - 1) / GRID_COLUMNS)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", column * (ITEM_SIZE + ITEM_SPACING), -row * (ITEM_SIZE + ITEM_SPACING))
			button.entry = entry
			button.category = model
			button.Icon:SetTexture(entry.iconID)
			button:Show()
		end
		for itemIndex = #visibleEntries + 1, #frame.Container.buttons do
			frame.Container.buttons[itemIndex].entry = nil
			frame.Container.buttons[itemIndex]:Hide()
		end
		local rowCount = math.max(1, math.ceil(#visibleEntries / GRID_COLUMNS))
		local containerHeight = rowCount * ITEM_SIZE + math.max(0, rowCount - 1) * ITEM_SPACING
		frame.Container:SetHeight(containerHeight)
		local frameHeight = isCollapsed and 22 or 22 + 15 + containerHeight + 10
		frame:SetHeight(frameHeight)
		frame:Show()
		yOffset = yOffset + frameHeight + 18
	end
	reminderContent.ScrollChild:SetHeight(math.max(1, yOffset))
	reminderContent.Empty:SetShown(visibleTotal == 0)
end

local function SetCustomMode(enabled)
	if not settingsFrame or not reminderContent then return end
	customMode = enabled
	reminderContent:SetShown(enabled)
	if enabled then
		settingsFrame.CooldownScroll:Hide()
		settingsFrame.GroupBuffFilter:Hide()
		SetStockControlsShown(false)
		for _, tab in ipairs(stockTabs) do tab:SetChecked(false) end
		reminderTab:SetChecked(true)
		CooldownManagerUtils:RefreshReminderSettings()
	else
		SetStockControlsShown(true)
		reminderTab:SetChecked(false)
	end
end

local function CreateReminderContent(parent)
	local content = CreateFrame("Frame", nil, parent)
	content:SetPoint("TOPLEFT", 17, -72)
	content:SetPoint("BOTTOMRIGHT", -30, 29)
	content.Scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
	content.Scroll:SetAllPoints()
	content.ScrollChild = CreateFrame("Frame", nil, content.Scroll)
	content.ScrollChild:SetWidth(CATEGORY_WIDTH)
	content.ScrollChild:SetHeight(1)
	content.Scroll:SetScrollChild(content.ScrollChild)
	content.Empty = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	content.Empty:SetPoint("CENTER", content.Scroll, "CENTER", 0, 20)
	content.Empty:SetText(CooldownManagerUtils:Trans("LID_BUFFREMINDERS_EMPTY"))
	for index, definition in ipairs(CATEGORY_DEFINITIONS) do CreateCategoryFrame(content.ScrollChild, definition, index) end
	content:Hide()
	return content
end

local function CreateReminderTab(parent)
	local tab = CreateFrame("Frame", nil, parent, "LargeSideTabButtonTemplate")
	tab.activeAtlas = "icon_trackedbuffs"
	tab.inactiveAtlas = "icon_trackedbuffs"
	tab.tooltipText = CooldownManagerUtils:Trans("LID_BUFFREMINDERS")
	tab.Icon:SetAtlas("icon_trackedbuffs", true)
	tab:ClearAllPoints()
	tab:SetPoint("TOP", parent.GroupBuffsTab, "BOTTOM", 0, -3)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then SetCustomMode(true) end
	end)
	return tab
end

function CooldownManagerUtils:InitializeReminderSettings()
	if settingsFrame then return end
	if not C_AddOns or not C_AddOns.LoadAddOn then return end
	if not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then
		local loaded = C_AddOns.LoadAddOn("Blizzard_CooldownViewer")
		if not loaded then return end
	end
	local frame = CooldownViewerSettings
	if not frame or not frame.SpellsTab or not frame.AurasTab or not frame.GroupBuffsTab then return end
	settingsFrame = frame
	reminderContent = CreateReminderContent(frame)
	reminderTab = CreateReminderTab(frame)
	stockTabs = {frame.SpellsTab, frame.AurasTab, frame.GroupBuffsTab}
	stockControls = {frame.LayoutDropdown, frame.UndoButton}
	hooksecurefunc(frame, "SetDisplayMode", function() SetCustomMode(false) end)
	hooksecurefunc(frame, "SetFilterText", function()
		if customMode then CooldownManagerUtils:RefreshReminderSettings() end
	end)
	frame:HookScript("OnShow", function()
		if customMode then SetCustomMode(true) end
	end)
	self:RefreshReminderSettings()
end
