-- Configuration module for neoflow.nvim

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
M.config = defaults

-- Setup function to merge user config with defaults
---@param user_config table User-provided configuration
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", defaults, user_config or {})
end

return M
