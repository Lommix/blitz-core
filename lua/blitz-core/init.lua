--- Default plugins for the Blitzdenk harness.
--- Subagents and todo register their tools on require; pass the returned toolset
--- to `blitz.add_tool` / `blitz.set_agent_tools`. Codemode registers on `setup`.
local M = {}

--- Codemode module. `core.codemode.setup({ tools = { ... } })` registers a
--- codemode tool granted exactly those tools and returns its tool name.
---@type { setup: fun(opts: CodemodeOpts): string }
M.codemode = require("blitz-core.codemode")

--- Subagent toolset: `agent`, `message_agent`, `cancel_agent`, `idle`.
--- Spawns background agents and injects the agent catalogue into sessions
--- that hold the agent tool.
M.subagents = require("blitz-core.subagents")

--- Todo toolset: `todo_add`, `todo_start`, `todo_done`, `todo_list`.
--- One list per agent in session state, with open counts injected into the
--- session context.
M.todo = require("blitz-core.todo")

--- Default Statusbar render
---@type fun(): string
M.statusbar = require("blitz-core.statusbar")

return M
