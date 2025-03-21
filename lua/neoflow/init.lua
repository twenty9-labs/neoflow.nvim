-- Main module for neoflow
local config = require("neoflow.config")
local api = vim.api
local fn = vim.fn

-- Type annotations
---@class Worktree
---@field name string Name of the worktree (directory name)
---@field path string Full path to the worktree
---@field branch string Branch associated with the worktree

-- Define module table upfront
local M = {}

-- Get list of worktrees from the current Git repo
---@return Worktree[]
local function get_worktrees()
	local worktrees = {}
	-- Use `git worktree list` for accurate detection
	local wt_lines = fn.systemlist("git worktree list")
	if vim.v.shell_error ~= 0 or #wt_lines == 0 then
		vim.notify("No worktrees found or not in a Git repository", vim.log.levels.WARN)
		return worktrees
	end

	for _, line in ipairs(wt_lines) do
		-- Parse lines like: "/path/to/worktree  commit  [branch]"
		local path, branch = line:match("^(%S+)%s+.-%[(.-)%]")
		if path and branch then
			local name = path:match("[^/]+$") or path -- Extract last directory name
			table.insert(worktrees, { name = name, path = path, branch = branch })
		end
	end
	return worktrees
end

-- Open a floating window with worktree list
function M.open_worktree_window()
	local worktrees = get_worktrees()
	if #worktrees == 0 then
		vim.notify("No worktrees found", vim.log.levels.WARN)
		return
	end

	-- Create buffer and window
	local buf = api.nvim_create_buf(false, true)
	local width = math.min(50, math.max(30, #worktrees[1].name + #worktrees[1].branch + 10))
	local height = math.min(#worktrees, 10)
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = config.border,
	}

	api.nvim_open_win(buf, true, opts)

	-- Populate buffer with worktree info
	local lines = {}
	for i, wt in ipairs(worktrees) do
		table.insert(lines, string.format("%d: %s (%s)", i, wt.name, wt.branch))
	end
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = buf })
end

-- Switch to selected worktree and handle current file
function M.select_worktree()
	local line = api.nvim_get_current_line()
	local wt_index = tonumber(line:match("^(%d+):"))
	if not wt_index then
		return
	end

	local worktrees = get_worktrees()
	local selected = worktrees[wt_index]
	if not selected then
		return
	end

	-- Close the window
	api.nvim_win_close(0, true)

	-- Get current file relative to current worktree
	local current_file = fn.expand("%:p")
	local current_wt_root = fn.systemlist("git rev-parse --show-toplevel")[1]
	local relative_file = current_file:gsub("^" .. current_wt_root .. "/", "")

	-- Switch to new worktree
	fn.chdir(selected.path)

	-- Try to open the same file in the new worktree
	local new_file = selected.path .. "/" .. relative_file
	if fn.filereadable(new_file) == 1 then
		api.nvim_command("edit " .. new_file)
	else
		vim.notify("File not found in " .. selected.name, vim.log.levels.WARN, { title = "neoflow" })
		api.nvim_command("Oil " .. selected.path) -- Use oil.nvim to show root
	end
end

-- Public setup function
---@param user_config? table Configuration table to override defaults
function M.setup(user_config)
	config.setup(user_config or {})
	api.nvim_create_user_command("NeoFlow", M.open_worktree_window, { desc = "List and switch Git worktrees" })
end

return M
