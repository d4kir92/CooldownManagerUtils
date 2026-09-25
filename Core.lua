local _, CooldownManagerUtils = ...
CooldownManagerUtils:SetAddonOutput("CooldownManagerUtils", 134376)
local ICON_SIZE = 40
local ICON_SPACING = 4
local ICON_SCALE_MIN = 50
local ICON_SCALE_MAX = 400
local ICON_COUNTDOWN_FONT = "GameFontHighlightHugeOutline"
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
local snapTargetLookup = {}
local snapPreviewFrame
local snapScanFrame
local snapScanCursor
local SNAP_DISTANCE = 8
local SNAP_CORNER_DISTANCE_SQ = SNAP_DISTANCE * SNAP_DISTANCE * 2
local SNAP_SELECTION_PADDING = 2
local SNAP_LINE_WIDTH = 1.5
local snapExclusions = {}
local snapSidesCache = setmetatable({}, {__mode = "k"})
local topLevelParent = {}
local SNAP_CORNER_POINTS = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
local SNAP_DIAGONAL_CORNERS = {TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT"}
local reminderSettingDefaults = {
	orientation = 0,
	iconDirection = 1,
	iconSize = 100,
	iconPadding = ICON_SPACING,
	opacity = 100,
	visibleSetting = 0,
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
		if position.relativeSelection and relativeTo.Selection then
			frame.snapTarget = relativeTo
			relativeTo = relativeTo.Selection
		end
		frame:SetPoint(position.point or "CENTER", relativeTo, position.relativePoint or "CENTER", position.x or DEFAULT_REMINDER_X, position.y or DEFAULT_REMINDER_Y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_REMINDER_X, DEFAULT_REMINDER_Y)
	end
end

local function SavePosition(frame)
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	local relativeName = relativeTo and relativeTo ~= UIParent and relativeTo:GetName() or nil
	local relativeSelection
	if frame.snapTarget and relativeTo == frame.snapTarget.Selection then
		relativeName = frame.snapTarget:GetName()
		relativeSelection = relativeName and true or nil
	end
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
		relativeSelection = relativeSelection,
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
	settings.hideWhenInactive = nil
	settings.iconSize = math.min(math.max(settings.iconSize, ICON_SCALE_MIN), ICON_SCALE_MAX)
	return settings
end

local function ApplyReminderSettings(frame)
	local settings = GetReminderSettings()
	frame.orientationSetting = settings.orientation
	frame.iconDirection = settings.iconDirection
	frame.iconScale = settings.iconSize / 100
	frame.iconPadding = settings.iconPadding
	frame.visibleSetting = settings.visibleSetting
	frame.showTimer = settings.showTimer == 1
	frame.showTooltips = settings.showTooltips == 1
	frame:SetAlpha(settings.opacity / 100)
	CooldownManagerUtils:UpdateReminderBar()
	if reminderOptionsFrame and reminderOptionsFrame:IsShown() and reminderOptionsFrame.Refresh then reminderOptionsFrame:Refresh() end
end

local function IsSnapEnabled()
	return not EditModeManagerFrame or EditModeManagerFrame.snapEnabled ~= false
end

local function GetUIParentScaleFactor(region)
	return region:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function GetScaledSelectionSides(frame)
	local selection = frame and frame.Selection
	if not selection or not selection:IsShown() then return end
	local left, bottom, width, height = selection:GetRect()
	if not left then return end
	local factor = GetUIParentScaleFactor(selection)
	local sides = snapSidesCache[frame]
	if not sides then
		sides = {}
		snapSidesCache[frame] = sides
	end
	sides.left = left * factor
	sides.right = (left + width) * factor
	sides.bottom = bottom * factor
	sides.top = (bottom + height) * factor
	sides.centerX = (sides.left + sides.right) / 2
	sides.centerY = (sides.bottom + sides.top) / 2
	return sides
end

local function UpdateTopLevelParent()
	local left, bottom, width, height = UIParent:GetRect()
	topLevelParent.left = left
	topLevelParent.bottom = bottom
	topLevelParent.width = width
	topLevelParent.height = height
	topLevelParent.right = left + width
	topLevelParent.top = bottom + height
	topLevelParent.centerX, topLevelParent.centerY = UIParent:GetCenter()
end

local function IsRegionAnchoredTo(region, anchor, depth)
	if depth > 20 then return false end
	for index = 1, region:GetNumPoints() do
		local _, relativeTo = region:GetPoint(index)
		if not relativeTo then return false end
		if relativeTo == anchor then return true end
		local forbidden = relativeTo.IsForbidden and relativeTo:IsForbidden()
		if not forbidden and IsRegionAnchoredTo(relativeTo, anchor, depth + 1) then return true end
	end
	return false
end

local function IsMagneticTarget(frame, target)
	if target == frame then return false end
	local forbidden = target.IsForbidden and target:IsForbidden()
	if forbidden or not target:IsVisible() then return false end
	local excluded = snapExclusions[target]
	if excluded == nil then
		excluded = IsRegionAnchoredTo(target, frame, 0)
		snapExclusions[target] = excluded
	end
	return not excluded
end

local function GetGridLines(verticalLines)
	local gridLines = EditModeMagnetismManager and EditModeMagnetismManager.magneticGridLines
	if type(gridLines) ~= "table" then return end
	return verticalLines and gridLines.vertical or gridLines.horizontal
end

local function FindClosestGridLine(sides, verticalLines)
	local parent = topLevelParent
	local checkPoints
	if verticalLines then
		checkPoints = {
			{"LEFT", "LEFT", sides.left, parent.left},
			{"RIGHT", "RIGHT", sides.right, parent.right},
			{"CENTER", "CENTER", sides.centerX, parent.centerX},
			{"LEFT", "CENTER", sides.left, parent.centerX},
			{"RIGHT", "CENTER", sides.right, parent.centerX}
		}
	else
		checkPoints = {
			{"TOP", "TOP", sides.top, parent.top},
			{"BOTTOM", "BOTTOM", sides.bottom, parent.bottom},
			{"CENTER", "CENTER", sides.centerY, parent.centerY},
			{"TOP", "CENTER", sides.top, parent.centerY},
			{"BOTTOM", "CENTER", sides.bottom, parent.centerY}
		}
	end
	local closestDistance, closestPoint, closestRelativePoint
	local closestOffset = 0
	for _, checkPoint in ipairs(checkPoints) do
		local distance = math.abs(checkPoint[4] - checkPoint[3])
		if not closestDistance or distance < closestDistance then
			closestDistance, closestPoint, closestRelativePoint = distance, checkPoint[1], checkPoint[2]
		end
	end
	local gridLines = GetGridLines(verticalLines)
	if gridLines then
		for _, gridLineOffset in pairs(gridLines) do
			if type(gridLineOffset) == "number" then
				for index = 1, 3 do
					local checkPoint = checkPoints[index]
					local distance = math.abs(gridLineOffset - checkPoint[3])
					if distance < closestDistance then
						closestDistance, closestPoint, closestRelativePoint = distance, checkPoint[1], checkPoint[1]
						if closestPoint == "TOP" then
							closestOffset = gridLineOffset - parent.top
						elseif closestPoint == "RIGHT" then
							closestOffset = gridLineOffset - parent.right
						elseif closestPoint == "CENTER" then
							closestOffset = gridLineOffset - (verticalLines and parent.centerX or parent.centerY)
						else
							closestOffset = gridLineOffset
						end
					end
				end
			end
		end
	end
	return closestDistance, closestPoint, closestRelativePoint, closestOffset
end

local function CheckReplaceMagneticFrameInfo(current, target, sides, point, relativePoint, distance, offset, isHorizontal)
	local scaledDistance = distance * UIParent:GetEffectiveScale()
	if scaledDistance > SNAP_DISTANCE then return current end
	if not current or scaledDistance < current.distance then
		return {target = target, sides = sides, point = point, relativePoint = relativePoint, distance = scaledDistance, offset = offset, isHorizontal = isHorizontal}
	end
	return current
end

local function GetCornerPosition(sides, corner)
	local x = corner:find("LEFT") and sides.left or sides.right
	local y = corner:find("TOP") and sides.top or sides.bottom
	return x, y
end

local function GetCornerMagneticFrameInfo(sides, relativeInfo)
	if not relativeInfo then return end
	local relativeSides = relativeInfo.sides
	local closestPoint, closestRelativePoint, closestSqrDistance
	for _, point in ipairs(SNAP_CORNER_POINTS) do
		local x, y = GetCornerPosition(sides, point)
		for _, relativePoint in ipairs(SNAP_CORNER_POINTS) do
			if SNAP_DIAGONAL_CORNERS[point] ~= relativePoint then
				local relativeX, relativeY = GetCornerPosition(relativeSides, relativePoint)
				local sqrDistance = (x - relativeX) * (x - relativeX) + (y - relativeY) * (y - relativeY)
				if sqrDistance <= SNAP_CORNER_DISTANCE_SQ and (not closestSqrDistance or sqrDistance < closestSqrDistance) then
					closestPoint, closestRelativePoint, closestSqrDistance = point, relativePoint, sqrDistance
				end
			end
		end
	end
	if not closestSqrDistance then return end
	return {target = relativeInfo.target, sides = relativeSides, point = closestPoint, relativePoint = closestRelativePoint, distance = math.sqrt(closestSqrDistance), offset = 0, isHorizontal = relativeInfo.isHorizontal, isCornerSnap = true}
end

local function GetMagneticFrameInfos(frame)
	local sides = GetScaledSelectionSides(frame)
	if not sides then return end
	UpdateTopLevelParent()
	local distance, point, relativePoint, offset = FindClosestGridLine(sides, true)
	local horizontalInfo = CheckReplaceMagneticFrameInfo(nil, UIParent, nil, point, relativePoint, distance, offset, true)
	distance, point, relativePoint, offset = FindClosestGridLine(sides, false)
	local verticalInfo = CheckReplaceMagneticFrameInfo(nil, UIParent, nil, point, relativePoint, distance, offset, false)
	local horizontalCornerInfo, verticalCornerInfo
	for _, target in ipairs(snapTargets) do
		if IsMagneticTarget(frame, target) then
			local targetSides = GetScaledSelectionSides(target)
			if targetSides then
				local verticallyAligned = sides.top >= targetSides.bottom and sides.bottom <= targetSides.top
				local horizontallyAligned = sides.right >= targetSides.left and sides.left <= targetSides.right
				if verticallyAligned and (sides.right < targetSides.left or sides.left > targetSides.right) then
					if targetSides.right < sides.left then
						distance, point, relativePoint = sides.left - targetSides.right, "LEFT", "RIGHT"
					else
						distance, point, relativePoint = targetSides.left - sides.right, "RIGHT", "LEFT"
					end
					horizontalInfo = CheckReplaceMagneticFrameInfo(horizontalInfo, target, targetSides, point, relativePoint, distance, 0, true)
					horizontalCornerInfo = CheckReplaceMagneticFrameInfo(horizontalCornerInfo, target, targetSides, point, relativePoint, distance, 0, true)
				end
				if horizontallyAligned and (sides.bottom > targetSides.top or sides.top < targetSides.bottom) then
					if targetSides.bottom > sides.top then
						distance, point, relativePoint = targetSides.bottom - sides.top, "TOP", "BOTTOM"
					else
						distance, point, relativePoint = sides.bottom - targetSides.top, "BOTTOM", "TOP"
					end
					verticalInfo = CheckReplaceMagneticFrameInfo(verticalInfo, target, targetSides, point, relativePoint, distance, 0, false)
					verticalCornerInfo = CheckReplaceMagneticFrameInfo(verticalCornerInfo, target, targetSides, point, relativePoint, distance, 0, false)
				end
			end
		end
	end
	local horizontalCorner = GetCornerMagneticFrameInfo(sides, horizontalCornerInfo)
	local verticalCorner = GetCornerMagneticFrameInfo(sides, verticalCornerInfo)
	if horizontalCorner and (not verticalCorner or horizontalCorner.distance < verticalCorner.distance) then
		return {horizontalCorner}
	elseif verticalCorner then
		return {verticalCorner}
	elseif horizontalInfo and horizontalInfo.target == UIParent and verticalInfo and verticalInfo.target == UIParent then
		return {horizontalInfo, verticalInfo}
	elseif horizontalInfo and (not verticalInfo or horizontalInfo.distance < verticalInfo.distance) then
		return {horizontalInfo}
	elseif verticalInfo then
		return {verticalInfo}
	end
end

local function GetPreviewLineAnchors(info)
	local relativePoint = info.relativePoint
	if relativePoint:find("CENTER") then
		return {info.isHorizontal and "CenterVertical" or "CenterHorizontal"}
	end
	local anchors = {}
	if relativePoint:find("TOP") then table.insert(anchors, "Top") end
	if relativePoint:find("BOTTOM") then table.insert(anchors, "Bottom") end
	if relativePoint:find("LEFT") then table.insert(anchors, "Left") end
	if relativePoint:find("RIGHT") then table.insert(anchors, "Right") end
	return anchors
end

local function SetupPreviewLine(line, info, lineAnchor)
	local parent = topLevelParent
	local offsetX, offsetY = 0, 0
	if info.target == UIParent then
		if lineAnchor == "CenterHorizontal" then
			offsetY = info.offset
		elseif lineAnchor == "CenterVertical" then
			offsetX = info.offset
		elseif lineAnchor == "Top" then
			offsetY = parent.height + info.offset - parent.centerY
		elseif lineAnchor == "Bottom" then
			offsetY = info.offset - parent.centerY
		elseif lineAnchor == "Right" then
			offsetX = parent.width + info.offset - parent.centerX
		else
			offsetX = info.offset - parent.centerX
		end
	else
		local sides = info.sides
		if lineAnchor == "Top" then
			offsetY = sides.top - parent.centerY
		elseif lineAnchor == "Bottom" then
			offsetY = sides.bottom - parent.centerY
		elseif lineAnchor == "CenterHorizontal" then
			offsetY = sides.centerY - parent.centerY
		elseif lineAnchor == "Left" then
			offsetX = sides.left - parent.centerX
		elseif lineAnchor == "Right" then
			offsetX = sides.right - parent.centerX
		else
			offsetX = sides.centerX - parent.centerX
		end
	end
	line:ClearAllPoints()
	if lineAnchor == "Top" or lineAnchor == "Bottom" or lineAnchor == "CenterHorizontal" then
		line:SetStartPoint("LEFT", UIParent, offsetX, offsetY)
		line:SetEndPoint("RIGHT", UIParent, offsetX, offsetY)
	else
		line:SetStartPoint("TOP", UIParent, offsetX, offsetY)
		line:SetEndPoint("BOTTOM", UIParent, offsetX, offsetY)
	end
	line:SetThickness(PixelUtil.GetNearestPixelSize(SNAP_LINE_WIDTH, line:GetEffectiveScale(), SNAP_LINE_WIDTH))
	line:Show()
end

local function GetSnapPreviewFrame()
	if snapPreviewFrame then return snapPreviewFrame end
	local preview = CreateFrame("Frame", nil, UIParent)
	preview:SetPoint("TOPLEFT", UIParent)
	preview:SetPoint("BOTTOMRIGHT", UIParent)
	preview:SetFrameStrata("HIGH")
	preview:EnableMouse(false)
	preview.Lines = {}
	preview:Hide()
	snapPreviewFrame = preview
	return preview
end

local function UpdateSnapPreview(frame)
	local preview = GetSnapPreviewFrame()
	local infos = IsSnapEnabled() and GetMagneticFrameInfos(frame)
	local count = 0
	if infos then
		for _, info in ipairs(infos) do
			for _, lineAnchor in ipairs(GetPreviewLineAnchors(info)) do
				count = count + 1
				local line = preview.Lines[count]
				if not line then
					line = preview:CreateLine()
					line:SetColorTexture(1, 0, 0, 1)
					preview.Lines[count] = line
				end
				SetupPreviewLine(line, info, lineAnchor)
			end
		end
	end
	for index = count + 1, #preview.Lines do
		preview.Lines[index]:Hide()
	end
	preview:SetShown(count > 0)
end

local function HideSnapPreview()
	if snapPreviewFrame then snapPreviewFrame:Hide() end
end

local function GetSelectionPadding(point, forYOffset, factor)
	if forYOffset then
		if point:find("TOP") then return SNAP_SELECTION_PADDING * factor end
		if point:find("BOTTOM") then return -SNAP_SELECTION_PADDING * factor end
	else
		if point:find("LEFT") then return -SNAP_SELECTION_PADDING * factor end
		if point:find("RIGHT") then return SNAP_SELECTION_PADDING * factor end
	end
	return 0
end

local function GetCombinedSelectionOffset(frame, info, forYOffset)
	local factor = GetUIParentScaleFactor(frame)
	local offset = info.offset - GetSelectionPadding(info.point, forYOffset, factor)
	if info.target ~= UIParent then
		offset = offset + GetSelectionPadding(info.relativePoint, forYOffset, GetUIParentScaleFactor(info.target.Selection))
	end
	return offset / factor
end

local function GetCombinedCenterOffset(frame, relativeRegion)
	local factor = GetUIParentScaleFactor(frame)
	local relativeFactor = GetUIParentScaleFactor(relativeRegion)
	local centerX, centerY = frame:GetCenter()
	local relativeX, relativeY = relativeRegion:GetCenter()
	return (centerX * factor - relativeX * relativeFactor) / factor, (centerY * factor - relativeY * relativeFactor) / factor
end

local function SnapToMagneticFrame(frame, info)
	local relativeRegion = info.target == UIParent and UIParent or info.target.Selection
	local offsetX, offsetY
	if info.isCornerSnap then
		offsetX = GetCombinedSelectionOffset(frame, info, false)
		offsetY = GetCombinedSelectionOffset(frame, info, true)
	else
		offsetX, offsetY = GetCombinedCenterOffset(frame, relativeRegion)
		if info.isHorizontal then
			offsetX = GetCombinedSelectionOffset(frame, info, false)
		else
			offsetY = GetCombinedSelectionOffset(frame, info, true)
		end
	end
	frame:ClearAllPoints()
	frame:SetPoint(info.point, relativeRegion, info.relativePoint, offsetX, offsetY)
	frame.snapTarget = info.target ~= UIParent and info.target or nil
end

local function ApplyMagnetism(frame)
	if not IsSnapEnabled() then return end
	local infos = GetMagneticFrameInfos(frame)
	if not infos then return end
	for _, info in ipairs(infos) do
		SnapToMagneticFrame(frame, info)
	end
end

local function AddSnapTarget(target)
	if not target or target == reminderFrame or snapTargetLookup[target] then return end
	local forbidden = target.IsForbidden and target:IsForbidden()
	if forbidden or type(target.Selection) ~= "table" or not target.Selection.ShowHighlighted then return end
	snapTargetLookup[target] = true
	table.insert(snapTargets, target)
end

local function StopSnapTargetScan()
	if snapScanFrame then snapScanFrame:SetScript("OnUpdate", nil) end
	snapScanCursor = nil
end

local function RefreshSnapTargets()
	StopSnapTargetScan()
	wipe(snapTargets)
	wipe(snapTargetLookup)
	local children = {UIParent:GetChildren()}
	for _, target in ipairs(children) do AddSnapTarget(target) end
	if type(EnumerateFrames) ~= "function" then return end
	if not snapScanFrame then snapScanFrame = CreateFrame("Frame") end
	snapScanCursor = nil
	snapScanFrame:SetScript("OnUpdate", function(self)
		local started = debugprofilestop()
		repeat
			snapScanCursor = EnumerateFrames(snapScanCursor)
			if not snapScanCursor then
				self:SetScript("OnUpdate", nil)
				return
			end
			AddSnapTarget(snapScanCursor)
		until debugprofilestop() - started >= 1.5
	end)
	for _ = 1, 50 do
		snapScanCursor = EnumerateFrames(snapScanCursor)
		if not snapScanCursor then
			StopSnapTargetScan()
			break
		end
		AddSnapTarget(snapScanCursor)
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
	row.Refresh = function(self) self.Dropdown:GenerateMenu() end
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
		showTimer = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_SHOW_TIMER or "Show timer",
		showTooltips = _G.HUD_EDIT_MODE_SETTING_COOLDOWN_VIEWER_SHOW_TOOLTIPS or "Show tooltips"
	}
	table.insert(panel.controls, CreateDropdownSetting(panel.Settings, 1, labels.orientation, "orientation", orientationValues, OrientationText))
	table.insert(panel.controls, CreateDropdownSetting(panel.Settings, 2, labels.direction, "iconDirection", directionValues, DirectionText))
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 3, labels.size, "iconSize", ICON_SCALE_MIN, ICON_SCALE_MAX, 10, "%"))
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 4, labels.padding, "iconPadding", 0, 14, 1, ""))
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 5, labels.opacity, "opacity", 50, 100, 1, "%"))
	table.insert(panel.controls, CreateDropdownSetting(panel.Settings, 6, labels.visibility, "visibleSetting", visibilityValues, VisibilityText))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 7, labels.showTimer, "showTimer"))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 8, labels.showTooltips, "showTooltips"))
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
		self.snapTarget = nil
		wipe(snapExclusions)
		self:StartMoving()
		self.isDragging = true
		self:SetScript("OnUpdate", UpdateSnapPreview)
	end
	frame.OnDragStop = function(self)
		if not self.isDragging then return end
		self:SetScript("OnUpdate", nil)
		HideSnapPreview()
		self:StopMovingOrSizing()
		self.isDragging = false
		ApplyMagnetism(self)
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
	icon:SetMouseClickEnabled(false)
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
	icon.Cooldown = CreateFrame("Cooldown", nil, icon)
	icon.Cooldown:SetAllPoints()
	icon.Cooldown:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe")
	icon.Cooldown:SetEdgeTexture("Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown")
	icon.Cooldown:SetSwipeColor(0, 0, 0, 0.7)
	icon.Cooldown:SetDrawSwipe(true)
	icon.Cooldown:SetDrawEdge(false)
	if _G[ICON_COUNTDOWN_FONT] and icon.Cooldown.SetCountdownFont then icon.Cooldown:SetCountdownFont(ICON_COUNTDOWN_FONT) end
	icon.Cooldown:SetScript("OnCooldownDone", function() CooldownManagerUtils:ScheduleReminderUpdate() end)
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

local function GetSpellCooldownState(spellID)
	if not C_Spell then return false end
	if C_Spell.GetSpellCooldownDuration then
		local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
		if ok and duration and duration.IsZero then
			local zeroOK, isZero = pcall(duration.IsZero, duration)
			if zeroOK and not IsSecret(isZero) then
				if isZero then return false end
				return true, duration
			end
		end
	end
	if not C_Spell.GetSpellCooldown then return false end
	local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
	if not ok or type(info) ~= "table" or info.isOnGCD == true or info.isEnabled == false then return false end
	local startTime, duration = info.startTime, info.duration
	if IsSecret(startTime) or IsSecret(duration) then return info.isActive == true end
	if type(startTime) ~= "number" or type(duration) ~= "number" or startTime <= 0 or duration <= 1.5 then return false end
	if startTime + duration <= GetTime() then return false end
	return true, nil, startTime, duration, not IsSecret(info.modRate) and info.modRate or 1
end

local function UpdateIconCooldown(icon, spellID, showTimer)
	local cooldown = icon.Cooldown
	cooldown:SetHideCountdownNumbers(not showTimer)
	local onCooldown, durationObject, startTime, duration, modRate = GetSpellCooldownState(spellID)
	if onCooldown and durationObject and cooldown.SetCooldownFromDurationObject then
		cooldown:SetCooldownFromDurationObject(durationObject)
	elseif onCooldown and startTime then
		cooldown:SetCooldown(startTime, duration, modRate or 1)
	else
		cooldown:Clear()
	end
	return onCooldown
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

	local iconScale = frame.iconScale or 1
	local iconSize = ICON_SIZE * iconScale
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
		icon:SetScale(iconScale)
		icon:ClearAllPoints()
		local offset = (FRAME_PADDING + (index - 1) * (iconSize + iconPadding)) / iconScale
		if horizontal then
			icon:SetPoint(forward and "LEFT" or "RIGHT", frame, forward and "LEFT" or "RIGHT", forward and offset or -offset, 0)
		else
			icon:SetPoint(forward and "TOP" or "BOTTOM", frame, forward and "TOP" or "BOTTOM", 0, forward and -offset or offset)
		end
		local previewPresent = editModeActive and presenceCache[entry.spellID] == true
		local onCooldown = UpdateIconCooldown(icon, entry.spellID, frame.showTimer ~= false)
		icon.Texture:SetTexture(entry.iconID)
		icon.Texture:SetDesaturated(previewPresent or onCooldown)
		icon.Texture:SetAlpha(previewPresent and 0.5 or 1)
		icon:SetMouseMotionEnabled(frame.showTooltips ~= false)
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
			StopSnapTargetScan()
			wipe(snapTargets)
			wipe(snapTargetLookup)
			HideSnapPreview()
			if reminderOptionsFrame then reminderOptionsFrame:Hide() end
			reminderFrame:ClearHighlight()
			reminderFrame:SetScript("OnUpdate", nil)
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
	eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
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
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" or event == "SPELL_UPDATE_COOLDOWN" then
		CooldownManagerUtils:ScheduleReminderUpdate()
	else
		CooldownManagerUtils:RefreshAvailableBuffs()
	end
end)
