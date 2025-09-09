local M = {}

local sessions_dir = vim.fn.expand("/tmp/nvim-sessions/")
vim.fn.mkdir(sessions_dir, "p")

M.sessions = {}
M.current_index = nil

local config = {
	no_zoxide = false,
	search_dirs = { "~/projects", "~/work" },
	max_depth = 3,
}

--- Verify if a command exists in the system.
---@param cmd string Command name to check.
---@return boolean True if the command exists, false otherwise.
local function command_exists(cmd)
	return vim.fn.executable(cmd) == 1
end

--- List all available sessions in the sessions directory.
---@return string[] A list of session file paths.
local function list_sessions()
	return vim.fn.globpath(sessions_dir, "*", false, true)
end

--- Return the current session name.
---@return string The current session name.
function M.get_current_session()
	return vim.fn.fnamemodify(vim.v.servername, ":t")
end

--- Update the session list and set the current index.
local function update_sessions()
	local sessions = list_sessions()
	M.sessions = {}
	for _, path in ipairs(sessions) do
		table.insert(M.sessions, vim.fn.fnamemodify(path, ":t"))
	end
	table.sort(M.sessions)

	if #M.sessions == 0 then
		M.current_index = nil
	else
		local current = M.get_current_session()
		M.current_index = nil
		for i, name in ipairs(M.sessions) do
			if name == current then
				M.current_index = i
				break
			end
		end
	end
end


--- Select an item from a list using Telescope, fzf-lua, or fallback to vim.ui.select.
---@param items table List of items to choose from.
---@param opts table Options for the picker. Accepts:
---  - prompt: string (optional) Custom prompt text.
---  - format_item: fun(item:any):string (optional) Function to format display text.
---@param callback fun(item:any) Function called with the selected item.
local function select_item(items, opts, callback)
	-- 1. Try Telescope
	local has_telescope, telescope = pcall(require, "telescope")
	if has_telescope then
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		pickers
			.new({}, {
				prompt_title = opts.prompt or "Select Item",
				finder = finders.new_table({
					results = items,
					entry_maker = function(entry)
						return {
							value = entry,
							display = opts.format_item and opts.format_item(entry) or tostring(entry),
							ordinal = opts.format_item and opts.format_item(entry) or tostring(entry),
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(_, map)
					map("i", "<CR>", function(bufnr)
						local selection = action_state.get_selected_entry()
						actions.close(bufnr)
						if selection then
							callback(selection.value)
						end
					end)
					return true
				end,
			})
			:find()
		return
	end

	-- 2. Try fzf-lua
	local has_fzf, fzf = pcall(require, "fzf-lua")
	if has_fzf then
		fzf.fzf_exec(
			vim.tbl_map(function(entry)
				return opts.format_item and opts.format_item(entry) or tostring(entry)
			end, items),
			{
				prompt = opts.prompt or "Select Item> ",
				actions = {
					["default"] = function(selected)
						local idx = nil
						for i, entry in ipairs(items) do
							if (opts.format_item and opts.format_item(entry) or tostring(entry)) == selected[1] then
								idx = i
								break
							end
						end
						if idx then
							callback(items[idx])
						end
					end,
				},
			}
		)
		return
	end

	--TODO: 3. Try snacks.picker

	-- 4. Fallback to vim.ui.select
	vim.ui.select(items, opts, callback)
end

--- Create a new Neovim session and connect to it.
---@param path string The path where the session will be started.
---@param name? string Optional session name. If not provided, it defaults to the last directory name in `path`.
local function create_session(path, name)
	if not path then
		vim.notify("Path is required!", vim.log.levels.ERROR)
		return
	end

	-- If name isn't provided, use the directory name from path
	name = name or vim.fn.fnamemodify(path, ":t"):gsub("%.", "_")
	local socket = sessions_dir .. "/" .. name
	local cmd = string.format('nohup nvim --listen "%s" -c "cd %s" >/dev/null 2>&1 &', socket, path)
	vim.fn.system(cmd)

	vim.defer_fn(function()
		vim.cmd("connect " .. socket)
		vim.notify("New session: " .. name)
		update_sessions()
	end, 500)
end

local function select_project(callback)
	local results = {}

	-- Se zoxide está disponível e não está desabilitado
	if not config.no_zoxide and command_exists("zoxide") then
		results = vim.fn.systemlist("zoxide query -l -s", nil, true)
		if #results == 0 then
			vim.notify("No directories found by zoxide", vim.log.levels.WARN)
		end

		local items = {}
		for _, line in ipairs(results) do
			local score, path = line:match("(%S+)%s+(.+)")
			if path then
				table.insert(items, {
					path = path,
					display = string.format("%s (%s)", path, score),
				})
			end
		end

		if #items > 0 then
			select_item(items, {
				prompt = "Select a project:",
				format_item = function(item)
					return item.display
				end,
			}, function(choice)
				if choice and choice.path then
					callback(choice.path)
				else
					vim.notify("No project selected", vim.log.levels.WARN)
				end
			end)
			return
		end
	end

	local existing_dirs = {}
	for _, dir in ipairs(config.search_dirs or {}) do
		local expanded = vim.fn.expand(dir)
		if vim.fn.isdirectory(expanded) == 1 then
			table.insert(existing_dirs, expanded)
		end
	end

	if #existing_dirs == 0 then
		vim.notify("No valid search directories found", vim.log.levels.ERROR)
		return
	end

	local cmd = nil
	--TODO: fix fd command
	-- if command_exists("fd") then
	-- 	cmd = string.format("fd --type d --color=never --max-depth %d '' %s",
	-- 		config.max_depth or 3,
	-- 		table.concat(existing_dirs, " "))
	if command_exists("find") then
		cmd = string.format(
			"find %s -mindepth 1 -maxdepth %d -type d",
			table.concat(existing_dirs, " "),
			config.max_depth or 3
		)
	else
		vim.notify("Neither zoxide, fd, nor find are available", vim.log.levels.ERROR)
		return
	end

	results = vim.fn.systemlist(cmd, nil, true)
	if vim.v.shell_error ~= 0 then
		vim.notify("Command failed: " .. cmd, vim.log.levels.ERROR)
		return
	end

	if #results == 0 then
		vim.notify("No directories found", vim.log.levels.WARN)
		return
	end

	local items = {}
	for _, path in ipairs(results) do
		table.insert(items, { path = path, display = path })
	end

	select_item(items, {
		prompt = "Select a project:",
		format_item = function(item)
			return item.display
		end,
	}, function(choice)
		if choice and choice.path then
			callback(choice.path)
		else
			vim.notify("No project selected", vim.log.levels.WARN)
		end
	end)
end

function M.new_session()
	vim.ui.input({ prompt = "Session name:" }, function(name)
		local path = vim.uv.cwd() .. ""
		create_session(path, name)
	end)
end

function M.attach_session(arg)
	update_sessions()
	if #M.sessions == 0 then
		vim.notify("No sessions found", vim.log.levels.WARN)
		return
	end

	if arg == "+1" or arg == "-1" or tonumber(arg) then
		if not M.current_index then
			vim.notify("Current session not found, please select manually.", vim.log.levels.WARN)
			return
		end

		local new_index
		if arg == "+1" then
			new_index = M.current_index + 1
		elseif arg == "-1" then
			new_index = M.current_index - 1
		else
			new_index = tonumber(arg)
		end

		if new_index < 1 then
			new_index = #M.sessions
		elseif new_index > #M.sessions then
			new_index = 1
		end

		local next_session = M.sessions[new_index]
		local socket = sessions_dir .. "/" .. next_session
		vim.cmd("connect " .. socket)
		vim.notify("Connected to session: " .. next_session .. " (index " .. new_index .. ")")
		M.current_index = new_index
	else
		select_item(M.sessions, { prompt = "Select a session to connect:" }, function(choice)
			if choice then
				local socket = sessions_dir .. "/" .. choice
				vim.cmd("connect " .. socket)
				vim.notify("Connected to session: " .. choice)
				update_sessions()
			end
		end)
	end
end

function M.remove_session()
	update_sessions()
	if #M.sessions == 0 then
		vim.notify("No sessions to remove", vim.log.levels.WARN)
		return
	end

	select_item(M.sessions, { prompt = "Select a session to remove:" }, function(choice)
		if choice then
			local socket = sessions_dir .. "/" .. choice
			if vim.fn.filereadable(socket) == 1 or vim.fn.getftype(socket) == "socket" then
				-- Envia comando para fechar Neovim
				vim.cmd(string.format("silent! call server2client('%s', 'qa!')", socket))
				-- Dá um tempo para o processo fechar antes de remover
				vim.defer_fn(function()
					vim.fn.delete(socket)
					vim.notify("Session removed: " .. choice)
					M.update_sessions()
				end, 200)
			else
				vim.notify("Socket not found: " .. socket, vim.log.levels.WARN)
			end
		end
	end)
end

function M.get_sessions()
	update_sessions()
	if #M.sessions == 0 then
		vim.notify("No active sessions", vim.log.levels.INFO)
	else
		local formatted = {}
		for i, name in ipairs(M.sessions) do
			local mark = (i == M.current_index) and "(*)" or "   "
			table.insert(formatted, string.format("%s %d:%s", mark, i, name))
		end
		vim.notify("Sessions:\n" .. table.concat(formatted, "\n"))
	end
end

function M.sessionizer()
	select_project(function(path)
		local name = vim.fn.fnamemodify(path, ":t"):gsub("%.", "_")
		local socket = sessions_dir .. "/" .. name
		if
			vim.fn.filereadable(socket) == 1
			or vim.fn.isdirectory(socket) == 1
			or vim.fn.getftype(socket) == "socket"
		then
			--TODO: change it to M.attach_session()
			vim.cmd("connect " .. socket)
			vim.notify("Connected to existing session: " .. name)
		else
			create_session(path, name)
		end
	end)
end

function M.setup(user_config)
	config = vim.tbl_extend("force", config, user_config or {})
	vim.api.nvim_create_user_command("Sessionizer", function(opts)
		local sub = opts.fargs[1]
		if sub == "new" then
			M.new_session()
		elseif sub == "attach" then
			M.attach_session(opts.fargs[2])
		elseif sub == "remove" then
			M.remove_session()
		elseif sub == "list" then
			M.get_sessions()
		elseif not sub then
			M.sessionizer()
		end
	end, { nargs = "*" })
end

return M
