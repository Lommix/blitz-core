# Blitzdenk - Default Plugin Core

A collection of useful defaults for the [Blitzdenk harness](https://github.com/Lommix/blitzdenk).

## Includes

- codemode
- sub agents
- todos

## Codemode

```lua
local core = require("blitz-core")

local codemode_fs = core.codemode.setup({
	name = "codemode_fs",
	tools = {
		blitz.toolsets.BASH_BACKGROUND,
		blitz.tools.READ,
		blitz.tools.EDIT,
		blitz.tools.WRITE,
	},
})

blitz.set_agent_tools(blitz.AGENT_GENERAL, { codemode_fs })
```

`setup` returns the tool name. Add it to an agent tool set. Call it once per permission level; do not share one instance between agents with different permissions.

- The grant list is sealed. A script can only call the tools in `tools`, even when the agent does not hold them, and the model only sees the codemode tool. The model learns the granted tools only from the description you pass (see below).
- Scripts call tools directly with one table: `bash{ command = "rg TODO", description = "find todos" }`. The globals are the exposed tool names. A name that is not a valid Lua identifier, a Lua keyword, or already a global is reachable through `ctx:batch` only.
- `ctx:batch({ { name = "read", args = { file_path = "a.zig" } }, ... })` runs up to 8 calls in parallel and returns one text per request, in order. `ctx:call` is blocked inside scripts.
- `print(...)` output and the return value are the only text that enters the chat.
- Options: `name` (default `codemode`), `tools` (required, toolsets flatten, at most 64), `description` (appended to the fixed description; put the granted tools' arguments here, `blitz.tool_info` returns them), `snippet`, `guidelines`.
- A codemode tool cannot be granted to another codemode tool.
- Needs a harness with `ToolDef.tools` (sealed grants) and `blitz.tool_info`.
