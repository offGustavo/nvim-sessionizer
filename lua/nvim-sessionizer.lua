local M = {}

local sessions_dir = vim.fn.expand("/tmp/nvim-sessions/")
vim.fn.mkdir(sessions_dir, "p")

M.sessions = {}
M.current_index = nil

local config = {
	no_zoxide = false,
	search_dirs = { "~/projects", "~/work" },
	fd_cmd = "fd --type d --max-depth 1",
	find_cmd = "find %s -type d -maxdepth 1",
}

local function command_exists(cmd)
	return vim.fn.executable(cmd) == 1
end

local function list_sessions()
	return vim.fn.globpath(sessions_dir, "*", false, true)
end

function M.update_sessions()
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

function M.new_session()
	vim.ui.input({ prompt = "Session name:" }, function(name)
		if name and name ~= "" then
			local socket = sessions_dir .. "/" .. name
			local cmd = { "nohup", "nvim", "--listen", socket, ">/dev/null", "2>&1", "&" }
			vim.fn.jobstart(table.concat(cmd, " "), { detach = true })
			vim.defer_fn(function()
				vim.cmd("connect " .. socket)
				vim.notify("Session created and connected: " .. name)
				M.update_sessions()
			end, 300)
		end
	end)
end

function M.attach_session(arg)
	M.update_sessions()
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
		vim.ui.select(M.sessions, { prompt = "Select a session to connect:" }, function(choice)
			if choice then
				local socket = sessions_dir .. "/" .. choice
				vim.cmd("connect " .. socket)
				vim.notify("Connected to session: " .. choice)
				M.update_sessions()
			end
		end)
	end
end

function M.remove_session()
	M.update_sessions()
	if #M.sessions == 0 then
		vim.notify("No sessions to remove", vim.log.levels.WARN)
		return
	end

	vim.ui.select(M.sessions, { prompt = "Select a session to remove:" }, function(choice)
		if choice then
			local socket = sessions_dir .. "/" .. choice
			vim.fn.delete(socket)
			vim.notify("Session removed: " .. choice)
			M.update_sessions()
		end
	end)
end

function M.get_sessions()
	M.update_sessions()
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

function M.get_current_session()
	return vim.fn.fnamemodify(vim.v.servername, ":t")
end

local function select_project(callback)
	local results = {}

	if not config.no_zoxide and command_exists("zoxide") then
		results = vim.fn.systemlist("zoxide query -l -s")
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

	local cmd = nil
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

	if command_exists("fd") then
		cmd = string.format("fd --type d --max-depth %d '' %s",
			config.fd_max_depth or 3,
			table.concat(existing_dirs, " "))
	elseif command_exists("find") then
		cmd = string.format("find %s -mindepth 1 -maxdepth %d -type d",
			table.concat(existing_dirs, " "),
			config.find_max_depth or 3)
	else
		vim.notify("Neither zoxide, fd, nor find are available", vim.log.levels.ERROR)
		return
	end

	results = vim.fn.systemlist(cmd)
	if #results == 0 then
		vim.notify("No directories found", vim.log.levels.WARN)
		return
	end

	local items = {}
	for _, path in ipairs(results) do
		table.insert(items, {
			path = path,
			display = path,
		})
	end

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

function M.sessionizer()
	select_project(function(selected_path)
		local session_name = vim.fn.fnamemodify(selected_path, ":t"):gsub("%.", "_")
		local socket = sessions_dir .. "/" .. session_name

		if
			vim.fn.filereadable(socket) == 1
			or vim.fn.isdirectory(socket) == 1
			or vim.fn.getftype(socket) == "socket"
		then
			vim.cmd("connect " .. socket)
			vim.notify("Connected to existing session: " .. session_name)
		else
			local cmd = string.format('nohup nvim --listen "%s" -c "cd %s" >/dev/null 2>&1 &', socket, selected_path)
			vim.fn.system(cmd)

			vim.defer_fn(function()
				vim.cmd("connect " .. socket)
				vim.notify("New session: " .. session_name)
				M.update_sessions()
			end, 500)
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
