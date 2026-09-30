local _, CooldownManagerUtils = ...
local optionsWindow = nil
local ICON = 134376
local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 320
local OPTION_DEFAULTS = {
	EXPIRYWARNINGTIME = 5
}

function CooldownManagerUtils:GetOptions()
	CooldownManagerUtilsDB = CooldownManagerUtilsDB or {}
	CooldownManagerUtilsDB.options = CooldownManagerUtilsDB.options or {}
	return CooldownManagerUtilsDB.options
end

function CooldownManagerUtils:GetOption(key)
	local value = self:GetOptions()[key]
	if value == nil then return OPTION_DEFAULTS[key] end
	return value
end

function CooldownManagerUtils:GetExpiryWarningTime()
	local seconds = tonumber(self:GetOption("EXPIRYWARNINGTIME"))
	if not seconds or seconds <= 0 then return nil end
	return seconds
end

function CooldownManagerUtils:ToggleOptions()
	if not optionsWindow then self:InitOptions() end
	if not optionsWindow then return end
	optionsWindow:Toggle()
	if optionsWindow:IsShown() then optionsWindow:Raise() end
end

local function GetVersionText()
	local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
	local version = getMetadata and getMetadata("CooldownManagerUtils", "Version")
	return version and (" v" .. version) or ""
end

local function SetOption(key, value)
	CooldownManagerUtils:GetOptions()[key] = value
	CooldownManagerUtils:ScheduleReminderUpdate()
end

function CooldownManagerUtils:InitOptions()
	if optionsWindow then return end
	local options = self:GetOptions()
	optionsWindow = self:CreateUIWindow({
		["name"] = "CooldownManagerUtilsOptions",
		["pTab"] = {"CENTER"},
		["width"] = self:GV(options, "WINDOWWIDTH", DEFAULT_WIDTH),
		["height"] = self:GV(options, "WINDOWHEIGHT", DEFAULT_HEIGHT),
		["minWidth"] = 360,
		["minHeight"] = 240,
		["onResize"] = function(width, height)
			CooldownManagerUtils:SV(options, "WINDOWWIDTH", width)
			CooldownManagerUtils:SV(options, "WINDOWHEIGHT", height)
		end,
		["title"] = format("|T%d:16:16:0:0|t Cooldown Manager Utils%s", ICON, GetVersionText())
	})

	optionsWindow:SuspendLayout()
	optionsWindow:AddSearch()
	optionsWindow:AddCategory({
		["label"] = "LID_GENERAL",
		["key"] = "GENERAL",
		["search"] = "GENERAL"
	})

	optionsWindow.minimapCheckbox = optionsWindow:AddCheckbox({
		["label"] = "LID_MMBTN",
		["search"] = "MMBTN",
		["added"] = "2026-09-30",
		["value"] = self:GV(options, "MMBTN", self:GetWoWBuild() ~= "RETAIL"),
		["func"] = function(value)
			CooldownManagerUtils:SV(options, "MMBTN", value)
			if value then
				CooldownManagerUtils:ShowMMBtn("CooldownManagerUtils")
			else
				CooldownManagerUtils:HideMMBtn("CooldownManagerUtils")
			end
		end
	})

	optionsWindow:AddCategory({
		["label"] = "LID_BUFFREMINDERS_CATEGORY_EXPIRING",
		["key"] = "EXPIRINGBUFFS",
		["search"] = "EXPIRINGBUFFS"
	})

	optionsWindow:AddSlider({
		["label"] = "LID_EXPIRYWARNINGTIME",
		["search"] = "EXPIRYWARNINGTIME",
		["added"] = "2026-09-30",
		["value"] = self:GetOption("EXPIRYWARNINGTIME"),
		["min"] = 1,
		["max"] = 60,
		["step"] = 1,
		["decimals"] = 0,
		["func"] = function(value) SetOption("EXPIRYWARNINGTIME", value) end
	})

	optionsWindow:ResumeLayout()
end

function CooldownManagerUtils:ToggleCooldownManager()
	if C_AddOns and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then C_AddOns.LoadAddOn("Blizzard_CooldownViewer") end
	local frame = CooldownViewerSettings
	if frame and frame.TogglePanel then
		frame:TogglePanel()
	else
		self:ToggleOptions()
	end
end

function CooldownManagerUtils:InitMinimapButton()
	local options = self:GetOptions()
	self:CreateMinimapButton({
		["name"] = "CooldownManagerUtils",
		["icon"] = ICON,
		["dbtab"] = options,
		["vTT"] = {{format("|T%d:16:16:0:0|t Cooldown Manager Utils", ICON), strtrim(GetVersionText())}, {self:Trans("LID_LEFTCLICK"), self:Trans("LID_OPENCOOLDOWNMANAGER")}, {self:Trans("LID_RIGHTCLICK"), self:Trans("LID_OPENSETTINGS")}, {self:Trans("LID_SHIFTRIGHTCLICK"), self:Trans("LID_HIDEMINIMAPBUTTON")}},
		["funcL"] = function() CooldownManagerUtils:ToggleCooldownManager() end,
		["funcR"] = function() CooldownManagerUtils:ToggleOptions() end,
		["funcSR"] = function()
			CooldownManagerUtils:SV(options, "MMBTN", false)
			CooldownManagerUtils:HideMMBtn("CooldownManagerUtils")
			if optionsWindow and optionsWindow.minimapCheckbox then optionsWindow.minimapCheckbox:SetChecked(false) end
		end,
		["dbkey"] = "MMBTN"
	})
end

CooldownManagerUtils:AddSlash("cmu", function() CooldownManagerUtils:ToggleOptions() end)
CooldownManagerUtils:AddSlash("cooldownmanagerutils", function() CooldownManagerUtils:ToggleOptions() end)
