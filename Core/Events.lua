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

--@class Events
local Events = {};
Engine.Events = Events;


--# -------------------- Internal Helpers --------------------

local function OnEvent(frame, event, ...)
	local owner = frame._owner;
	if not owner then return; end

	local callback = owner[event];
	if callback then
		callback(owner, ...);
	end
end

local function SetupEventFrame(frame, owner, events)
	frame._owner = owner;
	frame:SetScript("OnEvent", OnEvent);

	for i = 1, #events do
		frame:RegisterEvent(events[i]);
	end
end

-- Script handlers cache
local scriptHandlers = {};

local function GetOrCreateScriptHandler(scriptName)
	local handler = scriptHandlers[scriptName];
	if handler then
		return handler;
	end

	-- key store
	local methodKey = "_" .. scriptName .. "Method";
	handler = function(frame, ...)
		local owner = frame._owner;
		if not owner then return; end

		local method = frame[methodKey] or scriptName;
		local callback = owner[method];
		if callback then
			callback(owner, ...);
		end
	end

	scriptHandlers[scriptName] = handler;
	return handler;
end


--# -------------------- Events API --------------------

---@param owner<table> - self
---@param events<table> — array[]
---@return<Frame> NECESSARILY
function Events:CreateEventFrame(owner, events)
	local frame = CreateFrame("Frame");
	SetupEventFrame(frame, owner, events);
	return frame;
end

---@param frame<Frame>
---@param owner<table>
---@param events<table> - array[]
function Events:RegisterEvents(frame, owner, events)
	SetupEventFrame(frame, owner, events);
end



---@param frame<Frame>
---@param owner<table>
---@param eventMap<table> { EVENT_NAME = "MethodName" }
function Events:RegisterEventsWithMap(frame, owner, eventMap)
	frame._owner = owner;
	frame._eventMap = eventMap;

	frame:SetScript("OnEvent", function(f, event, ...)
		local method = eventMap[event] or event;
		local callback = owner[method];
		if callback then
			callback(owner, ...);
		end
	end);

	for event in pairs(eventMap) do
		frame:RegisterEvent(event);
	end
end


---@param frame<Frame>
---@param owner<table>
---@param scriptName<string>
---@param methodName<string?> (default = scriptName)
function Events:SetScriptHandler(frame, owner, scriptName, methodName)
	frame._owner = owner;
	frame["_" .. scriptName .. "Method"] = methodName; -- nil = fallback to scriptName
	frame:SetScript(scriptName, GetOrCreateScriptHandler(scriptName));
end


---@param frame<Frame>
---@param scriptName<string>
function Events:ClearScriptHandler(frame, scriptName)
	frame:SetScript(scriptName, nil);
end
