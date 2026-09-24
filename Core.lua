local _, CooldownManagerUtils = ...
CooldownManagerUtils:SetAddonOutput("CooldownManagerUtils", 134376)
local ICON_SIZE = 40
local ICON_SPACING = 4
local FRAME_PADDING = 6
local DEFAULT_REMINDER_X = 0
local DEFAULT_REMINDER_Y = -180
local REMINDER_CATEGORY_ORDER = {
	trackedBuff = 1,
	hidden = 2
}
local COOLDOWN_AURA_CATEGORIES = {
	"Essential",
	"Utility",
	"TrackedBuff",
	"TrackedBar",
	"HiddenActive",
	"HiddenPassive"
}
local CLASS_AURA_FALLBACKS = {
	DRUID = {
		{spellID = 1126}
	},
	EVOKER = {
		{spellID = 364342}
	},
	MAGE = {
		{spellID = 1459}
	},
	PRIEST = {
		{spellID = 21562}
	},
	SHAMAN = {
		{spellID = 462854}
	},
	WARRIOR = {
		{spellID = 6673},
		{spellID = 97462, auraSpellID = 97463}
	}
}

local eventFrame = CreateFrame("Frame")
local reminderFrame
local reminderOptionsFrame
local editModeActive = false
local updatePending = false
local presenceCache = {}
local snapTargets = {}
local SNAP_DISTANCE = 10
local reminderSettingDefaults = {
	orientation = 0,
	iconDirection = 1,
	iconSize = 100,
	iconPadding = ICON_SPACING,
	opacity = 100,
	visibleSetting = 0,
	hideWhenInactive = 1,
	showTimer = 1,
	showTooltips = 1
}
local function IsSupportedClient()
	return CooldownManagerUtils:GetWoWBuildNr() >= 120000 or CooldownManagerUtils:IsForever()
end

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

local function GetReminderSpellInfo(spellID)
	if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spellID) end
	local name, _, iconID = _G.GetSpellInfo(spellID)
	if name then
		return {
			name = name,
			iconID = iconID
		}
	end
end

local function GetSpecKey()
	if GetSpecialization and GetSpecializationInfo then
		local specializationIndex = GetSpecialization()
		if specializationIndex then
			local specializationID = GetSpecializationInfo(specializationIndex)
			if specializationID then return tostring(specializationID) end
		end
	end

	local _, class = UnitClass("player")
	return class or "DEFAULT"
end

local function AddCandidate(candidates, seen, spellID)
	if type(spellID) ~= "number" or seen[spellID] then return end
	seen[spellID] = true
	table.insert(candidates, spellID)
end

local function GetSpellPredicate(predicate, spellID)
	if type(predicate) ~= "function" then return false end
	local ok, result = pcall(predicate, spellID)
	if not ok or IsSecret(result) then return false end
	return result == true
end

local function AddAuraMappingSpell(mapping, spellID)
	if type(spellID) ~= "number" then return end
	AddCandidate(mapping.candidates, mapping.seen, spellID)
end

local function AddCooldownAuraMapping(knownAuraSpells, knownAuraSources, info)
	if type(info) ~= "table" or info.hasAura ~= true or info.selfAura ~= true then return end
	local mapping = {
		candidates = {},
		seen = {}
	}
	AddAuraMappingSpell(mapping, info.overrideSpellID)
	AddAuraMappingSpell(mapping, info.overrideTooltipSpellID)
	AddAuraMappingSpell(mapping, info.spellID)
	if type(info.linkedSpellIDs) == "table" then
		for _, linkedSpellID in ipairs(info.linkedSpellIDs) do
			AddAuraMappingSpell(mapping, linkedSpellID)
		end
	end
	local sourceSpellID = info.overrideSpellID or info.spellID
	if type(sourceSpellID) == "number" then knownAuraSources[sourceSpellID] = info.spellID or sourceSpellID end

	for _, mappedSpellID in ipairs(mapping.candidates) do
		knownAuraSpells[mappedSpellID] = knownAuraSpells[mappedSpellID] or {
			candidates = {},
			seen = {}
		}
		local target = knownAuraSpells[mappedSpellID]
		for _, candidateSpellID in ipairs(mapping.candidates) do
			AddCandidate(target.candidates, target.seen, candidateSpellID)
		end
	end
end

local function AddCooldownCategoryMappings(cooldownViewer, category, knownAuraSpells, knownAuraSources, seenCooldownIDs)
	local categoryOK, cooldownIDs = pcall(cooldownViewer.GetCooldownViewerCategorySet, category, true)
	if not categoryOK or type(cooldownIDs) ~= "table" then return end
	for _, cooldownID in ipairs(cooldownIDs) do
		if not seenCooldownIDs[cooldownID] then
			seenCooldownIDs[cooldownID] = true
			local infoOK, info = pcall(cooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
			if infoOK then AddCooldownAuraMapping(knownAuraSpells, knownAuraSources, info) end
		end
	end
end

local function AddGroupBuffMappings(cooldownViewer, knownAuraSpells, knownAuraSources)
	if type(cooldownViewer.GetGroupBuffItems) ~= "function" then return end
	local itemsOK, items = pcall(cooldownViewer.GetGroupBuffItems)
	if not itemsOK or type(items) ~= "table" then return end
	for _, item in ipairs(items) do
		local spellID = type(item) == "table" and item.spellID
		if type(spellID) == "number" then
			knownAuraSources[spellID] = spellID
			knownAuraSpells[spellID] = knownAuraSpells[spellID] or {
				candidates = {},
				seen = {}
			}
			local mapping = knownAuraSpells[spellID]
			AddCandidate(mapping.candidates, mapping.seen, spellID)
		end
	end
end

local function AddClassAuraFallbackMappings(knownAuraSpells, knownAuraSources)
	local _, class = UnitClass("player")
	local definitions = CLASS_AURA_FALLBACKS[class]
	if not definitions then return end
	for _, definition in ipairs(definitions) do
		local spellID = definition.spellID
		local mapping = {
			candidates = {},
			seen = {}
		}
		AddCandidate(mapping.candidates, mapping.seen, spellID)
		AddCandidate(mapping.candidates, mapping.seen, definition.auraSpellID)
		knownAuraSpells[spellID] = mapping
		knownAuraSources[spellID] = spellID
	end
end

local function BuildKnownAuraSpellLookup()
	local knownAuraSpells = {}
	local knownAuraSources = {}
	AddClassAuraFallbackMappings(knownAuraSpells, knownAuraSources)
	local cooldownViewer = C_CooldownViewer
	local categoryEnum = Enum and Enum.CooldownViewerCategory
	if not cooldownViewer or not categoryEnum or not cooldownViewer.GetCooldownViewerCategorySet or not cooldownViewer.GetCooldownViewerCooldownInfo then return knownAuraSpells, knownAuraSources end

	AddGroupBuffMappings(cooldownViewer, knownAuraSpells, knownAuraSources)
	local seenCooldownIDs = {}
	for _, categoryName in ipairs(COOLDOWN_AURA_CATEGORIES) do
		local category = categoryEnum[categoryName]
		if category ~= nil then AddCooldownCategoryMappings(cooldownViewer, category, knownAuraSpells, knownAuraSources, seenCooldownIDs) end
	end

	return knownAuraSpells, knownAuraSources
end

local function IsPlayerBuffSpell(spellID, baseSpellID, knownAuraSpells)
	if not C_Spell or GetSpellPredicate(C_Spell.IsSpellPassive, spellID) then return false end
	if knownAuraSpells[spellID] or knownAuraSpells[baseSpellID] then return true end
	if GetSpellPredicate(C_Spell.IsSelfBuff, spellID) then return true end
	if not GetSpellPredicate(C_Spell.IsSpellHelpful, spellID) then return false end
	if type(C_Spell.GetSpellMaxCumulativeAuraApplications) ~= "function" then return false end
	local ok, applications = pcall(C_Spell.GetSpellMaxCumulativeAuraApplications, spellID)
	return ok and not IsSecret(applications) and type(applications) == "number" and applications > 0
end

local function AddAvailableSpell(spellID, baseSpellID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	if type(spellID) ~= "number" or not IsPlayerBuffSpell(spellID, baseSpellID, knownAuraSpells) then return end
	local candidates = {}
	local seenCandidates = {}
	AddCandidate(candidates, seenCandidates, spellID)
	AddCandidate(candidates, seenCandidates, baseSpellID)
	local auraMapping = knownAuraSpells[spellID] or knownAuraSpells[baseSpellID]
	if auraMapping then
		for _, auraSpellID in ipairs(auraMapping.candidates) do
			AddCandidate(candidates, seenCandidates, auraSpellID)
		end
	end
	if C_Spell.GetBaseSpell then
		local ok, result = pcall(C_Spell.GetBaseSpell, spellID)
		if ok and not IsSecret(result) then AddCandidate(candidates, seenCandidates, result) end
	end

	local existing = availableBuffsBySpellID[spellID]
	if existing then
		local existingCandidates = {}
		for _, candidateSpellID in ipairs(existing.candidates) do
			existingCandidates[candidateSpellID] = true
		end

		for _, candidateSpellID in ipairs(candidates) do
			AddCandidate(existing.candidates, existingCandidates, candidateSpellID)
		end
		return
	end

	local spellInfo = GetReminderSpellInfo(spellID)
	if not spellInfo or not spellInfo.name then return end
	local entry = {
		spellID = spellID,
		name = spellInfo.name,
		iconID = spellInfo.iconID,
		defaultCategory = "hidden",
		candidates = candidates
	}

	availableBuffsBySpellID[spellID] = entry
	table.insert(availableBuffs, entry)
end

local function AddFlyoutSpells(flyoutID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	if type(GetFlyoutInfo) ~= "function" or type(GetFlyoutSlotInfo) ~= "function" then return end
	local _, _, numSlots, isKnown = GetFlyoutInfo(flyoutID)
	if not isKnown or type(numSlots) ~= "number" then return end
	for slotIndex = 1, numSlots do
		local baseSpellID, overrideSpellID, isKnownSlot = GetFlyoutSlotInfo(flyoutID, slotIndex)
		if isKnownSlot then AddAvailableSpell(overrideSpellID or baseSpellID, baseSpellID, knownAuraSpells, availableBuffs, availableBuffsBySpellID) end
	end
end

local function AddSpellBookSkillLine(skillLineIndex, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
	if not skillLineInfo or skillLineInfo.shouldHide or skillLineInfo.isGuild then return end
	local playerBank = Enum.SpellBookSpellBank.Player
	local spellType = Enum.SpellBookItemType.Spell
	local flyoutType = Enum.SpellBookItemType.Flyout
	local firstItem = skillLineInfo.itemIndexOffset + 1
	local lastItem = firstItem + skillLineInfo.numSpellBookItems - 1
	for itemIndex = firstItem, lastItem do
		local itemInfo = C_SpellBook.GetSpellBookItemInfo(itemIndex, playerBank)
		if itemInfo and not itemInfo.isPassive and not itemInfo.isOffSpec then
			if itemInfo.itemType == spellType and itemInfo.spellID then
				AddAvailableSpell(itemInfo.spellID, itemInfo.actionID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
			elseif itemInfo.itemType == flyoutType then
				AddFlyoutSpells(itemInfo.actionID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
			end
		end
	end
end

local function AddKnownAuraSources(knownAuraSources, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	if type(C_SpellBook.IsSpellKnownOrInSpellBook) ~= "function" then return end
	local playerBank = Enum.SpellBookSpellBank.Player
	for spellID, baseSpellID in pairs(knownAuraSources) do
		local knownOK, isKnown = pcall(C_SpellBook.IsSpellKnownOrInSpellBook, spellID, playerBank, true)
		if knownOK and not IsSecret(isKnown) and isKnown == true then
			AddAvailableSpell(spellID, baseSpellID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
		end
	end
end

function CooldownManagerUtils:GetProfile()
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	CooldownManagerUtilsDB.profiles = CooldownManagerUtilsDB.profiles or {}
	local specKey = GetSpecKey()
	CooldownManagerUtilsDB.profiles[specKey] = CooldownManagerUtilsDB.profiles[specKey] or {
		selected = {}
	}

	local profile = CooldownManagerUtilsDB.profiles[specKey]
	if profile.layoutVersion ~= 4 then
		profile.selected = {}
		profile.layout = {}
		profile.layoutVersion = 4
	end

	profile.selected = profile.selected or {}
	profile.layout = profile.layout or {}
	return profile
end

function CooldownManagerUtils:GetReminderLayout(spellID)
	return self:GetProfile().layout[spellID]
end

function CooldownManagerUtils:SaveReminderLayout(categories)
	local layout = {}
	local selected = {}
	for _, category in ipairs(categories) do
		for order, entry in ipairs(category.entries) do
			layout[entry.spellID] = {
				category = category.key,
				order = order
			}

			if category.key ~= "hidden" then selected[entry.spellID] = true end
		end
	end

	local profile = self:GetProfile()
	profile.layout = layout
	profile.selected = selected
	self:UpdateReminderBar()
end

function CooldownManagerUtils:IsReminderSelected(spellID)
	return self:GetProfile().selected[spellID] == true
end

function CooldownManagerUtils:SetReminderSelected(spellID, selected)
	local profile = self:GetProfile()
	if selected then
		profile.selected[spellID] = true
	else
		profile.selected[spellID] = nil
		presenceCache[spellID] = nil
	end

	self:UpdateReminderBar()
end

function CooldownManagerUtils:RefreshAvailableBuffs()
	if InCombatLockdown() then
		self.pendingSourceRefresh = true
		return
	end

	if not C_SpellBook or not C_SpellBook.GetSpellBookSkillLineInfo or not C_SpellBook.GetSpellBookItemInfo or not Enum or not Enum.SpellBookSpellBank or not Enum.SpellBookItemType then
		self.availableBuffs = {}
		self.availableBuffsBySpellID = {}
		return
	end

	local availableBuffs = {}
	local availableBuffsBySpellID = {}
	local knownAuraSpells, knownAuraSources = BuildKnownAuraSpellLookup()
	local skillLineEnum = Enum.SpellBookSkillLineIndex
	local classLine = skillLineEnum and skillLineEnum.Class or 2
	local specLine = skillLineEnum and skillLineEnum.MainSpec or 3
	AddSpellBookSkillLine(classLine, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	AddSpellBookSkillLine(specLine, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	AddKnownAuraSources(knownAuraSources, knownAuraSpells, availableBuffs, availableBuffsBySpellID)

	table.sort(availableBuffs, function(left, right) return left.name < right.name end)
	self.availableBuffs = availableBuffs
	self.availableBuffsBySpellID = availableBuffsBySpellID
	self.pendingSourceRefresh = nil
	if self.RefreshReminderSettings then self:RefreshReminderSettings() end
	self:UpdateReminderBar()
end

function CooldownManagerUtils:GetAvailableBuffs()
	return self.availableBuffs or {}
end

local function RestorePosition(frame)
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	local position = CooldownManagerUtilsDB.position
	frame:ClearAllPoints()
	if position then
		local relativeTo = position.relativeTo and _G[position.relativeTo] or UIParent
		frame:SetPoint(position.point or "CENTER", relativeTo, position.relativePoint or "CENTER", position.x or DEFAULT_REMINDER_X, position.y or DEFAULT_REMINDER_Y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_REMINDER_X, DEFAULT_REMINDER_Y)
	end
end

local function SavePosition(frame)
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	local relativeName = relativeTo and relativeTo ~= UIParent and relativeTo:GetName() or nil
	if relativeTo and relativeTo ~= UIParent and not relativeName then
		local centerX, centerY = frame:GetCenter()
		local parentCenterX, parentCenterY = UIParent:GetCenter()
		point = "CENTER"
		relativePoint = "CENTER"
		x = centerX - parentCenterX
		y = centerY - parentCenterY
	end
	CooldownManagerUtilsDB.position = {
		point = point,
		relativeTo = relativeName,
		relativePoint = relativePoint,
		x = x,
		y = y
	}
end

local function GetReminderSettings()
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	CooldownManagerUtilsDB.reminderSettings = CooldownManagerUtilsDB.reminderSettings or {}
	local settings = CooldownManagerUtilsDB.reminderSettings
	for key, value in pairs(reminderSettingDefaults) do
		if settings[key] == nil then settings[key] = value end
	end
	return settings
end

local function ApplyReminderSettings(frame)
	local settings = GetReminderSettings()
	frame.orientationSetting = settings.orientation
	frame.iconDirection = settings.iconDirection
	frame.iconScale = settings.iconSize / 100
	frame.iconPadding = settings.iconPadding
	frame.visibleSetting = settings.visibleSetting
	frame.hideWhenInactive = settings.hideWhenInactive == 1
	frame.showTimer = settings.showTimer == 1
	frame.showTooltips = settings.showTooltips == 1
	frame:SetAlpha(settings.opacity / 100)
	CooldownManagerUtils:UpdateReminderBar()
	if reminderOptionsFrame and reminderOptionsFrame:IsShown() and reminderOptionsFrame.Refresh then reminderOptionsFrame:Refresh() end
end

local function GetFrameRect(frame)
	local selection = frame and frame.Selection
	if not selection or not selection:IsShown() then return end
	return selection:GetLeft(), selection:GetRight(), selection:GetBottom(), selection:GetTop()
end

local function GetSnapCandidate(frame, target)
	local left, right, bottom, top = GetFrameRect(frame)
	local targetLeft, targetRight, targetBottom, targetTop = GetFrameRect(target)
	if not left or not targetLeft then return end
	local centerX = (left + right) / 2
	local centerY = (bottom + top) / 2
	local targetCenterX = (targetLeft + targetRight) / 2
	local targetCenterY = (targetBottom + targetTop) / 2
	local best
	local function SetSnapCandidate(distance, point, relativePoint, x, y)
		local absoluteDistance = math.abs(distance)
		if absoluteDistance <= SNAP_DISTANCE and (not best or absoluteDistance < best.distance) then
			best = {distance = absoluteDistance, point = point, relativePoint = relativePoint, x = x, y = y, target = target}
		end
	end
	if top >= targetBottom and bottom <= targetTop then
		SetSnapCandidate(left - targetRight, "LEFT", "RIGHT", 0, centerY - targetCenterY)
		SetSnapCandidate(right - targetLeft, "RIGHT", "LEFT", 0, centerY - targetCenterY)
	end
	if right >= targetLeft and left <= targetRight then
		SetSnapCandidate(top - targetBottom, "TOP", "BOTTOM", centerX - targetCenterX, 0)
		SetSnapCandidate(bottom - targetTop, "BOTTOM", "TOP", centerX - targetCenterX, 0)
	end
	return best
end

local function SnapReminderFrame(frame)
	local best
	for _, target in ipairs(snapTargets) do
		local forbidden = target.IsForbidden and target:IsForbidden()
		if not forbidden and target ~= frame and target.Selection and target:IsVisible() then
			local candidate = GetSnapCandidate(frame, target)
			if candidate and (not best or candidate.distance < best.distance) then best = candidate end
		end
	end
	if not best then return end
	frame:ClearAllPoints()
	frame:SetPoint(best.point, best.target, best.relativePoint, best.x, best.y)
end

local function RefreshSnapTargets()
	wipe(snapTargets)
	local children = {UIParent:GetChildren()}
	for _, target in ipairs(children) do
		local forbidden = target.IsForbidden and target:IsForbidden()
		if not forbidden and target ~= reminderFrame and target.Selection then
			table.insert(snapTargets, target)
		end
	end
end

local function CreateSettingLabel(parent, text)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
	label:SetPoint("LEFT")
	label:SetSize(100, 32)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

local function CreateDropdownSetting(parent, layoutIndex, labelText, key, values, getText)
	local row = CreateFrame("Frame", nil, parent, "ResizeLayoutFrame")
	row.fixedHeight = 32
	row.layoutIndex = layoutIndex
	row.Label = CreateSettingLabel(row, labelText)
	row.Dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	row.Dropdown:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
	row.Dropdown:SetSize(225, 30)
	row.Dropdown:SetupMenu(function(_, rootDescription)
		for _, value in ipairs(values) do
			rootDescription:CreateRadio(getText(value), function(option)
				return GetReminderSettings()[key] == option
			end, function(option)
				GetReminderSettings()[key] = option
				local panel = parent:GetParent()
				if panel.RevertChanges then panel.RevertChanges:SetEnabled(true) end
				ApplyReminderSettings(reminderFrame)
			end, value)
		end
	end)
	row.Refresh = function() end
	row:Show()
	return row
end

local function CreateSliderSetting(parent, layoutIndex, labelText, key, minimum, maximum, step, suffix)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(343, 32)
	row.layoutIndex = layoutIndex
	row.Label = CreateSettingLabel(row, labelText)
	row.Slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
	row.Slider:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
	row.Slider:SetSize(200, 32)
	row.Slider.MinText:Hide()
	row.Slider.MaxText:Hide()
	local formatter = function(value) return value .. suffix end
	local formatters = {
		[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
	}
	local steps = (maximum - minimum) / step
	row.Slider:Init(GetReminderSettings()[key], minimum, maximum, steps, formatters)
	row.cbrHandles = EventUtil.CreateCallbackHandleContainer()
	row.cbrHandles:RegisterCallback(row.Slider, MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(self, value)
		if self.refreshing then return end
		GetReminderSettings()[key] = math.floor(value / step + 0.5) * step
		local panel = parent:GetParent()
		if panel.RevertChanges then panel.RevertChanges:SetEnabled(true) end
		ApplyReminderSettings(reminderFrame)
	end, row)
	row.Refresh = function(self)
		self.refreshing = true
		self.Slider:SetValue(GetReminderSettings()[key])
		self.refreshing = nil
	end
	row:Show()
	return row
end

local function CreateCheckboxSetting(parent, layoutIndex, labelText, key)
	local row = CreateFrame("Frame", nil, parent, "ResizeLayoutFrame")
	row.fixedHeight = 32
	row.widthPadding = -5
	row.layoutIndex = layoutIndex
	row.Button = CreateFrame("CheckButton", nil, row)
	row.Button:SetPoint("LEFT", -5, 0)
	row.Button:SetSize(32, 32)
	row.Button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	row.Button:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	row.Button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	row.Button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	row.Button:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
	row.Label:SetPoint("LEFT", row.Button, "RIGHT", 5, 0)
	row.Label:SetSize(300, 32)
	row.Label:SetJustifyH("LEFT")
	row.Label:SetText(labelText)
	row.Button:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		GetReminderSettings()[key] = self:GetChecked() and 1 or 0
		local panel = parent:GetParent()
		if panel.RevertChanges then panel.RevertChanges:SetEnabled(true) end
		ApplyReminderSettings(reminderFrame)
	end)
	row.Refresh = function(self) self.Button:SetChecked(GetReminderSettings()[key] == 1) end
	row:Show()
	return row
end

local function CreateReminderOptionsFrame(owner)
	if reminderOptionsFrame then return reminderOptionsFrame end
	local panel = CreateFrame("Frame", "CooldownManagerUtilsReminderOptions", UIParent, "ResizeLayoutFrame")
	panel:SetSize(300, 350)
	panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -250, 250)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(200)
	panel.widthPadding = 40
	panel.heightPadding = 40
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetDontSavePosition(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel.Border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
	panel.Border.ignoreInLayout = true
	panel.Title = panel:CreateFontString(nil, nil, "GameFontHighlightLarge")
	panel.Title:SetPoint("TOP", 0, -15)
	panel.Title:SetText(CooldownManagerUtils:Trans("LID_BUFFREMINDERS_EDITMODE"))
	panel.Close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	panel.Close:SetPoint("TOPRIGHT")
	panel.Close.ignoreInLayout = true
	panel.Close:SetScript("OnClick", function() panel:Hide() end)
	panel.Settings = CreateFrame("Frame", nil, panel, "VerticalLayoutFrame")
	panel.Settings:SetPoint("TOP", panel.Title, "BOTTOM", 0, -12)
	panel.Settings.spacing = 2
	panel.controls = {}
	local orientationValues = {0, 1}
	local directionValues = {0, 1}
	local visibilityValues = {0, 1, 2}
	local function OrientationText(value)
		return value == 0 and (_G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ORIENTATION_HORIZONTAL or HORIZONTAL or "Horizontal") or (_G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ORIENTATION_VERTICAL or VERTICAL or "Vertical")
	end
	local function DirectionText(value)
		local vertical = GetReminderSettings().orientation == 1
		if vertical then return value == 0 and (_G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ICON_DIRECTION_DOWN or "Down") or (_G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ICON_DIRECTION_UP or "Up") end
		return value == 0 and (_G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ICON_DIRECTION_LEFT or "Left") or (_G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ICON_DIRECTION_RIGHT or "Right")
	end
	local function VisibilityText(value)
		if value == 1 then return _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_VISIBLE_SETTING_IN_COMBAT or "In combat" end
		if value == 2 then return _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_VISIBLE_SETTING_HIDDEN or HIDDEN or "Hidden" end
		return _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_VISIBLE_SETTING_ALWAYS or ALWAYS or "Always"
	end
	local labels = {
		orientation = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ORIENTATION or "Orientation",
		direction = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ICON_DIRECTION or "Icon direction",
		size = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ICON_SIZE or "Icon size",
		padding = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_ICON_PADDING or "Icon padding",
		opacity = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_OPACITY or OPACITY or "Opacity",
		visibility = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_VISIBLE_SETTING or "Visibility",
		hideInactive = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_HIDE_WHEN_INACTIVE or "Hide when inactive",
		showTimer = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_SHOW_TIMER or "Show timer",
		showTooltips = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_SHOW_TOOLTIPS or "Show tooltips"
	}
	table.insert(panel.controls, CreateDropdownSetting(panel.Settings, 1, labels.orientation, "orientation", orientationValues, OrientationText))
	table.insert(panel.controls, CreateDropdownSetting(panel.Settings, 2, labels.direction, "iconDirection", directionValues, DirectionText))
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 3, labels.size, "iconSize", 50, 200, 10, "%"))
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 4, labels.padding, "iconPadding", 0, 14, 1, ""))
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 5, labels.opacity, "opacity", 50, 100, 1, "%"))
	table.insert(panel.controls, CreateDropdownSetting(panel.Settings, 6, labels.visibility, "visibleSetting", visibilityValues, VisibilityText))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 7, labels.hideInactive, "hideWhenInactive"))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 8, labels.showTimer, "showTimer"))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 9, labels.showTooltips, "showTooltips"))
	panel.Buttons = CreateFrame("Frame", nil, panel, "VerticalLayoutFrame")
	panel.Buttons:SetPoint("TOP", panel.Settings, "BOTTOM", 0, -12)
	panel.Buttons.spacing = 2
	panel.RevertChanges = CreateFrame("Button", nil, panel.Buttons, "EditModeSystemSettingsDialogButtonTemplate")
	panel.RevertChanges.layoutIndex = 1
	panel.RevertChanges:SetText(_G.HUD_EDIT_MODE_REVERT_CHANGES or "Änderungen verwerfen")
	panel.RevertChanges:SetEnabled(false)
	panel.RevertChanges:SetScript("OnClick", function(self)
		if not panel.originalSettings then return end
		local settings = GetReminderSettings()
		for key, value in pairs(panel.originalSettings) do settings[key] = value end
		self:SetEnabled(false)
		ApplyReminderSettings(owner)
	end)
	panel.Divider = panel.Buttons:CreateTexture(nil, "ARTWORK")
	panel.Divider:SetSize(330, 16)
	panel.Divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
	panel.Divider.layoutIndex = 2
	panel.Reset = CreateFrame("Button", nil, panel.Buttons, "EditModeSystemSettingsDialogExtraButtonTemplate")
	panel.Reset.layoutIndex = 3
	panel.Reset:SetText(_G.HUD_EDIT_MODE_RESET_POSITION or RESET_POSITION or "Reset position")
	panel.Reset:SetScript("OnClick", function()
		owner:ClearAllPoints()
		owner:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_REMINDER_X, DEFAULT_REMINDER_Y)
		CooldownManagerUtilsDB.position = nil
	end)
	panel.Refresh = function(self)
		for _, control in ipairs(self.controls) do control:Refresh() end
		if self:IsShown() then self:Layout() end
	end
	panel:SetScript("OnShow", function(self)
		self.originalSettings = {}
		for key, value in pairs(GetReminderSettings()) do self.originalSettings[key] = value end
		self.RevertChanges:SetEnabled(false)
		self:Refresh()
		self:Layout()
	end)
	panel:SetScript("OnHide", function()
		if editModeActive and owner.Selection then owner:HighlightSystem() end
	end)
	panel:Hide()
	reminderOptionsFrame = panel
	return panel
end

local function IsNativeSelectionAvailable()
	return EditModeSystemSelectionMixin ~= nil
end

local function SetupAddonEditModeFrame(frame)
	frame:SetMovable(true)
	frame.Selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
	frame.Selection:SetAllPoints()
	frame.Selection:SetSystem(frame)
	frame.Selection:Hide()
	frame.GetSystemName = function() return CooldownManagerUtils:Trans("LID_BUFFREMINDERS_EDITMODE") end
	frame.HighlightSystem = function(self)
		self.Selection:ShowHighlighted()
		self.isSelected = false
	end
	frame.SelectSystem = function(self)
		self.Selection:ShowSelected()
		self.isSelected = true
		local panel = CreateReminderOptionsFrame(self)
		panel:Show()
	end
	frame.ClearHighlight = function(self)
		self.Selection:Hide()
		self.isSelected = false
	end
	frame.OnDragStart = function(self)
		if not self.isSelected then return end
		self:StartMoving()
		self.isDragging = true
	end
	frame.OnDragStop = function(self)
		if not self.isDragging then return end
		self:StopMovingOrSizing()
		self.isDragging = false
		SnapReminderFrame(self)
		SavePosition(self)
	end
	frame.Selection:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then frame:SelectSystem() end
	end)
	RestorePosition(frame)
	ApplyReminderSettings(frame)
end

local function CreateReminderIcon(parent, index)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:EnableMouse(true)
	icon.Texture = icon:CreateTexture(nil, "ARTWORK")
	icon.Texture:SetAllPoints()
	icon.Mask = icon:CreateMaskTexture()
	icon.Mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
	icon.Mask:SetAllPoints()
	icon.Texture:AddMaskTexture(icon.Mask)
	icon.Overlay = icon:CreateTexture(nil, "OVERLAY")
	icon.Overlay:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
	icon.Overlay:SetPoint("TOPLEFT", -8, 7)
	icon.Overlay:SetPoint("BOTTOMRIGHT", 8, -7)
	icon:SetScript("OnEnter", function(self)
		if not self.spellID or parent.showTooltips == false then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.spellID)
		GameTooltip:Show()
	end)

	icon:SetScript("OnLeave", GameTooltip_Hide)
	parent.icons[index] = icon
	return icon
end

function CooldownManagerUtils:CreateReminderBar()
	if reminderFrame then return reminderFrame end
	local nativeSelection = IsNativeSelectionAvailable()
	local template = nativeSelection and nil or "BackdropTemplate"
	local frame = CreateFrame("Frame", "CooldownManagerUtilsReminderFrame", UIParent, template)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame.icons = {}
	reminderFrame = frame
	if nativeSelection then
		SetupAddonEditModeFrame(frame)
	else
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 2
		})
		frame:SetBackdropColor(0, 0, 0, 0)
		frame:SetBackdropBorderColor(0.2, 0.6, 1, 0)
		frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		frame.Label:SetPoint("CENTER")
		frame.Label:SetText(self:Trans("LID_BUFFREMINDERS_EDITMODE"))
		frame.Label:Hide()
		frame:SetScript("OnDragStart", function(mover) if editModeActive then mover:StartMoving() end end)
		frame:SetScript("OnDragStop", function(mover)
			mover:StopMovingOrSizing()
			SavePosition(mover)
		end)
		RestorePosition(frame)
	end
	return frame
end

local function GetSavedEntry(spellID)
	local entry = CooldownManagerUtils.availableBuffsBySpellID and CooldownManagerUtils.availableBuffsBySpellID[spellID]
	if entry then return entry end
	local spellInfo = GetReminderSpellInfo(spellID)
	if not spellInfo or not spellInfo.name then return end
	return {
		spellID = spellID,
		name = spellInfo.name,
		iconID = spellInfo.iconID,
		candidates = {spellID}
	}
end

local function GetAuraState(entry)
	if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return nil end
	local unknown = false
	for _, spellID in ipairs(entry.candidates) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
		if not ok or IsSecret(aura) then
			unknown = true
		elseif aura then
			return true
		end
	end

	if unknown then return nil end
	return false
end

function CooldownManagerUtils:UpdateReminderBar()
	local frame = self:CreateReminderBar()
	local selected = self:GetProfile().selected
	local entries = {}
	for spellID in pairs(selected) do
		local entry = GetSavedEntry(spellID)
		if entry then
			local present = GetAuraState(entry)
			if present ~= nil then presenceCache[spellID] = present end
			if editModeActive or presenceCache[spellID] == false then table.insert(entries, entry) end
		end
	end

	local profile = self:GetProfile()
	table.sort(entries, function(left, right)
		local leftLayout = profile.layout[left.spellID]
		local rightLayout = profile.layout[right.spellID]
		local leftCategory = leftLayout and leftLayout.category or left.defaultCategory or "hidden"
		local rightCategory = rightLayout and rightLayout.category or right.defaultCategory or "hidden"
		local leftCategoryOrder = REMINDER_CATEGORY_ORDER[leftCategory] or 5
		local rightCategoryOrder = REMINDER_CATEGORY_ORDER[rightCategory] or 5
		if leftCategoryOrder ~= rightCategoryOrder then return leftCategoryOrder < rightCategoryOrder end
		local leftOrder = leftLayout and leftLayout.order or math.huge
		local rightOrder = rightLayout and rightLayout.order or math.huge
		if leftOrder ~= rightOrder then return leftOrder < rightOrder end
		return left.name < right.name
	end)

	local iconSize = ICON_SIZE * (frame.iconScale or 1)
	local iconPadding = frame.iconPadding or ICON_SPACING
	local horizontal = not Enum or not Enum.CooldownViewerOrientation or frame.orientationSetting == nil or frame.orientationSetting == Enum.CooldownViewerOrientation.Horizontal
	local forward
	if horizontal then
		forward = not Enum or not Enum.CooldownViewerIconDirection or frame.iconDirection == nil or frame.iconDirection == Enum.CooldownViewerIconDirection.Right
	else
		forward = Enum and Enum.CooldownViewerIconDirection and frame.iconDirection == Enum.CooldownViewerIconDirection.Left
	end
	for index, entry in ipairs(entries) do
		local icon = frame.icons[index] or CreateReminderIcon(frame, index)
		icon:SetSize(iconSize, iconSize)
		icon:ClearAllPoints()
		local offset = FRAME_PADDING + (index - 1) * (iconSize + iconPadding)
		if horizontal then
			icon:SetPoint(forward and "LEFT" or "RIGHT", frame, forward and "LEFT" or "RIGHT", forward and offset or -offset, 0)
		else
			icon:SetPoint(forward and "TOP" or "BOTTOM", frame, forward and "TOP" or "BOTTOM", 0, forward and -offset or offset)
		end
		icon.Texture:SetTexture(entry.iconID)
		icon.Texture:SetDesaturated(editModeActive and presenceCache[entry.spellID] == true)
		icon.Texture:SetAlpha(editModeActive and presenceCache[entry.spellID] == true and 0.5 or 1)
		icon.spellID = entry.spellID
		icon:Show()
	end

	for index = #entries + 1, #frame.icons do
		frame.icons[index]:Hide()
	end

	local extent = #entries > 0 and FRAME_PADDING * 2 + #entries * iconSize + (#entries - 1) * iconPadding or 180
	frame:SetSize(horizontal and extent or iconSize + FRAME_PADDING * 2, horizontal and iconSize + FRAME_PADDING * 2 or extent)
	if frame.Label then frame.Label:SetShown(editModeActive and #entries == 0) end
	if frame.SetBackdropColor then frame:SetBackdropColor(0.05, 0.15, 0.25, editModeActive and 0.65 or 0) end
	if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.2, 0.65, 1, editModeActive and 1 or 0) end
	if not frame.Selection then frame:EnableMouse(editModeActive) end
	local visibleSetting = frame.visibleSetting
	local visible = #entries > 0
	if Enum and Enum.CooldownViewerVisibleSetting and visibleSetting == Enum.CooldownViewerVisibleSetting.InCombat then
		visible = visible and InCombatLockdown()
	elseif Enum and Enum.CooldownViewerVisibleSetting and visibleSetting == Enum.CooldownViewerVisibleSetting.Hidden then
		visible = false
	end
	frame:SetShown(editModeActive or visible)
end

function CooldownManagerUtils:ScheduleReminderUpdate()
	if updatePending then return end
	updatePending = true
	C_Timer.After(0, function()
		updatePending = false
		CooldownManagerUtils:UpdateReminderBar()
	end)
end

local function SetEditModeActive(active)
	editModeActive = active
	CooldownManagerUtils:UpdateReminderBar()
	if reminderFrame and reminderFrame.Selection then
		if active then
			RefreshSnapTargets()
			reminderFrame:HighlightSystem()
		else
			wipe(snapTargets)
			if reminderOptionsFrame then reminderOptionsFrame:Hide() end
			reminderFrame:ClearHighlight()
			reminderFrame:StopMovingOrSizing()
		end
	end
end

function CooldownManagerUtils:Initialize()
	if not IsSupportedClient() then return end
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	self:CreateReminderBar()
	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Enter", function() SetEditModeActive(true) end, self)
		EventRegistry:RegisterCallback("EditMode.Exit", function() SetEditModeActive(false) end, self)
	end

	self:InitializeReminderSettings()
	self:RefreshAvailableBuffs()
	self:UpdateReminderBar()
end

if IsSupportedClient() then
	eventFrame:RegisterEvent("PLAYER_LOGIN")
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
	eventFrame:RegisterEvent("SPELLS_CHANGED")
	eventFrame:RegisterEvent("UNIT_AURA")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
	eventFrame:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		CooldownManagerUtils:Initialize()
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "player" then CooldownManagerUtils:ScheduleReminderUpdate() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if CooldownManagerUtils.pendingSourceRefresh then CooldownManagerUtils:RefreshAvailableBuffs() end
		CooldownManagerUtils:ScheduleReminderUpdate()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" then
		CooldownManagerUtils:ScheduleReminderUpdate()
	else
		CooldownManagerUtils:RefreshAvailableBuffs()
	end
end)
