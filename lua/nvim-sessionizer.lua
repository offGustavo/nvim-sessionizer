local M = {}

local sessions_dir = vim.fn.expand("/tmp/nvim-sessions/")
vim.fn.mkdir(sessions_dir, "p")

M.sessions = {}
M.current_index = nil

---Configuration table for Sessionizer
---@class SessionizerConfig
---@field no_zoxide boolean Whether to disable zoxide integration
---@field search_dirs string[] Directories to search for projects
---@field max_depth number Maximum depth to search for projects
local config = {
	no_zoxide = false,
	search_dirs = { "~/projects", "~/work" },
	max_depth = 3,
	ui = {
		keymap = {
			quit = "q",
			attach = "<CR>",
			delete = "D",
		},
		win = {
			width = 0.6,
			height = 0.4,
			winbar = {
				hl_left = "Title", -- highlight group para a parte esquerda
				hl_right = "Comment", -- highlight group para a parte direita
				hl_separator = "Comment", -- highlight group para a parte direita
				sep_left = "/", -- separador entre ações
				sep_mid = "%=", -- separador para alinhar
				sep_right = "│",
				format = function(config) -- agora recebe o config
					return {
						left = {
							config.ui.keymap.quit .. " close",
							config.ui.keymap.delete .. " delete session",
						},
						right = {
							config.ui.keymap.attach .. " attach session",
						},
					}
				end,
			},
		},
		current = {
			mark = ">",
			hl = "MatchParen",
		},
	},
}

--- Verify if a command exists in the system.
---@param cmd string Command name to check.
---@return boolean True if the command exists, false otherwise.
local function command_exists(cmd)
	return vim.fn.executable(cmd) == 1
end

--- Return the current session name.
---@return string The current session name.
function M.get_current_session()
	return vim.fn.fnamemodify(vim.v.servername, ":t")
end

--- Update the session list and set the current index.
local function update_sessions()
	local sessions = vim.fn.globpath(sessions_dir, "*", false, true)
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

--- Select a project directory using zoxide, find, or configured search paths,
--- and call the provided callback with the selected path.
---@param callback fun(path:string) Function to call with the selected project path.
---@return nil
local function select_project(callback)
	local results = {}

	-- 1. Try zoxide if available and not disabled
	if not config.no_zoxide and command_exists("zoxide") then
		results = vim.fn.systemlist("zoxide query -l -s", nil, 1)
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
			vim.ui.select(items, {
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

	-- 2. Collect existing search directories from config
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

	-- 3. Build search command using `find` (TODO: fix fd command support)
	local cmd = nil
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

	results = vim.fn.systemlist(cmd, nil, 1)
	if vim.v.shell_error ~= 0 then
		vim.notify("Command failed: " .. cmd, vim.log.levels.ERROR)
		return
	end

	if #results == 0 then
		vim.notify("No directories found", vim.log.levels.WARN)
		return
	end

	-- 4. Prepare items for selection
	local items = {}
	for _, path in ipairs(results) do
		table.insert(items, { path = path, display = path })
	end

	--TODO: move this to the sessionizer fucntion
	-- 5. Use vim.ui.select to show picker
	vim.ui.select(items, {
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

local function build_winbar()
	local wb_cfg = config.ui.win.winbar
	local fmt = wb_cfg.format(config)

	local left = {}
	for i, txt in ipairs(fmt.left or {}) do
		table.insert(left, string.format("%%#%s#%s%%*", wb_cfg.hl_left, txt))
		if i < #fmt.left then
			table.insert(left, wb_cfg.sep_left)
		end
	end

	local right = {}
	for i, txt in ipairs(fmt.right or {}) do
		table.insert(right, string.format("%%#%s#%s%%*", wb_cfg.hl_right, txt))
		if i < #fmt.right then
			table.insert(right, wb_cfg.sep_right)
		end
	end

	return table.concat(left, " ") .. " " .. wb_cfg.sep_mid .. " " .. table.concat(right, " ")
end

--- Create a new session in the current working directory.
--- Prompts the user for a session name, then calls `create_session`.
function M.new_session()
	vim.ui.input({ prompt = "Session name:" }, function(name)
		local path = vim.uv.cwd() .. ""
		create_session(path, name)
	end)
end

--- Attach to an existing session.
--- If `arg` is:
---   - `+1`: attach to the next session in the list
---   - `-1`: attach to the previous session
---   - a number: attach to the session at that index
--- Otherwise, shows a session picker for manual selection.
---@param arg? string|number|nil Session selector (`+1`, `-1`, index number, or nil for manual choice).
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

		-- Wrap around if index goes out of range
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
		-- Show session picker if no index or relative argument provided
		vim.ui.select(M.sessions, { prompt = "Select a session to connect:" }, function(choice)
			if choice then
				local socket = sessions_dir .. "/" .. choice
				vim.cmd("connect " .. socket)
				vim.notify("Connected to session: " .. choice)
				update_sessions()
			end
		end)
	end
end

--- Remove a session by ID, name, or path.
--- If no arguments are provided, a popup will appear to select the session to delete.
---@param id? number  # Optional session index
---@param name? string  # Optional session name
---@return nil
function M.remove_session(id, name)
	update_sessions()
	if #M.sessions == 0 then
		vim.notify("No sessions to remove", vim.log.levels.WARN)
		return
	end

	-- If ID or name is provided, try to find and remove the specific session
	if id or name then
		local target_session

		if id then
			-- Find session by index (ID)
			if id >= 1 and id <= #M.sessions then
				target_session = M.sessions[id]
			else
				vim.notify("Invalid session ID: " .. id, vim.log.levels.ERROR)
				return
			end
		elseif name then
			-- Find session by name
			for _, session in ipairs(M.sessions) do
				if session == name then
					target_session = session
					break
				end
			end
			if not target_session then
				vim.notify("Session not found: " .. name, vim.log.levels.ERROR)
				return
			end
		end

		-- Remove the found session
		local socket = sessions_dir .. "/" .. target_session
		if vim.fn.filereadable(socket) == 1 or vim.fn.getftype(socket) == "socket" then
			-- Send command to close Neovim
			vim.cmd(string.format("silent! call server2client('%s', 'qa!')", socket))
			-- Give time for the process to close before removing
			vim.defer_fn(function()
				vim.fn.delete(socket)
				vim.notify("Session removed: " .. target_session)
				M.update_sessions()
			end, 200)
		else
			vim.notify("Socket not found: " .. socket, vim.log.levels.WARN)
		end
	else
		-- No arguments provided, show selection popup
		vim.ui.select(M.sessions, { prompt = "Select a session to remove:" }, function(choice)
			if choice then
				local socket = sessions_dir .. "/" .. choice
				if vim.fn.filereadable(socket) == 1 or vim.fn.getftype(socket) == "socket" then
					-- Send command to close Neovim
					vim.cmd(string.format("silent! call server2client('%s', 'qa!')", socket))
					-- Give time for the process to close before removing
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
end

--- List all available sessions in an interactive buffer
---comment
---@param opts table config
function M.manage_sessions(opts)
	opts = opts or {}
	local width_ratio = opts.width or config.ui.win.width
	local height_ratio = opts.height or config.ui.win.height

	--TODO: change it to update_sessions return the log...(idk)
	update_sessions()
	if #M.sessions == 0 then
		vim.notify("No active sessions", vim.log.levels.INFO)
		return
	end

	local width = math.floor(vim.o.columns * width_ratio)
	local height = math.floor(vim.o.lines * height_ratio)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})
	vim.wo[win].winbar = build_winbar()

	-- define o ícone usado na signcolumn
	vim.fn.sign_define(
		"SessionMark",
		{ text = config.ui.current.mark, texthl = config.ui.current.hl, linehl = "", numhl = "" }
	)

	local function render_sessions()
		local formatted = {}
		for i, name in ipairs(M.sessions) do
			table.insert(formatted, string.format("%d: %s", i, name))
		end

		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
		vim.bo[buf].modifiable = false

		-- limpa signs antigos antes de aplicar de novo
		vim.fn.sign_unplace("session_marks", { buffer = buf })

		-- aplica mark na linha atual
		if M.current_index and M.sessions[M.current_index] then
			vim.fn.sign_place(
				0, -- id (0 = auto)
				"session_marks", -- group
				"SessionMark", -- nome do sign definido
				buf, -- buffer alvo
				{ lnum = M.current_index, priority = 10 }
			)
		end
	end

	render_sessions()

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false

	-- função para remover sessão
	local function remove_session()
		local line = vim.fn.line(".")
		local session = M.sessions[line]
		if session then
			M.remove_session(line)
			vim.defer_fn(function()
				update_sessions()
				render_sessions()
			end, 300)
		end
	end

	-- função para fazer attach na sessão
	local function attach_session()
		local line = vim.fn.line(".")
		local session = M.sessions[line]
		if session then
			M.attach_session(line) -- precisa estar implementado no seu módulo
			vim.api.nvim_win_close(win, true)
		end
	end

	-- mapear <CR> para attach
	vim.keymap.set("n", config.ui.keymap.attach, attach_session, { buffer = buf, nowait = true })

	-- mapear D para remover sessão
	vim.keymap.set("n", config.ui.keymap.delete, remove_session, { buffer = buf, nowait = true })

	-- mapear q para fechar a janela
	vim.keymap.set("n", config.ui.keymap.quit, function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })
end

--- Create a new session or attach to an existing one by selecting a project path
--- Uses vim.ui.select() to choose from available projects
---@return nil
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

---Setup function for Sessionizer
---@param user_config? SessionizerConfig User configuration to override defaults
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
	end, {
		nargs = "*",
		complete = function(_, line)
			local words = vim.split(line, "%s+")
			local n = #words
			if n == 2 then
				return { "new", "attach", "remove", "list" }
			elseif n == 3 and words[2] == "attach" then
				M.update_sessions()
				return M.sessions or {}
			end
			return {}
		end,
	})
end

return M
