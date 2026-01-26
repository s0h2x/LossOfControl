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

--@natives<lua>
local pairs, type, wipe = pairs, type, wipe;

--@class SavedVariable<db>
Engine.DB = {};
local DB = Engine.DB;

--@defaults<db>
local defaults = {
	enabled = true,

	-- Sound
	soundEnabled = true,

	-- Position
	frameUnlocked = false,
	framePoint = "CENTER",
	frameRelative = "CENTER",
	frameX = 0,
	frameY = 0,
	frameScale = 1.0,

	-- Visual
	showBackground = true,
	showRedLines = true,
	enableAnimations = true,
	enablePulse = true,
	dynamicTextOn = true,

	-- Display types: 0=off, 1=alert, 2=full
	displayTypeByKind = {
		SCHOOL_INTERRUPT = 2,
		STUN = 2,
		FEAR = 2,
		ROOT = 2,
		SILENCE = 2,
		DISARM = 2,
		POLYMORPH = 2,
		FREEZE = 2,
		CYCLONE = 2,
		BANISH = 2,
		DISORIENT = 2,
	},

	-- Custom overrides
	customAuras = {},
	customInterrupts = {},

	-- Debug
	logUnknown = false,
	unknownSeen = {},
};


-- Table Utilities
----------------------------------------------------------------
local function copyTable(src)
	if type(src) ~= "table" then
		return src;
	end

	local copy = {};
	for k, v in pairs(src) do
		copy[k] = copyTable(v);
	end
	return copy;
end

local function applyDefaults(target, defaults)
	for key, defaultValue in pairs(defaults) do
		local currentValue = target[key];
		if currentValue == nil then
			target[key] = copyTable(defaultValue);
		elseif type(defaultValue) == "table" and type(currentValue) == "table" then
			applyDefaults(currentValue, defaultValue);
		end
	end
end

--# -------------------- DB Init --------------------

function DB:Init()
	-- _G.SavedVariable
	LoCDB = LoCDB or {};
	LoCDB.profile = LoCDB.profile or {};

	applyDefaults(LoCDB.profile, defaults);

	-- Shortcuts
	self.profile = LoCDB.profile;
	Engine.Settings = self.profile;

	-- Debug mode
	if Engine.Debug then
		self.profile.logUnknown = true;
	end
end

function DB:Reset()
	wipe(LoCDB.profile);
	applyDefaults(LoCDB.profile, defaults);
end


function DB:GetDefault(key)
	return defaults[key];
end