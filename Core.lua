local _, CooldownManagerUtils = ...
CooldownManagerUtils:SetAddonOutput("CooldownManagerUtils", 134376)
local ICON_SIZE = 40
local ICON_SPACING = 4
local FRAME_PADDING = 6
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
local editModeActive = false
local updatePending = false
local presenceCache = {}
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
		frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 0, position.y or -180)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
	end
end

local function SavePosition(frame)
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	CooldownManagerUtilsDB.position = {
		point = point,
		relativePoint = relativePoint,
		x = x,
		y = y
	}
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
		if not self.spellID then return end
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
	local frame = CreateFrame("Frame", "CooldownManagerUtilsReminderFrame", UIParent, "BackdropTemplate")
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2
	})

	frame:SetBackdropColor(0, 0, 0, 0)
	frame:SetBackdropBorderColor(0.2, 0.6, 1, 0)
	frame.icons = {}
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
	reminderFrame = frame
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

	for index, entry in ipairs(entries) do
		local icon = frame.icons[index] or CreateReminderIcon(frame, index)
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", frame, "LEFT", FRAME_PADDING + (index - 1) * (ICON_SIZE + ICON_SPACING), 0)
		icon.Texture:SetTexture(entry.iconID)
		icon.Texture:SetDesaturated(editModeActive and presenceCache[entry.spellID] == true)
		icon.Texture:SetAlpha(editModeActive and presenceCache[entry.spellID] == true and 0.5 or 1)
		icon.spellID = entry.spellID
		icon:Show()
	end

	for index = #entries + 1, #frame.icons do
		frame.icons[index]:Hide()
	end

	local width = #entries > 0 and FRAME_PADDING * 2 + #entries * ICON_SIZE + (#entries - 1) * ICON_SPACING or 180
	frame:SetSize(width, ICON_SIZE + FRAME_PADDING * 2)
	frame.Label:SetShown(editModeActive and #entries == 0)
	frame:SetBackdropColor(0.05, 0.15, 0.25, editModeActive and 0.65 or 0)
	frame:SetBackdropBorderColor(0.2, 0.65, 1, editModeActive and 1 or 0)
	frame:EnableMouse(editModeActive)
	frame:SetShown(editModeActive or #entries > 0)
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
end

function CooldownManagerUtils:Initialize()
	if not IsSupportedClient() then return end
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	self:CreateReminderBar()
	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Enter", function() SetEditModeActive(true) end, self)
		EventRegistry:RegisterCallback("EditMode.Exit", function() SetEditModeActive(false) end, self)
	end

	if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive then editModeActive = EditModeManagerFrame:IsEditModeActive() == true end
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
	elseif event == "PLAYER_ENTERING_WORLD" then
		CooldownManagerUtils:ScheduleReminderUpdate()
	else
		CooldownManagerUtils:RefreshAvailableBuffs()
	end
end)
