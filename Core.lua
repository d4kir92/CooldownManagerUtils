local _, CooldownManagerUtils = ...
CooldownManagerUtils:SetAddonOutput("CooldownManagerUtils", 134376)
local ICON_SIZE = 40
local ICON_SPACING = 4
local ICON_SCALE_MIN = 50
local ICON_SCALE_MAX = 400
local ICON_COUNTDOWN_FONT = "GameFontHighlightHugeOutline"
local GROUP_COUNT_FONT_SIZE = 10
local FRAME_PADDING = 6
local DEFAULT_REMINDER_X = 0
local DEFAULT_REMINDER_Y = -180
local REMINDER_CATEGORY_ORDER = {
	expiringBuff = 1,
	trackedBuff = 2,
	hidden = 3
}

local OBSOLETE_REMINDER_SPELLS = {
	[78] = true,
	[284] = true,
	[285] = true,
	[1608] = true,
	[11564] = true,
	[11565] = true,
	[11566] = true,
	[11567] = true,
	[25286] = true,
	[29707] = true,
	[30324] = true,
	[47449] = true,
	[47450] = true
}

local COOLDOWN_AURA_CATEGORIES = {"Essential", "Utility", "TrackedBuff", "TrackedBar", "HiddenActive", "HiddenPassive"}
CooldownManagerUtils.retailProcCategories = {"Essential", "Utility"}
local CLASS_AURA_FALLBACKS = {
	DRUID = {
		{
			spellID = 1126,
			groupBuff = true
		}
	},
	EVOKER = {
		{
			spellID = 364342,
			groupBuff = true
		}
	},
	MAGE = {
		{
			spellID = 1459,
			groupBuff = true
		}
	},
	PRIEST = {
		{
			spellID = 21562,
			groupBuff = true
		}
	},
	SHAMAN = {
		{
			spellID = 462854,
			groupBuff = true
		}
	},
	WARRIOR = {
		{
			spellID = 6673,
			groupBuff = true
		},
		{
			spellID = 97462,
			auraSpellID = 97463
		}
	}
}

CooldownManagerUtils.foreverBattleShoutSpecs = {
	[66] = true,
	[70] = true,
	[71] = true,
	[72] = true,
	[73] = true,
	[103] = true,
	[104] = true,
	[250] = true,
	[251] = true,
	[252] = true,
	[259] = true,
	[260] = true,
	[261] = true,
	[263] = true,
	[268] = true,
	[269] = true,
	[577] = true,
	[581] = true
}

CooldownManagerUtils.foreverBattleShoutFallbackClasses = {
	ROGUE = true,
	WARRIOR = true
}

local RACIAL_AURA_FALLBACKS = {
	{
		spellID = 20594
	},
	{
		spellID = 20600
	},
	{
		spellID = 20580
	},
	{
		spellID = 58984
	},
	{
		spellID = 20572
	},
	{
		spellID = 33697
	},
	{
		spellID = 33702
	},
	{
		spellID = 26297
	},
	{
		spellID = 20577
	},
	{
		spellID = 20589,
		foreverOnly = true
	},
	{
		spellID = 28880
	},
	{
		spellID = 59542
	},
	{
		spellID = 59543
	},
	{
		spellID = 59544
	},
	{
		spellID = 59545
	},
	{
		spellID = 59547
	},
	{
		spellID = 59548
	},
	{
		spellID = 68992
	},
	{
		spellID = 265221
	},
	{
		spellID = 274738
	},
	{
		spellID = 291944
	},
	{
		spellID = 1259799
	},
	{
		spellID = 1299026
	},
	{
		spellID = 1260270
	},
	{
		spellID = 1259812
	},
	{
		spellID = 1259813
	},
	{
		spellID = 1259817
	},
	{
		spellID = 1259821
	},
	{
		spellID = 1259823
	},
	{
		spellID = 1259416,
		auraSpellIDs = {1308663}
	},
	{
		spellID = 1259705,
		auraSpellIDs = {1270842}
	},
	{
		spellID = 1259686,
		auraSpellIDs = {1259688, 1270893}
	}
}

local WEAPON_ENCHANT_FAMILIES = {
	PALADIN = {
		{
			spells = {433568},
			enchants = {7143}
		},
		{
			spells = {433583},
			enchants = {7144}
		}
	},
	SHAMAN = {
		{
			spells = {8017, 8018, 8019, 10399, 16314, 16315, 16316, 25479, 25485},
			enchants = {29, 6, 1, 503, 1663, 683, 1664}
		},
		{
			spells = {8024, 8027, 8030, 16339, 16341, 16342, 25489, 58785, 58789, 58790},
			enchants = {5, 4, 3, 523, 1665, 1666, 2634, 3779, 3780, 3781}
		},
		{
			spells = {8033, 8038, 10456, 16355, 16356, 25500, 58794, 58795, 58796},
			enchants = {2, 12, 524, 1667, 1668, 2635, 3782, 3783, 3784}
		},
		{
			spells = {8232, 8235, 10486, 16362, 25505, 58801, 58803, 58804},
			enchants = {283, 284, 525, 1669, 2636, 3785, 3786, 3787}
		},
		{
			spells = {51730, 51988, 51991, 51992, 51993, 51994},
			enchants = {3345, 3346, 3347, 3348, 3349, 3350}
		},
		{
			spells = {318038}
		},
		{
			spells = {33757}
		},
		{
			spells = {382021}
		},
		{
			spells = {457481},
			shield = true
		},
		{
			spells = {462757},
			shield = true
		}
	}
}

local HIT_CHARGE_AURAS = {
	DRUID = {
		{
			spells = {16689, 16810, 16811, 16812, 16813, 17329, 27009, 53312},
			lockout = 1,
			schoolMask = 1
		}
	},
	SHAMAN = {
		{
			spells = {324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281},
			lockout = 3.5,
			castCharges = 3
		},
		{
			spells = {52127, 52129, 52131, 52134, 52136, 52138, 24398, 33736, 57960, 408510},
			lockout = 3.5,
			castCharges = 3,
			healCrit = true
		}
	}
}

CooldownManagerUtils.foreverReactiveAbilityFamilies = {
	WARRIOR = {
		{
			spells = {7384, 7887, 11584, 11585}
		},
		{
			spells = {6572, 6574, 7379, 11600, 11601, 25288, 25269, 30357, 57823}
		}
	},
	ROGUE = {
		{
			spells = {14251}
		}
	},
	HUNTER = {
		{
			spells = {1495, 14269, 14270, 14271, 36916, 53339}
		},
		{
			spells = {19306, 20909, 20910, 27067, 48998, 48999}
		}
	}
}

local MINIMAP_TRACKING_SPELLS = {
	[2481] = true,
	[2383] = true,
	[2580] = true,
	[8387] = true,
	[8388] = true,
	[43308] = true,
	[1494] = true,
	[19878] = true,
	[19879] = true,
	[19880] = true,
	[19882] = true,
	[19883] = true,
	[19884] = true,
	[19885] = true,
	[229533] = true
}

local PALADIN_BLESSING_FAMILIES = {
	{
		spells = {19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932}
	},
	{
		spells = {25782, 25916, 27141, 48933, 48934}
	},
	{
		spells = {19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936}
	},
	{
		spells = {25894, 25918, 27143, 48937, 48938}
	},
	{
		spells = {20217}
	},
	{
		spells = {25898}
	},
	{
		spells = {20911, 20912, 20913, 20914, 27168}
	},
	{
		spells = {25899}
	},
	{
		spells = {1038}
	},
	{
		spells = {25895}
	},
	{
		spells = {19977, 19978, 19979, 27144, 32770}
	},
	{
		spells = {25890}
	}
}

local PALADIN_OTHER_BLESSING_AURA_SPELLS = {1022, 1044, 5599, 6940, 10278, 20729, 27147, 27148, 48949, 48950}
local PALADIN_SEAL_FAMILIES = {
	{
		spells = {21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293}
	},
	{
		spells = {21082, 20162, 20305, 20306, 20307, 20308}
	},
	{
		spells = {20164}
	},
	{
		spells = {20165, 20347, 20348, 20349}
	},
	{
		spells = {20166, 20356, 20357}
	},
	{
		spells = {20375, 20915, 20918, 20919, 20920}
	},
	{
		spells = {1311649, 1311656, 20163, 20419, 20421, 20422, 20423}
	}
}

local HUNTER_ASPECT_FAMILIES = {
	{
		spells = {13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044}
	},
	{
		spells = {13163}
	},
	{
		spells = {5118}
	},
	{
		spells = {13159}
	},
	{
		spells = {13161, 1299445, 1299446, 1299447}
	},
	{
		spells = {20043, 20190, 27045, 49071}
	},
	{
		spells = {34074, 415423}
	},
	{
		spells = {61846, 61847}
	},
	{
		spells = {469145}
	}
}

local TIMING = {
	WEAPON_ENCHANT_LEARN_WINDOW = 0.5,
	WEAPON_ENCHANT_LATE_CAST_WINDOW = 0.2,
	WEAPON_ENCHANT_REFRESH_MS = 5000,
	AURA_EXPIRY_GRACE = 0.1,
	GROUP_BUFF_UPDATE_DELAY = 0.5,
	GROUP_BUFF_REFRESH_INTERVAL = 2
}

local WEAPON_ENCHANT_INVENTORY_SLOTS = {INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17, INVSLOT_RANGED or 18}
local WEAPON_ENCHANT_SLOT_NAMES = {"MainHand", "OffHand", "Ranged"}
local WEAPON_ENCHANT_SLOT_BY_INVENTORY = {
	[INVSLOT_MAINHAND or 16] = "MainHand",
	[INVSLOT_OFFHAND or 17] = "OffHand",
	[INVSLOT_RANGED or 18] = "Ranged"
}

local WEAPON_ENCHANT_REQUIRED_SLOTS = {
	MainHand = INVSLOT_MAINHAND or 16,
	OffHand = INVSLOT_OFFHAND or 17
}

local eventFrame = CreateFrame("Frame")
CooldownManagerUtils.reminderFrames = {}
local reminderOptionsFrame
local editModeActive = false
local updatePending = false
local presenceCache = {}
local groupBuffCache = {}
local groupUpdatePending = false
local auraExpirationCache = {}
local auraChargeCache = {}
local hitChargeAuraBySpell
local availableBuffsByName = {}
local weaponEnchantState = {}
local recentWeaponEnchantChanges = {}
local recentPlayerCasts = {}
local weaponEnchantFallbackNames
local weaponEnchantFamilyBySpell
local paladinBlessingSpellLookup
local paladinBlessingAuraSpells
local paladinSealSpellLookup
local paladinSealAuraSpells
local paladinSealPresent
local paladinSealExpiration
local paladinSealDuration
local hunterAspectSpellLookup
local hunterAspectAuraSpells
local hunterAspectPresent
local hunterAspectExpiration
local hunterAspectDuration
local activeLayoutKey
local activeLayoutData
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
local snapSidesCache = setmetatable({}, {
	__mode = "k"
})

local topLevelParent = {}
local SNAP_CORNER_POINTS = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
local SNAP_DIAGONAL_CORNERS = {
	TOPLEFT = "BOTTOMRIGHT",
	TOPRIGHT = "BOTTOMLEFT",
	BOTTOMLEFT = "TOPRIGHT",
	BOTTOMRIGHT = "TOPLEFT"
}

local reminderSettingDefaults = {
	orientation = 0,
	iconDirection = 1,
	iconSize = 100,
	iconPadding = ICON_SPACING,
	opacity = 100,
	visibleSetting = 0,
	showTimer = 1,
	showTooltips = 1,
	showGlow = 1,
	checkGroupBuffs = 1,
	cooldownDisplayTime = 5
}

local function IsSupportedClient()
	return CooldownManagerUtils:GetWoWBuildNr() >= 120000 or CooldownManagerUtils:IsForever()
end

local function IsSecret(value)
	return CooldownManagerUtils:IsSecret(value)
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

local function GetSpellNameSafe(spellID)
	if type(spellID) ~= "number" then return end
	local spellInfo = GetReminderSpellInfo(spellID)
	local name = spellInfo and spellInfo.name
	if IsSecret(name) or type(name) ~= "string" then return end
	return name
end

function CooldownManagerUtils:HasRetailProcAbilities()
	if self:IsForever() then return false end
	if not C_SpellActivationOverlay or type(C_SpellActivationOverlay.IsSpellOverlayed) ~= "function" then return false end
	return C_CooldownViewer ~= nil and type(C_CooldownViewer.GetCooldownViewerCategorySet) == "function" and type(C_CooldownViewer.GetCooldownViewerCooldownInfo) == "function" and Enum ~= nil and Enum.CooldownViewerCategory ~= nil
end

function CooldownManagerUtils:HasReactiveAbilities()
	if self:HasRetailProcAbilities() then return true end
	if not self:IsForever() then return false end
	local _, class = UnitClass("player")
	return self.foreverReactiveAbilityFamilies[class] ~= nil
end

function CooldownManagerUtils.GetForeverReactiveAbilityFamily(spellID)
	if not CooldownManagerUtils:IsForever() or type(spellID) ~= "number" then return end
	local _, class = UnitClass("player")
	for _, family in ipairs(CooldownManagerUtils.foreverReactiveAbilityFamilies[class] or {}) do
		for _, familySpellID in ipairs(family.spells) do
			if familySpellID == spellID then return family end
		end
	end
end

local function IsPaladinBlessingSpell(spellID)
	if type(spellID) ~= "number" then return false end
	if not paladinBlessingSpellLookup then
		paladinBlessingSpellLookup = {}
		for _, family in ipairs(PALADIN_BLESSING_FAMILIES) do
			for _, familySpellID in ipairs(family.spells) do
				paladinBlessingSpellLookup[familySpellID] = true
			end
		end
	end
	return paladinBlessingSpellLookup[spellID] == true
end

local function GetPaladinBlessingAuraSpells()
	if paladinBlessingAuraSpells then return paladinBlessingAuraSpells end
	local spells = {}
	local seen = {}
	for _, family in ipairs(PALADIN_BLESSING_FAMILIES) do
		for _, spellID in ipairs(family.spells) do
			AddCandidate(spells, seen, spellID)
		end
	end

	for _, spellID in ipairs(PALADIN_OTHER_BLESSING_AURA_SPELLS) do
		AddCandidate(spells, seen, spellID)
	end

	paladinBlessingAuraSpells = spells
	return spells
end

local function IsPaladinSealSpell(spellID)
	if type(spellID) ~= "number" then return false end
	if not paladinSealSpellLookup then
		paladinSealSpellLookup = {}
		for _, family in ipairs(PALADIN_SEAL_FAMILIES) do
			for _, familySpellID in ipairs(family.spells) do
				paladinSealSpellLookup[familySpellID] = true
			end
		end
	end
	return paladinSealSpellLookup[spellID] == true
end

local function GetPaladinSealAuraSpells()
	if paladinSealAuraSpells then return paladinSealAuraSpells end
	local spells = {}
	local seen = {}
	for _, family in ipairs(PALADIN_SEAL_FAMILIES) do
		for _, spellID in ipairs(family.spells) do
			AddCandidate(spells, seen, spellID)
		end
	end

	paladinSealAuraSpells = spells
	return spells
end

local function IsHunterAspectSpell(spellID)
	if type(spellID) ~= "number" then return false end
	if not hunterAspectSpellLookup then
		hunterAspectSpellLookup = {}
		for _, family in ipairs(HUNTER_ASPECT_FAMILIES) do
			for _, familySpellID in ipairs(family.spells) do
				hunterAspectSpellLookup[familySpellID] = true
			end
		end
	end
	return hunterAspectSpellLookup[spellID] == true
end

local function GetHunterAspectAuraSpells()
	if hunterAspectAuraSpells then return hunterAspectAuraSpells end
	local spells = {}
	local seen = {}
	for _, family in ipairs(HUNTER_ASPECT_FAMILIES) do
		for _, spellID in ipairs(family.spells) do
			AddCandidate(spells, seen, spellID)
		end
	end

	hunterAspectAuraSpells = spells
	return spells
end

local function GetLearnedAuras()
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	local learned = CooldownManagerUtilsDB.learnedAuras
	if type(learned) ~= "table" then
		learned = {}
		CooldownManagerUtilsDB.learnedAuras = learned
	end

	learned.spells = learned.spells or {}
	learned.names = learned.names or {}
	learned.durations = learned.durations or {}
	learned.charges = learned.charges or {}
	return learned
end

local function LearnPlayerAura(aura)
	if IsSecret(aura) or type(aura) ~= "table" then return false end
	local spellID, name, sourceUnit, isHelpful = aura.spellId, aura.name, aura.sourceUnit, aura.isHelpful
	if IsSecret(spellID) or IsSecret(name) or IsSecret(sourceUnit) or IsSecret(isHelpful) then return false end
	if isHelpful == false or sourceUnit ~= "player" or type(spellID) ~= "number" or type(name) ~= "string" then return false end
	local learned = GetLearnedAuras()
	if learned.spells[spellID] and learned.names[name] then return false end
	learned.spells[spellID] = true
	learned.names[name] = learned.names[name] or spellID
	return true
end

local function LearnCurrentPlayerAuras()
	if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then return false end
	local changed = false
	for index = 1, 255 do
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
		if not ok or (not IsSecret(aura) and aura == nil) then break end
		if LearnPlayerAura(aura) then changed = true end
	end
	return changed
end

local function IsLearnedBuffSpell(spellID)
	if type(spellID) ~= "number" then return false end
	local learned = GetLearnedAuras()
	if learned.spells[spellID] then return true end
	local name = GetSpellNameSafe(spellID)
	return name ~= nil and learned.names[name] ~= nil
end

local function GetLearnedWeaponEnchants()
	local learned = GetLearnedAuras()
	learned.weaponSpells = learned.weaponSpells or {}
	learned.weaponNames = learned.weaponNames or {}
	return learned
end

local function GetWeaponEnchantFamilies()
	local _, class = UnitClass("player")
	return WEAPON_ENCHANT_FAMILIES[class] or {}
end

local function GetWeaponEnchantFamily(spellID)
	if type(spellID) ~= "number" then return end
	if not weaponEnchantFamilyBySpell then
		weaponEnchantFamilyBySpell = {}
		for _, family in ipairs(GetWeaponEnchantFamilies()) do
			for _, familySpellID in ipairs(family.spells) do
				weaponEnchantFamilyBySpell[familySpellID] = family
			end
		end
	end
	return weaponEnchantFamilyBySpell[spellID]
end

local function GetWeaponEnchantFallbackIDs()
	local spellIDs = {}
	for _, family in ipairs(GetWeaponEnchantFamilies()) do
		for _, spellID in ipairs(family.spells) do
			table.insert(spellIDs, spellID)
		end
	end
	return spellIDs
end

local function GetWeaponEnchantFallbackNames()
	if weaponEnchantFallbackNames then return weaponEnchantFallbackNames end
	local names = {}
	for _, family in ipairs(GetWeaponEnchantFamilies()) do
		local name = GetSpellNameSafe(family.spells[1])
		if name and not names[name] then names[name] = family end
	end

	weaponEnchantFallbackNames = names
	return names
end

local function GetWeaponEnchantCatalogFamily(spellID, spellName)
	local family = GetWeaponEnchantFamily(spellID)
	if family then return family end
	spellName = spellName or GetSpellNameSafe(spellID)
	if spellName then return GetWeaponEnchantFallbackNames()[spellName] end
end

local function IsWeaponEnchantSpell(spellID)
	return GetWeaponEnchantCatalogFamily(spellID) ~= nil
end

local function IsForeignWeaponEnchant(family, enchantID)
	for _, otherFamily in ipairs(GetWeaponEnchantFamilies()) do
		if otherFamily ~= family then
			for _, otherEnchantID in ipairs(otherFamily.enchants or {}) do
				if otherEnchantID == enchantID then return true end
			end
		end
	end
	return false
end

local function AddTemporaryWeaponEnchant(enchants, slot, enchantID, remaining)
	if IsSecret(enchantID) then
		enchants.hasSecret = true
		return
	end

	if type(enchantID) ~= "number" or enchants.slots[slot] then return end
	enchants.slots[slot] = true
	table.insert(enchants, {
		slot = slot,
		enchantID = enchantID,
		remaining = not IsSecret(remaining) and type(remaining) == "number" and remaining or nil
	})
end

local function GetTemporaryWeaponEnchants()
	local enchants = {
		slots = {}
	}

	if C_Item and type(C_Item.GetWeaponEnchantInfo) == "function" and Enum and Enum.WeaponSlot then
		local permanentType = Enum.ItemEnchantType and Enum.ItemEnchantType.Permanent or 1
		for _, slotName in ipairs(WEAPON_ENCHANT_SLOT_NAMES) do
			local slot = Enum.WeaponSlot[slotName]
			if slot ~= nil then
				local ok, list = pcall(C_Item.GetWeaponEnchantInfo, slot)
				if ok and IsSecret(list) then
					enchants.hasSecret = true
				elseif ok and type(list) == "table" then
					for _, info in pairs(list) do
						if type(info) == "table" and info.hasEnchant == true and info.enchantType ~= permanentType then AddTemporaryWeaponEnchant(enchants, slotName, info.enchantID, info.timeLeft) end
					end
				end
			end
		end
	end

	if C_PaperDollInfo and type(C_PaperDollInfo.GetTemporaryEnchantmentInfo) == "function" then
		for _, slot in ipairs(WEAPON_ENCHANT_INVENTORY_SLOTS) do
			local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, slot)
			if ok and IsSecret(info) then
				enchants.hasSecret = true
			elseif ok and type(info) == "table" then
				AddTemporaryWeaponEnchant(enchants, WEAPON_ENCHANT_SLOT_BY_INVENTORY[slot], info.enchantID, info.remainingTimeMs)
			end
		end
	end

	if #enchants == 0 and type(GetWeaponEnchantInfo) == "function" then
		local ok, hasMainHand, mainHandRemaining, _, mainHandID, hasOffHand, offHandRemaining, _, offHandID = pcall(GetWeaponEnchantInfo)
		if ok and (IsSecret(hasMainHand) or IsSecret(hasOffHand)) then
			enchants.hasSecret = true
		else
			if ok and hasMainHand then AddTemporaryWeaponEnchant(enchants, "MainHand", mainHandID, mainHandRemaining) end
			if ok and hasOffHand then AddTemporaryWeaponEnchant(enchants, "OffHand", offHandID, offHandRemaining) end
		end
	end
	return enchants
end

local function RecordWeaponEnchantChanges(silent)
	local now = GetTime()
	local current = GetTemporaryWeaponEnchants()
	if silent then wipe(recentWeaponEnchantChanges) end
	local seenSlots = {}
	for _, enchant in ipairs(current) do
		seenSlots[enchant.slot] = true
		local previous = weaponEnchantState[enchant.slot]
		local changed = not previous or previous.enchantID ~= enchant.enchantID
		if not changed and enchant.remaining and previous.remaining then
			local expected = previous.remaining - (now - previous.time) * 1000
			changed = enchant.remaining - expected > TIMING.WEAPON_ENCHANT_REFRESH_MS
		end

		if changed and not silent then
			table.insert(recentWeaponEnchantChanges, {
				enchantID = enchant.enchantID,
				time = now
			})
		end

		weaponEnchantState[enchant.slot] = {
			enchantID = enchant.enchantID,
			remaining = enchant.remaining,
			time = now
		}
	end

	if current.hasSecret then return end
	for slot in pairs(weaponEnchantState) do
		if not seenSlots[slot] then weaponEnchantState[slot] = nil end
	end
end

local function PruneRecentEvents(list, now)
	for index = #list, 1, -1 do
		if now - list[index].time > TIMING.WEAPON_ENCHANT_LEARN_WINDOW * 2 then table.remove(list, index) end
	end
end

local function PruneLearnedEnchantIDs(list, key, family)
	local enchantIDs = list[key]
	if type(enchantIDs) ~= "table" or not family then
		list[key] = nil
		return
	end

	for enchantID in pairs(enchantIDs) do
		if IsForeignWeaponEnchant(family, enchantID) then enchantIDs[enchantID] = nil end
	end

	if not next(enchantIDs) then list[key] = nil end
end

local function PruneLearnedWeaponEnchants()
	local learned = GetLearnedWeaponEnchants()
	for spellID in pairs(learned.weaponSpells) do
		PruneLearnedEnchantIDs(learned.weaponSpells, spellID, GetWeaponEnchantCatalogFamily(spellID))
	end

	for spellName in pairs(learned.weaponNames) do
		PruneLearnedEnchantIDs(learned.weaponNames, spellName, GetWeaponEnchantFallbackNames()[spellName])
	end
end

local function LearnWeaponEnchant(spellID, spellName, enchantID)
	local family = GetWeaponEnchantCatalogFamily(spellID, spellName)
	if not family or IsForeignWeaponEnchant(family, enchantID) then return false end
	local learned = GetLearnedWeaponEnchants()
	local changed = false
	learned.weaponSpells[spellID] = learned.weaponSpells[spellID] or {}
	if not learned.weaponSpells[spellID][enchantID] then
		learned.weaponSpells[spellID][enchantID] = true
		changed = true
	end

	if spellName then
		learned.weaponNames[spellName] = learned.weaponNames[spellName] or {}
		if not learned.weaponNames[spellName][enchantID] then
			learned.weaponNames[spellName][enchantID] = true
			changed = true
		end
	end
	return changed
end

local function MatchWeaponEnchantLearning()
	local now = GetTime()
	PruneRecentEvents(recentPlayerCasts, now)
	PruneRecentEvents(recentWeaponEnchantChanges, now)
	local learnedNew = false
	for changeIndex = #recentWeaponEnchantChanges, 1, -1 do
		local change = recentWeaponEnchantChanges[changeIndex]
		local bestCast, bestDelta
		for _, cast in ipairs(recentPlayerCasts) do
			local delta = change.time - cast.time
			if delta >= -TIMING.WEAPON_ENCHANT_LATE_CAST_WINDOW and delta <= TIMING.WEAPON_ENCHANT_LEARN_WINDOW and (not bestDelta or math.abs(delta) < bestDelta) then bestCast, bestDelta = cast, math.abs(delta) end
		end

		if bestCast then
			if LearnWeaponEnchant(bestCast.spellID, bestCast.name, change.enchantID) then learnedNew = true end
			table.remove(recentWeaponEnchantChanges, changeIndex)
		end
	end
	return learnedNew
end

local function GetKnownWeaponEnchantIDs()
	local knownEnchantIDs = {}
	for _, family in ipairs(GetWeaponEnchantFamilies()) do
		for _, enchantID in ipairs(family.enchants or {}) do
			knownEnchantIDs[enchantID] = true
		end
	end

	for _, enchantIDs in pairs(GetLearnedWeaponEnchants().weaponSpells) do
		for enchantID in pairs(enchantIDs) do
			knownEnchantIDs[enchantID] = true
		end
	end
	return knownEnchantIDs
end

local function GetEntryWeaponEnchantIDs(entry)
	local learned = GetLearnedWeaponEnchants()
	local enchantIDs = {}
	local function AddSpell(spellID)
		local family = GetWeaponEnchantFamily(spellID)
		for _, enchantID in ipairs(family and family.enchants or {}) do
			enchantIDs[enchantID] = true
		end

		for enchantID in pairs(learned.weaponSpells[spellID] or {}) do
			enchantIDs[enchantID] = true
		end
	end

	AddSpell(entry.spellID)
	for _, candidateSpellID in ipairs(entry.candidates) do
		AddSpell(candidateSpellID)
	end

	for enchantID in pairs(learned.weaponNames[entry.name] or {}) do
		enchantIDs[enchantID] = true
	end
	return enchantIDs
end

local function IsShieldWeaponEnchantEntry(entry)
	local family = GetWeaponEnchantFamily(entry.spellID)
	for _, candidateSpellID in ipairs(entry.candidates) do
		family = family or GetWeaponEnchantFamily(candidateSpellID)
	end
	return family ~= nil and family.shield == true
end

local function GetEquippedWeaponEnchantSlotKind(inventorySlot)
	local itemID = GetInventoryItemID("player", inventorySlot)
	if type(itemID) ~= "number" then return end
	local getItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
	if not getItemInfoInstant then return inventorySlot == WEAPON_ENCHANT_REQUIRED_SLOTS.MainHand and "weapon" or nil end
	local _, _, _, equipLoc, _, classID = getItemInfoInstant(itemID)
	if equipLoc == "INVTYPE_SHIELD" then return "shield" end
	if classID == (Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2) then return "weapon" end
end

local function AddAuraMappingSpell(mapping, spellID)
	if type(spellID) ~= "number" then return end
	AddCandidate(mapping.candidates, mapping.seen, spellID)
end

local function AddCooldownAuraMapping(knownAuraSpells, knownAuraSources, unlearnedAuraSources, learnedAuraSources, info)
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
	if type(sourceSpellID) == "number" then
		knownAuraSources[sourceSpellID] = info.spellID or sourceSpellID
		unlearnedAuraSources[sourceSpellID] = true
		if not IsSecret(info.isKnown) and type(info.isKnown) == "boolean" then learnedAuraSources[sourceSpellID] = info.isKnown end
	end

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

local function AddCooldownCategoryMappings(cooldownViewer, category, knownAuraSpells, knownAuraSources, unlearnedAuraSources, learnedAuraSources, seenCooldownIDs)
	local categoryOK, cooldownIDs = pcall(cooldownViewer.GetCooldownViewerCategorySet, category, true)
	if not categoryOK or type(cooldownIDs) ~= "table" then return end
	for _, cooldownID in ipairs(cooldownIDs) do
		if not seenCooldownIDs[cooldownID] then
			seenCooldownIDs[cooldownID] = true
			local infoOK, info = pcall(cooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
			if infoOK then AddCooldownAuraMapping(knownAuraSpells, knownAuraSources, unlearnedAuraSources, learnedAuraSources, info) end
		end
	end
end

local function AddGroupBuffMappings(cooldownViewer, knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	if type(cooldownViewer.GetGroupBuffItems) ~= "function" then return end
	local itemsOK, items = pcall(cooldownViewer.GetGroupBuffItems)
	if not itemsOK or type(items) ~= "table" then return end
	for _, item in ipairs(items) do
		local spellID = type(item) == "table" and item.spellID
		if type(spellID) == "number" then
			knownAuraSources[spellID] = spellID
			unlearnedAuraSources[spellID] = true
			knownAuraSpells[spellID] = knownAuraSpells[spellID] or {
				candidates = {},
				seen = {}
			}

			local mapping = knownAuraSpells[spellID]
			mapping.groupBuff = true
			AddCandidate(mapping.candidates, mapping.seen, spellID)
		end
	end
end

local function AddClassAuraFallbackMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	local _, class = UnitClass("player")
	local definitions = CLASS_AURA_FALLBACKS[class]
	if not definitions then return end
	for _, definition in ipairs(definitions) do
		local spellID = definition.spellID
		local mapping = {
			candidates = {},
			seen = {},
			groupBuff = definition.groupBuff
		}

		AddCandidate(mapping.candidates, mapping.seen, spellID)
		AddCandidate(mapping.candidates, mapping.seen, definition.auraSpellID)
		knownAuraSpells[spellID] = mapping
		knownAuraSources[spellID] = spellID
		unlearnedAuraSources[spellID] = true
	end
end

local function AddRacialAuraFallbackMappings(knownAuraSpells, knownAuraSources)
	for _, definition in ipairs(RACIAL_AURA_FALLBACKS) do
		if not definition.foreverOnly or CooldownManagerUtils:IsForever() then
			local spellID = definition.spellID
			local mapping = {
				candidates = {},
				seen = {}
			}

			AddCandidate(mapping.candidates, mapping.seen, spellID)
			for _, auraSpellID in ipairs(definition.auraSpellIDs or {}) do
				AddCandidate(mapping.candidates, mapping.seen, auraSpellID)
			end

			knownAuraSpells[spellID] = mapping
			knownAuraSources[spellID] = spellID
		end
	end
end

local function AddPaladinBlessingMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	local _, class = UnitClass("player")
	if class ~= "PALADIN" then return end
	for _, family in ipairs(PALADIN_BLESSING_FAMILIES) do
		local mapping = {
			candidates = {},
			seen = {},
			groupBuff = true,
			paladinBlessing = true
		}

		for _, spellID in ipairs(family.spells) do
			AddCandidate(mapping.candidates, mapping.seen, spellID)
			knownAuraSpells[spellID] = mapping
			knownAuraSources[spellID] = family.spells[1]
			unlearnedAuraSources[spellID] = true
		end
	end
end

local function AddPaladinSealMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	local _, class = UnitClass("player")
	if class ~= "PALADIN" then return end
	for _, family in ipairs(PALADIN_SEAL_FAMILIES) do
		local mapping = {
			candidates = {},
			seen = {},
			paladinSeal = true
		}

		for _, spellID in ipairs(family.spells) do
			AddCandidate(mapping.candidates, mapping.seen, spellID)
			knownAuraSpells[spellID] = mapping
			knownAuraSources[spellID] = family.spells[1]
			unlearnedAuraSources[spellID] = true
		end
	end
end

local function AddHunterAspectMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	local _, class = UnitClass("player")
	if class ~= "HUNTER" then return end
	for _, family in ipairs(HUNTER_ASPECT_FAMILIES) do
		local mapping = {
			candidates = {},
			seen = {},
			hunterAspect = true
		}

		for _, spellID in ipairs(family.spells) do
			AddCandidate(mapping.candidates, mapping.seen, spellID)
			knownAuraSpells[spellID] = mapping
			knownAuraSources[spellID] = family.spells[1]
			unlearnedAuraSources[spellID] = true
		end
	end
end

function CooldownManagerUtils.AddForeverReactiveAbilityMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	if not CooldownManagerUtils:IsForever() then return end
	local _, class = UnitClass("player")
	for _, family in ipairs(CooldownManagerUtils.foreverReactiveAbilityFamilies[class] or {}) do
		local mapping = {
			candidates = {},
			seen = {},
			reactiveAbility = true
		}

		for _, spellID in ipairs(family.spells) do
			AddCandidate(mapping.candidates, mapping.seen, spellID)
			knownAuraSpells[spellID] = mapping
			knownAuraSources[spellID] = family.spells[1]
			unlearnedAuraSources[spellID] = true
		end
	end
end

local function BuildKnownAuraSpellLookup()
	local knownAuraSpells = {}
	local knownAuraSources = {}
	local unlearnedAuraSources = {}
	local learnedAuraSources = {}
	AddRacialAuraFallbackMappings(knownAuraSpells, knownAuraSources)
	AddClassAuraFallbackMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	AddPaladinBlessingMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	AddPaladinSealMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	AddHunterAspectMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	CooldownManagerUtils.AddForeverReactiveAbilityMappings(knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	for _, spellID in ipairs(GetWeaponEnchantFallbackIDs()) do
		knownAuraSources[spellID] = spellID
		unlearnedAuraSources[spellID] = true
	end

	local cooldownViewer = C_CooldownViewer
	local categoryEnum = Enum and Enum.CooldownViewerCategory
	if not cooldownViewer or not categoryEnum or not cooldownViewer.GetCooldownViewerCategorySet or not cooldownViewer.GetCooldownViewerCooldownInfo then return knownAuraSpells, knownAuraSources, unlearnedAuraSources, learnedAuraSources end
	AddGroupBuffMappings(cooldownViewer, knownAuraSpells, knownAuraSources, unlearnedAuraSources)
	local seenCooldownIDs = {}
	for _, categoryName in ipairs(COOLDOWN_AURA_CATEGORIES) do
		local category = categoryEnum[categoryName]
		if category ~= nil then AddCooldownCategoryMappings(cooldownViewer, category, knownAuraSpells, knownAuraSources, unlearnedAuraSources, learnedAuraSources, seenCooldownIDs) end
	end
	return knownAuraSpells, knownAuraSources, unlearnedAuraSources, learnedAuraSources
end

local function IsPlayerBuffSpell(spellID, baseSpellID, knownAuraSpells)
	if not C_Spell then return false end
	if MINIMAP_TRACKING_SPELLS[spellID] or MINIMAP_TRACKING_SPELLS[baseSpellID] then return true end
	if GetSpellPredicate(C_Spell.IsSpellPassive, spellID) then return false end
	if knownAuraSpells[spellID] or knownAuraSpells[baseSpellID] then return true end
	if IsLearnedBuffSpell(spellID) or IsLearnedBuffSpell(baseSpellID) then return true end
	if IsWeaponEnchantSpell(spellID) or IsWeaponEnchantSpell(baseSpellID) then return true end
	if GetSpellPredicate(C_Spell.IsSelfBuff, spellID) then return true end
	if not GetSpellPredicate(C_Spell.IsSpellHelpful, spellID) then return false end
	if type(C_Spell.GetSpellMaxCumulativeAuraApplications) ~= "function" then return false end
	local ok, applications = pcall(C_Spell.GetSpellMaxCumulativeAuraApplications, spellID)
	return ok and not IsSecret(applications) and type(applications) == "number" and applications > 0
end

local function IsGroupBuffMapping(knownAuraSpells, ...)
	for index = 1, select("#", ...) do
		local mapping = knownAuraSpells[select(index, ...)]
		if mapping and mapping.groupBuff then return true end
	end
	return false
end

local function IsPaladinBlessingMapping(knownAuraSpells, ...)
	for index = 1, select("#", ...) do
		local mapping = knownAuraSpells[select(index, ...)]
		if mapping and mapping.paladinBlessing then return true end
	end
	return false
end

local function IsPaladinSealMapping(knownAuraSpells, ...)
	for index = 1, select("#", ...) do
		local mapping = knownAuraSpells[select(index, ...)]
		if mapping and mapping.paladinSeal then return true end
	end
	return false
end

local function IsHunterAspectMapping(knownAuraSpells, ...)
	for index = 1, select("#", ...) do
		local mapping = knownAuraSpells[select(index, ...)]
		if mapping and mapping.hunterAspect then return true end
	end
	return false
end

local function AddAvailableSpell(spellID, baseSpellID, knownAuraSpells, availableBuffs, availableBuffsBySpellID, learned)
	if type(spellID) ~= "number" or not IsPlayerBuffSpell(spellID, baseSpellID, knownAuraSpells) then return end
	local isLearned = learned ~= false
	local sourceSpellID = spellID
	local groupBuff = IsGroupBuffMapping(knownAuraSpells, spellID, baseSpellID)
	local paladinBlessing = IsPaladinBlessingMapping(knownAuraSpells, spellID, baseSpellID)
	local paladinSeal = IsPaladinSealMapping(knownAuraSpells, spellID, baseSpellID)
	local hunterAspect = IsHunterAspectMapping(knownAuraSpells, spellID, baseSpellID)
	local reactiveFamily = CooldownManagerUtils.GetForeverReactiveAbilityFamily(spellID) or CooldownManagerUtils.GetForeverReactiveAbilityFamily(baseSpellID)
	local family = GetWeaponEnchantFamily(spellID) or GetWeaponEnchantFamily(baseSpellID)
	if family then
		spellID = family.spells[1]
	elseif reactiveFamily then
		spellID = reactiveFamily.spells[1]
	end

	local candidates = {}
	local seenCandidates = {}
	AddCandidate(candidates, seenCandidates, spellID)
	AddCandidate(candidates, seenCandidates, sourceSpellID)
	AddCandidate(candidates, seenCandidates, baseSpellID)
	for _, familySpellID in ipairs(family and family.spells or {}) do
		AddCandidate(candidates, seenCandidates, familySpellID)
	end

	for _, familySpellID in ipairs(reactiveFamily and reactiveFamily.spells or {}) do
		AddCandidate(candidates, seenCandidates, familySpellID)
	end

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

	local spellName = GetSpellNameSafe(spellID)
	if spellName then AddCandidate(candidates, seenCandidates, GetLearnedAuras().names[spellName]) end
	local weaponEnchant = family ~= nil or IsWeaponEnchantSpell(sourceSpellID) or IsWeaponEnchantSpell(baseSpellID)
	local minimapTracking = MINIMAP_TRACKING_SPELLS[sourceSpellID] == true or MINIMAP_TRACKING_SPELLS[baseSpellID] == true
	local existing = availableBuffsBySpellID[spellID] or (spellName and availableBuffsByName[spellName])
	if existing then
		availableBuffsBySpellID[spellID] = existing
		availableBuffsBySpellID[sourceSpellID] = existing
		existing.weaponEnchant = existing.weaponEnchant or weaponEnchant
		existing.minimapTracking = existing.minimapTracking or minimapTracking
		existing.groupBuff = existing.groupBuff or groupBuff
		existing.paladinBlessing = existing.paladinBlessing or paladinBlessing
		existing.paladinSeal = existing.paladinSeal or paladinSeal
		existing.hunterAspect = existing.hunterAspect or hunterAspect
		existing.reactiveAbility = existing.reactiveAbility or reactiveFamily ~= nil
		existing.isLearned = existing.isLearned or isLearned
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
		weaponEnchant = weaponEnchant,
		minimapTracking = minimapTracking,
		groupBuff = groupBuff,
		paladinBlessing = paladinBlessing,
		paladinSeal = paladinSeal,
		hunterAspect = hunterAspect,
		reactiveAbility = reactiveFamily ~= nil,
		isLearned = isLearned,
		candidates = candidates
	}

	availableBuffsBySpellID[spellID] = entry
	availableBuffsBySpellID[sourceSpellID] = entry
	availableBuffsByName[entry.name] = entry
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
		if itemInfo and not itemInfo.isPassive then
			if itemInfo.itemType == spellType and itemInfo.spellID and (not itemInfo.isOffSpec or IsLearnedBuffSpell(itemInfo.spellID) or IsLearnedBuffSpell(itemInfo.actionID)) then
				AddAvailableSpell(itemInfo.spellID, itemInfo.actionID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
			elseif itemInfo.itemType == flyoutType and not itemInfo.isOffSpec then
				AddFlyoutSpells(itemInfo.actionID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
			end
		end
	end
end

local function AddMinimapTrackingSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	if not C_Minimap or type(C_Minimap.GetNumTrackingTypes) ~= "function" or type(C_Minimap.GetTrackingFilter) ~= "function" then return end
	local countOK, count = pcall(C_Minimap.GetNumTrackingTypes)
	if not countOK or IsSecret(count) or type(count) ~= "number" then return end
	for index = 1, count do
		local filterOK, filter = pcall(C_Minimap.GetTrackingFilter, index)
		local spellID = filterOK and not IsSecret(filter) and type(filter) == "table" and filter.spellID
		if not IsSecret(spellID) and type(spellID) == "number" then
			MINIMAP_TRACKING_SPELLS[spellID] = true
			AddAvailableSpell(spellID, spellID, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
		end
	end
end

local function AddKnownAuraSources(knownAuraSources, unlearnedAuraSources, learnedAuraSources, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	local isSpellKnown = C_SpellBook.IsSpellKnownOrInSpellBook
	local playerBank = Enum.SpellBookSpellBank.Player
	for spellID, baseSpellID in pairs(knownAuraSources) do
		local isKnown = learnedAuraSources[spellID]
		if type(isKnown) ~= "boolean" and type(isSpellKnown) == "function" then
			local knownOK, result = pcall(isSpellKnown, spellID, playerBank, true)
			if knownOK and not IsSecret(result) and type(result) == "boolean" then isKnown = result end
		end

		if type(isKnown) == "boolean" and (isKnown or unlearnedAuraSources[spellID]) then AddAvailableSpell(spellID, baseSpellID, knownAuraSpells, availableBuffs, availableBuffsBySpellID, isKnown) end
	end
end

function CooldownManagerUtils.GetTalentSpellLearnedState(spellID, learned)
	if type(learned) == "boolean" then return learned end
	local isSpellKnown = C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
	if type(isSpellKnown) ~= "function" then return false end
	local playerBank = Enum.SpellBookSpellBank.Player
	local knownOK, result = pcall(isSpellKnown, spellID, playerBank, true)
	return knownOK and not IsSecret(result) and result == true
end

function CooldownManagerUtils.AddTalentSpell(spellID, learned, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	if IsSecret(spellID) or type(spellID) ~= "number" or spellID <= 0 then return end
	AddAvailableSpell(spellID, spellID, knownAuraSpells, availableBuffs, availableBuffsBySpellID, CooldownManagerUtils.GetTalentSpellLearnedState(spellID, learned))
end

function CooldownManagerUtils.AddTraitTalentSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	if not C_ClassTalents or type(C_ClassTalents.GetActiveConfigID) ~= "function" or not C_Traits or type(C_Traits.GetConfigInfo) ~= "function" or type(C_Traits.GetTreeNodes) ~= "function" or type(C_Traits.GetNodeInfo) ~= "function" or type(C_Traits.GetEntryInfo) ~= "function" or type(C_Traits.GetDefinitionInfo) ~= "function" then return false end
	local configOK, configID = pcall(C_ClassTalents.GetActiveConfigID)
	if not configOK or IsSecret(configID) or type(configID) ~= "number" then return false end
	local infoOK, configInfo = pcall(C_Traits.GetConfigInfo, configID)
	if not infoOK or type(configInfo) ~= "table" or type(configInfo.treeIDs) ~= "table" then return false end
	local found = false
	for _, treeID in ipairs(configInfo.treeIDs) do
		local nodesOK, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
		if nodesOK and type(nodeIDs) == "table" then
			for _, nodeID in ipairs(nodeIDs) do
				local nodeOK, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
				if nodeOK and type(nodeInfo) == "table" and nodeInfo.isVisible ~= false and type(nodeInfo.entryIDs) == "table" then
					for _, entryID in ipairs(nodeInfo.entryIDs) do
						local entryOK, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
						local definitionID = entryOK and type(entryInfo) == "table" and entryInfo.definitionID
						if type(definitionID) == "number" then
							local definitionOK, definitionInfo = pcall(C_Traits.GetDefinitionInfo, definitionID)
							local spellID = definitionOK and type(definitionInfo) == "table" and definitionInfo.spellID
							if type(spellID) == "number" then
								CooldownManagerUtils.AddTalentSpell(spellID, nil, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
								found = true
							end
						end
					end
				end
			end
		end
	end
	return found
end

function CooldownManagerUtils.AddSpecializationTalentSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	local getTalentInfo = C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
	if type(getTalentInfo) ~= "function" then return end
	local _, _, classID = UnitClass("player")
	local getSpecCount = C_SpecializationInfo.GetNumSpecializationsForClassID
	local specCount = type(getSpecCount) == "function" and classID and getSpecCount(classID) or type(GetNumTalentTabs) == "function" and GetNumTalentTabs() or 3
	local groupIndex = type(C_SpecializationInfo.GetActiveSpecGroup) == "function" and C_SpecializationInfo.GetActiveSpecGroup() or nil
	for specializationIndex = 1, specCount do
		local talentCount = type(GetNumTalents) == "function" and GetNumTalents(specializationIndex) or 100
		if type(talentCount) ~= "number" then talentCount = 100 end
		for talentIndex = 1, talentCount do
			local talentOK, talentInfo = pcall(getTalentInfo, {
				specializationIndex = specializationIndex,
				talentIndex = talentIndex,
				isInspect = false,
				isPet = false,
				groupIndex = groupIndex
			})

			if talentOK and type(talentInfo) == "table" then
				local learned = type(talentInfo.known) == "boolean" and talentInfo.known or type(talentInfo.rank) == "number" and talentInfo.rank > 0
				CooldownManagerUtils.AddTalentSpell(talentInfo.spellID, learned, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
			elseif type(GetNumTalents) ~= "function" then
				break
			end
		end
	end
end

function CooldownManagerUtils.AddUnlearnedTalentSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	if not CooldownManagerUtils.AddTraitTalentSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID) then CooldownManagerUtils.AddSpecializationTalentSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID) end
end

function CooldownManagerUtils:GetCooldownManagerLayoutKey()
	local settings = CooldownViewerSettings
	if not settings or type(settings.GetLayoutManager) ~= "function" then return "starter" end
	local manager = settings:GetLayoutManager()
	if not manager or type(manager.GetActiveLayoutID) ~= "function" then return "starter" end
	local ok, layoutID = pcall(manager.GetActiveLayoutID, manager)
	if ok and not IsSecret(layoutID) and layoutID ~= nil then return "layout:" .. tostring(layoutID) end
	return "starter"
end

function CooldownManagerUtils.PruneObsoleteReminderSpells(profile)
	for spellID in pairs(OBSOLETE_REMINDER_SPELLS) do
		if profile.selected[spellID] ~= nil then profile.selected[spellID] = nil end
		if profile.layout[spellID] ~= nil then profile.layout[spellID] = nil end
	end
end

function CooldownManagerUtils:GetProfile()
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	CooldownManagerUtilsDB.cooldownManagerProfiles = CooldownManagerUtilsDB.cooldownManagerProfiles or {}
	local specKey = GetSpecKey()
	local layoutKey = self:GetCooldownManagerLayoutKey()
	local profiles = CooldownManagerUtilsDB.cooldownManagerProfiles
	profiles[specKey] = profiles[specKey] or {}
	local profile = profiles[specKey][layoutKey]
	if type(profile) ~= "table" then
		local template
		if self.activeCooldownManagerSpecKey == specKey then template = self.activeCooldownManagerProfile end
		if not template and CooldownManagerUtilsDB.profiles then template = CooldownManagerUtilsDB.profiles[specKey] end
		if not template and activeLayoutData and activeLayoutData.profiles then template = activeLayoutData.profiles[specKey] end
		profile = template and CopyTable(template) or {
			selected = {}
		}

		profiles[specKey][layoutKey] = profile
	end

	self.activeCooldownManagerSpecKey = specKey
	self.activeCooldownManagerLayoutKey = layoutKey
	self.activeCooldownManagerProfile = profile
	if profile.layoutVersion ~= 4 then
		profile.selected = {}
		profile.layout = {}
		profile.layoutVersion = 4
	end

	profile.selected = profile.selected or {}
	profile.layout = profile.layout or {}
	CooldownManagerUtils.PruneObsoleteReminderSpells(profile)
	return profile
end

function CooldownManagerUtils:OnCooldownManagerLayoutChanged()
	local previousSpecKey = self.activeCooldownManagerSpecKey
	local previousLayoutKey = self.activeCooldownManagerLayoutKey
	self:GetProfile()
	if previousSpecKey == self.activeCooldownManagerSpecKey and previousLayoutKey == self.activeCooldownManagerLayoutKey then return end
	if self.CaptureReminderRestorePoint then self:CaptureReminderRestorePoint() end
	if self.RefreshReminderSettings then self:RefreshReminderSettings() end
	self:UpdateReminderBar()
end

function CooldownManagerUtils:ScheduleCooldownManagerLayoutCheck()
	if self.cooldownManagerLayoutCheckPending then return end
	self.cooldownManagerLayoutCheckPending = true
	C_Timer.After(0, function()
		CooldownManagerUtils.cooldownManagerLayoutCheckPending = nil
		CooldownManagerUtils:OnCooldownManagerLayoutChanged()
	end)
end

function CooldownManagerUtils:GetReminderLayout(spellID)
	return self:GetProfile().layout[spellID]
end

function CooldownManagerUtils:SaveReminderLayout(categories)
	local profile = self:GetProfile()
	local layout = CopyTable(profile.layout)
	local selected = CopyTable(profile.selected)
	for _, category in ipairs(categories) do
		if not category.readOnly then
			for order, entry in ipairs(category.entries) do
				layout[entry.spellID] = {
					category = category.key,
					order = order
				}

				if category.key ~= "hidden" then
					selected[entry.spellID] = true
				else
					selected[entry.spellID] = nil
				end
			end
		end
	end

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

function CooldownManagerUtils.AddRetailProcAbilities(availableBuffs, availableBuffsBySpellID)
	if not CooldownManagerUtils:HasRetailProcAbilities() then return end
	local cooldownViewer = C_CooldownViewer
	local categoryEnum = Enum.CooldownViewerCategory
	local seenCooldownIDs = {}
	for _, categoryName in ipairs(CooldownManagerUtils.retailProcCategories) do
		local category = categoryEnum[categoryName]
		local categoryOK, cooldownIDs = false, nil
		if category ~= nil then categoryOK, cooldownIDs = pcall(cooldownViewer.GetCooldownViewerCategorySet, category, true) end
		if categoryOK and type(cooldownIDs) == "table" then
			for _, cooldownID in ipairs(cooldownIDs) do
				if not seenCooldownIDs[cooldownID] then
					seenCooldownIDs[cooldownID] = true
					local infoOK, info = pcall(cooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
					local spellID = infoOK and type(info) == "table" and info.spellID
					if not IsSecret(spellID) and type(spellID) == "number" and not availableBuffsBySpellID[spellID] then
						local overrideSpellID = not IsSecret(info.overrideSpellID) and type(info.overrideSpellID) == "number" and info.overrideSpellID or nil
						local spellInfo = GetReminderSpellInfo(spellID)
						if spellInfo and spellInfo.name and not (overrideSpellID and availableBuffsBySpellID[overrideSpellID]) then
							local candidates = {}
							local seenCandidates = {}
							AddCandidate(candidates, seenCandidates, spellID)
							AddCandidate(candidates, seenCandidates, overrideSpellID)
							if type(info.linkedSpellIDs) == "table" then
								for _, linkedSpellID in ipairs(info.linkedSpellIDs) do
									if not IsSecret(linkedSpellID) then AddCandidate(candidates, seenCandidates, linkedSpellID) end
								end
							end

							local entry = {
								spellID = spellID,
								name = spellInfo.name,
								iconID = spellInfo.iconID,
								defaultCategory = "hidden",
								reactiveAbility = true,
								isLearned = IsSecret(info.isKnown) or info.isKnown ~= false,
								candidates = candidates
							}

							availableBuffsBySpellID[spellID] = entry
							if overrideSpellID then availableBuffsBySpellID[overrideSpellID] = entry end
							table.insert(availableBuffs, entry)
						end
					end
				end
			end
		end
	end
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
	wipe(availableBuffsByName)
	weaponEnchantFallbackNames = nil
	LearnCurrentPlayerAuras()
	local knownAuraSpells, knownAuraSources, unlearnedAuraSources, learnedAuraSources = BuildKnownAuraSpellLookup()
	local skillLineEnum = Enum.SpellBookSkillLineIndex
	local generalLine = skillLineEnum and skillLineEnum.General or 1
	local numSkillLines = type(C_SpellBook.GetNumSpellBookSkillLines) == "function" and C_SpellBook.GetNumSpellBookSkillLines() or 3
	for skillLineIndex = 1, numSkillLines do
		if skillLineIndex ~= generalLine then AddSpellBookSkillLine(skillLineIndex, knownAuraSpells, availableBuffs, availableBuffsBySpellID) end
	end

	CooldownManagerUtils.AddUnlearnedTalentSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	AddMinimapTrackingSpells(knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	AddKnownAuraSources(knownAuraSources, unlearnedAuraSources, learnedAuraSources, knownAuraSpells, availableBuffs, availableBuffsBySpellID)
	CooldownManagerUtils.AddRetailProcAbilities(availableBuffs, availableBuffsBySpellID)
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

local function GetActiveEditModeLayout()
	if not C_EditMode or type(C_EditMode.GetLayouts) ~= "function" then return end
	local ok, layouts = pcall(C_EditMode.GetLayouts)
	if not ok or type(layouts) ~= "table" or type(layouts.activeLayout) ~= "number" then return end
	local presets = EditModePresetLayoutManager and EditModePresetLayoutManager.presetLayoutInfo
	local presetCount = type(presets) == "table" and #presets or (Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues) or 2
	local presetType = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset or 0
	if layouts.activeLayout <= presetCount then return "preset:" .. layouts.activeLayout, presetType end
	local layoutInfo = type(layouts.layouts) == "table" and layouts.layouts[layouts.activeLayout - presetCount]
	if type(layoutInfo) ~= "table" or type(layoutInfo.layoutName) ~= "string" then return end
	return tostring(layoutInfo.layoutType) .. ":" .. layoutInfo.layoutName, layoutInfo.layoutType
end

local function GetLayoutStore(layoutType)
	local characterType = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character or 2
	local root
	if layoutType == characterType then
		CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
		root = CooldownManagerUtilsDB
	else
		CooldownManagerUtilsGlobalDB = CooldownManagerUtilsGlobalDB or {}
		root = CooldownManagerUtilsGlobalDB
	end

	root.editModeLayouts = root.editModeLayouts or {}
	return root.editModeLayouts
end

local function ResolveActiveLayoutData()
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	local key, layoutType = GetActiveEditModeLayout()
	if not key then
		key = "default"
		layoutType = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character or 2
	end

	local store = GetLayoutStore(layoutType)
	local data = store[key]
	if type(data) ~= "table" then
		local template = activeLayoutData
		if not template and (CooldownManagerUtilsDB.position or CooldownManagerUtilsDB.reminderSettings) then
			template = {
				position = CooldownManagerUtilsDB.position,
				settings = CooldownManagerUtilsDB.reminderSettings
			}
		end

		data = {
			positions = {
				buff = template and (template.positions and template.positions.buff or template.position) and CopyTable(template.positions and template.positions.buff or template.position) or nil,
				ability = template and template.positions and template.positions.ability and CopyTable(template.positions.ability) or nil
			},
			barSettings = {
				buff = template and (template.barSettings and template.barSettings.buff or template.settings) and CopyTable(template.barSettings and template.barSettings.buff or template.settings) or {},
				ability = template and template.barSettings and template.barSettings.ability and CopyTable(template.barSettings.ability) or {}
			}
		}

		store[key] = data
		CooldownManagerUtilsDB.position = nil
		CooldownManagerUtilsDB.reminderSettings = nil
	end

	data.positions = type(data.positions) == "table" and data.positions or {
		buff = data.position
	}

	data.barSettings = type(data.barSettings) == "table" and data.barSettings or {
		buff = type(data.settings) == "table" and data.settings or {}
	}

	data.barSettings.buff = type(data.barSettings.buff) == "table" and data.barSettings.buff or {}
	data.barSettings.ability = type(data.barSettings.ability) == "table" and data.barSettings.ability or {}
	data.barSettings.expiring = type(data.barSettings.expiring) == "table" and data.barSettings.expiring or {}
	data.position = nil
	data.settings = nil
	local changed = key ~= activeLayoutKey or data ~= activeLayoutData
	activeLayoutKey = key
	activeLayoutData = data
	return data, changed
end

local function GetActiveLayoutData()
	return activeLayoutData or ResolveActiveLayoutData()
end

local function RestorePosition(frame)
	local position = GetActiveLayoutData().positions[frame.reminderType]
	local defaultY = frame.reminderType == "ability" and DEFAULT_REMINDER_Y - 60 or frame.reminderType == "expiring" and DEFAULT_REMINDER_Y + 60 or DEFAULT_REMINDER_Y
	frame:ClearAllPoints()
	if position then
		local relativeTo = position.relativeTo and _G[position.relativeTo] or UIParent
		if position.relativeSelection and relativeTo.Selection then
			frame.snapTarget = relativeTo
			relativeTo = relativeTo.Selection
		end

		frame:SetPoint(position.point or "CENTER", relativeTo, position.relativePoint or "CENTER", position.x or DEFAULT_REMINDER_X, position.y or defaultY)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_REMINDER_X, defaultY)
	end
end

local function SavePosition(frame)
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
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

	GetActiveLayoutData().positions[frame.reminderType] = {
		point = point,
		relativeTo = relativeName,
		relativeSelection = relativeSelection,
		relativePoint = relativePoint,
		x = x,
		y = y
	}
end

local function GetReminderSettings(reminderType)
	local settings = GetActiveLayoutData().barSettings[reminderType or "buff"]
	for key, value in pairs(reminderSettingDefaults) do
		if settings[key] == nil then settings[key] = value end
	end

	settings.hideWhenInactive = nil
	settings.iconSize = math.min(math.max(settings.iconSize, ICON_SCALE_MIN), ICON_SCALE_MAX)
	return settings
end

local function ApplyReminderSettings(frame)
	local settings = GetReminderSettings(frame.reminderType)
	frame.orientationSetting = settings.orientation
	frame.iconDirection = settings.iconDirection
	frame.iconScale = settings.iconSize / 100
	frame.iconPadding = settings.iconPadding
	frame.visibleSetting = settings.visibleSetting
	frame.showTimer = settings.showTimer == 1
	frame.showTooltips = settings.showTooltips == 1
	frame.showGlow = settings.showGlow == 1
	frame.checkGroupBuffs = settings.checkGroupBuffs == 1
	frame.cooldownDisplayTime = settings.cooldownDisplayTime
	frame:SetAlpha(settings.opacity / 100)
	CooldownManagerUtils:UpdateReminderBar()
	if reminderOptionsFrame and reminderOptionsFrame:IsShown() and reminderOptionsFrame.owner == frame and reminderOptionsFrame.Refresh then reminderOptionsFrame:Refresh() end
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
		checkPoints = {{"LEFT", "LEFT", sides.left, parent.left}, {"RIGHT", "RIGHT", sides.right, parent.right}, {"CENTER", "CENTER", sides.centerX, parent.centerX}, {"LEFT", "CENTER", sides.left, parent.centerX}, {"RIGHT", "CENTER", sides.right, parent.centerX}}
	else
		checkPoints = {{"TOP", "TOP", sides.top, parent.top}, {"BOTTOM", "BOTTOM", sides.bottom, parent.bottom}, {"CENTER", "CENTER", sides.centerY, parent.centerY}, {"TOP", "CENTER", sides.top, parent.centerY}, {"BOTTOM", "CENTER", sides.bottom, parent.centerY}}
	end

	local closestDistance, closestPoint, closestRelativePoint
	local closestOffset = 0
	for _, checkPoint in ipairs(checkPoints) do
		local distance = math.abs(checkPoint[4] - checkPoint[3])
		if not closestDistance or distance < closestDistance then closestDistance, closestPoint, closestRelativePoint = distance, checkPoint[1], checkPoint[2] end
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
		return {
			target = target,
			sides = sides,
			point = point,
			relativePoint = relativePoint,
			distance = scaledDistance,
			offset = offset,
			isHorizontal = isHorizontal
		}
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
				if sqrDistance <= SNAP_CORNER_DISTANCE_SQ and (not closestSqrDistance or sqrDistance < closestSqrDistance) then closestPoint, closestRelativePoint, closestSqrDistance = point, relativePoint, sqrDistance end
			end
		end
	end

	if not closestSqrDistance then return end
	return {
		target = relativeInfo.target,
		sides = relativeSides,
		point = closestPoint,
		relativePoint = closestRelativePoint,
		distance = math.sqrt(closestSqrDistance),
		offset = 0,
		isHorizontal = relativeInfo.isHorizontal,
		isCornerSnap = true
	}
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
	if relativePoint:find("CENTER") then return {info.isHorizontal and "CenterVertical" or "CenterHorizontal"} end
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
	if info.target ~= UIParent then offset = offset + GetSelectionPadding(info.relativePoint, forYOffset, GetUIParentScaleFactor(info.target.Selection)) end
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
	if not target or target.isDragging or snapTargetLookup[target] then return end
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
	for _, target in ipairs(children) do
		AddSnapTarget(target)
	end

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
				local owner = parent:GetParent().owner
				return owner and GetReminderSettings(owner.reminderType)[key] == option
			end, function(option)
				local panel = parent:GetParent()
				GetReminderSettings(panel.owner.reminderType)[key] = option
				if panel.RevertChanges then panel.RevertChanges:SetEnabled(true) end
				ApplyReminderSettings(panel.owner)
			end, value)
		end
	end)

	row.Refresh = function(self) self.Dropdown:GenerateMenu() end
	row:Show()
	return row
end

local function CreateSliderSetting(parent, layoutIndex, labelText, key, minimum, maximum, step, suffix, optionKey, tooltipText)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(343, 32)
	row.layoutIndex = layoutIndex
	row.Label = CreateSettingLabel(row, labelText)
	row.Slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
	row.Slider:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
	row.Slider:SetSize(200, 32)
	row.Slider.MinText:Hide()
	row.Slider.MaxText:Hide()
	if tooltipText then
		local function ShowTooltip(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(labelText)
			GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
			GameTooltip:Show()
		end
		row:EnableMouse(true)
		row:HookScript("OnEnter", ShowTooltip)
		row:HookScript("OnLeave", function() GameTooltip:Hide() end)
		row.Slider:HookScript("OnEnter", ShowTooltip)
		row.Slider:HookScript("OnLeave", function() GameTooltip:Hide() end)
		if row.Slider.Slider then
			row.Slider.Slider:HookScript("OnEnter", ShowTooltip)
			row.Slider.Slider:HookScript("OnLeave", function() GameTooltip:Hide() end)
		end
	end
	local formatter = function(value) return value .. suffix end
	local formatters = {
		[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
	}

	local steps = (maximum - minimum) / step
	row.Slider:Init(optionKey and CooldownManagerUtils:GetOption(optionKey) or reminderSettingDefaults[key], minimum, maximum, steps, formatters)
	row.cbrHandles = EventUtil.CreateCallbackHandleContainer()
	row.cbrHandles:RegisterCallback(row.Slider, MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(self, value)
		if self.refreshing then return end
		local panel = parent:GetParent()
		local rounded = math.floor(value / step + 0.5) * step
		if optionKey then
			CooldownManagerUtils:GetOptions()[optionKey] = rounded
		else
			GetReminderSettings(panel.owner.reminderType)[key] = rounded
		end
		if panel.RevertChanges then panel.RevertChanges:SetEnabled(true) end
		ApplyReminderSettings(panel.owner)
	end, row)

	row.Refresh = function(self)
		self.refreshing = true
		local owner = parent:GetParent().owner
		self:SetShown(not optionKey or owner.reminderType == "expiring")
		self.Slider:SetValue(optionKey and CooldownManagerUtils:GetOption(optionKey) or GetReminderSettings(owner.reminderType)[key])
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
		local panel = parent:GetParent()
		GetReminderSettings(panel.owner.reminderType)[key] = self:GetChecked() and 1 or 0
		if panel.RevertChanges then panel.RevertChanges:SetEnabled(true) end
		ApplyReminderSettings(panel.owner)
	end)

	row.Refresh = function(self)
		local owner = parent:GetParent().owner
		self.Button:SetChecked(GetReminderSettings(owner.reminderType)[key] == 1)
	end

	row:Show()
	return row
end

local function CreateReminderOptionsFrame(owner)
	if reminderOptionsFrame then
		reminderOptionsFrame.owner = owner
		return reminderOptionsFrame
	end

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
	panel.owner = owner
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
		local vertical = GetReminderSettings(panel.owner.reminderType).orientation == 1
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
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 8, CooldownManagerUtils:Trans("LID_COOLDOWN_DISPLAY_TIME"), "cooldownDisplayTime", 0, 60, 1, "", nil, CooldownManagerUtils:Trans("LID_COOLDOWN_DISPLAY_TIME_TOOLTIP")))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 9, labels.showTooltips, "showTooltips"))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 10, CooldownManagerUtils:Trans("LID_BUFFREMINDERS_SHOW_GLOW"), "showGlow"))
	table.insert(panel.controls, CreateCheckboxSetting(panel.Settings, 11, CooldownManagerUtils:Trans("LID_BUFFREMINDERS_CHECK_GROUP_BUFFS"), "checkGroupBuffs"))
	table.insert(panel.controls, CreateSliderSetting(panel.Settings, 12, CooldownManagerUtils:Trans("LID_EXPIRYWARNINGTIME"), "expiryWarningTime", 1, 60, 1, "", "EXPIRYWARNINGTIME", CooldownManagerUtils:Trans("LID_EXPIRYWARNINGTIME_TOOLTIP")))
	panel.Buttons = CreateFrame("Frame", nil, panel, "VerticalLayoutFrame")
	panel.Buttons:SetPoint("TOP", panel.Settings, "BOTTOM", 0, -12)
	panel.Buttons.spacing = 2
	panel.RevertChanges = CreateFrame("Button", nil, panel.Buttons, "EditModeSystemSettingsDialogButtonTemplate")
	panel.RevertChanges.layoutIndex = 1
	panel.RevertChanges:SetText(_G.HUD_EDIT_MODE_REVERT_CHANGES or "Änderungen verwerfen")
	panel.RevertChanges:SetEnabled(false)
	panel.RevertChanges:SetScript("OnClick", function(self)
		if not panel.originalSettings then return end
		local settings = GetReminderSettings(panel.owner.reminderType)
		for key, value in pairs(panel.originalSettings) do
			settings[key] = value
		end

		if panel.owner.reminderType == "expiring" then CooldownManagerUtils:GetOptions().EXPIRYWARNINGTIME = panel.originalExpiryWarningTime end
		self:SetEnabled(false)
		ApplyReminderSettings(panel.owner)
	end)

	panel.Divider = panel.Buttons:CreateTexture(nil, "ARTWORK")
	panel.Divider:SetSize(330, 16)
	panel.Divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
	panel.Divider.layoutIndex = 2
	panel.Reset = CreateFrame("Button", nil, panel.Buttons, "EditModeSystemSettingsDialogExtraButtonTemplate")
	panel.Reset.layoutIndex = 3
	panel.Reset:SetText(_G.HUD_EDIT_MODE_RESET_POSITION or RESET_POSITION or "Reset position")
	panel.Reset:SetScript("OnClick", function()
		local frame = panel.owner
		frame.snapTarget = nil
		GetActiveLayoutData().positions[frame.reminderType] = nil
		RestorePosition(frame)
	end)

	panel.EditModeClose = CreateFrame("Button", "CooldownManagerUtilsEditModeClose", UIParent, "InsecureActionButtonTemplate")
	panel.EditModeClose:Hide()
	panel.EditModeClose:SetAttribute("useOnKeyDown", false)
	panel.EditModeClose:SetAttribute("type", "click")
	panel.EditModeClose:SetAttribute("clickbutton", EditModeManagerFrame and EditModeManagerFrame.CloseButton)
	panel.CooldownSettings = CreateFrame("Button", nil, panel.Buttons, "EditModeSystemSettingsDialogExtraButtonTemplate, InsecureActionButtonTemplate")
	panel.CooldownSettings.layoutIndex = 4
	panel.CooldownSettings:SetText(_G.HUD_EDIT_MODE_COOLDOWN_VIEWER_SETTINGS or "Cooldown Settings")
	panel.CooldownSettings:RegisterForClicks("LeftButtonUp")
	panel.CooldownSettings:SetAttribute("useOnKeyDown", false)
	panel.CooldownSettings:SetAttribute("type", "macro")
	if _G.SLASH_COOLDOWNMANAGER1 then
		panel.CooldownSettings:SetAttribute("macrotext", (_G.SLASH_CLICK1 or "/click") .. " CooldownManagerUtilsEditModeClose\n" .. _G.SLASH_COOLDOWNMANAGER1)
	else
		panel.CooldownSettings:SetEnabled(false)
	end

	panel.CooldownSettings:SetScript("PostClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		CooldownManagerUtils:ShowReminderSettingsTab(panel.owner.reminderType)
	end)

	panel.Refresh = function(self)
		for _, control in ipairs(self.controls) do
			control:Refresh()
		end

		if self:IsShown() then self:Layout() end
	end

	panel:SetScript("OnShow", function(self)
		self.Title:SetText(CooldownManagerUtils:Trans(self.owner.labelKey))
		self.originalSettings = {}
		for key, value in pairs(GetReminderSettings(self.owner.reminderType)) do
			self.originalSettings[key] = value
		end

		self.originalExpiryWarningTime = CooldownManagerUtils:GetOption("EXPIRYWARNINGTIME")
		self.RevertChanges:SetEnabled(false)
		self:Refresh()
		self:Layout()
	end)

	panel:Hide()
	panel:SetScript("OnHide", function() if editModeActive and panel.owner and panel.owner.Selection then panel.owner:HighlightSystem() end end)
	panel:SetScript("OnUpdate", function(self)
		local dialog = EditModeSystemSettingsDialog
		local attached = dialog and dialog:IsShown() and dialog.attachedToSystem or nil
		if attached and attached ~= self.blizzardDialogSystem then
			self:Hide()
			return
		end

		self.blizzardDialogSystem = attached
	end)

	panel.AvoidBlizzardDialog = function(self)
		local dialog = EditModeSystemSettingsDialog
		if not dialog or not dialog:IsShown() then return end
		local dLeft, dBottom, dWidth, dHeight = dialog:GetRect()
		local pLeft, pBottom, pWidth, pHeight = self:GetRect()
		if not dLeft or not pLeft then return end
		local ratio = dialog:GetEffectiveScale() / self:GetEffectiveScale()
		dLeft, dBottom, dWidth, dHeight = dLeft * ratio, dBottom * ratio, dWidth * ratio, dHeight * ratio
		if pLeft >= dLeft + dWidth or pLeft + pWidth <= dLeft or pBottom >= dBottom + dHeight or pBottom + pHeight <= dBottom then return end
		local parentTop = UIParent:GetTop() * UIParent:GetEffectiveScale() / self:GetEffectiveScale()
		self:ClearAllPoints()
		if dBottom + dHeight + pHeight <= parentTop then
			self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", dLeft, dBottom + dHeight)
		else
			self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", dLeft, dBottom)
		end
	end

	panel.ShowFor = function(self)
		local dialog = EditModeSystemSettingsDialog
		self.blizzardDialogSystem = dialog and dialog:IsShown() and dialog.attachedToSystem or nil
		if not self:IsShown() then self:Show() end
		if InCombatLockdown() then self:AvoidBlizzardDialog() end
	end

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
	frame.GetSystemName = function(self) return CooldownManagerUtils:Trans(self.labelKey) end
	frame.HighlightSystem = function(self)
		self.Selection:ShowHighlighted()
		self.isSelected = false
	end

	frame.SelectSystem = function(self)
		if reminderOptionsFrame and reminderOptionsFrame:IsShown() and reminderOptionsFrame.owner ~= self then reminderOptionsFrame:Hide() end
		self.Selection:ShowSelected()
		self.isSelected = true
		CreateReminderOptionsFrame(self):ShowFor()
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

	frame.Selection:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then frame:SelectSystem() end end)
	if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog.CloseButton then
		local clicker = CreateFrame("Button", nil, frame.Selection, "InsecureActionButtonTemplate")
		clicker:SetAllPoints()
		clicker:RegisterForClicks("LeftButtonUp")
		clicker:RegisterForDrag("LeftButton")
		clicker:SetAttribute("useOnKeyDown", false)
		clicker:SetAttribute("type", "click")
		clicker:SetAttribute("clickbutton", EditModeSystemSettingsDialog.CloseButton)
		clicker:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then frame:SelectSystem() end end)
		clicker:SetScript("OnDragStart", function() frame:OnDragStart() end)
		clicker:SetScript("OnDragStop", function() frame:OnDragStop() end)
		clicker:SetScript("OnEnter", function() frame.Selection:OnEnter() end)
		clicker:SetScript("OnLeave", function() frame.Selection:OnLeave() end)
		frame.Selection.Clicker = clicker
	end

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
	icon.Cooldown:SetScript("OnCooldownDone", function(cooldown) if not cooldown.updating then CooldownManagerUtils:ScheduleReminderUpdate() end end)
	icon.Cooldown:SetScript("OnUpdate", function(cooldown, elapsed)
		if not cooldown.displayTime or cooldown.displayTime <= 0 then return end
		cooldown.displayElapsed = (cooldown.displayElapsed or 0) + elapsed
		if cooldown.displayElapsed < 0.1 then return end
		cooldown.displayElapsed = 0
		CooldownManagerUtils.UpdateCooldownDisplayAlpha(cooldown)
	end)
	icon.CountFrame = CreateFrame("Frame", nil, icon)
	icon.CountFrame:SetAllPoints()
	icon.CountFrame:SetFrameLevel(icon.Cooldown:GetFrameLevel() + 2)
	icon.GroupCount = icon.CountFrame:CreateFontString(nil, "OVERLAY", _G[ICON_COUNTDOWN_FONT] and ICON_COUNTDOWN_FONT or "NumberFontNormal")
	local groupCountFont, _, groupCountFlags = icon.GroupCount:GetFont()
	if groupCountFont then icon.GroupCount:SetFont(groupCountFont, GROUP_COUNT_FONT_SIZE, groupCountFlags) end
	icon.GroupCount:SetPoint("BOTTOMRIGHT", -2, 2)
	icon.GroupCount:Hide()
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

function CooldownManagerUtils:CreateReminderBar(reminderType)
	reminderType = reminderType or "buff"
	if self.reminderFrames[reminderType] then return self.reminderFrames[reminderType] end
	local nativeSelection = IsNativeSelectionAvailable()
	local template = nativeSelection and nil or "BackdropTemplate"
	local frameName = reminderType == "ability" and "CooldownManagerUtilsAbilityReminderFrame" or reminderType == "expiring" and "CooldownManagerUtilsExpiringReminderFrame" or "CooldownManagerUtilsReminderFrame"
	local frame = CreateFrame("Frame", frameName, UIParent, template)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame.icons = {}
	frame.reminderType = reminderType
	frame.labelKey = reminderType == "ability" and "LID_PROCREMINDER_EDITMODE" or reminderType == "expiring" and "LID_EXPIRINGBUFFS_EDITMODE" or "LID_BUFFREMINDERS_EDITMODE"
	self.reminderFrames[reminderType] = frame
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
		frame.Label:SetText(self:Trans(frame.labelKey))
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
		weaponEnchant = IsWeaponEnchantSpell(spellID),
		minimapTracking = MINIMAP_TRACKING_SPELLS[spellID] == true,
		paladinBlessing = IsPaladinBlessingSpell(spellID),
		paladinSeal = IsPaladinSealSpell(spellID),
		hunterAspect = IsHunterAspectSpell(spellID),
		reactiveAbility = CooldownManagerUtils.GetForeverReactiveAbilityFamily(spellID) ~= nil,
		groupBuff = IsPaladinBlessingSpell(spellID),
		candidates = {spellID}
	}
end

local function GetTrackedWeaponEnchantEntries(entry)
	local trackedEntries = {
		[entry.spellID] = entry
	}

	for spellID in pairs(CooldownManagerUtils:GetProfile().selected) do
		local trackedEntry = GetSavedEntry(spellID)
		if trackedEntry and trackedEntry.weaponEnchant then trackedEntries[trackedEntry.spellID] = trackedEntry end
	end
	return trackedEntries
end

local function GetWeaponEnchantState(entry)
	local current = GetTemporaryWeaponEnchants()
	if current.hasSecret then return nil end
	local trackedEntries = GetTrackedWeaponEnchantEntries(entry)
	local entryEnchantIDs = {}
	local entryKinds = {}
	local tracksShield = false
	for spellID, trackedEntry in pairs(trackedEntries) do
		entryEnchantIDs[spellID] = GetEntryWeaponEnchantIDs(trackedEntry)
		entryKinds[spellID] = IsShieldWeaponEnchantEntry(trackedEntry) and "shield" or "weapon"
		tracksShield = tracksShield or entryKinds[spellID] == "shield"
	end

	local knownEnchantIDs = GetKnownWeaponEnchantIDs()
	local activeEntries = {}
	local imbuedSlots = {}
	for _, enchant in ipairs(current) do
		local counts = not knownEnchantIDs[enchant.enchantID]
		for spellID, enchantIDs in pairs(entryEnchantIDs) do
			if enchantIDs[enchant.enchantID] then
				activeEntries[spellID] = true
				counts = true
			end
		end

		if counts then imbuedSlots[enchant.slot] = true end
	end

	local missingKinds = {}
	for slotName, inventorySlot in pairs(WEAPON_ENCHANT_REQUIRED_SLOTS) do
		local kind = GetEquippedWeaponEnchantSlotKind(inventorySlot)
		if kind == "shield" and not tracksShield then kind = nil end
		if kind and not imbuedSlots[slotName] then missingKinds[kind] = true end
	end

	local kind = entryKinds[entry.spellID]
	if not missingKinds[kind] then return true end
	if not activeEntries[entry.spellID] then return false end
	for spellID in pairs(trackedEntries) do
		if not activeEntries[spellID] and entryKinds[spellID] == kind then return true end
	end
	return false
end

local function IsAuraSecretNow(spellID)
	if not C_Secrets or type(C_Secrets.ShouldSpellAuraBeSecret) ~= "function" then return false end
	local ok, secret = pcall(C_Secrets.ShouldSpellAuraBeSecret, spellID)
	if not ok then return false end
	if IsSecret(secret) then return true end
	return secret == true
end

local function SetPaladinSealExpiration(expirationTime)
	if paladinSealExpiration == expirationTime then return end
	paladinSealExpiration = expirationTime
	if not expirationTime then return end
	C_Timer.After(math.max(expirationTime - GetTime(), 0) + TIMING.AURA_EXPIRY_GRACE, function() CooldownManagerUtils:ScheduleReminderUpdate() end)
end

local function TrackPaladinSealAura(aura)
	local expirationTime, duration = aura.expirationTime, aura.duration
	if IsSecret(expirationTime) or IsSecret(duration) then return end
	if type(duration) == "number" and duration > 0 then paladinSealDuration = duration end
	if type(expirationTime) ~= "number" or expirationTime <= 0 then expirationTime = nil end
	SetPaladinSealExpiration(expirationTime)
end

local function GetPaladinSealState()
	if not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function" then return end
	local unknown = false
	for _, spellID in ipairs(GetPaladinSealAuraSpells()) do
		if IsAuraSecretNow(spellID) then
			unknown = true
		else
			local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
			if not ok or IsSecret(aura) then
				unknown = true
			elseif aura then
				TrackPaladinSealAura(aura)
				paladinSealPresent = true
				return true
			end
		end
	end

	if unknown then
		if paladinSealExpiration and GetTime() >= paladinSealExpiration then
			paladinSealPresent = false
			SetPaladinSealExpiration(nil)
		end
		return paladinSealPresent
	end

	paladinSealPresent = false
	SetPaladinSealExpiration(nil)
	return false
end

local function SetHunterAspectExpiration(expirationTime)
	if hunterAspectExpiration == expirationTime then return end
	hunterAspectExpiration = expirationTime
	if not expirationTime then return end
	C_Timer.After(math.max(expirationTime - GetTime(), 0) + TIMING.AURA_EXPIRY_GRACE, function() CooldownManagerUtils:ScheduleReminderUpdate() end)
end

local function TrackHunterAspectAura(aura)
	local expirationTime, duration = aura.expirationTime, aura.duration
	if IsSecret(expirationTime) or IsSecret(duration) then return end
	if type(duration) == "number" and duration > 0 then hunterAspectDuration = duration end
	if type(expirationTime) ~= "number" or expirationTime <= 0 then expirationTime = nil end
	SetHunterAspectExpiration(expirationTime)
end

local function GetHunterAspectState()
	if not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function" then return end
	local unknown = false
	for _, spellID in ipairs(GetHunterAspectAuraSpells()) do
		if IsAuraSecretNow(spellID) then
			unknown = true
		else
			local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
			if not ok or IsSecret(aura) then
				unknown = true
			elseif aura then
				TrackHunterAspectAura(aura)
				hunterAspectPresent = true
				return true
			end
		end
	end

	if unknown then
		if hunterAspectExpiration and GetTime() >= hunterAspectExpiration then
			hunterAspectPresent = false
			SetHunterAspectExpiration(nil)
		end
		return hunterAspectPresent
	end

	hunterAspectPresent = false
	SetHunterAspectExpiration(nil)
	return false
end

local function SetAuraExpiration(entrySpellID, expirationTime)
	if auraExpirationCache[entrySpellID] == expirationTime then return end
	auraExpirationCache[entrySpellID] = expirationTime
	if not expirationTime then return end
	C_Timer.After(math.max(expirationTime - GetTime(), 0) + TIMING.AURA_EXPIRY_GRACE, function() CooldownManagerUtils:ScheduleReminderUpdate() end)
end

local function GetHitChargeAura(entry)
	if not hitChargeAuraBySpell then
		hitChargeAuraBySpell = {}
		local _, class = UnitClass("player")
		for _, definition in ipairs(HIT_CHARGE_AURAS[class] or {}) do
			for _, spellID in ipairs(definition.spells) do
				hitChargeAuraBySpell[spellID] = definition
			end
		end
	end

	local definition = hitChargeAuraBySpell[entry.spellID]
	for _, candidateSpellID in ipairs(entry.candidates) do
		definition = definition or hitChargeAuraBySpell[candidateSpellID]
	end
	return definition
end

function CooldownManagerUtils:TraceAuraCharges(spellID, reason, charges, detail)
	if not self.traceAuraCharges then return end
	print(string.format("CMU %.2f spell=%s %s charges=%s %s", GetTime(), tostring(spellID), reason, tostring(charges), detail or ""))
end

CooldownManagerUtils:AddSlash("cmucharges", function()
	CooldownManagerUtils.traceAuraCharges = not CooldownManagerUtils.traceAuraCharges
	print("CMU charge trace: " .. (CooldownManagerUtils.traceAuraCharges and "ON" or "OFF"))
end)

local function GetAuraChargeCount(aura)
	local count = 0
	for _, key in ipairs({"charges", "applications"}) do
		local value = aura[key]
		if not IsSecret(value) and type(value) == "number" and value > count then count = value end
	end
	return count
end

local function TrackAuraCharges(entry, aura)
	local definition = GetHitChargeAura(entry)
	if not definition then return end
	local state = auraChargeCache[entry.spellID]
	if state and state.refreshPendingUntil and GetTime() < state.refreshPendingUntil then return end
	local charges = GetAuraChargeCount(aura)
	if not state or state.charges ~= charges then CooldownManagerUtils:TraceAuraCharges(entry.spellID, "read", charges) end
	if charges <= 0 then
		auraChargeCache[entry.spellID] = nil
		return
	end

	local learnedCharges = GetLearnedAuras().charges
	learnedCharges[entry.spellID] = math.max(learnedCharges[entry.spellID] or 0, charges)
	state = state or {
		lockout = definition.lockout,
		lockoutUntil = 0,
		schoolMask = definition.schoolMask,
		healCrit = definition.healCrit
	}

	state.charges = charges
	auraChargeCache[entry.spellID] = state
end

local function ResetAuraCharges(entry)
	local definition = GetHitChargeAura(entry)
	local charges = definition and (definition.castCharges or GetLearnedAuras().charges[entry.spellID])
	if definition then CooldownManagerUtils:TraceAuraCharges(entry.spellID, "cast reset", charges) end
	auraChargeCache[entry.spellID] = charges and {
		charges = charges,
		lockout = definition.lockout,
		lockoutUntil = GetTime() + 0.5,
		schoolMask = definition.schoolMask,
		healCrit = definition.healCrit,
		refreshPendingUntil = GetTime() + 0.5
	} or nil
end

local function TrackAuraExpiration(entry, aura)
	TrackAuraCharges(entry, aura)
	local expirationTime, duration = aura.expirationTime, aura.duration
	if IsSecret(expirationTime) or IsSecret(duration) then return end
	if type(duration) == "number" and duration > 0 then GetLearnedAuras().durations[entry.spellID] = duration end
	if type(expirationTime) ~= "number" or expirationTime <= 0 then expirationTime = nil end
	SetAuraExpiration(entry.spellID, expirationTime)
end

local function GetMinimapTrackingState()
	if not C_Minimap or type(C_Minimap.GetNumTrackingTypes) ~= "function" or type(C_Minimap.GetTrackingFilter) ~= "function" or type(C_Minimap.GetTrackingInfo) ~= "function" then return nil end
	local countOK, count = pcall(C_Minimap.GetNumTrackingTypes)
	if not countOK or IsSecret(count) or type(count) ~= "number" then return nil end
	local found = false
	local unknown = false
	for index = 1, count do
		local filterOK, filter = pcall(C_Minimap.GetTrackingFilter, index)
		local infoOK, info = pcall(C_Minimap.GetTrackingInfo, index)
		if filterOK and infoOK and not IsSecret(filter) and not IsSecret(info) and type(filter) == "table" and type(info) == "table" then
			local spellID = filter.spellID or info.spellID
			if not IsSecret(spellID) and type(spellID) == "number" then
				found = true
				if IsSecret(info.active) then
					unknown = true
				elseif info.active == true then
					return true
				end
			end
		end
	end

	if found and not unknown then return false end
end

function CooldownManagerUtils.GetReactiveAbilityState(entry)
	local overlay = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
	if type(overlay) ~= "function" then overlay = nil end
	local isSpellUsable = CooldownManagerUtils.GetForeverReactiveAbilityFamily(entry.spellID) and (C_Spell and C_Spell.IsSpellUsable or _G.IsUsableSpell)
	if type(isSpellUsable) ~= "function" then isSpellUsable = nil end
	if not overlay and not isSpellUsable then return end
	local resolved = false
	for _, spellID in ipairs(entry.candidates) do
		if overlay then
			local ok, active = pcall(overlay, spellID)
			if ok and not IsSecret(active) then
				resolved = true
				if active == true then return true end
			end
		end

		if isSpellUsable then
			local ok, usable = pcall(isSpellUsable, spellID)
			if ok and not IsSecret(usable) then
				resolved = true
				if usable == true then return true end
			end
		end
	end

	if resolved then return false end
end

local function GetReadableAuraState(entry)
	if entry.reactiveAbility then return CooldownManagerUtils.GetReactiveAbilityState(entry) end
	if entry.minimapTracking then return GetMinimapTrackingState() end
	if entry.weaponEnchant then return GetWeaponEnchantState(entry) end
	if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return nil end
	local unknown = false
	for _, spellID in ipairs(entry.candidates) do
		if IsAuraSecretNow(spellID) then
			unknown = true
		else
			local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
			if not ok or IsSecret(aura) then
				unknown = true
			elseif aura then
				TrackAuraExpiration(entry, aura)
				return true
			end
		end
	end

	if entry.name and type(C_UnitAuras.GetAuraDataBySpellName) == "function" then
		local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", entry.name, "HELPFUL")
		if ok and not IsSecret(aura) and aura then
			TrackAuraExpiration(entry, aura)
			return true
		end
	end

	if unknown then return nil end
	SetAuraExpiration(entry.spellID, nil)
	auraChargeCache[entry.spellID] = nil
	return false
end

local function GetAuraState(entry)
	local present = GetReadableAuraState(entry)
	if present ~= nil or entry.weaponEnchant then return present end
	local chargeState = auraChargeCache[entry.spellID]
	if chargeState and chargeState.charges <= 0 then
		auraChargeCache[entry.spellID] = nil
		SetAuraExpiration(entry.spellID, nil)
		return false
	end

	local expirationTime = auraExpirationCache[entry.spellID]
	if not expirationTime or GetTime() < expirationTime then return nil end
	SetAuraExpiration(entry.spellID, nil)
	return false
end

local function GetGroupUnits()
	if IsInRaid() then
		local units = {}
		for index = 1, GetNumGroupMembers() do
			table.insert(units, "raid" .. index)
		end
		return units
	end

	if not IsInGroup() then return end
	local units = {"player"}
	for index = 1, GetNumSubgroupMembers() do
		table.insert(units, "party" .. index)
	end
	return units
end

local function IsGroupUnit(unit)
	return not IsSecret(unit) and type(unit) == "string" and (unit:find("^party%d") ~= nil or unit:find("^raid%d") ~= nil)
end

local function GetUnitFlag(unitFunction, unit)
	if type(unitFunction) ~= "function" then return end
	local ok, value = pcall(unitFunction, unit)
	if not ok or IsSecret(value) then return end
	return value and true or false
end

function CooldownManagerUtils.IsPlayerFlying()
	local ok, flying = pcall(IsFlying)
	if ok and not IsSecret(flying) and flying then return true end
	return GetUnitFlag(UnitOnTaxi, "player") == true
end

function CooldownManagerUtils.CheckFlyingState()
	local flying = CooldownManagerUtils.IsPlayerFlying()
	if flying == CooldownManagerUtils.playerFlying then return end
	CooldownManagerUtils.playerFlying = flying
	CooldownManagerUtils:ScheduleReminderUpdate()
end

function CooldownManagerUtils.EntryContainsSpell(entry, spellID)
	if entry.spellID == spellID then return true end
	for _, candidateSpellID in ipairs(entry.candidates) do
		if candidateSpellID == spellID then return true end
	end
	return false
end

function CooldownManagerUtils.IsForeverBattleShout(entry)
	return CooldownManagerUtils:IsForever() and CooldownManagerUtils.EntryContainsSpell(entry, 6673)
end

function CooldownManagerUtils.GetUnitSpecializationID(unit)
	if unit == "player" and type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
		local specializationIndex = GetSpecialization()
		if specializationIndex then
			local ok, specializationID = pcall(GetSpecializationInfo, specializationIndex)
			if ok and not IsSecret(specializationID) and type(specializationID) == "number" then return specializationID end
		end
	end

	local specializationInfo = C_SpecializationInfo
	if specializationInfo and type(specializationInfo.GetInspectSpecialization) == "function" then
		local ok, specializationID = pcall(specializationInfo.GetInspectSpecialization, unit)
		if ok and not IsSecret(specializationID) and type(specializationID) == "number" and specializationID > 0 then return specializationID end
	end
end

function CooldownManagerUtils.IsForeverBattleShoutUnitEligible(unit, entry)
	if not CooldownManagerUtils.IsForeverBattleShout(entry) then return true end
	local specializationID = CooldownManagerUtils.GetUnitSpecializationID(unit)
	if specializationID then return CooldownManagerUtils.foreverBattleShoutSpecs[specializationID] == true end
	local ok, _, class = pcall(UnitClass, unit)
	return ok and not IsSecret(class) and CooldownManagerUtils.foreverBattleShoutFallbackClasses[class] == true
end

function CooldownManagerUtils.IsUnitInForeverBattleShoutRange(unit)
	if unit == "player" then return true end
	if type(UnitDistanceSquared) == "function" then
		local ok, distanceSquared, checkedDistance = pcall(UnitDistanceSquared, unit)
		if ok and not IsSecret(distanceSquared) and not IsSecret(checkedDistance) and checkedDistance == true and type(distanceSquared) == "number" then return distanceSquared <= 529 end
	end

	if type(CheckInteractDistance) == "function" and (type(InCombatLockdown) ~= "function" or not InCombatLockdown()) then
		local ok, inRange = pcall(CheckInteractDistance, unit, 4)
		if ok and not IsSecret(inRange) then return inRange == true end
	end
	return false
end

local function IsUnitInBuffRange(unit, entry)
	if CooldownManagerUtils.IsForeverBattleShout(entry) then return CooldownManagerUtils.IsUnitInForeverBattleShoutRange(unit) end
	if unit == "player" or not C_Spell or type(C_Spell.IsSpellInRange) ~= "function" then return true end
	local checked = false
	local spellIDs = {entry.spellID}
	for _, spellID in ipairs(entry.candidates) do
		if spellID ~= entry.spellID then table.insert(spellIDs, spellID) end
	end

	for _, spellID in ipairs(spellIDs) do
		local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, unit)
		if ok and not IsSecret(inRange) and type(inRange) == "boolean" then
			checked = true
			if inRange then return true end
		end
	end
	return not checked
end

local function GetUnitPaladinBlessingState(unit)
	local unknown = false
	for _, spellID in ipairs(GetPaladinBlessingAuraSpells()) do
		if IsAuraSecretNow(spellID) then
			unknown = true
		else
			local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
			if not ok or IsSecret(aura) then
				unknown = true
			elseif aura then
				local sourceUnit = aura.sourceUnit
				if IsSecret(sourceUnit) then
					unknown = true
				elseif sourceUnit == "player" then
					return "present"
				end
			end
		end
	end
	return unknown and "unknown" or "missing"
end

function CooldownManagerUtils.GetUnitBuffState(unit, entry)
	if GetUnitFlag(UnitIsConnected, unit) == false or GetUnitFlag(UnitIsDeadOrGhost, unit) == true or GetUnitFlag(UnitIsVisible, unit) == false then return "unchecked" end
	if not CooldownManagerUtils.IsForeverBattleShoutUnitEligible(unit, entry) then return "unchecked" end
	if not IsUnitInBuffRange(unit, entry) then return "unchecked" end
	if entry.paladinBlessing then return GetUnitPaladinBlessingState(unit) end
	local unknown = false
	for _, spellID in ipairs(entry.candidates) do
		if IsAuraSecretNow(spellID) then
			unknown = true
		else
			local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
			if not ok or IsSecret(aura) then
				unknown = true
			elseif aura then
				return "present"
			end
		end
	end

	if entry.name and type(C_UnitAuras.GetAuraDataBySpellName) == "function" then
		local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, entry.name, "HELPFUL")
		if ok and not IsSecret(aura) and aura then return "present" end
	end
	return unknown and "unknown" or "missing"
end

function CooldownManagerUtils.GetTankShieldNames()
	local names = {}
	for _, spellID in ipairs({467, 2947, 8316}) do
		local info = GetReminderSpellInfo(spellID)
		if info and info.name then names[info.name] = true end
	end
	return names
end

function CooldownManagerUtils.UpdateTankShieldState(entry)
	entry.tankOnly = false
	local names = CooldownManagerUtils.GetTankShieldNames()
	if not names[entry.name] or not C_UnitAuras or type(C_UnitAuras.GetAuraDataBySpellName) ~= "function" or type(UnitGroupRolesAssigned) ~= "function" then return false end
	local units = GetGroupUnits() or {"player"}
	local tanks = {}
	for _, unit in ipairs(units) do
		local ok, role = pcall(UnitGroupRolesAssigned, unit)
		if ok and not IsSecret(role) and role == "TANK" and GetUnitFlag(UnitExists, unit) then table.insert(tanks, unit) end
	end
	if #tanks == 0 then return false end
	entry.tankOnly = true
	local total, have, missing, unknown = 0, 0, 0, false
	for _, unit in ipairs(tanks) do
		if GetUnitFlag(UnitIsConnected, unit) ~= false and GetUnitFlag(UnitIsDeadOrGhost, unit) ~= true and GetUnitFlag(UnitIsVisible, unit) ~= false and IsUnitInBuffRange(unit, entry) then
			total = total + 1
			local present, unreadable = false, false
			for name in pairs(names) do
				local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
				if not ok or IsSecret(aura) then
					unreadable = true
				elseif aura then
					present = true
				end
			end
			if present then
				have = have + 1
			elseif unreadable then
				unknown = true
			else
				missing = missing + 1
			end
		end
	end
	local cached = groupBuffCache[entry.spellID]
	if not unknown or missing > 0 then
		groupBuffCache[entry.spellID] = {total = total, have = have, missing = missing, tankOnly = true}
	elseif not cached or not cached.tankOnly then
		groupBuffCache[entry.spellID] = nil
	end
	return true
end

function CooldownManagerUtils.UpdateGroupBuffState(entry, sharedPaladinState, checkGroupBuffs)
	if CooldownManagerUtils.UpdateTankShieldState(entry) then return end
	if entry.paladinBlessing and sharedPaladinState and sharedPaladinState.resolved then
		groupBuffCache[entry.spellID] = sharedPaladinState.state
		return
	end

	local units = checkGroupBuffs ~= false and entry.groupBuff and C_UnitAuras and type(C_UnitAuras.GetUnitAuraBySpellID) == "function" and GetGroupUnits()
	if not units then
		groupBuffCache[entry.spellID] = nil
		if entry.paladinBlessing and sharedPaladinState then
			sharedPaladinState.resolved = true
			sharedPaladinState.state = nil
		end
		return
	end

	local total, have, missing, unknown = 0, 0, 0, false
	for _, unit in ipairs(units) do
		if GetUnitFlag(UnitExists, unit) then
			local state = CooldownManagerUtils.GetUnitBuffState(unit, entry)
			if state ~= "unchecked" then total = total + 1 end
			if state == "present" then
				have = have + 1
			elseif state == "missing" then
				missing = missing + 1
			elseif state == "unknown" then
				unknown = true
			end
		end
	end

	local cached = groupBuffCache[entry.spellID]
	if unknown then
		if cached then
			cached.total = total
			cached.have = math.min(cached.have, total)
		end

		if entry.paladinBlessing and sharedPaladinState then
			sharedPaladinState.resolved = true
			sharedPaladinState.state = cached
		end
		return
	end

	local state = {
		total = total,
		have = have,
		missing = missing
	}

	groupBuffCache[entry.spellID] = state
	if entry.paladinBlessing and sharedPaladinState then
		sharedPaladinState.resolved = true
		sharedPaladinState.state = state
	end
end

function CooldownManagerUtils.IsGroupBuffMissing(entry)
	local state = groupBuffCache[entry.spellID]
	return state ~= nil and state.missing > 0
end

function CooldownManagerUtils.EntryMatchesSpell(entry, spellID, spellName)
	if entry.spellID == spellID or (spellName and entry.name == spellName) then return true end
	for _, candidateSpellID in ipairs(entry.candidates) do
		if candidateSpellID == spellID then return true end
	end
	return false
end

function CooldownManagerUtils.GetSpellCooldownState(spellID)
	if not C_Spell then return false end
	if C_Spell.GetSpellCooldownDuration then
		local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
		if ok and duration and duration.IsZero then
			local zeroOK, isZero = pcall(duration.IsZero, duration)
			if zeroOK and not IsSecret(isZero) then
				if isZero then return false end
				return true, duration
			end

			if zeroOK then return false, duration, nil, nil, nil, true, isZero end
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

function CooldownManagerUtils.CanGlowReactiveAbility(entry)
	local isSpellUsable = C_Spell and C_Spell.IsSpellUsable or _G.IsUsableSpell
	if type(isSpellUsable) ~= "function" then return false end
	for _, spellID in ipairs(entry.candidates) do
		local ok, usable, insufficientPower = pcall(isSpellUsable, spellID)
		if ok and not IsSecret(usable) and usable == true and not IsSecret(insufficientPower) and insufficientPower ~= true then
			local onCooldown, _, _, _, _, secret = CooldownManagerUtils.GetSpellCooldownState(spellID)
			if not onCooldown and not secret then return true end
		end
	end
	return false
end

function CooldownManagerUtils.HasInsufficientPower(spellID)
	local isSpellUsable = C_Spell and C_Spell.IsSpellUsable or _G.IsUsableSpell
	if type(isSpellUsable) ~= "function" then return false end
	local ok, _, insufficientPower = pcall(isSpellUsable, spellID)
	if not ok or IsSecret(insufficientPower) then return false end
	return insufficientPower == true
end

function CooldownManagerUtils.IsCooldownAboveDisplayTime(spellID, threshold)
	if not threshold or threshold <= 0 then return false end
	local onCooldown, durationObject, startTime, duration, modRate = CooldownManagerUtils.GetSpellCooldownState(spellID)
	local remaining
	if durationObject and durationObject.GetRemainingDuration then
		local ok, value = pcall(durationObject.GetRemainingDuration, durationObject)
		if ok and not IsSecret(value) and type(value) == "number" then remaining = value end
	elseif onCooldown and startTime and duration then
		remaining = startTime + duration / (modRate or 1) - GetTime()
	end
	if not remaining or remaining <= threshold then return false end
	local at = GetTime() + remaining - threshold
	local addon = CooldownManagerUtils
	addon.cooldownDisplayUpdates = addon.cooldownDisplayUpdates or {}
	local pending = addon.cooldownDisplayUpdates[spellID]
	if not pending or at < pending - 0.05 then
		addon.cooldownDisplayUpdates[spellID] = at
		C_Timer.After(math.max(at - GetTime(), 0) + 0.01, function()
			if CooldownManagerUtils.cooldownDisplayUpdates[spellID] ~= at then return end
			CooldownManagerUtils.cooldownDisplayUpdates[spellID] = nil
			CooldownManagerUtils:ScheduleReminderUpdate()
		end)
	end
	return true
end

function CooldownManagerUtils.UpdateCooldownDisplayAlpha(cooldown)
	local threshold = cooldown.displayTime or 0
	local target = cooldown:GetParent()
	cooldown:SetAlpha(threshold > 0 and 1 or 0)
	if threshold <= 0 or not cooldown.filterIcon or not cooldown.displayDuration and not cooldown.displayEndTime then target:SetAlpha(1) return end
	local durationObject = cooldown.displayDuration
	if durationObject and durationObject.EvaluateRemainingDuration and C_CurveUtil and C_CurveUtil.CreateCurve then
		if cooldown.displayCurveThreshold ~= threshold then
			local curve = C_CurveUtil.CreateCurve()
			curve:AddPoint(0, 1)
			curve:AddPoint(threshold, 1)
			curve:AddPoint(threshold + 0.001, 0)
			cooldown.displayCurve = curve
			cooldown.displayCurveThreshold = threshold
		end
		local ok, alpha = pcall(durationObject.EvaluateRemainingDuration, durationObject, cooldown.displayCurve)
		if ok and pcall(target.SetAlpha, target, alpha) then return end
	end
	local remaining
	if durationObject and durationObject.GetRemainingDuration then
		local ok, value = pcall(durationObject.GetRemainingDuration, durationObject)
		if ok and not IsSecret(value) and type(value) == "number" then remaining = value end
	elseif cooldown.displayEndTime then
		remaining = cooldown.displayEndTime - GetTime()
	end
	target:SetAlpha(remaining and remaining <= threshold and 1 or 0)
end

function CooldownManagerUtils.UpdateIconCooldown(icon, spellID, showTimer, displayTime)
	local cooldown = icon.Cooldown
	cooldown.updating = true
	cooldown:SetHideCountdownNumbers(not showTimer)
	local onCooldown, durationObject, startTime, duration, modRate, isSecret, secretIsZero = CooldownManagerUtils.GetSpellCooldownState(spellID)
	cooldown.displayTime = displayTime or 0
	cooldown.filterIcon = showTimer and not editModeActive
	cooldown.displayDuration = durationObject
	cooldown.displayEndTime = startTime and duration and startTime + duration / (modRate or 1) or nil
	cooldown.displayElapsed = 0
	CooldownManagerUtils.UpdateCooldownDisplayAlpha(cooldown)
	if (onCooldown or isSecret) and durationObject and cooldown.SetCooldownFromDurationObject then
		cooldown:SetCooldownFromDurationObject(durationObject)
	elseif onCooldown and startTime then
		cooldown:SetCooldown(startTime, duration, modRate or 1)
	else
		cooldown:Clear()
	end

	cooldown.updating = nil
	return onCooldown, isSecret, secretIsZero
end

function CooldownManagerUtils.SetIconDesaturation(texture, desaturated, isSecret, secretIsZero)
	if desaturated or not isSecret then
		texture:SetDesaturated(desaturated == true)
		return
	end

	local evaluate = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
	if type(evaluate) ~= "function" then
		texture:SetDesaturated(false)
		return
	end

	local ok, value = pcall(evaluate, secretIsZero, 0, 1)
	if not ok or not pcall(texture.SetDesaturation, texture, value) then texture:SetDesaturated(false) end
end

function CooldownManagerUtils.UpdateIconGlow(icon, show, birth)
	local alert = icon.SpellAlert
	if not show then
		if alert then
			alert.ProcStartAnim:Stop()
			alert.ProcLoop:Stop()
			alert:Hide()
		end
		return
	end

	if not alert then
		alert = CreateFrame("Frame", nil, icon, "ActionButtonSpellAlertTemplate")
		alert:SetSize(ICON_SIZE * 1.4, ICON_SIZE * 1.4)
		alert:SetPoint("CENTER")
		alert:SetFrameLevel(icon.Cooldown:GetFrameLevel() + 1)
		alert:HookScript("OnShow", function(self) if not self.ProcStartAnim:IsPlaying() and not self.ProcLoop:IsPlaying() then self.ProcLoop:Play() end end)
		icon.SpellAlert = alert
		birth = true
	end

	if not alert:IsShown() then
		alert:Show()
		birth = true
	end

	if not alert:IsVisible() then return end
	if birth then
		alert.ProcLoop:Stop()
		alert.ProcStartAnim:Play()
	elseif not alert.ProcStartAnim:IsPlaying() and not alert.ProcLoop:IsPlaying() then
		alert.ProcLoop:Play()
	end
end

function CooldownManagerUtils.ScheduleExpiryWarning(warningAt)
	local pending = CooldownManagerUtils.expiryWarningAt
	if pending and pending > GetTime() and pending <= warningAt then return end
	CooldownManagerUtils.expiryWarningAt = warningAt
	C_Timer.After(math.max(warningAt - GetTime(), 0) + TIMING.AURA_EXPIRY_GRACE, function()
		if CooldownManagerUtils.expiryWarningAt == warningAt then CooldownManagerUtils.expiryWarningAt = nil end
		CooldownManagerUtils:ScheduleReminderUpdate()
	end)
end

function CooldownManagerUtils:UpdateReminderBarType(reminderType)
	local frame = self:CreateReminderBar(reminderType)
	local visibleSetting = frame.visibleSetting
	local visibilityAllowed = true
	if Enum and Enum.CooldownViewerVisibleSetting then
		if visibleSetting == Enum.CooldownViewerVisibleSetting.InCombat then
			visibilityAllowed = InCombatLockdown() and true or false
		elseif visibleSetting == Enum.CooldownViewerVisibleSetting.Hidden then
			visibilityAllowed = false
		end
	end

	if not editModeActive and not visibilityAllowed then frame:Hide() end
	local selected = self:GetProfile().selected
	local entries = {}
	local seenEntries = {}
	local sharedPaladinState = {}
	local sharedPaladinSealState = {}
	local sharedHunterAspectState = {}
	local sharedMinimapTrackingState = {}
	local expiringEntries = {}
	local warningTime = reminderType == "expiring" and self:GetExpiryWarningTime()
	local layouts = self:GetProfile().layout
	if editModeActive or (GetUnitFlag(UnitIsDeadOrGhost, "player") ~= true and not self.IsPlayerFlying()) then
		for spellID in pairs(selected) do
			local entry = GetSavedEntry(spellID)
			local entryLayout = entry and layouts[entry.spellID]
			local entryBarType = entry and (entry.reactiveAbility and "ability" or entryLayout and entryLayout.category == "expiringBuff" and "expiring" or "buff")
			if entry and entry.isLearned ~= false and entryBarType == reminderType and not seenEntries[entry] then
				seenEntries[entry] = true
				local present = GetAuraState(entry)
				if present ~= nil then presenceCache[entry.spellID] = present end
				CooldownManagerUtils.UpdateGroupBuffState(entry, sharedPaladinState, frame.checkGroupBuffs)
				local show
				if entry.reactiveAbility then
					show = presenceCache[entry.spellID] == true
				else
					show = presenceCache[entry.spellID] == false or CooldownManagerUtils.IsGroupBuffMissing(entry)
				end

				if entry.tankOnly or entry.paladinBlessing and frame.checkGroupBuffs and IsInGroup() then show = CooldownManagerUtils.IsGroupBuffMissing(entry) end
				if entry.paladinSeal then
					if not sharedPaladinSealState.resolved then
						sharedPaladinSealState.present = GetPaladinSealState()
						sharedPaladinSealState.resolved = true
					end

					if sharedPaladinSealState.present ~= nil then show = not sharedPaladinSealState.present end
				end

				if entry.hunterAspect then
					if not sharedHunterAspectState.resolved then
						sharedHunterAspectState.present = GetHunterAspectState()
						sharedHunterAspectState.resolved = true
					end

					if sharedHunterAspectState.present ~= nil then show = not sharedHunterAspectState.present end
				end

				if entry.minimapTracking then
					if not sharedMinimapTrackingState.resolved then
						sharedMinimapTrackingState.present = GetMinimapTrackingState()
						sharedMinimapTrackingState.resolved = true
					end

					if sharedMinimapTrackingState.present ~= nil then show = not sharedMinimapTrackingState.present end
				end

				if not show and warningTime and not entry.reactiveAbility then
					local expirationTime, duration
					if entry.paladinSeal then
						expirationTime, duration = sharedPaladinSealState.present and paladinSealExpiration, paladinSealDuration
					elseif entry.hunterAspect then
						expirationTime, duration = sharedHunterAspectState.present and hunterAspectExpiration, hunterAspectDuration
					elseif not entry.tankOnly and not entry.minimapTracking and not entry.weaponEnchant and presenceCache[entry.spellID] == true then
						expirationTime, duration = auraExpirationCache[entry.spellID], GetLearnedAuras().durations[entry.spellID]
					end

					local remaining = expirationTime and expirationTime - GetTime()
					if remaining and remaining > 0 then
						if remaining <= warningTime then
							show = true
							if not duration or duration < remaining then duration = remaining end
							if duration > warningTime then duration = warningTime end
							expiringEntries[entry] = {
								expirationTime = expirationTime,
								duration = duration
							}
						else
							CooldownManagerUtils.ScheduleExpiryWarning(expirationTime - warningTime)
						end
					end
				end

				if not editModeActive and show and frame.showTimer and not expiringEntries[entry] and CooldownManagerUtils.IsCooldownAboveDisplayTime(entry.spellID, frame.cooldownDisplayTime) then show = false end
				if editModeActive or show then table.insert(entries, entry) end
			end
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

	local glowingSpells = {}
	local previousGlowingSpells = frame.glowingSpells or {}
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

		local expiring = expiringEntries[entry]
		local previewPresent = editModeActive and not expiring and not entry.reactiveAbility and presenceCache[entry.spellID] == true and not CooldownManagerUtils.IsGroupBuffMissing(entry)
		local onCooldown, cooldownSecret, cooldownSecretIsZero
		if expiring then
			icon.Cooldown.displayTime = 0
			icon:SetAlpha(1)
			icon.Cooldown:SetAlpha(1)
			icon.Cooldown:SetHideCountdownNumbers(false)
			icon.Cooldown:SetCooldown(expiring.expirationTime - expiring.duration, expiring.duration)
		else
			onCooldown, cooldownSecret, cooldownSecretIsZero = CooldownManagerUtils.UpdateIconCooldown(icon, entry.spellID, frame.showTimer ~= false, frame.cooldownDisplayTime)
		end

		icon.Texture:SetTexture(entry.iconID)
		CooldownManagerUtils.SetIconDesaturation(icon.Texture, previewPresent or onCooldown or CooldownManagerUtils.HasInsufficientPower(entry.spellID), cooldownSecret, cooldownSecretIsZero)
		icon.Texture:SetAlpha(previewPresent and 0.5 or 1)
		icon:SetMouseClickEnabled(false)
		icon:SetMouseMotionEnabled(frame.showTooltips ~= false)
		icon.spellID = entry.spellID
		local groupState = groupBuffCache[entry.spellID]
		icon.GroupCount:SetText(entry.tankOnly and "Tank" or groupState and (groupState.have .. "/" .. groupState.total) or "")
		icon.GroupCount:SetShown(entry.tankOnly or groupState ~= nil)
		icon:Show()
		local glow = (editModeActive or visibilityAllowed) and frame.showGlow and not previewPresent and not onCooldown and not expiring
		if entry.reactiveAbility and not editModeActive then glow = glow and not cooldownSecret and CooldownManagerUtils.CanGlowReactiveAbility(entry) end
		if glow then glowingSpells[entry.spellID] = true end
		CooldownManagerUtils.UpdateIconGlow(icon, glow, not previousGlowingSpells[entry.spellID])
	end

	frame.glowingSpells = glowingSpells
	for index = #entries + 1, #frame.icons do
		CooldownManagerUtils.UpdateIconGlow(frame.icons[index], false)
		frame.icons[index]:Hide()
	end

	local extent = #entries > 0 and FRAME_PADDING * 2 + #entries * iconSize + (#entries - 1) * iconPadding or 180
	frame:SetSize(horizontal and extent or iconSize + FRAME_PADDING * 2, horizontal and iconSize + FRAME_PADDING * 2 or extent)
	if frame.Label then frame.Label:SetShown(editModeActive and #entries == 0) end
	if frame.SetBackdropColor then frame:SetBackdropColor(0.05, 0.15, 0.25, editModeActive and 0.65 or 0) end
	if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.2, 0.65, 1, editModeActive and 1 or 0) end
	if not frame.Selection then frame:EnableMouse(editModeActive) end
	frame:SetShown(editModeActive or (#entries > 0 and visibilityAllowed))
end

function CooldownManagerUtils:UpdateReminderBar()
	self:UpdateReminderBarType("buff")
	self:UpdateReminderBarType("expiring")
	if self:HasReactiveAbilities() then self:UpdateReminderBarType("ability") end
end

function CooldownManagerUtils:ScheduleReminderUpdate()
	if updatePending then return end
	updatePending = true
	C_Timer.After(0, function()
		updatePending = false
		CooldownManagerUtils:UpdateReminderBar()
	end)
end

function CooldownManagerUtils:ScheduleGroupBuffUpdate()
	if groupUpdatePending then return end
	groupUpdatePending = true
	C_Timer.After(TIMING.GROUP_BUFF_UPDATE_DELAY, function()
		groupUpdatePending = false
		CooldownManagerUtils:ScheduleReminderUpdate()
	end)
end

function CooldownManagerUtils:OnWeaponEnchantUpdate(silent)
	RecordWeaponEnchantChanges(silent)
	if not silent and MatchWeaponEnchantLearning() then self:RefreshAvailableBuffs() end
	self:ScheduleReminderUpdate()
end

function CooldownManagerUtils:OnPlayerSpellCast(spellID)
	if IsSecret(spellID) or type(spellID) ~= "number" then return end
	local spellName = GetSpellNameSafe(spellID)
	if GetWeaponEnchantCatalogFamily(spellID, spellName) then
		table.insert(recentPlayerCasts, {
			spellID = spellID,
			name = spellName,
			time = GetTime()
		})
	end

	if MatchWeaponEnchantLearning() then self:RefreshAvailableBuffs() end
	C_Timer.After(0.3, function() CooldownManagerUtils:OnWeaponEnchantUpdate() end)
	local changed = false
	local castTime = GetTime()
	if IsPaladinSealSpell(spellID) then
		paladinSealPresent = true
		SetPaladinSealExpiration(paladinSealDuration and castTime + paladinSealDuration or nil)
		changed = true
	end

	if IsHunterAspectSpell(spellID) then
		hunterAspectPresent = true
		SetHunterAspectExpiration(hunterAspectDuration and castTime + hunterAspectDuration or nil)
		changed = true
	end

	for selectedSpellID in pairs(self:GetProfile().selected) do
		local entry = GetSavedEntry(selectedSpellID)
		if entry and CooldownManagerUtils.EntryMatchesSpell(entry, spellID, spellName) and (GetReadableAuraState(entry) == nil or (GetHitChargeAura(entry) and GetHitChargeAura(entry).castCharges)) then
			presenceCache[entry.spellID] = true
			changed = true
			local groupState = groupBuffCache[entry.spellID]
			if groupState and not entry.tankOnly and not entry.paladinBlessing then
				groupState.have = groupState.total
				groupState.missing = 0
			end

			if not entry.weaponEnchant then
				local duration = GetLearnedAuras().durations[entry.spellID]
				SetAuraExpiration(entry.spellID, duration and castTime + duration or nil)
				ResetAuraCharges(entry)
			end
		end
	end

	if changed then self:ScheduleReminderUpdate() end
end

function CooldownManagerUtils:OnPlayerCombatEvent(action, schoolMask)
	if IsSecret(action) or (action ~= "WOUND" and action ~= "HEAL_CRIT") then return end
	local now = GetTime()
	local changed = false
	for spellID, state in pairs(auraChargeCache) do
		if (action == "WOUND" or state.healCrit) and state.charges > 0 and now >= state.lockoutUntil and (not state.schoolMask or not IsSecret(schoolMask) and schoolMask == state.schoolMask) then
			state.charges = state.charges - 1
			self:TraceAuraCharges(spellID, action .. " counted", state.charges, "school=" .. (IsSecret(schoolMask) and "secret" or tostring(schoolMask)))
			state.lockoutUntil = now + state.lockout
			changed = true
		elseif (action == "WOUND" or state.healCrit) and state.charges > 0 then
			self:TraceAuraCharges(spellID, action .. " ignored", state.charges, string.format("lockout=%.2f", math.max(state.lockoutUntil - now, 0)))
		end
	end

	if changed then self:ScheduleReminderUpdate() end
end

function CooldownManagerUtils:OnCriticalHealCombatLog()
	if not self:IsForever() or type(CombatLogGetCurrentEventInfo) ~= "function" then return end
	if C_CombatLog and C_CombatLog.IsCombatLogRestricted and C_CombatLog.IsCombatLogRestricted() then return end
	local ok, _, subevent, _, sourceGUID, _, _, _, _, _, _, _, _, _, _, _, _, _, critical = pcall(CombatLogGetCurrentEventInfo)
	if not ok or IsSecret(subevent) or (subevent ~= "SPELL_HEAL" and subevent ~= "SPELL_PERIODIC_HEAL") then return end
	if IsSecret(sourceGUID) or IsSecret(critical) or critical ~= true then return end
	local playerGUID = UnitGUID("player")
	if IsSecret(playerGUID) or not playerGUID or sourceGUID ~= playerGUID then return end
	self:OnPlayerCombatEvent("HEAL_CRIT")
end

function CooldownManagerUtils:OnPlayerAuraUpdate(updateInfo)
	local learnedNew = false
	if not IsSecret(updateInfo) and type(updateInfo) == "table" then
		local isFullUpdate = updateInfo.isFullUpdate
		local addedAuras = updateInfo.addedAuras
		if not IsSecret(isFullUpdate) and isFullUpdate == true then
			learnedNew = LearnCurrentPlayerAuras()
		elseif not IsSecret(addedAuras) and type(addedAuras) == "table" then
			for _, aura in ipairs(addedAuras) do
				if LearnPlayerAura(aura) then learnedNew = true end
			end
		end
	end

	if learnedNew then self:RefreshAvailableBuffs() end
	self:ScheduleReminderUpdate()
end

function CooldownManagerUtils.SetEditModeActive(active)
	editModeActive = active
	CooldownManagerUtils:UpdateReminderBar()
	if active then RefreshSnapTargets() end
	for _, frame in pairs(CooldownManagerUtils.reminderFrames) do
		if frame.Selection then
			if active then
				frame:HighlightSystem()
			else
				frame:ClearHighlight()
				frame:SetScript("OnUpdate", nil)
				frame:StopMovingOrSizing()
			end
		end
	end

	if not active then
		StopSnapTargetScan()
		wipe(snapTargets)
		wipe(snapTargetLookup)
		HideSnapPreview()
		if reminderOptionsFrame then reminderOptionsFrame:Hide() end
	end
end

function CooldownManagerUtils:OnEditModeLayoutChanged()
	local _, changed = ResolveActiveLayoutData()
	if not changed then return end
	if reminderOptionsFrame and reminderOptionsFrame:IsShown() then reminderOptionsFrame:Hide() end
	for _, frame in pairs(self.reminderFrames) do
		frame.snapTarget = nil
		RestorePosition(frame)
		ApplyReminderSettings(frame)
	end
end

function CooldownManagerUtils:ScheduleEditModeLayoutCheck()
	C_Timer.After(0, function() CooldownManagerUtils:OnEditModeLayoutChanged() end)
end

function CooldownManagerUtils:Initialize()
	if not IsSupportedClient() then return end
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	self:CreateReminderBar("buff")
	self:CreateReminderBar("expiring")
	if self:HasReactiveAbilities() then self:CreateReminderBar("ability") end
	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Enter", function() CooldownManagerUtils.SetEditModeActive(true) end, self)
		EventRegistry:RegisterCallback("EditMode.Exit", function() CooldownManagerUtils.SetEditModeActive(false) end, self)
	end

	self:InitializeReminderSettings()
	self:InitMinimapButton()
	PruneLearnedWeaponEnchants()
	self:RefreshAvailableBuffs()
	self:UpdateReminderBar()
	self:ScheduleCooldownManagerLayoutCheck()
	C_Timer.NewTicker(TIMING.GROUP_BUFF_REFRESH_INTERVAL, function() if IsInGroup() then CooldownManagerUtils:ScheduleGroupBuffUpdate() end end)
	self.playerFlying = self.IsPlayerFlying()
	C_Timer.NewTicker(0.25, self.CheckFlyingState)
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
	eventFrame:RegisterEvent("PLAYER_DEAD")
	eventFrame:RegisterEvent("PLAYER_ALIVE")
	eventFrame:RegisterEvent("PLAYER_UNGHOST")
	eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	eventFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
	eventFrame:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
	eventFrame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
	pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_COMBAT", "player")
	if CooldownManagerUtils:IsForever() and type(CombatLogGetCurrentEventInfo) == "function" and (not C_CombatLog or not C_CombatLog.IsCombatLogRestricted or not C_CombatLog.IsCombatLogRestricted()) then pcall(eventFrame.RegisterEvent, eventFrame, "COMBAT_LOG_EVENT_UNFILTERED") end
	eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_CONNECTION")
	pcall(eventFrame.RegisterEvent, eventFrame, "WEAPON_ENCHANT_CHANGED")
	pcall(eventFrame.RegisterEvent, eventFrame, "ACTIONBAR_UPDATE_USABLE")
	pcall(eventFrame.RegisterEvent, eventFrame, "SPELL_UPDATE_USABLE")
	pcall(eventFrame.RegisterEvent, eventFrame, "SPELL_ACTIVATION_OVERLAY_SHOW")
	pcall(eventFrame.RegisterEvent, eventFrame, "SPELL_ACTIVATION_OVERLAY_HIDE")
	pcall(eventFrame.RegisterEvent, eventFrame, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
	pcall(eventFrame.RegisterEvent, eventFrame, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
	pcall(eventFrame.RegisterEvent, eventFrame, "ADDON_RESTRICTION_STATE_CHANGED")
	pcall(eventFrame.RegisterEvent, eventFrame, "EDIT_MODE_LAYOUTS_UPDATED")
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		CooldownManagerUtils:Initialize()
	elseif event == "UNIT_AURA" then
		local unit, updateInfo = ...
		if unit == "player" then
			CooldownManagerUtils:OnPlayerAuraUpdate(updateInfo)
		elseif IsGroupUnit(unit) then
			CooldownManagerUtils:ScheduleGroupBuffUpdate()
		end
	elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_CONNECTION" then
		CooldownManagerUtils:ScheduleGroupBuffUpdate()
	elseif event == "MINIMAP_UPDATE_TRACKING" then
		CooldownManagerUtils:ScheduleReminderUpdate()
	elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
		CooldownManagerUtils:ScheduleReminderUpdate()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, _, spellID = ...
		CooldownManagerUtils:OnPlayerSpellCast(spellID)
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		CooldownManagerUtils:OnCriticalHealCombatLog()
	elseif event == "UNIT_COMBAT" then
		local _, action, _, _, schoolMask = ...
		CooldownManagerUtils:OnPlayerCombatEvent(action, schoolMask)
	elseif event == "WEAPON_ENCHANT_CHANGED" then
		CooldownManagerUtils:OnWeaponEnchantUpdate()
	elseif event == "UNIT_INVENTORY_CHANGED" then
		local unit = ...
		if unit == "player" then CooldownManagerUtils:OnWeaponEnchantUpdate() end
	elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
		CooldownManagerUtils:ScheduleEditModeLayoutCheck()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		CooldownManagerUtils:OnWeaponEnchantUpdate(true)
	elseif event == "PLAYER_ENTERING_WORLD" then
		CooldownManagerUtils:OnWeaponEnchantUpdate(true)
		CooldownManagerUtils:ScheduleEditModeLayoutCheck()
		CooldownManagerUtils:ScheduleCooldownManagerLayoutCheck()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		CooldownManagerUtils:RefreshAvailableBuffs()
		CooldownManagerUtils:ScheduleEditModeLayoutCheck()
		CooldownManagerUtils:ScheduleCooldownManagerLayoutCheck()
	elseif event == "COOLDOWN_VIEWER_DATA_LOADED" then
		CooldownManagerUtils:RefreshAvailableBuffs()
		CooldownManagerUtils:ScheduleCooldownManagerLayoutCheck()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if CooldownManagerUtils.pendingSourceRefresh then CooldownManagerUtils:RefreshAvailableBuffs() end
		CooldownManagerUtils:ScheduleReminderUpdate()
	elseif event == "PLAYER_REGEN_DISABLED" or event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE" or event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_HIDE" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" or event == "ADDON_RESTRICTION_STATE_CHANGED" then
		CooldownManagerUtils:ScheduleReminderUpdate()
	else
		CooldownManagerUtils:RefreshAvailableBuffs()
	end
end)
