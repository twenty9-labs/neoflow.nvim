-- Configuration module for neoflow

---@class Config
---@field keymap_open string Keymap to open the worktree window
---@field keymap_select string Keymap to select a worktree from the list
---@field border string|table Border style for the floating window

local M = {}

-- Default configuration
local defaults = {
	keymap_open = "<leader>gw",
	keymap_select = "<CR>",
	border = "single",
}

---@type Config
M.config = vim.deepcopy(defaults) -- Ensure a fresh copy

-- Setup function to merge user config with defaults
---@param user_config table User-provided configuration
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", defaults, user_config or {})
	-- Validate keymap_select (used in buffer keymap)
	if type(M.config.keymap_select) ~= "string" or M.config.keymap_select == "" then
		vim.notify("neoflow: Invalid keymap_select, using default '<CR>'", vim.log.levels.WARN)
		M.config.keymap_select = "<CR>"
	end
	-- Validate border
	if type(M.config.border) ~= "string" and type(M.config.border) ~= "table" then
		vim.notify("neoflow: Invalid border, using default 'single'", vim.log.levels.WARN)
		M.config.border = "single"
	end
end

return M
