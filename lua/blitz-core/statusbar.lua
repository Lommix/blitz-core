local function fmt(n)
	local units = { "k", "M", "G" }
	local u = 0
	while n >= 1000 and u < #units do
		n = n / 1000
		u = u + 1
	end
	if u == 0 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f%s", n, units[u])
end

return function()
	local use = blitz.token_usage()
	local white = "\27[1;37m"
	local green = "\27[32m"
	local orange = "\27[38;5;208m"
	local red = "\27[31m"
	local reset = "\27[0m"

	local prompt_tokens = use.input + use.cache + use.cache_creation
	local hit_percent = 0
	if prompt_tokens > 0 then
		hit_percent = use.cache / prompt_tokens * 100
	end

	local model = blitz.get_model_name(blitz.AGENT_GENERAL)
	local effort = blitz.get_agent_effort(blitz.AGENT_GENERAL)
	local main_id = blitz.get_main_agent()

	if main_id ~= nil then
		model = blitz.agent.get_model(main_id)
		effort = blitz.agent.get_effort(main_id)
	end

	return white
		.. model
		.. " • "
		.. effort
		.. reset
		.. " (Cache:"
		.. green
		.. fmt(use.cache)
		.. reset
		.. " In:"
		.. orange
		.. fmt(use.input)
		.. reset
		.. " Out:"
		.. orange
		.. fmt(use.output)
		.. reset
		.. ") Ctx:"
		.. white
		.. math.floor(blitz.context_percent())
		.. "%"
		.. reset
		.. " Hit:"
		.. green
		.. string.format("%.1f", hit_percent)
		.. "%"
		.. reset
		.. " Cost:"
		.. red
		.. string.format("$%.2f", use.cost)
end
