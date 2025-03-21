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

	local current_path = fn.systemlist("git rev-parse --show-toplevel")[1] or fn.getcwd()

	for _, line in ipairs(wt_lines) do
		-- Parse lines like: "/path/to/worktree  commit  [branch]"
		local path, branch = line:match("^(%S+)%s+.-%[(.-)%]")
		if path and branch then
			local name = path:match("[^/]+$") or path -- Extract last directory name
			local is_current = (path == current_path)
			table.insert(worktrees, { name = name, path = path, branch = branch, is_current = is_current })
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
	local max_name_len = math.max(unpack(vim.tbl_map(function(wt)
		return #wt.name
	end, worktrees)))
	local max_branch_len = math.max(unpack(vim.tbl_map(function(wt)
		return #wt.branch
	end, worktrees)))
	local min_width = max_name_len + max_branch_len + 20 -- Minimum width for content
	local width = math.max(min_width, math.floor(vim.o.columns * config.width))
	local min_height = #worktrees + 3 -- Minimum height for content plus padding
	local height = math.max(min_height, math.floor(vim.o.lines * config.height))
	-- Ensure border is valid for title
	local border = config.border
	if type(border) ~= "string" and type(border) ~= "table" then
		border = "single" -- Fallback to default if invalid
	end
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = border,
		title = " NeoFlow Worktrees ",
		title_pos = "center",
	}

	api.nvim_open_win(buf, true, opts)

	-- Populate buffer with worktree info
	local lines = { "" } -- Top padding
	for i, wt in ipairs(worktrees) do
		-- Pad the name and branch for alignment
		local name = wt.name .. string.rep(" ", max_name_len - #wt.name + 2)
		local branch = "(" .. wt.branch .. ")"
		local label = wt.is_current and " (current)" or ""
		table.insert(lines, string.format(" %d: %s%s%s", i, name, branch, label))
	end
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Add syntax highlighting
	api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, -1) -- Highlight the title line
	for i = 1, #worktrees do
		local line_start = 1
		api.nvim_buf_add_highlight(buf, -1, "Number", i, line_start, line_start + 2) -- Highlight the number
		line_start = line_start + 3
		api.nvim_buf_add_highlight(buf, -1, "Directory", i, line_start, line_start + max_name_len) -- Highlight the name
		line_start = line_start + max_name_len + 2
		local branch_end = line_start + #worktrees[i].branch + 2
		api.nvim_buf_add_highlight(buf, -1, "Comment", i, line_start, branch_end) -- Highlight the branch
		if worktrees[i].is_current then
			api.nvim_buf_add_highlight(buf, -1, "Special", i, branch_end, -1) -- Highlight "(current)"
		end
	end

	-- Set buffer-local keymap for selecting with Enter
	api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		":lua require('neoflow').select_worktree()<CR>",
		{ noremap = true, silent = true }
	)
	-- Allow closing with 'q'
	api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
end

-- Switch to selected worktree and handle current file
function M.select_worktree()
	local line = api.nvim_get_current_line()
	local wt_index = tonumber(line:match("^%s*(%d+):"))
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
	local had_file = current_file ~= "" and current_wt_root -- Check if there was a file open

	-- Switch to new worktree
	fn.chdir(selected.path)

	-- Try to open the same file in the new worktree
	if had_file then
		local relative_file = current_file:gsub("^" .. current_wt_root .. "/", "")
		local new_file = selected.path .. "/" .. relative_file
		if fn.filereadable(new_file) == 1 then
			api.nvim_command("edit " .. new_file)
			vim.notify("Switched worktree to " .. selected.name, vim.log.levels.INFO)
			return
		end
	end
	-- If no file was open or file doesn't exist, just notify the switch
	vim.notify("Switched worktree to " .. selected.name, vim.log.levels.INFO)
	api.nvim_command("Oil " .. selected.path) -- Use oil.nvim to show root
end

-- Public setup function
---@param user_config? table Configuration table to override defaults
function M.setup(user_config)
	config.setup(user_config or {})
	api.nvim_create_user_command("NeoFlow", M.open_worktree_window, { desc = "List and switch Git worktrees" })
end

return M
