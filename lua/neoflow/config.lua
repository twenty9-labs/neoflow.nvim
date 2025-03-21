-- Configuration module for neoflow

---@class Config
---@field border string|table Border style for the floating window

local M = {}

-- Default configuration
local defaults = {
	border = "single",
}

---@type Config
M.config = vim.deepcopy(defaults) -- Ensure a fresh copy

-- Setup function to merge user config with defaults
---@param user_config table User-provided configuration
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", defaults, user_config or {})
	-- Validate border
	if type(M.config.border) ~= "string" and type(M.config.border) ~= "table" then
		vim.notify("neoflow: Invalid border, using default 'single'", vim.log.levels.WARN)
		M.config.border = "single"
	end
end

return M
