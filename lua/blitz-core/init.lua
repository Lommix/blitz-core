--- Default plugins for the Blitzdenk harness.
--- Each module registers its tools on require; pass the returned tool name or
--- toolset to `blitz.add_tool` / `blitz.set_agent_tools`.
local M = {}

--- Tool name for codemode. Executes a Lua script in the agent sandbox that
--- drives every registered tool through `ctx:call` and `ctx:batch`.
---@type string
M.codemode = require("blitz-core.codemode")

--- Subagent toolset: `agent`, `message_agent`, `cancel_agent`, `idle`.
--- Spawns background agents and injects the agent catalogue into sessions
--- that hold the agent tool.
M.subagents = require("blitz-core.subagents")

--- Todo toolset: `todo_add`, `todo_start`, `todo_done`, `todo_list`.
--- One list per agent in session state, with open counts injected into the
--- session context.
M.todo = require("blitz-core.todo")

return M
