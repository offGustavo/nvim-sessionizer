local M = {}

local sessions_dir = vim.fn.expand("/tmp/nvim-sessions/")
vim.fn.mkdir(sessions_dir, "p")

local function list_sessions()
	return vim.fn.globpath(sessions_dir, "*", false, true)
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
			end, 300)
		end
	end)
end

function M.attach_session()
	local sessions = list_sessions()
	if #sessions == 0 then
		vim.notify("Nenhuma sessão encontrada", vim.log.levels.WARN)
		return
	end

	local names = {}
	for _, path in ipairs(sessions) do
		table.insert(names, vim.fn.fnamemodify(path, ":t"))
	end

	vim.ui.select(names, { prompt = "Selecionar sessão para conectar:" }, function(choice)
		if choice then
			local socket = sessions_dir .. "/" .. choice
			vim.cmd("connect " .. socket)
			vim.notify("Conectado à sessão: " .. choice)
		end
	end)
end

function M.remove_session()
	local sessions = list_sessions()
	if #sessions == 0 then
		vim.notify("Nenhuma sessão para remover", vim.log.levels.WARN)
		return
	end

	local names = {}
	for _, path in ipairs(sessions) do
		table.insert(names, vim.fn.fnamemodify(path, ":t"))
	end

	vim.ui.select(names, { prompt = "Selecionar sessão para remover:" }, function(choice)
		if choice then
			local socket = sessions_dir .. "/" .. choice
			vim.fn.delete(socket)
			vim.notify("Sessão removida: " .. choice)
		end
	end)
end

function M.list_sessions()
	local sessions = list_sessions()
	if #sessions == 0 then
		vim.notify("Nenhuma sessão ativa", vim.log.levels.INFO)
	else
		local names = {}
		for _, s in ipairs(sessions) do
			table.insert(names, vim.fn.fnamemodify(s, ":t"))
		end
		vim.notify("Sessões:\n" .. table.concat(names, "\n"))
	end
end

function M.get_current_session()
	return vim.fn.fnamemodify(vim.v.servername, ":t")
end

if vim.fn.executable("zoxide") ~= 1 then
	vim.notify("Zoxide not found in PATH", vim.log.levels.WARN)
end

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
			vim.notify("Conectado à sessão existente: " .. session_name)
		else
			local cmd = string.format('nohup nvim --listen "%s" -c "cd %s" >/dev/null 2>&1 &', socket, selected_path)
			vim.fn.system(cmd)

			vim.defer_fn(function()
				vim.cmd("connect " .. socket)
				vim.notify("Nova sessão criada: " .. session_name)
			end, 500)
		end
	end)
end

function M.setup(user_config)
	vim.api.nvim_create_user_command("Sessionizer", M.sessionizer, {})
	vim.api.nvim_create_user_command("NvimSessionNew", M.new_session, {})
	vim.api.nvim_create_user_command("NvimSessionAttach", M.attach_session, {})
	vim.api.nvim_create_user_command("NvimSessionRemove", M.remove_session, {})
	vim.api.nvim_create_user_command("NvimSessionList", M.list_sessions, {})

	-- TODO: remove this keymaps
	vim.keymap.set("n", "<A-n>", ":NvimSessionNew<CR>")
	vim.keymap.set("n", "<A-d>", ":detach<CR>")
	vim.keymap.set("n", "<A-u>", ":NvimSessionAttach<CR>")
	vim.keymap.set("n", "<A-S-0>", ":NvimSessionAttach<CR>")
	vim.keymap.set("n", "<A-S-9>", ":NvimSessionAttach<CR>")
	vim.keymap.set("n", "<A-x>", ":NvimSessionRemove<CR>")
	vim.keymap.set("n", "<A-s>", ":NvimSessionList<CR>")
	vim.keymap.set("n", "<A-o>", ":Sessionizer<CR>")
end

return M
