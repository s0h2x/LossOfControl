--[[
 Copyright (c) 2026 s0high
 https://github.com/s0h2x/LossOfControl
    
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@import<ns>
local Log = Engine.Log;

--@natives<lua,wow>
local strsplit, strlower, strupper = strsplit, strlower, strupper;
local tonumber, tostring = tonumber, tostring;
local format = string.format;
local pairs, wipe = pairs, wipe;
local min, max = math.min, math.max;
local GetSpellInfo = GetSpellInfo;
local print = print;


--@class Commands<core>
local Commands = {};
Engine.Commands = Commands;


--@constants
local COLOR = {
	ON    = "|cff00ff00",
	OFF   = "|cffff0000",
	WARN  = "|cffffff00",
	VALUE = "|cffffffff",
	LABEL = "|cff188888",
	R     = "|r",
};

local SCALE_MIN = 0.5;
local SCALE_MAX = 3.0;


-- Formatting Utils
----------------------------------------------------------------
local function Colorize(color, text)
	return color .. text .. COLOR.R;
end
local function Value(value)
	return Colorize(COLOR.VALUE, tostring(value));
end
local function Bool(value)
	return value and Colorize(COLOR.ON, "ON") or Colorize(COLOR.OFF, "OFF");
end
local function Info(value)
	return Colorize(COLOR.WARN, tostring(value));
end
-- if nil = true (default)
local function BoolDefault(value)
	return Bool(value ~= false);
end

-- Argument Parsing
----------------------------------------------------------------
local BOOL_TRUE  = { on = true, ["1"] = true, ["true"] = true };
local BOOL_FALSE = { off = true, ["0"] = true, ["false"] = true };
local function ParseBool(arg)
	if BOOL_TRUE[arg] then return true; end
	if BOOL_FALSE[arg] then return false; end
	return nil;
end


--# -------------------- Factories & Output --------------------

local INDENT = "  ";
function Commands:Print(line)
	print(INDENT .. line);
end

function Commands:PrintSection(title)
	print(COLOR.LABEL .. INDENT .. "*** " .. title .. " ***" .. COLOR.R)
end

function Commands:PrintCmd(cmd, desc)
	self:Print(Colorize(COLOR.VALUE, cmd) .. " - " .. desc)
end


function Commands:ToggleOption(key, label, arg, defaultTrue, after)
	local db = self.db;
	local explicit = ParseBool(arg);

	if defaultTrue then
		if explicit == true then
			db[key] = nil;
		elseif explicit == false then
			db[key] = false;
		else
			db[key] = (db[key] ~= false) and false or nil;
		end
	else
		if explicit ~= nil then
			db[key] = explicit;
		else
			db[key] = not db[key];
		end
	end

	local effective = defaultTrue and (db[key] ~= false) or db[key];
	local text = defaultTrue and BoolDefault(db[key]) or Bool(db[key]);

	Log("%s: %s", label, text);
	if after then after(self, effective); end

	return effective;
end


--# -------------------- Command Registry --------------------

local Registry, Ordered = {}, {};
local function Register(cmd, spec)
	spec.cmd = cmd;
	Registry[cmd] = spec;
	Ordered[#Ordered + 1] = spec;

	if spec.aliases then
		for i = 1, #spec.aliases do
			Registry[spec.aliases[i]] = spec;
		end
	end
end

--# -------------------- Chat Commands --------------------

-- General
----------------------------------------------------------------
Register("status", {
	section = "General",
	help = "Show all settings",
	run = function(self)
		local db = self.db;

		local customCount = 0;
		for _ in pairs(db.customAuras) do
			customCount = customCount + 1;
		end

		Log("Status:");
		self:Print("Addon: " .. Bool(db.enabled));
		self:Print("Sound: " .. Bool(db.soundEnabled));
		self:Print("Animations: " .. BoolDefault(db.enableAnimations));
		self:Print("Pulse: " .. BoolDefault(db.enablePulse));
		self:Print("Background: " .. BoolDefault(db.showBackground));
		self:Print("Red Lines: " .. BoolDefault(db.showRedLines));
		self:Print("Dynamic: " .. BoolDefault(db.dynamicTextOn));
		self:Print("Scale: " .. Info(format("%.1f", db.frameScale or 1.0)));
		self:Print(format("Position: %s (%d, %d)", db.framePoint or "CENTER", db.frameX or 0, db.frameY or 0));
		-- self:Print("Frame: %s" .. db.frameUnlocked and Colorize(COLOR.ON, "UNLOCKED") or Colorize(COLOR.OFF, "LOCKED"));
		self:Print("Custom: " .. Value(customCount));
		self:Print("Debug: " .. Bool(Engine.Debug));
		self:PrintSection(Engine.Title);
		self:Print("Author: " .. Info("s0high"));
		self:Print("Version: " .. Info(Engine.Version));
		self:Print("License: " .. Info("GPLv3"));
		self:Print("Source: " .. Info("https://github.com/s0h2x/LossOfControl"));
	end,
});

Register("debug", {
	section = "General",
	help = "Toggle debug mode",
	run = function(self, arg)
		Engine.Debug = self:ToggleOption("logUnknown", "Debug", arg);
	end,
});

Register("help", {
	section = "General",
	help = "Show this help",
	run = function(self)
		self:Help();
	end,
});


-- Frame
----------------------------------------------------------------
Register("move", {
	section = "Frame",
	help = "Toggle move mode",
	run = function(self)
		local newState = not self.db.frameUnlocked;
		self.frame:SetMoverEnabled(newState);
		Log("Frame %s", newState and (Colorize(COLOR.WARN, "UNLOCKED") .. " - drag to move") or "LOCKED");
	end,
});

Register("reset", {
	section = "Frame",
	help = "Reset position",
	run = function(self)
		self.frame:ResetPosition();
		Log("Position reset");
	end,
});

Register("scale", {
	section = "Frame",
	help = "Set scale",
	usage = "<0.5-3>",
	run = function(self, arg)
		local db = self.db;
		local scale = tonumber(arg);
		if scale then
			db.frameScale = max(SCALE_MIN, min(SCALE_MAX, scale));
			self.frame:ApplyPosition();
			Log("Scale: %s", Value(format("%.1f", db.frameScale)));
		else
			Log("Scale: %s (range %.1f-%.1f)", Value(format("%.1f", db.frameScale or 1.0)), SCALE_MIN, SCALE_MAX);
		end
	end,
});


-- Visual
----------------------------------------------------------------
Register("sound", {
	section = "Visual",
	help = "Toggle sound",
	run = function(self, arg)
		self:ToggleOption("soundEnabled", "Sound", arg);
	end,
});

Register("anim", {
	section = "Visual",
	help = "Toggle animations",
	aliases = { "animations" },
	run = function(self, arg)
		self:ToggleOption("enableAnimations", "Animations", arg, true);
	end,
});

Register("pulse", {
	section = "Visual",
	help = "Toggle pulse",
	run = function(self, arg)
		self:ToggleOption("enablePulse", "Pulse", arg, true);
	end,
});

Register("bg", {
	section = "Visual",
	help = "Toggle background",
	aliases = { "background" },
	run = function(self, arg)
		self:ToggleOption("showBackground", "Background", arg, true);
		self.frame:ApplyVisualOptions();
	end,
});

Register("lines", {
	section = "Visual",
	help = "Toggle red lines",
	aliases = { "redlines" },
	run = function(self, arg)
		self:ToggleOption("showRedLines", "Red lines", arg, true);
		self.frame:ApplyVisualOptions();
	end,
});

Register("dynamic", {
	section = "Visual",
	help = "Toggle dynamic text",
	run = function(self, arg)
		self:ToggleOption("dynamicTextOn", "Dynamic text", arg, true);
	end,
});


-- Custom CC
----------------------------------------------------------------
Register("add", {
	section = "Custom CC",
	help = "Add spell",
	usage = "<id> <type>",
	run = function(self, arg1, arg2)
		local spellID = tonumber(arg1);
		if not spellID then
			Log("Usage: /loc add <spellID> <TYPE>");
			self:Print("Types: STUN, FEAR, SILENCE, ROOT, POLYMORPH ...");
			return;
		end

		if not arg2 or arg2 == "" then
			Log("Specify type: /loc add %d STUN", spellID);
			return;
		end

		local ccType = strupper(arg2);
		if not Engine.Data.PRIORITY[ccType] then
			Log("%sWarning:%s unknown type '%s'", COLOR.WARN, COLOR.R, ccType);
		end

		self.db.customAuras[spellID] = ccType;
		local name = GetSpellInfo(spellID) or "Unknown";
		Log("Added [%d] %s = %s", spellID, Value(name), Value(ccType));
	end,
});

Register("remove", {
	section = "Custom CC",
	help = "Remove spell",
	usage = "<id>",
	aliases = { "rm" },
	run = function(self, arg)
		local spellID = tonumber(arg);
		if not spellID then
			Log("Usage: /loc remove <spellID>");
			return;
		end

		local ccType = self.db.customAuras[spellID];
		if ccType then
			self.db.customAuras[spellID] = nil;
			local name = GetSpellInfo(spellID) or "Unknown";
			Log("Removed [%d] %s", spellID, Value(name));
		else
			Log("Spell %s not found", Value(spellID));
		end
	end,
});

Register("list", {
	section = "Custom CC",
	help = "List custom spells",
	run = function(self)
		local count = 0;

		for spellID, ccType in pairs(self.db.customAuras) do
			if count == 0 then
				Log("Custom auras:");
			end
			count = count + 1;
			local name = GetSpellInfo(spellID) or "?";
			self:Print(format("[%d] %s = %s", spellID, Value(name), Value(ccType)));
		end

		if count == 0 then
			Log("No custom auras");
		else
			Log("Total: %s", Value(count));
		end
	end,
});

Register("clear", {
	section = "Custom CC",
	help = "Clear cache",
	usage = "<unknown|custom>",
	run = function(self, arg)
		if arg == "unknown" then
			wipe(self.db.unknownSeen);
			Log("Unknown cache cleared");
		elseif arg == "custom" then
			wipe(self.db.customAuras);
			Log("Custom auras cleared");
		else
			Log("Usage: /loc clear <unknown|custom>");
		end
	end,
});

--@aliases<helper>
Registry["?"] = Registry["help"];
Registry[""]  = Registry["help"];

-- Help Generator
function Commands:Help()
	Log("Commands:");

	local currentSection;
	for i = 1, #Ordered do
		local spec = Ordered[i];
		if spec.section ~= currentSection then
			currentSection = spec.section;
			self:PrintSection(currentSection);
		end

		local usage = spec.usage and (" " .. spec.usage) or "";
		self:PrintCmd("/loc " .. spec.cmd .. usage, spec.help);
	end
end


-- Initialization
----------------------------------------------------------------
function Commands:Init()
	self.db = Engine.Settings;
	self.frame = Engine.Modules.LossOfControlFrameMixin;

	if not self.frame then
		Log("Commands: Frame not found!");
		return;
	end

	SLASH_LOC1 = "/loc";
	SLASH_LOC2 = "/los";

	SlashCmdList.LOC = function(msg)
		Commands:Handle(msg);
	end
end

function Commands:Handle(msg)
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$");
	cmd = strlower(cmd or "");

	local spec = Registry[cmd];
	if spec then
		local arg1, arg2 = strsplit(" ", rest or "");
		spec.run(self, arg1, arg2);
	else
		Log("Unknown: '%s' - try /loc help", cmd);
	end
end