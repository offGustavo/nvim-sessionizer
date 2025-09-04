local M = {}

local sessions_dir = vim.fn.expand("/tmp/nvim-sessions/")
vim.fn.mkdir(sessions_dir, "p")

M.sessions = {}
M.current_index = nil

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
	vim.ui.input({ prompt = "Nome da nova sessão: " }, function(name)
		if name and name ~= "" then
			local socket = sessions_dir .. "/" .. name
			local cmd = { "nohup", "nvim", "--listen", socket, ">/dev/null", "2>&1", "&" }
			vim.fn.jobstart(table.concat(cmd, " "), { detach = true })
			vim.defer_fn(function()
				vim.cmd("connect " .. socket)
				vim.notify("Sessão criada e conectada: " .. name)
				M.update_sessions()
			end, 300)
		end
	end)
end

function M.attach_session(arg)
	M.update_sessions()
	if #M.sessions == 0 then
		vim.notify("Nenhuma sessão encontrada", vim.log.levels.WARN)
		return
	end

	if arg == "+1" or arg == "-1" or tonumber(arg) then
		if not M.current_index then
			vim.notify("Sessão atual não encontrada, selecione manualmente.", vim.log.levels.WARN)
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
		vim.notify("Conectado à sessão: " .. next_session .. " (índice " .. new_index .. ")")
		M.current_index = new_index
	else
		vim.ui.select(M.sessions, { prompt = "Selecionar sessão para conectar:" }, function(choice)
			if choice then
				local socket = sessions_dir .. "/" .. choice
				vim.cmd("connect " .. socket)
				vim.notify("Conectado à sessão: " .. choice)
				M.update_sessions()
			end
		end)
	end
end

function M.remove_session()
	M.update_sessions()
	if #M.sessions == 0 then
		vim.notify("Nenhuma sessão para remover", vim.log.levels.WARN)
		return
	end

	vim.ui.select(M.sessions, { prompt = "Selecionar sessão para remover:" }, function(choice)
		if choice then
			local socket = sessions_dir .. "/" .. choice
			vim.fn.delete(socket)
			vim.notify("Sessão removida: " .. choice)
			M.update_sessions()
		end
	end)
end

function M.list_sessions()
	M.update_sessions()
	if #M.sessions == 0 then
		vim.notify("Nenhuma sessão ativa", vim.log.levels.INFO)
	else
		local formatted = {}
		for i, name in ipairs(M.sessions) do
			local mark = (i == M.current_index) and " [ATUAL]" or ""
			table.insert(formatted, string.format("%d: %s%s", i, name, mark))
		end
		vim.notify("Sessões:\n" .. table.concat(formatted, "\n"))
	end
end

function M.get_current_session()
	return vim.fn.fnamemodify(vim.v.servername, ":t")
end

function M.sessionizer()
	local function select_project(callback)
		local results = vim.fn.systemlist("zoxide query -l -s")
		if #results == 0 then
			vim.notify("Nenhum diretório encontrado pelo zoxide", vim.log.levels.WARN)
			return
		end

		local items = {}
		for _, line in ipairs(results) do
			local score, path = line:match("(%S+)%s+(.+)")
			if path then
				table.insert(items, {
					path = path,
					score = score,
					display = string.format("%s (%s)", path, score),
				})
			end
		end

		vim.ui.select(items, {
			prompt = "Selecionar Projeto:",
			format_item = function(item)
				return item.display
			end,
		}, function(choice)
			if choice and choice.path then
				callback(choice.path)
			else
				vim.notify("Nenhum projeto selecionado", vim.log.levels.WARN)
			end
		end)
	end

	select_project(function(selected_path)
		local session_name = vim.fn.fnamemodify(selected_path, ":t"):gsub("%.", "_")
		local socket = sessions_dir .. "/" .. session_name

		if
			vim.fn.filereadable(socket) == 1
			or vim.fn.isdirectory(socket) == 1
			or vim.fn.getftype(socket) == "socket"
		then
			vim.cmd("connect " .. socket)
			vim.notify("Conectado à sessão existente: " .. session_name)
		else
			local cmd = string.format('nohup nvim --listen "%s" -c "cd %s" >/dev/null 2>&1 &', socket, selected_path)
			vim.fn.system(cmd)

			vim.defer_fn(function()
				vim.cmd("connect " .. socket)
				vim.notify("Nova sessão criada: " .. session_name)
				M.update_sessions()
			end, 500)
		end
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("Sessionizer", function(opts)
		local sub = opts.fargs[1]
		if sub == "new" then
			M.new_session()
		elseif sub == "attach" then
			M.attach_session(opts.fargs[2])
		elseif sub == "remove" then
			M.remove_session()
		elseif sub == "list" then
			M.list_sessions()
		elseif not sub then
			M.sessionizer()
		end
	end, { nargs = "*" })
end

return M
