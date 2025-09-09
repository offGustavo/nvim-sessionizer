local M = {}

---@param path string
---@param name? string
function M.create_session(path,name )
	if path then
    -- If name isent declaraty use the session_name
    name = name or vim.fn.fnamemodify(path, ":t"):gsub("%.", "_")
		local socket = sessions_dir .. "/" .. name
		local cmd = string.format('nohup nvim --listen "%s" -c "cd %s" >/dev/null 2>&1 &', socket, path)
		vim.fn.system(cmd)

		vim.defer_fn(function()
			vim.cmd("connect " .. socket)
			vim.notify("New session: " .. session_name)
			update_sessions()
		end, 500)
	end
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
	picker.select_item(M.sessions, { prompt = "Select a session to connect:" }, function(choice)
			if choice then
				local socket = sessions_dir .. "/" .. choice
				vim.cmd("connect " .. socket)
				vim.notify("Connected to session: " .. choice)
				update_sessions()
			end
		end)
	end
end


function M.new_session()
	vim.ui.input({ prompt = "Session name:" }, function(name)
    local path = vim.uv.cwd() .. ""
    create_session(path, name)
	end)
end

function M.sessionizer()
	select_project(function(path)
		local session_name = vim.fn.fnamemodify(ath, ":t"):gsub("%.", "_")
		local socket = sessions_dir .. "/" .. session_name

		if
			vim.fn.filereadable(socket) == 1
			or vim.fn.isdirectory(socket) == 1
			or vim.fn.getftype(socket) == "socket"
		then
      M.attach_session(path)
		else
			local cmd = string.format('nohup nvim --listen "%s" -c "cd %s" >/dev/null 2>&1 &', socket, selected_path)
			vim.fn.system(cmd)

			vim.defer_fn(function()
				vim.cmd("connect " .. socket)
				vim.notify("New session: " .. session_name)
				update_sessions()
			end, 500)
		end
	end)
end

return M
