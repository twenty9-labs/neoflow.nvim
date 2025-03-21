-- Main module for neoflow.nvim
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
	local git_root = fn.systemlist("git rev-parse --git-dir")[1]
	if not git_root or vim.v.shell_error ~= 0 then
		vim.notify("Not in a Git repository", vim.log.levels.ERROR)
		return worktrees
	end

	-- For bare repos, worktrees might be in the root; for non-bare, in .git/worktrees
	local wt_dir = git_root:match("%.git$") and git_root .. "/worktrees" or git_root .. "/../worktrees"
	if fn.isdirectory(wt_dir) == 0 then
		-- Check for bare repo worktrees in the root
		wt_dir = git_root:match("%.git$") and fn.getcwd() or git_root .. "/.."
	end

	local dirs = fn.readdir(wt_dir, [[v:val !~ '^\.' && isdirectory(v:val)]])
	for _, dir in ipairs(dirs) do
		local path = wt_dir .. "/" .. dir
		local branch = fn.systemlist("git -C " .. path .. " rev-parse --abbrev-ref HEAD")[1] or "unknown"
		table.insert(worktrees, { name = dir, path = path, branch = branch })
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

	api.nvim_open_win(buf, true, opts) -- Removed `local win =`

	-- Populate buffer with worktree info
	local lines = {}
	for i, wt in ipairs(worktrees) do
		table.insert(lines, string.format("%d: %s (%s)", i, wt.name, wt.branch))
	end
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Keymap to select worktree
	api.nvim_buf_set_keymap(
		buf,
		"n",
		config.keymap_select,
		":lua require('neoflow').select_worktree()<CR>",
		{ noremap = true, silent = true }
	)
	api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
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
	-- Register keymap and command after setup
	api.nvim_set_keymap(
		"n",
		config.keymap_open,
		":lua require('neoflow').open_worktree_window()<CR>",
		{ noremap = true, silent = true }
	)
	api.nvim_create_user_command("GitWorktree", M.open_worktree_window, { desc = "List and switch Git worktrees" })
end

return M
