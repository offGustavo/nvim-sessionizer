local M = {}

local sessions_dir = vim.fn.expand("/tmp/nvim-sessions/")
vim.fn.mkdir(sessions_dir, "p")

M.sessions = {}
M.current_index = nil
M.session_order = {}

--- Configuration table for Sessionizer
---@class SessionizerConfig
---@field no_zoxide boolean Disable zoxide integration
---@field search_dirs string[] Directories to search for projects
---@field max_depth integer Maximum depth to search for projects
---@field ui SessionizerUIConfig? UI configuration

---@class SessionizerUIConfig
---@field keymap SessionizerKeymapConfig Key mappings for actions
---@field win SessionizerWinConfig Window configuration
---@field current SessionizerCurrentConfig Highlight for the current session

---@class SessionizerKeymapConfig
---@field quit string Key to quit the window
---@field attach string Key to attach to a session
---@field delete string Key to delete a session
---@field move_up string Key to move session up
---@field move_down string Key to move session down

---@class SessionizerWinConfig
---@field width number Window width ratio (0-1)
---@field height number Window height ratio (0-1)
---@field winbar SessionizerWinbarConfig Winbar configuration

---@class SessionizerWinbarConfig
---@field hl_left string Highlight group for left section text
---@field hl_right string Highlight group for right section text
---@field hl_separator string Highlight group for separators
---@field sep_left string Separator between left items
---@field sep_mid string Separator for middle alignment
---@field sep_right string Separator between right items
---@field format fun(config:SessionizerConfig):{left:string[], right:string[]} Function that returns formatted winbar items

---@class SessionizerCurrentConfig
---@field mark string Marker for the current session
---@field hl string Highlight group for the marker
local config = {
	no_zoxide = false,
	search_dirs = { "~/projects", "~/work" },
	max_depth = 3,
	ui = {
		keymap = {
			quit = "q",
			attach = "<CR>",
			delete = "<S-d>",
			move_up = "<S-k>",
			move_down = "<S-j>",
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
							" " .. config.ui.keymap.quit .. " close",
							config.ui.keymap.delete .. " delete session",
						},
						right = {
							config.ui.keymap.attach .. " attach session",
							config.ui.keymap.move_up .. "/" .. config.ui.keymap.move_down .. " move session ",
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

---Save the session order to a file.
---@return nil
local function save_session_order()
	local order_file = sessions_dir .. "/session_order"
	local lines = {}
	for _, session_name in ipairs(M.session_order) do
		table.insert(lines, session_name)
	end
	vim.fn.writefile(lines, order_file)
end

---Load the session order from a file.
---@return nil
local function load_session_order()
	local order_file = sessions_dir .. "/session_order"
	if vim.fn.filereadable(order_file) == 1 then
		local lines = vim.fn.readfile(order_file)
		M.session_order = lines
	else
		M.session_order = {}
	end
end

---Apply the saved session order to the current sessions list.
---@return nil
local function apply_session_order()
	if #M.session_order > 0 then
		local ordered_sessions = {}
		local unordered_sessions = {}

		for _, ordered_name in ipairs(M.session_order) do
			for _, session_name in ipairs(M.sessions) do
				if session_name == ordered_name then
					table.insert(ordered_sessions, session_name)
					break
				end
			end
		end

		for _, session_name in ipairs(M.sessions) do
			local found = false
			for _, ordered_name in ipairs(ordered_sessions) do
				if session_name == ordered_name then
					found = true
					break
				end
			end
			if not found then
				table.insert(unordered_sessions, session_name)
			end
		end

		M.sessions = ordered_sessions
		for _, session_name in ipairs(unordered_sessions) do
			table.insert(M.sessions, session_name)
		end
	end
end

---Build a formatted winbar string with highlights and separators.
---The function processes left and right sections of the winbar configuration,
---applying highlights to keymaps and using specified separators.
---@return string # Formatted winbar string ready for vim.wo.winbar
local function build_winbar()
	-- TODO: Simplificar isso
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

---Verify if a command exists in the system.
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
--- @return nil
local function update_sessions()
	local sessions = vim.fn.globpath(sessions_dir, "*", false, true)
	M.sessions = {}
	for _, path in ipairs(sessions) do
		local session_name = vim.fn.fnamemodify(path, ":t")
		-- Ignora o arquivo de ordem das sessões
		if session_name ~= "session_order" and not session_name:match("%.vim$") then
			table.insert(M.sessions, session_name)
		end
	end

	load_session_order()
	apply_session_order()

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

--- Create (or connect to) a Neovim session.
---
--- This function will:
--- 1. Validate the provided path.
--- 2. Derive a session name if one is not provided.
--- 3. Check if a socket for this session already exists.
---    - If it exists, connect to the running session.
---    - If it doesn't, start a new Neovim instance with the session socket.
--- 4. Attach the current client to the session.
---
---@param path string The filesystem path where the session will start.
---@param name? string Optional session name. Defaults to the last directory name in `path`.
local function create_session(path, name)
	if not path then
		vim.notify("Path is required!", vim.log.levels.ERROR)
		return
	end

	name = name or vim.fn.fnamemodify(path, ":t"):gsub("%.", "_")
	local socket = sessions_dir .. "/" .. name
	local session_file = sessions_dir .. "/" .. name .. ".vim" -- arquivo de mksession

	-- Se o socket já existir, conecta
	if vim.fn.filereadable(socket) == 1 or vim.fn.getftype(socket) == "socket" then
		vim.notify("Existing session found. Connecting to '" .. name .. "'...", vim.log.levels.INFO)
	else
		-- Se houver arquivo de sessão salvo, carrega ele
		local cmd
		if vim.fn.filereadable(session_file) == 1 then
			vim.notify("Session file found. Restoring session '" .. name .. "'...", vim.log.levels.INFO)
			cmd = string.format('nohup nvim --listen "%s" -S "%s" >/dev/null 2>&1 &', socket, session_file)
		else
			-- Caso contrário, apenas abre Neovim no diretório
			cmd = string.format('nohup nvim --listen "%s" -c "cd %s" >/dev/null 2>&1 &', socket, path)
		end
		vim.fn.system(cmd)
	end

	-- Conecta depois de iniciar
	vim.defer_fn(function()
		M.attach_session(name)
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
					display = string.format("%s %s", score, path),
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

	-- 3. Build search command using `find` (TODO: add fd command support)
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

--- Create a new session in the current working directory.
--- Prompts the user for a session name, then calls `create_session`.
--- If the user presses <Esc>, the operation is canceled.
--- If the user presses <Enter> without typing a name, a new session will be created
--- using the current directory name as default.
---@return nil
function M.new_session()
	vim.ui.input({ prompt = "Session name: " }, function(name)
		local path = vim.uv.cwd() .. ""

		if name == nil then
			vim.notify("Operation canceled. Session not created.", vim.log.levels.WARN)
			return
		end

		if name == "" then
			name = vim.fn.fnamemodify(path, ":t"):gsub("%.", "_")
			vim.notify("No session name provided. Using default: " .. name, vim.log.levels.INFO)
		end

		local session_file = sessions_dir .. "/" .. name .. ".vim"
		vim.cmd("mksession! " .. vim.fn.fnameescape(session_file))

		create_session(path, name)
	end)
end

--- Attach to an existing session.
--- If `arg` is:
---   - `+1`: attach to the next session in the list
---   - `-1`: attach to the previous session
---   - a number: attach to the session at that index
---   - a string: attach to the session by name
--- Otherwise, shows a session picker for manual selection.
---@param arg? string|number|nil Session selector (`+1`, `-1`, index number, name, or nil for manual choice).
function M.attach_session(arg)
	update_sessions()
	if #M.sessions == 0 then
		vim.notify("No sessions found", vim.log.levels.WARN)
		return
	end

	-- Handle relative (+1/-1) or numeric index
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

	-- Handle string session name
	elseif type(arg) == "string" and arg ~= "" then
		local found_index
		for i, name in ipairs(M.sessions) do
			if name == arg then
				found_index = i
				break
			end
		end

		if found_index then
			local socket = sessions_dir .. "/" .. arg
			vim.cmd("connect " .. socket)
			vim.notify("Connected to session: " .. arg)
			M.current_index = found_index
		else
			vim.notify("Session not found: " .. arg, vim.log.levels.ERROR)
		end

	-- Fallback: manual picker
	else
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
				update_sessions()
				-- Atualiza a ordem após remover a sessão
				for i, session_name in ipairs(M.session_order) do
					if session_name == target_session then
						table.remove(M.session_order, i)
						break
					end
				end
				save_session_order()
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
						update_sessions()
						-- Atualiza a ordem após remover a sessão
						for i, session_name in ipairs(M.session_order) do
							if session_name == choice then
								table.remove(M.session_order, i)
								break
							end
						end
						save_session_order()
					end, 200)
				else
					vim.notify("Socket not found: " .. socket, vim.log.levels.WARN)
				end
			end
		end)
	end
end

--- Reorders the session list by moving a session up or down.
---
--- If `up` is true, the session will move one position up.
--- Otherwise, it will move one position down.
--- The custom order (`M.session_order`) is updated after the move.
---
---@param line integer The index (1-based) of the session to move.
---@param up boolean If true, move the session up; if false or nil, move it down.
---@return boolean success True if the session was successfully moved, false otherwise.
---
---@example
--- -- Move the second session down
--- local ok = move_session(2, false)
--- print(ok) -- true if moved
---
--- -- Move the third session up
--- local ok = move_session(3, true)
--- print(ok) -- true if moved
local function move_session(line, up)
	if line < #M.sessions and not up then
		-- Move a sessão na lista
		local temp = M.sessions[line]
		M.sessions[line] = M.sessions[line + 1]
		M.sessions[line + 1] = temp

		-- Atualiza a ordem personalizada
		M.session_order = vim.deepcopy(M.sessions)
		save_session_order()

		return true
	end

	if line > 1 and up then
		-- Move a sessão na lista
		local temp = M.sessions[line]
		M.sessions[line] = M.sessions[line - 1]
		M.sessions[line - 1] = temp

		-- Atualiza a ordem personalizada
		M.session_order = vim.deepcopy(M.sessions)
		save_session_order()

		return true
	end

	render_sessions()
	return false
end

--- List all available sessions in an interactive buffer
---@param opts? table config
function M.manage_sessions(opts)
	opts = opts or {}
	local width_ratio = opts.width or config.ui.win.width
	local height_ratio = opts.height or config.ui.win.height

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
		title = " Sessionizer ",
		border = "rounded",
	})
	vim.wo[win].winbar = build_winbar()
	vim.wo[win].number = true
	vim.wo[win].cursorline = true

	-- define o ícone usado na signcolumn
	vim.fn.sign_define(
		"SessionMark",
		{ text = config.ui.current.mark, texthl = config.ui.current.hl, linehl = "", numhl = "" }
	)

	local function render_sessions()
    local formatted = {}
    for i, name in ipairs(M.sessions) do
        -- Usa apenas o número da linha para representar a ordem
        table.insert(formatted, string.format("%s", name))
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
    vim.bo[buf].modifiable = false

    -- limpa signs antigos antes de aplicar de novo
    vim.fn.sign_unplace("session_marks", { buffer = buf })

    -- Atualiza o current_index para refletir a nova posição da sessão atual
    if M.current_index then
        local current_session = M.get_current_session()
        -- Encontra a nova posição da sessão atual na lista reordenada
        for i, name in ipairs(M.sessions) do
            if name == current_session then
                M.current_index = i
                break
            end
        end
    end

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
			M.attach_session(line)
			vim.api.nvim_win_close(win, true)
		end
	end

	-- Key mappings for session management in the session picker buffer
	-- All mappings use the configured keybinds and are buffer-local with nowait

	-- Default: <CR> - Attach to the selected session
	-- When pressed, attaches to the session at the current cursor line
	-- Customize: Modify config.ui.keymap.attach to change this binding
	vim.keymap.set("n", config.ui.keymap.attach, attach_session, { buffer = buf, nowait = true })

	-- Default: Shift+D - Delete the selected session
	-- Removes the session at the current cursor line and updates the list
	-- Customize: Modify config.ui.keymap.delete to change this binding
	vim.keymap.set("n", config.ui.keymap.delete, remove_session, { buffer = buf, nowait = true })

	-- Default: Shift+K - Move session up in the list
	-- Moves the current session up one position and moves cursor to follow it
	-- Customize: Modify config.ui.keymap.move_up to change this binding
	vim.keymap.set("n", config.ui.keymap.move_up, function()
		-- Get current cursor line (1-based index)
		local line = vim.fn.line(".")
		-- Attempt to move session up; if successful, update cursor position
		if move_session(line, true) then
			-- Move cursor up to follow the moved session
			vim.api.nvim_win_set_cursor(win, { line - 1, 0 })
		end
		-- Refresh the session list display to show new order
		render_sessions()
	end, { buffer = buf, nowait = true })

	-- Default: Shift+J - Move session down in the list
	-- Moves the current session down one position and moves cursor to follow it
	-- Customize: Modify config.ui.keymap.move_down to change this binding
	vim.keymap.set("n", config.ui.keymap.move_down, function()
		-- Get current cursor line (1-based index)
		local line = vim.fn.line(".")
		-- Attempt to move session down; if successful, update cursor position
		if move_session(line, false) then
			-- Move cursor down to follow the moved session
			vim.api.nvim_win_set_cursor(win, { line + 1, 0 })
		end
		-- Refresh the session list display to show new order
		render_sessions()
	end, { buffer = buf, nowait = true })

	-- Default: q - Close the session management window
	-- Safely closes the floating window without affecting sessions
	-- Customize: Modify config.ui.keymap.quit to change this binding
	vim.keymap.set("n", config.ui.keymap.quit, function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })
end

--- Create a new session or attach to an existing one by selecting a project path
--- Uses vim.ui.select() to choose from available projects
---@return nil
function M.sessionizer()
	select_project(function(path)
		create_session(path)
	end)
end

---Setup function for Sessionizer
---@param user_config? SessionizerConfig User configuration to override defaults
function M.setup(user_config)
	config = vim.tbl_extend("force", config, user_config or {})

	-- Carrega a ordem das sessões ao inicializar
	load_session_order()

	vim.api.nvim_create_user_command("Sessionizer", function(opts)
		local sub = opts.fargs[1]
		if sub == "new" then
			M.new_session()
		elseif sub == "attach" then
			M.attach_session(opts.fargs[2])
		elseif sub == "remove" then
			M.remove_session()
		elseif sub == "manage" then
			M.manage_sessions()
		elseif not sub then
			M.sessionizer()
		end
	end, {
		nargs = "*",
		complete = function(_, line)
			local words = vim.split(line, "%s+")
			local n = #words
			if n == 2 then
				return { "new", "attach", "remove", "manage" }
			elseif n == 3 and words[2] == "attach" then
				update_sessions()
				return M.sessions or {}
			end
			return {}
		end,
	})
end

return M
