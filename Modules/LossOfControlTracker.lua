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
local Events = Engine.Events;
local Dispatch = Engine.Dispatcher;
local C_LossOfControl = Engine.API.C_LossOfControl;

--@natives<lua,wow>
local pairs = pairs;
local wipe = wipe;
local select = select;
local UnitAura = UnitAura;
local UnitGUID = UnitGUID;
local GetTime = GetTime;
local GetSpellTexture = GetSpellTexture;


--@import<data>
local AURA_CC = Engine.Data.AURA_CC;
local INTERRUPT_LOCKOUT = Engine.Data.INTERRUPT_LOCKOUT;
local PRIORITY = Engine.Data.PRIORITY;

--@constants
local MAX_AURAS = 40;
local SCHOOL_INTERRUPT = "SCHOOL_INTERRUPT";
local SPELL_INTERRUPT = "SPELL_INTERRUPT";
local PLAYER = "player";
local HARMFUL = "HARMFUL";


--@class LossOfControlTracker<mixin>
local LossOfControlTracker = {
	activeSpells = {},
	trackedExpires = {},
	trackedTypes = {},
};
Engine.Modules.LossOfControlTracker = LossOfControlTracker;

local LossOfControlTrackerEvents = {
	"UNIT_AURA",
	"COMBAT_LOG_EVENT_UNFILTERED",
	"PLAYER_ENTERING_WORLD",
};

function LossOfControlTracker:Init()
	self.db = Engine.Settings;
	self.guid = UnitGUID(PLAYER);
	self.frame = Events:CreateEventFrame(self, LossOfControlTrackerEvents);
end

--# -------------------- Event Handlers --------------------

function LossOfControlTracker:UNIT_AURA(unit)
	if unit ~= PLAYER or not self.db.enabled then
		return;
	end

	self:PlayerAuraUpdate();
end

function LossOfControlTracker:COMBAT_LOG_EVENT_UNFILTERED(...)
	if self.db.enabled then
		self:ProcessCombatLogEvent(...);
	end

	--@debug
	--[[
	if Engine.Debug then
		local event = select(2, ...);
		if event == "SPELL_INTERRUPT" then
			print("[SPELL_INTERRUPT DEBUG] >");
			for i = 1, select("#", ...) do
				print(i, select(i, ...));
			end
		end
	end
	]]
end

function LossOfControlTracker:PLAYER_ENTERING_WORLD()
	self.guid = UnitGUID(PLAYER); -- refresh

	if self.db.enabled then
		self:PlayerAuraUpdate();
	end

	Dispatch:FireEvent("LOSS_OF_CONTROL_UPDATE");
end


-- Unknown Aura Logging
----------------------------------------------------------------
function LossOfControlTracker:LogUnknownAura(spellID, name, icon)
	local db = self.db;
	if not db.logUnknown then
		return;
	end
	if db.unknownSeen[spellID] then
		return;
	end

	db.unknownSeen[spellID] = true;

	Engine.DebugLog("|cffffff00[Unknown CC]|r %s (ID: %d)", name or "?", spellID);
	Engine.DebugLog("  → Add with: /loc add %d STUN", spellID);
end


--# -------------------- Aura Scanning --------------------

function LossOfControlTracker:PlayerAuraUpdate()
	local activeSpells = self.activeSpells;
	local trackedExpires = self.trackedExpires;
	local trackedTypes = self.trackedTypes;

	-- settings
	local db = self.db;
	local customAuras = db.customAuras;
	local displayTypeByKind = db.displayTypeByKind;

	-- Wipe current scan
	wipe(activeSpells);

	local hasChanges = false;

	for i = 1, MAX_AURAS do
		local name, rank, icon, _, debuffType, duration, expirationTime, _, _, _, spellID = UnitAura(PLAYER, i, HARMFUL);
		if not name or not spellID then
			break;
		end

		local locType = customAuras[spellID] or AURA_CC[spellID];
		if locType then
			activeSpells[spellID] = true;

			-- Only if `expirationTime` has changed (new effect or refresh)
			if trackedExpires[spellID] ~= expirationTime then
				trackedExpires[spellID] = expirationTime;
				trackedTypes[spellID] = locType;

				local priority = PRIORITY[locType] or 1;
				local displayType = displayTypeByKind[locType] or 2;

				local isNew = C_LossOfControl.AddLossOfControlEffect(
					spellID, locType, icon, duration, expirationTime, priority, displayType, nil
				);

				if isNew then
					Dispatch:FireEvent("LOSS_OF_CONTROL_ADDED", locType, spellID);
				end

				hasChanges = true;
				-- Engine.Log("%s %s", name, rank)
			end
		else
			-- Potentially unknown CC;
			-- Check debuffType - if it's a CC-like debuff
			if debuffType and self:IsPotentialCC(debuffType) then
				self:LogUnknownAura(spellID, name, icon);
			end
		end
	end

	for spellID in pairs(trackedExpires) do
		if not activeSpells[spellID] then
			trackedExpires[spellID] = nil;
			trackedTypes[spellID] = nil;

			if C_LossOfControl.RemoveBySpellID(spellID) then
				hasChanges = true;
			end
		end
	end

	if hasChanges then
		Dispatch:FireEvent("LOSS_OF_CONTROL_UPDATE");
	end
end


-- CC Detection Heuristic
----------------------------------------------------------------
local CC_DEBUFF_TYPES = {
	Magic = true,
	Curse = true,
};

function LossOfControlTracker:IsPotentialCC(debuffType)
	-- Magic and Curse often contain CC
	-- Can extend the logic if needed ...
	return CC_DEBUFF_TYPES[debuffType] or false;
end


function LossOfControlTracker:ProcessCombatLogEvent(...)
	local event = select(2, ...);
	if event ~= SPELL_INTERRUPT then return; end

	local destGuid = select(6, ...);
	if destGuid ~= self.guid then return; end

	-- 3.3.5a
	local interruptSpellID = select(9, ...);
	local interruptedSpellID = select(12, ...);
	local interruptedSchool = select(14, ...);

	local db = self.db;
	local lockoutDuration = db.customInterrupts[interruptSpellID] 
		or INTERRUPT_LOCKOUT[interruptSpellID];

	if not lockoutDuration then
		if db.logUnknown then
			local interruptName = select(10, ...) or "Unknown";
			Engine.Log("|cffffff00[Unknown Interrupt]|r %s (ID: %d)", interruptName, interruptSpellID or 0);
		end
		return;
	end

	local now = GetTime();
	local iconTexture = select(3, GetSpellInfo(interruptedSpellID)) 
		or "Interface\\Icons\\Spell_Frost_IceShock";

	local priority = PRIORITY[SCHOOL_INTERRUPT] or 10;
	local displayType = db.displayTypeByKind[SCHOOL_INTERRUPT] or 2;
	local lockoutSchool = interruptedSchool or 0;

	local isNew = C_LossOfControl.AddLossOfControlEffect(
		interruptedSpellID,
		SCHOOL_INTERRUPT,
		iconTexture,
		lockoutDuration,
		now + lockoutDuration,
		priority,
		displayType,
		lockoutSchool
	);

	if isNew then
		Dispatch:FireEvent("LOSS_OF_CONTROL_ADDED", SCHOOL_INTERRUPT, interruptedSpellID);
	end

	Dispatch:FireEvent("LOSS_OF_CONTROL_UPDATE");
end