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

--@imports<ns>
local Util = Engine.Util;
local Dispatch = Engine.Dispatcher
local Events = Engine.Events;
local C_LossOfControl = Engine.API.C_LossOfControl;


--@natives<lua,wow>
local max = math.max;
local GetTime = GetTime;
local CreateFrame = CreateFrame;
local UIParent = UIParent;
local PlaySoundFile = PlaySoundFile;


--@media
local SOUND_ALERT = Engine.Media.SOUND_ALERT;

--@constants
local ACTIVE_INDEX = 1;
local TIME_LEFT_FRAME_WIDTH = 200;
local TIME_OFFSET = 6;
local UPDATE_THROTTLE = 0.05;

local TIMING_NAME = {
	RAID_NOTICE_MIN_HEIGHT = 22,
	RAID_NOTICE_MAX_HEIGHT = 32,
	RAID_NOTICE_SCALE_UP_TIME = 0.1,
	RAID_NOTICE_SCALE_DOWN_TIME = 0.2,
};

local TIMING_TIME = {
	RAID_NOTICE_MIN_HEIGHT = 20,
	RAID_NOTICE_MAX_HEIGHT = 28,
	RAID_NOTICE_SCALE_UP_TIME = 0.1,
	RAID_NOTICE_SCALE_DOWN_TIME = 0.2,
};


-- test spell
local previewDataCache = {
	locType = "MOVE",
	spellID = 0,
	startTime = 0,
	duration = 60,
	expirationTime = 0,
	timeRemaining = 0,
	displayType = 2,
	displayText = "Move Mode",
	iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark",
	priority = 999,
};


--@class LossOfControlFrameMixin<mixin>
local LossOfControlFrameMixin = {};

function LossOfControlFrameMixin:OnLoad()
	self.db = Engine.Settings;
	self.L = Engine.Locale;

	local frame = CreateFrame("Frame", nil, UIParent, "LossOfControlFrameTemplate");
	self.frame = frame;

	self:InitFrame(frame);
	self:ApplyVisualOptions();
	self:ApplyPosition();

	-- self.eventIDs = {
	Dispatch:RegisterEvent("LOSS_OF_CONTROL_UPDATE", self, "OnLossOfControlUpdate");
	Dispatch:RegisterEvent("LOSS_OF_CONTROL_ADDED", self, "OnLossOfControlAdded");
	-- };

	self:UpdateDisplay(false);
end

function LossOfControlFrameMixin:InitFrame(frame)
	frame:Hide();

	frame.TimeLeft.SecondsText:SetText(self.L.SECONDS);
	frame.TimeLeft.secondsWidth = frame.TimeLeft.SecondsText:GetStringWidth();
	frame.TimeLeft.numberWidth = 0;

	frame.updateTick = 0;
	frame.isUpdating = false;

	frame.animationGroups = {
		frame.RedLineTop.Anim,
		frame.RedLineBottom.Anim,
		frame.Icon.Anim,
	};

	-- Master animation finished handler
	Events:SetScriptHandler(frame.RedLineBottom.Anim, self, "OnFinished", "OnAnimationFinished");

	-- mover/drag
	frame:SetMovable(true);
	frame:SetClampedToScreen(true);
	frame:RegisterForDrag("LeftButton");
	frame:EnableMouse(false);

	local mixin = self;
	frame:SetScript("OnDragStart", function(f)
		if mixin.db.frameUnlocked then
			f:StartMoving();
		end
	end);

	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing();
		mixin:SavePosition();
	end);
end

--# -------------------- Event Handlers --------------------

function LossOfControlFrameMixin:OnLossOfControlUpdate()
	self:UpdateDisplay(false);
end

function LossOfControlFrameMixin:OnLossOfControlAdded(event, locType, spellID)
	if self.isMoverActive then
		return;
	end

	local isNewEffect = self:UpdateDisplay(true);
	if isNewEffect then
		if self.db.soundEnabled then
			PlaySoundFile(SOUND_ALERT);
		end
	elseif (self.db.enablePulse ~= false) and self.frame:IsShown() then
		self:PulseCurrentDisplay();
	end
end

--# -------------------- Display --------------------

function LossOfControlFrameMixin:UpdateDisplay(animate)
	if not self.db.enabled then
		self:DisableUpdate();
		return false;
	end

	-- get data
	local data;
	if self.isMoverActive then
		data = self:GetPreviewData();
	else
		data = C_LossOfControl.GetActiveLossOfControlData(ACTIVE_INDEX);
	end

	-- validate
	if not data or data.displayType == 0 then
		if not self.isMoverActive then
			self:DisableUpdate();
		end
		return false;
	end

	-- format text
	local displayText = self:GetDisplayText(data);
	if not displayText then
		if not self.isMoverActive then
			self:DisableUpdate();
		end
		return false;
	end

	data.displayText = displayText;

	local isNewEffect = (data.locType ~= self.lastLocType)
		or (data.spellID ~= self.lastSpellID)
		or (data.startTime ~= self.lastStartTime);

	self.lastLocType = data.locType;
	self.lastSpellID = data.spellID;
	self.lastStartTime = data.startTime;

	local animateIntro = animate and isNewEffect and (self.db.enableAnimations ~= false);
	self:SetUpDisplay(animateIntro, data);

	return isNewEffect;
end

function LossOfControlFrameMixin:GetDisplayText(data)
	if not data then
		return nil;
	end

	-- Mover mode
	if data.locType == "MOVE" then
		return data.displayText or "Move Mode";
	end

	local L = self.L;
	local locType = data.locType;
	if locType == "SCHOOL_INTERRUPT" and data.lockoutSchool then
		local schoolName = Util.GetSchoolString(data.lockoutSchool);
		local fmt = L.INTERRUPT_FMT or L.SCHOOL_INTERRUPT;
		return fmt:format(schoolName);
	end

	local displayKey = L.DISPLAY and L.DISPLAY[locType];
	if displayKey then
		return displayKey;
	end

	return L[locType] or locType;
end

function LossOfControlFrameMixin:SetUpDisplay(animateIntro, data)
	local frame = self.frame;

	frame.AbilityName:SetText(data.displayText);
	frame.Icon:SetTexture(data.iconTexture);

	self:SetTimeLeft(data.timeRemaining);

	-- layout
	local abilityWidth = frame.AbilityName:GetWidth();
	local timeWidth = max(abilityWidth, frame.TimeLeft.numberWidth + frame.TimeLeft.secondsWidth);
	local longestWidth = max(abilityWidth, timeWidth);
	local baseWidth = self.db.dynamicTextOn and longestWidth or abilityWidth;

	local xOffset = (abilityWidth - baseWidth) / 2 + 27;

	frame.AbilityName:ClearAllPoints();
	frame.AbilityName:SetPoint("CENTER", xOffset, 11);

	frame.Icon:ClearAllPoints();
	frame.Icon:SetPoint("CENTER", -((6 + baseWidth) / 2), 0);

	frame.TimeLeft:ClearAllPoints();
	frame.TimeLeft:SetPoint("CENTER", xOffset + (TIME_LEFT_FRAME_WIDTH - abilityWidth) / 2, -12);

	-- cooldown: never show during intro if cooldownPending already set
	local cooldown = frame.Cooldown;
	local hasCooldown = data.displayType == 2
		and data.duration
		and data.duration > 0;

	if hasCooldown then
		cooldown:SetDrawEdge(true);
		cooldown:SetCooldown(data.startTime, data.duration);
		
		if animateIntro then
			self.cooldownPending = true;
			cooldown:Hide();
			self:PlayIntroAnimation();
		else
			if self.cooldownPending then
				cooldown:Hide();
			else
				cooldown:Show();
			end
		end
	else
		self.cooldownPending = nil;
		cooldown:Hide();
	end

	frame:Show();
	self:EnableUpdate();
end

function LossOfControlFrameMixin:SetTimeLeft(timeRemaining)
	local timeLeft = self.frame.TimeLeft;
	if not timeRemaining or timeRemaining <= 0 then
		-- timeLeft.numberWidth = 0;
		timeLeft:Hide();
		return;
	end

	local numberText = timeLeft.NumberText;
	if timeRemaining >= 10 then
		numberText:SetFormattedText("%d", timeRemaining);
	else
		numberText:SetFormattedText("%.1f", timeRemaining);
	end

	-- timeLeft.numberWidth = numberText:GetStringWidth() + TIME_OFFSET;
	timeLeft:Show();
end

--# -------------------- Animation --------------------

function LossOfControlFrameMixin:PlayIntroAnimation()
	local frame = self.frame;

	-- Reset text scaling
	frame.AbilityName.scrollTime = 0;
	frame.TimeLeft.NumberText.scrollTime = 0;
	frame.TimeLeft.SecondsText.scrollTime = 0;

	frame.Cooldown:Hide();

	-- Play all animations
	local groups = frame.animationGroups;
	for i = 1, #groups do -- so?
		local group = groups[i];
		group:Stop();
		group:Play();
	end
end

function LossOfControlFrameMixin:OnAnimationFinished()
	if self.cooldownPending then
		self.cooldownPending = nil;
		self.frame.Cooldown:Show();
	end
end

function LossOfControlFrameMixin:PulseCurrentDisplay()
	local frame = self.frame;
	frame.AbilityName.scrollTime = 0;
	frame.TimeLeft.NumberText.scrollTime = 0;
	frame.TimeLeft.SecondsText.scrollTime = 0;
end

--# -------------------- Update --------------------

function LossOfControlFrameMixin:EnableUpdate()
	local frame = self.frame;
	if frame.isUpdating then
		return;
	end

	frame.isUpdating = true;
	frame.updateTick = 0;

	Events:SetScriptHandler(frame, self, "OnUpdate");
end

function LossOfControlFrameMixin:DisableUpdate()
	local frame = self.frame;
	if not frame.isUpdating then
		return;
	end

	frame:Hide();
	frame.isUpdating = false;

	Events:ClearScriptHandler(frame, "OnUpdate");
end

function LossOfControlFrameMixin:OnUpdate(elapsed)
	local frame = self.frame;
	frame.updateTick = frame.updateTick + elapsed;
	if frame.updateTick < UPDATE_THROTTLE then return; end

	local dt = frame.updateTick;
	frame.updateTick = 0;

	Util.AnimateScaleText(frame.AbilityName, TIMING_NAME, dt);
	Util.AnimateScaleText(frame.TimeLeft.NumberText, TIMING_TIME, dt);
	Util.AnimateScaleText(frame.TimeLeft.SecondsText, TIMING_TIME, dt);

	-- Mover stays alive
	if self.isMoverActive then
		self:UpdateDisplay(false);
		return;
	end

	-- Fade (alert)
	if Util.ProcessFade(frame, dt) then
		return; -- still fading
	end

	-- Check for expired effects and refresh display
	local removed = C_LossOfControl.RemoveExpiredEffects();
	if (removed or C_LossOfControl.GetActiveLossOfControlDataCount() > 0) then
		self:UpdateDisplay(false);
	else
		self:DisableUpdate();
	end
end

--# -------------------- Visual Options --------------------

function LossOfControlFrameMixin:ApplyVisualOptions()
	local frame = self.frame;
	local showBg = (self.db.showBackground ~= false);
	local showRed = (self.db.showRedLines ~= false);

	Util.SetShown(frame.blackBg, showBg);
	Util.SetShown(frame.RedLineTop, showRed);
	Util.SetShown(frame.RedLineBottom, showRed);
end

function LossOfControlFrameMixin:SetMoverEnabled(enabled)
	local db = self.db;

	db.frameUnlocked = enabled;
	db.moverMode = enabled;
	self.isMoverActive = enabled;

	if enabled then
		self.moverStartTime = GetTime();
	end

	self:ApplyPosition();
	self:UpdateDisplay(true);
end

--# -------------------- Position --------------------

function LossOfControlFrameMixin:ApplyPosition()
	local db = self.db;
	local frame = self.frame;

	frame:ClearAllPoints();

	local point = db.framePoint or "CENTER";
	local relPoint = db.frameRelative or point;
	local x = db.frameX or 0;
	local y = db.frameY or 0;

	frame:SetPoint(point, UIParent, relPoint, x, y);
	frame:SetScale(db.frameScale or 1.0);
	frame:EnableMouse(db.frameUnlocked or false);
end

function LossOfControlFrameMixin:SavePosition()
	local db = self.db;
	local point, _, relPoint, x, y = self.frame:GetPoint(1);

	db.framePoint = point;
	db.frameRelative = relPoint;
	db.frameX = x;
	db.frameY = y;
end

function LossOfControlFrameMixin:ResetPosition()
	local db = self.db;

	db.framePoint = nil;
	db.frameRelative = nil;
	db.frameX = nil;
	db.frameY = nil;
	db.frameScale = 1.0;

	self:ApplyPosition();
end

function LossOfControlFrameMixin:ToggleUnlock()
	self:SetMoverEnabled(not self.db.frameUnlocked);
end


function LossOfControlFrameMixin:GetPreviewData()
	local now = GetTime();
	local startTime = self.moverStartTime or now;
	local duration = 60;
	local remaining = duration - (now - startTime);
	if remaining < 0 then remaining = 0; end

	-- update cache
	previewDataCache.startTime = startTime;
	previewDataCache.expirationTime = startTime + duration;
	previewDataCache.timeRemaining = remaining;

	return previewDataCache;
end

--@export<ns>
Engine.Modules.LossOfControlFrameMixin = LossOfControlFrameMixin;