return blitz.register_tool({
	name = "codemode",
	description = [[Execute a Lua script that drives the other tools instead of calling them one by one.
In the script:
- ctx:call(name, args) runs one tool of this agent, returns its result text (error text on failure)
- ctx:batch({ { name = ..., args = ... }, ... }) runs up to 8 in parallel, returns one text per request in order
- print(...) and the return value are the only text that enters the chat. Nested tool results never do: filter them inside the script and keep only what you need.

Example, two greps in one step, distilled to one line each:
local r = ctx:batch({
	{ name = "bash", args = { command = "rg -c TODO a.zig", description = "count TODOs" } },
	{ name = "bash", args = { command = "rg -c TODO b.zig", description = "count TODOs" } },
})
for i, out in ipairs(r) do print(i, out:match("^%S+") or "0") end

Tables use Lua syntax: `name = "bash"` and `command = "..."`, never JSON colons.
]],
	args = {
		code = {
			type = "string",
			description = "Lua source; print(...) output and the return value are the result",
			required = true,
		},
	},
	snippet = "Batch many tool calls into one Lua script: parallel calls, loops, output filtered before it enters the chat",
	guidelines = "Codemode is active. Use it to batch calls/agents effectivly",
	func = function(ctx, call)
		local orange = "\27[38;5;208m"
		local bold = "\27[1m"
		local reset = "\27[0m"

		ctx:set_status(orange .. bold .. "Codemode" .. reset .. "\n" .. call.arguments.code)
		local env = setmetatable({ ctx = ctx }, { __index = _G })
		local fn, err = load(call.arguments.code, "codemode", "t", env)
		if not fn then
			local message = tostring(err)
			if message:find("expected near") or message:find("unexpected symbol") then
				message = message
					.. '\ncodemode uses Lua table syntax: { name = "bash", args = { command = "..." } }; equals, not JSON colons'
			end
			error(message)
		end

		local ok, result = pcall(fn)
		if not ok then
			error(tostring(result))
		end

		return { msg = result ~= nil and tostring(result) or nil }
	end,
})
