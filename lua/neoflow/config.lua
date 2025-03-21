-- Configuration module for neoflow
local M = {}

-- Default configuration
local defaults = {
	border = "single",
	width = 0.8, -- 80% of editor width
	height = 0.6, -- 60% of editor height
}

M.config = vim.deepcopy(defaults) -- Ensure a fresh copy

-- Setup function to merge user config with defaults
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", defaults, user_config or {})
	-- Validate border
	if type(M.config.border) ~= "string" and type(M.config.border) ~= "table" then
		vim.notify("neoflow: Invalid border, using default 'single'", vim.log.levels.WARN)
		M.config.border = "single"
	end
	-- Validate width
	if type(M.config.width) ~= "number" or M.config.width < 0.1 or M.config.width > 1.0 then
		vim.notify("neoflow: Invalid width, using default 0.8", vim.log.levels.WARN)
		M.config.width = 0.8
	end
	-- Validate height
	if type(M.config.height) ~= "number" or M.config.height < 0.1 or M.config.height > 1.0 then
		vim.notify("neoflow: Invalid height, using default 0.6", vim.log.levels.WARN)
		M.config.height = 0.6
	end
end

return M
