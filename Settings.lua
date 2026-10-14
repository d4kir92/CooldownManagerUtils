local _, CooldownManagerUtils = ...

local GRID_COLUMNS = 7
local ITEM_SIZE = 38
local ITEM_SPACING = 8
local CATEGORY_WIDTH = 344
local TAB_ICON_SIZE = 32
local ADD_BUTTON_WIDTH = 200
local ADD_BUTTON_HEIGHT = 26
local INFO_SPACING = 6
local ADD_BUFF_MAX_RESULTS = 50
local CUSTOM_ALERT_TEXTURE = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"
local CUSTOM_ALERT_ICON = "|T" .. CUSTOM_ALERT_TEXTURE .. ":14:14:0:0:64:64:0:64:0:64:255:51:51|t"
local CATEGORY_DEFINITIONS = {
	{key = "expiringBuff", localeKey = "LID_BUFFREMINDERS_CATEGORY_EXPIRING", buffOnly = true},
	{key = "trackedBuff", titleGlobal = "COOLDOWN_VIEWER_SETTINGS_CATEGORY_TRACKED_BUFF", localeKey = "LID_BUFFREMINDERS_CATEGORY_BUFFS", abilityLocaleKey = "LID_ABILITYREMINDERS_CATEGORY_ABILITIES"},
	{key = "hidden", titleGlobal = "COOLDOWN_VIEWER_SETTINGS_CATEGORY_NOT_IN_BAR", localeKey = "LID_BUFFREMINDERS_CATEGORY_HIDDEN", abilityLocaleKey = "LID_ABILITYREMINDERS_CATEGORY_HIDDEN"},
	{key = "notLearned", localeKey = "LID_REMINDERS_CATEGORY_NOT_LEARNED", abilityLocaleKey = "LID_REMINDERS_CATEGORY_NOT_LEARNED", readOnly = true}
}

local settingsFrame
local reminderTab
local abilityReminderTab
local reminderContent
local reminderUndoButton
local reminderRestorePoint
local customMode = false
local stockTabs = {}
local categoryFrames = {}
local categoryModels = {}
local categoryByKey = {}
local collapsed = {}
local draggedButton
local dropCategory
local dropEntry
local dragPreview
local addBuffWindow

local function IsValidCategory(key)
	for _, definition in ipairs(CATEGORY_DEFINITIONS) do
		if definition.key == key and not definition.readOnly then return not definition.buffOnly or customMode ~= "ability" end
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
			if reminderUndoButton then reminderUndoButton:Enable() end
		end
	end
	dropCategory = nil
	dropEntry = nil
	CooldownManagerUtils:RefreshReminderSettings()
end

function CooldownManagerUtils:CaptureReminderRestorePoint()
	reminderRestorePoint = CopyTable(self:GetProfile())
	if reminderUndoButton then reminderUndoButton:Disable() end
end

local function RestoreReminderProfile()
	if not reminderRestorePoint then return end
	local profile = CooldownManagerUtils:GetProfile()
	wipe(profile)
	for key, value in pairs(reminderRestorePoint) do profile[key] = CopyTable(value) end
	CooldownManagerUtils:RefreshReminderSettings()
	CooldownManagerUtils:UpdateReminderBar()
	if reminderUndoButton then reminderUndoButton:Disable() end
end

local function CreateReminderUndoButton(parent)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonNoTooltipTemplate, UIButtonTemplate")
	button:SetSize(164, 22)
	button:SetPoint("BOTTOMRIGHT", -3, 4)
	button:SetText(COOLDOWN_VIEWER_SETTINGS_BUTTON_REVERT_CHANGES)
	button:SetScript("OnClick", function()
		StaticPopup_Show("COOLDOWN_MANAGER_UTILS_REVERT_REMINDER_CHANGES")
	end)
	button:Disable()
	button:Hide()
	return button
end

local function BeginDrag(button)
	if not button.entry or button.category.readOnly then return end
	draggedButton = button
	dropCategory = button.category
	dropEntry = button.entry
	button:SetAlpha(0.35)
	local preview = CreateDragPreview()
	preview.Icon:SetTexture(button.entry.iconID)
	preview:Show()
	GameTooltip:Hide()
end

local function AddCustomBuffTooltip(tooltip)
	tooltip:AddLine(" ")
	tooltip:AddLine(CUSTOM_ALERT_ICON .. " " .. CooldownManagerUtils:Trans("LID_CUSTOMBUFF"), 1, 0.2, 0.2)
	tooltip:AddLine(CooldownManagerUtils:Trans("LID_CUSTOMBUFF_WARNING"), 1, 0.82, 0, true)
	tooltip:AddLine(CooldownManagerUtils:Trans("LID_CUSTOMBUFF_CONTACT"), 0.8, 0.8, 0.8, true)
	tooltip:AddLine(CooldownManagerUtils:Trans("LID_CUSTOMBUFF_REMOVE_HINT"), 0.5, 0.8, 1, true)
end

local function ShowRemoveCustomBuffDialog(entry)
	GameTooltip:Hide()
	StaticPopup_Show("COOLDOWN_MANAGER_UTILS_REMOVE_CUSTOM_BUFF", entry.name, nil, entry)
end

local function CreateItemButton(parent, index)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(ITEM_SIZE, ITEM_SIZE)
	button:RegisterForDrag("LeftButton")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetAllPoints()
	button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.Highlight:SetAllPoints(button.Icon)
	button.Highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	button.Highlight:SetBlendMode("ADD")
	button.Filter = button:CreateTexture(nil, "OVERLAY")
	button.Filter:SetAllPoints(button.Icon)
	button.Filter:SetColorTexture(0, 0, 0, 0.72)
	button.Alert = button:CreateTexture(nil, "OVERLAY", nil, 7)
	button.Alert:SetTexture(CUSTOM_ALERT_TEXTURE)
	button.Alert:SetVertexColor(1, 0.2, 0.2, 1)
	button.Alert:SetSize(14, 14)
	button.Alert:SetPoint("TOPRIGHT", button, "TOPRIGHT", 3, 3)
	button.Alert:Hide()
	button:SetScript("OnDragStart", BeginDrag)
	button:SetScript("OnDragStop", FinishDrag)
	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" and not draggedButton and self.entry and self.entry.custom then ShowRemoveCustomBuffDialog(self.entry) end
	end)
	button:SetScript("OnEnter", function(self)
		if not self.entry then return end
		dropCategory = not self.category.readOnly and self.category or nil
		dropEntry = dropCategory and self.entry or nil
		if draggedButton then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.entry.spellID)
		if self.category.readOnly then
			GameTooltip:AddLine(CooldownManagerUtils:Trans("LID_REMINDERS_NOT_LEARNED_TOOLTIP"), 0.6, 0.6, 0.6, true)
		else
			GameTooltip:AddLine(CooldownManagerUtils:Trans(customMode == "ability" and "LID_ABILITYREMINDERS_TOOLTIP" or "LID_BUFFREMINDERS_TOOLTIP"), 0.8, 0.8, 0.8, true)
			GameTooltip:AddLine(CooldownManagerUtils:Trans("LID_BUFFREMINDERS_DRAG"), 0.5, 0.8, 1, true)
		end
		if self.entry.custom then AddCustomBuffTooltip(GameTooltip) end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	parent.buttons[index] = button
	return button
end

local function CreateCategoryFrame(parent, definition, index)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetWidth(CATEGORY_WIDTH)
	frame.Header = CreateFrame("Button", nil, frame, "ListHeaderThreeSliceTemplate")
	frame.Header:SetPoint("TOPLEFT")
	frame.Header:SetPoint("TOPRIGHT")
	frame.Header:SetHeight(22)
	frame.Header:SetTitleColor(false, NORMAL_FONT_COLOR)
	frame.Header:SetTitleColor(true, NORMAL_FONT_COLOR)
	frame.Header:SetClickHandler(function(_, button)
		if button == "LeftButton" then
			collapsed[definition.key] = not collapsed[definition.key]
			CooldownManagerUtils:RefreshReminderSettings()
		end
	end)
	frame.Header:HookScript("OnEnter", function()
		if draggedButton and not definition.readOnly then
			dropCategory = categoryByKey[definition.key]
			dropEntry = nil
		elseif draggedButton then
			dropCategory = nil
			dropEntry = nil
		end
	end)
	frame.Container = CreateFrame("Frame", nil, frame)
	frame.Container:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 13, -15)
	frame.Container:SetWidth(315)
	frame.Container:EnableMouse(true)
	frame.Container.buttons = {}
	frame.Container.Empty = CreateFrame("Frame", nil, frame.Container)
	frame.Container.Empty:SetSize(ITEM_SIZE, ITEM_SIZE)
	frame.Container.Empty:SetPoint("TOPLEFT")
	frame.Container.Empty:EnableMouse(true)
	frame.Container.Empty.Icon = frame.Container.Empty:CreateTexture(nil, "ARTWORK")
	frame.Container.Empty.Icon:SetAllPoints()
	frame.Container.Empty.Icon:SetAtlas("cdm-empty")
	frame.Container.Empty:SetScript("OnEnter", function()
		if draggedButton and not definition.readOnly then
			dropCategory = categoryByKey[definition.key]
			dropEntry = nil
		elseif draggedButton then
			dropCategory = nil
			dropEntry = nil
		end
	end)
	frame.Container:SetScript("OnEnter", function()
		if draggedButton and not definition.readOnly then
			dropCategory = categoryByKey[definition.key]
			dropEntry = nil
		elseif draggedButton then
			dropCategory = nil
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
		local model = {key = definition.key, entries = {}, readOnly = definition.readOnly}
		table.insert(models, model)
		byKey[definition.key] = model
	end
	for _, entry in ipairs(CooldownManagerUtils:GetAvailableBuffs()) do
		if (entry.reactiveAbility == true) == (customMode == "ability") then
			local layout = entry.isLearned ~= false and CooldownManagerUtils:GetReminderLayout(entry.spellID)
			local categoryKey = entry.isLearned == false and "notLearned" or layout and layout.category or "hidden"
			if entry.isLearned ~= false and not IsValidCategory(categoryKey) then categoryKey = "hidden" end
			table.insert(byKey[categoryKey].entries, entry)
		end
	end
	for _, model in ipairs(models) do
		table.sort(model.entries, function(left, right)
			if model.readOnly then return left.name < right.name end
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
	reminderContent.Empty:SetText(self:Trans(customMode == "ability" and "LID_ABILITYREMINDERS_EMPTY" or "LID_BUFFREMINDERS_EMPTY"))
	local filter = settingsFrame and settingsFrame.filterText or ""
	local info = reminderContent.Info
	local isBuffMode = customMode ~= "ability"
	info.AddButton:SetShown(isBuffMode)
	info.Text:ClearAllPoints()
	if isBuffMode then
		info.Text:SetPoint("TOP", info.AddButton, "BOTTOM", 0, -INFO_SPACING)
	else
		info.Text:SetPoint("TOP", info, "TOP", 0, 0)
	end
	info.Text:SetText(self:Trans(isBuffMode and "LID_BUFFREMINDERS_CONTACT" or "LID_ABILITYREMINDERS_CONTACT"))
	local infoHeight = math.ceil(info.Text:GetStringHeight()) + (isBuffMode and ADD_BUTTON_HEIGHT + INFO_SPACING or 0)
	info:ClearAllPoints()
	info:SetPoint("TOPLEFT", reminderContent.ScrollChild, "TOPLEFT", 0, 0)
	info:SetHeight(math.max(1, infoHeight))
	local yOffset = infoHeight + 18
	for index, definition in ipairs(CATEGORY_DEFINITIONS) do
		local model = categoryModels[index]
		local frame = categoryFrames[index]
		frame:ClearAllPoints()
		if definition.buffOnly and customMode == "ability" then
			frame:Hide()
		else
			frame:SetPoint("TOPLEFT", reminderContent.ScrollChild, "TOPLEFT", 0, -yOffset)
			local title = customMode == "ability" and self:Trans(definition.abilityLocaleKey) or definition.titleGlobal and _G[definition.titleGlobal] or self:Trans(definition.localeKey)
			local isCollapsed = collapsed[definition.key] == true
			frame.Header:SetHeaderText(title)
			frame.Header:UpdateCollapsedState(isCollapsed)
			frame.Container:SetShown(not isCollapsed)
			frame.Container.Empty:SetShown(#model.entries == 0)
			for itemIndex, entry in ipairs(model.entries) do
				local button = frame.Container.buttons[itemIndex] or CreateItemButton(frame.Container, itemIndex)
				local column = (itemIndex - 1) % GRID_COLUMNS
				local row = math.floor((itemIndex - 1) / GRID_COLUMNS)
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", column * (ITEM_SIZE + ITEM_SPACING), -row * (ITEM_SIZE + ITEM_SPACING))
				button.entry = entry
				button.category = model
				button.Icon:SetTexture(entry.iconID)
				button.Icon:SetDesaturated(entry.isLearned == false)
				button:SetAlpha(entry.isLearned == false and 0.45 or 1)
				button.Alert:SetShown(entry.custom == true)
				button.Filter:SetShown(filter ~= "" and not entry.name:lower():find(filter, 1, true))
				button:Show()
			end
			for itemIndex = #model.entries + 1, #frame.Container.buttons do
				frame.Container.buttons[itemIndex].entry = nil
				frame.Container.buttons[itemIndex]:Hide()
			end
			local rowCount = math.max(1, math.ceil(#model.entries / GRID_COLUMNS))
			local containerHeight = rowCount * ITEM_SIZE + math.max(0, rowCount - 1) * ITEM_SPACING
			frame.Container:SetHeight(containerHeight)
			local frameHeight = isCollapsed and 22 or 22 + 15 + containerHeight + 10
			frame:SetHeight(frameHeight)
			frame:Show()
			yOffset = yOffset + frameHeight + 18
		end
	end
	reminderContent.ScrollChild:SetHeight(math.max(1, yOffset))
	reminderContent.Empty:Hide()
end

local function SetCustomMode(mode)
	if not settingsFrame or not reminderContent then return end
	customMode = mode
	reminderContent:SetShown(mode ~= false)
	if mode ~= false then
		settingsFrame.CooldownScroll:Hide()
		settingsFrame.GroupBuffFilter:Hide()
		settingsFrame.LayoutDropdown:Show()
		settingsFrame.UndoButton:Hide()
		reminderUndoButton:Show()
		for _, tab in ipairs(stockTabs) do tab:SetChecked(false) end
		reminderTab:SetChecked(mode == "buff")
		if abilityReminderTab then abilityReminderTab:SetChecked(mode == "ability") end
		CooldownManagerUtils:RefreshReminderSettings()
	else
		settingsFrame.LayoutDropdown:Show()
		settingsFrame.UndoButton:Show()
		reminderUndoButton:Hide()
		reminderTab:SetChecked(false)
		if abilityReminderTab then abilityReminderTab:SetChecked(false) end
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
	content.Info = CreateFrame("Frame", nil, content.ScrollChild)
	content.Info:SetWidth(CATEGORY_WIDTH)
	content.Info.AddButton = CooldownManagerUtils:CreateButton("CooldownManagerUtilsAddBuffButton", content.Info)
	content.Info.AddButton:SetSize(ADD_BUTTON_WIDTH, ADD_BUTTON_HEIGHT)
	content.Info.AddButton:SetPoint("TOP", content.Info, "TOP", 0, 0)
	content.Info.AddButton:SetText(CooldownManagerUtils:Trans("LID_ADDBUFF"))
	content.Info.AddButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		CooldownManagerUtils:ToggleAddBuffWindow()
	end)
	content.Info.Text = content.Info:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	content.Info.Text:SetWidth(CATEGORY_WIDTH - 20)
	content.Info.Text:SetJustifyH("CENTER")
	content.Info.Text:SetTextColor(0.8, 0.8, 0.8)
	for index, definition in ipairs(CATEGORY_DEFINITIONS) do CreateCategoryFrame(content.ScrollChild, definition, index) end
	content:Hide()
	return content
end

local function CreateReminderTab(parent, mode)
	local tab = CreateFrame("Frame", nil, parent, "LargeSideTabButtonTemplate")
	if mode == "buff" then
		tab.tooltipText = CooldownManagerUtils:Trans("LID_BUFFREMINDERS")
		tab.iconTexture = "Interface\\AddOns\\CooldownManagerUtils\\media\\buffreminder.blp"
	else
		tab.tooltipText = CooldownManagerUtils:Trans("LID_ABILITYREMINDERS")
		tab.iconTexture = "Interface\\AddOns\\CooldownManagerUtils\\media\\proc.blp"
	end
	tab.SetChecked = function(self, checked)
		self.Icon:SetTexture(self.iconTexture)
		self.Icon:SetSize(TAB_ICON_SIZE, TAB_ICON_SIZE)
		self.SelectedTexture:SetShown(checked)
	end
	tab:SetChecked(false)
	tab:ClearAllPoints()
	if mode == "buff" then
		tab:SetPoint("TOP", parent.GroupBuffsTab, "BOTTOM", 0, -3)
	else
		tab:SetPoint("TOP", reminderTab, "BOTTOM", 0, -3)
	end
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then SetCustomMode(mode) end
	end)
	return tab
end

local function CreateOptionsButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(18, 18)
	if parent.CloseButton then
		button:SetPoint("RIGHT", parent.CloseButton, "LEFT", -2, 0)
	else
		button:SetPoint("TOPRIGHT", -28, -3)
	end
	if parent.CloseButton then button:SetFrameLevel(parent.CloseButton:GetFrameLevel()) end
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetAllPoints()
	button.Icon:SetTexture(134376)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		CooldownManagerUtils:ToggleOptions()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Cooldown Manager Utils")
		GameTooltip:AddLine(CooldownManagerUtils:Trans("LID_OPENSETTINGS"), 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	return button
end

local function GetAddBuffStatusText(row)
	if row.listing == "custom" then return "|cffff3333" .. CooldownManagerUtils:Trans("LID_CUSTOMBUFF") .. "|r" end
	if row.listing == "listed" then return "|cff808080" .. CooldownManagerUtils:Trans("LID_ADDBUFF_LISTED") .. "|r" end
	return "|cff33ff33" .. CooldownManagerUtils:Trans("LID_ADDBUFF_CLICK") .. "|r"
end

local function ShowAddBuffRowTooltip(tooltip, row)
	tooltip:SetSpellByID(row.spellID)
	if row.listing == "custom" then
		AddCustomBuffTooltip(tooltip)
	elseif row.listing == "listed" then
		tooltip:AddLine(CooldownManagerUtils:Trans("LID_ADDBUFF_LISTED"), 0.5, 0.5, 0.5)
	else
		tooltip:AddLine(CooldownManagerUtils:Trans("LID_ADDBUFF_CLICK"), 0.2, 1, 0.2)
	end
end

local function UpdateAddBuffResults()
	if not addBuffWindow or not addBuffWindow.results then return end
	local query = addBuffWindow.query or ""
	local rows = {}
	for _, spell in ipairs(CooldownManagerUtils:FindClassSpells(query)) do
		if #rows >= ADD_BUFF_MAX_RESULTS then break end
		table.insert(rows, {
			spellID = spell.spellID,
			name = spell.name,
			iconID = spell.iconID,
			listing = CooldownManagerUtils:GetBuffSpellListing(spell.spellID, spell.name)
		})
	end

	addBuffWindow.results.emptyText = strtrim(query) == "" and "LID_ADDBUFF_HINT" or "LID_ADDBUFF_EMPTY"
	addBuffWindow.results:SetRows(rows)
end

local function AddWindowText(win, text)
	local holder = CreateFrame("Frame", nil, win.content)
	holder:SetSize(math.max(1, win.contentWidth - 8), 1)
	holder.Text = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	holder.Text:SetPoint("TOPLEFT")
	holder.Text:SetPoint("TOPRIGHT")
	holder.Text:SetJustifyH("LEFT")
	holder.Text:SetText(text)
	local element = CooldownManagerUtils.UI:Add(win, holder, 1, nil, true)
	local function UpdateHeight()
		local height = math.max(1, math.ceil(holder.Text:GetStringHeight()))
		if element.height == height then return end
		element.height = height
		holder:SetHeight(height)
		win:Layout()
	end

	holder:SetScript("OnSizeChanged", UpdateHeight)
	holder:SetScript("OnShow", UpdateHeight)
	UpdateHeight()
	return holder
end

local function OnAddBuffRowClick(row, mouseButton)
	if mouseButton == "RightButton" then
		if row.listing == "custom" then ShowRemoveCustomBuffDialog({spellID = row.spellID, name = row.name}) end
		return
	end

	if row.listing ~= nil or not CooldownManagerUtils:AddCustomBuff(row.spellID) then return end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	UpdateAddBuffResults()
end

local function CreateAddBuffWindow()
	local win = CooldownManagerUtils:CreateUIWindow({
		["name"] = "CooldownManagerUtilsAddBuff",
		["title"] = format("|T%d:16:16:0:0|t %s", 134376, CooldownManagerUtils:Trans("LID_ADDBUFF")),
		["pTab"] = settingsFrame and {"TOPLEFT", settingsFrame, "TOPRIGHT", 4, 0} or {"CENTER"},
		["width"] = 420,
		["height"] = 440,
		["minWidth"] = 360,
		["minHeight"] = 300
	})

	win:SuspendLayout()
	AddWindowText(win, CooldownManagerUtils:Trans("LID_ADDBUFF_INFO") .. "\n\n|cffff3333" .. CUSTOM_ALERT_ICON .. " " .. CooldownManagerUtils:Trans("LID_CUSTOMBUFF_WARNING") .. "|r\n" .. CooldownManagerUtils:Trans("LID_CUSTOMBUFF_CONTACT"))
	win.searchBox = win:AddEditbox({
		["label"] = "LID_ADDBUFF_SEARCH",
		["func"] = function(value)
			win.query = value
			UpdateAddBuffResults()
		end
	})

	win.results = win:AddList({
		["stickyHeader"] = false,
		["sortKey"] = "name",
		["ascending"] = true,
		["emptyText"] = "LID_ADDBUFF_HINT",
		["onClick"] = OnAddBuffRowClick,
		["columns"] = {
			{
				["key"] = "name",
				["label"] = NAME,
				["width"] = 150,
				["flex"] = true,
				["text"] = function(row) return format("|T%s:16:16:0:0|t %s", tostring(row.iconID or 134400), row.name) end,
				["value"] = function(row) return row.name end,
				["tooltip"] = ShowAddBuffRowTooltip
			},
			{
				["key"] = "spellID",
				["label"] = "ID",
				["width"] = 60,
				["align"] = "RIGHT",
				["tooltip"] = ShowAddBuffRowTooltip
			},
			{
				["key"] = "status",
				["label"] = "LID_ADDBUFF_STATUS",
				["width"] = 120,
				["text"] = GetAddBuffStatusText,
				["value"] = function(row) return row.listing or "" end,
				["tooltip"] = ShowAddBuffRowTooltip
			}
		}
	})

	win:ResumeLayout()
	return win
end

function CooldownManagerUtils:ToggleAddBuffWindow()
	if not addBuffWindow then addBuffWindow = CreateAddBuffWindow() end
	addBuffWindow:Toggle()
	if addBuffWindow:IsShown() then
		addBuffWindow:Raise()
		addBuffWindow.searchBox.control:SetFocus()
		UpdateAddBuffResults()
	end
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
	reminderTab = CreateReminderTab(frame, "buff")
	if self:HasReactiveAbilities() then abilityReminderTab = CreateReminderTab(frame, "ability") end
	reminderUndoButton = CreateReminderUndoButton(frame)
	CreateOptionsButton(frame)
	stockTabs = {frame.SpellsTab, frame.AurasTab, frame.GroupBuffsTab}
	StaticPopupDialogs["COOLDOWN_MANAGER_UTILS_REVERT_REMINDER_CHANGES"] = {
		text = COOLDOWN_VIEWER_SETTINGS_DIALOG_TEXT_REVERT_CHANGES,
		button1 = YES,
		button2 = NO,
		OnAccept = RestoreReminderProfile,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1
	}
	StaticPopupDialogs["COOLDOWN_MANAGER_UTILS_REMOVE_CUSTOM_BUFF"] = {
		text = self:Trans("LID_CUSTOMBUFF_REMOVE_CONFIRM"),
		button1 = REMOVE or YES,
		button2 = CANCEL or NO,
		OnAccept = function(_, entry)
			CooldownManagerUtils:RemoveCustomBuff(entry)
			UpdateAddBuffResults()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1
	}
	hooksecurefunc(frame, "SetDisplayMode", function() SetCustomMode(false) end)
	hooksecurefunc(frame, "SetFilterText", function()
		if customMode then CooldownManagerUtils:RefreshReminderSettings() end
	end)
	frame:HookScript("OnShow", function()
		CooldownManagerUtils:OnCooldownManagerLayoutChanged()
		CooldownManagerUtils:CaptureReminderRestorePoint()
		if customMode then SetCustomMode(customMode) end
	end)
	frame:HookScript("OnHide", function()
		reminderRestorePoint = nil
		reminderUndoButton:Disable()
		if addBuffWindow then addBuffWindow:Hide() end
	end)
	if EventRegistry then
		EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
			CooldownManagerUtils:ScheduleCooldownManagerLayoutCheck()
		end, self)
	end
	self:OnCooldownManagerLayoutChanged()
	self:RefreshReminderSettings()
end

function CooldownManagerUtils:ShowReminderSettingsTab(reminderType)
	if settingsFrame and settingsFrame:IsShown() then SetCustomMode(reminderType == "ability" and "ability" or "buff") end
end
