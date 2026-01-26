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
local pairs = pairs;
local pcall = pcall;

--@class Dispatcher<core>
local Dispatcher = {};
Engine.Dispatcher = Dispatcher;

-- [event] = { [id]={owner, method} }
local events = {};
local nextID = 0;


---@param event <string>
---@param owner <table>
---@param methodName <string>
---@return <number> id
function Dispatcher:RegisterEvent(event, owner, methodName)
	nextID = nextID + 1;
	local id = nextID;

	-- Create an empty table
	local bucket = events[event];
	if not bucket then
		bucket = {};
		events[event] = bucket;
	end

	bucket[id] = { owner = owner, method = methodName };
	return id;
end


---@param event <string>
---@param id <number>
function Dispatcher:UnregisterEvent(event, id)
	local bucket = events[event];
	if bucket then
		bucket[id] = nil;
	end
end


---@param owner <table>
function Dispatcher:UnregisterAllForOwner(owner)
	for event, bucket in pairs(events) do
		for id, data in pairs(bucket) do
			if data.owner == owner then
				bucket[id] = nil;
			end
		end
	end
end


---@param event <string>
---@param ... <args>
function Dispatcher:FireEvent(event, ...)
	local bucket = events[event]
	if not bucket then
		return;
	end

	for id, data in pairs(bucket) do
		local owner = data.owner;
		local callback = owner[data.method];
		if callback then
			if Engine.Debug then
				local ok, err = pcall(callback, owner, event, ...);
				if not ok then
					Engine.Log("Dispatcher error [%s]: %s", event, err);
				end
			else
				callback(owner, event, ...);
			end
		end
	end
end


---@param event <string>
---@return <boolean>
function Dispatcher:HasListeners(event)
	local bucket = events[event];
	return bucket and next(bucket) ~= nil;
end