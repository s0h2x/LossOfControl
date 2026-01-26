--[[
 Copyright (c) 2026 s0high
 https://github.com/s0h2x/LossOfControl
    
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
]]

--@class Engine<ns>
local AddOnName, Engine = ...;

--@natives<lua,wow>
local format = string.format;
local print = print;
local tostring = tostring;
local select = select;
local GetAddOnMetadata = GetAddOnMetadata;


--@metadata
Engine.Name	   = AddOnName;
Engine.Title   = GetAddOnMetadata(AddOnName, "Title");
Engine.Author  = GetAddOnMetadata(AddOnName, "Author");
Engine.Version = GetAddOnMetadata(AddOnName, "Version");
Engine.Website = GetAddOnMetadata(AddOnName, "X-Website");
Engine.Debug   = false; -- Set true to see debug prints


--@namespaces
Engine.Data	= Engine.Data or {};
Engine.Util	= Engine.Util or {};
Engine.API  = Engine.API  or {};
-- Engine.Mixins  = Engine.Mixins or {};
Engine.Shared  = Engine.Shared or {};
Engine.Modules = Engine.Modules or {};


--@utils
local LOG_PREFIX = "|cff00ccff" .. (AddOnName) .. "|r > ";
Engine.Log = function(msg, ...)
	if select("#", ...) > 0 then
		print(LOG_PREFIX .. format(msg, ...));
	else
		print(LOG_PREFIX .. tostring(msg));
	end
end

-- Debug-only logging
Engine.DebugLog = function(msg, ...)
	if Engine.Debug then
		Engine.Log("|cff804a00[DEBUG]|r " .. msg, ...);
	end
end

--@media
local ADDON_PATH = "Interface\\AddOns\\" .. AddOnName;
Engine.Media = {
	SOUND_ALERT = ADDON_PATH .. "\\Resources\\Sound\\alert_ma_arcanemissles.ogg",
};

--@loader
local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:RegisterEvent("PLAYER_LOGIN");
loader:SetScript("OnEvent", function(self, event, arg1)
	if (event == "ADDON_LOADED" and arg1 == AddOnName) then
		Engine.DB:Init();
		Engine.Localization:Init();
	elseif (event == "PLAYER_LOGIN") then
		Engine.Modules.LossOfControlTracker:Init();
		Engine.Modules.LossOfControlFrameMixin:OnLoad();
		Engine.Commands:Init();

		self:UnregisterAllEvents();
		self:SetScript("OnEvent", nil);
		loader = nil;
	end
end);

-- Engine.Loader = loader;