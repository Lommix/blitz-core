local M = {}

local MAX_GRANTS = 64
local MAX_NAME_BYTES = 128
local MAX_TOOLSET_DEPTH = 8
local MAX_DESCRIPTION_BYTES = 16384
local MAX_SNIPPET_BYTES = 256
local MAX_GUIDELINES_BYTES = 512

local DEFAULT_NAME = "codemode"

local DEFAULT_DESCRIPTION = [[Execute a Lua script that drives this tool set.
Call a tool directly with one table: local result = bash{ command = "...", description = "..." }.
Returned value is always a string.
An image read by a tool (read on a png or jpg) is attached to the result automatically; only the last one is kept, so read one image per script.
print(...) output and the return value are the only text that enters the chat. Nested tool results never do: filter them inside the script and keep only what you need.
Tables use Lua syntax: `command = "..."`, never JSON colons.]]

local DEFAULT_SNIPPET = ""
-- "Batch tool calls into one Lua script: parallel calls, loops, output filtered before it enters the chat"
local DEFAULT_GUIDELINES = "" -- "Codemode is active. Use it to batch calls effectively"

local KEYWORDS = {}
for word in
	([[and break do else elseif end false for function goto if in local nil not or repeat return then true until while]]):gmatch(
		"%S+"
	)
do
	KEYWORDS[word] = true
end

local instances = {}

local function fail(message)
	error("codemode.setup: " .. message, 3)
end

local function flatten(list, out, depth)
	if type(list) == "string" then
		out[#out + 1] = list
	elseif type(list) == "table" then
		if depth >= MAX_TOOLSET_DEPTH then
			fail("toolsets nested too deep")
		end
		for _, item in ipairs(list) do
			flatten(item, out, depth + 1)
		end
	else
		fail("tools must be tool names or lists of tool names")
	end
end

local function checked_text(label, value, limit)
	if value == nil then
		return nil
	end
	if type(value) ~= "string" then
		fail(label .. " must be a string")
	end
	if #value > limit then
		fail(label .. " exceeds " .. limit .. " bytes")
	end
	return value
end

local function collect_grants(tools, own_name)
	if tools == nil then
		fail("tools is required")
	end
	local flat = {}
	flatten(tools, flat, 0)

	local grants, seen = {}, {}
	for _, grant in ipairs(flat) do
		if grant == "" then
			fail("empty tool name")
		end
		if #grant > MAX_NAME_BYTES or not utf8.len(grant) then
			fail("invalid tool name '" .. grant .. "'")
		end
		if grant == own_name then
			fail("'" .. grant .. "' cannot grant itself")
		end
		for _, other in ipairs(instances) do
			if grant == other.name then
				fail("'" .. grant .. "' is another codemode tool and cannot be granted")
			end
		end
		if not seen[grant] then
			seen[grant] = true
			grants[#grants + 1] = grant
		end
	end
	if #grants > MAX_GRANTS then
		fail("more than " .. MAX_GRANTS .. " tools")
	end
	return grants
end

local function is_global_name(name)
	return name:match("^[%a_][%w_]*$") ~= nil and not KEYWORDS[name] and name ~= "ctx" and rawget(_G, name) == nil
end

local function tool_function(ctx, name, images)
	return function(args)
		if type(args) ~= "table" then
			error(name .. " takes one table: " .. name .. "{ ... }", 2)
		end
		local text, image = ctx:call(name, args)
		if image then
			images[#images + 1] = image
		end
		return text
	end
end

local function script_environment(ctx, images)
	local script_ctx = {}
	for key, value in pairs(ctx) do
		script_ctx[key] = value
	end
	script_ctx.call = function()
		error("ctx:call is not available here; call tools directly, e.g. bash{ ... }, or use ctx:batch", 2)
	end
	script_ctx.batch = function(first, second)
		local requests = first == script_ctx and second or first
		local texts, batch_images = ctx:batch(requests)
		for index = 1, #requests do
			if batch_images[index] then
				images[#images + 1] = batch_images[index]
			end
		end
		return texts
	end

	local env = setmetatable({ ctx = script_ctx }, { __index = _G })
	for _, name in ipairs(ctx.tools) do
		if is_global_name(name) then
			env[name] = tool_function(ctx, name, images)
		end
	end
	return env
end

local function run_script(ctx, call)
	if ctx.tools == nil then
		error("this blitzdenk version does not support tool grants; update the harness")
	end

	local orange = "\27[38;5;208m"
	local bold = "\27[1m"
	local reset = "\27[0m"
	ctx:set_status(orange .. bold .. "Codemode" .. reset .. "\n" .. call.arguments.code)

	local images = {}
	local fn, err = load(call.arguments.code, "codemode", "t", script_environment(ctx, images))
	if not fn then
		local message = tostring(err)
		if message:find("expected near") or message:find("unexpected symbol") then
			message = message .. '\ncodemode uses Lua table syntax: bash{ command = "..." }; equals, not JSON colons'
		end
		error(message)
	end

	local ok, result = pcall(fn)
	if not ok then
		error(tostring(result))
	end

	local message = result ~= nil and tostring(result) or nil
	if #images > 1 then
		local note = "[" .. #images .. " images were read, only the last is attached]"
		message = message and (message .. "\n" .. note) or note
	end
	return { msg = message, img = images[#images] }
end

---@class CodemodeOpts
---@field name? string
---@field tools (string|string[])[]
---@field description? string appended to the fixed description; list the arguments of the granted tools here
---@field snippet? string
---@field guidelines? string

---@param opts CodemodeOpts
---@return string
function M.setup(opts)
	if type(opts) ~= "table" then
		fail("options table expected")
	end

	local name = opts.name or DEFAULT_NAME
	if type(name) ~= "string" or name == "" or #name > MAX_NAME_BYTES or not utf8.len(name) then
		fail("invalid tool name")
	end
	for _, other in ipairs(instances) do
		if other.name == name then
			fail("tool '" .. name .. "' is already set up")
		end
	end

	local grants = collect_grants(opts.tools, name)
	local extra = checked_text("description", opts.description, MAX_DESCRIPTION_BYTES)
	local description = extra and (DEFAULT_DESCRIPTION .. "\n\n" .. extra) or DEFAULT_DESCRIPTION
	if #description > MAX_DESCRIPTION_BYTES then
		fail("description exceeds " .. MAX_DESCRIPTION_BYTES .. " bytes with the fixed text")
	end
	local snippet = checked_text("snippet", opts.snippet, MAX_SNIPPET_BYTES) or DEFAULT_SNIPPET
	local guidelines = checked_text("guidelines", opts.guidelines, MAX_GUIDELINES_BYTES) or DEFAULT_GUIDELINES

	instances[#instances + 1] = { name = name }

	return blitz.register_tool({
		name = name,
		description = description,
		args = {
			code = {
				type = "string",
				description = "Lua source; print(...) output and the return value are the result",
				required = true,
			},
		},
		snippet = snippet,
		guidelines = guidelines,
		tools = grants,
		func = function(ctx, call)
			return run_script(ctx, call)
		end,
	})
end

return M
