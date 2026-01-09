  vim.api.nvim_create_user_command("Sessionizer", function(opts)
    local sub = opts.fargs[1]
    if sub == "new" then
      require("nvim-sessionizer").new_session()
    elseif sub == "attach" then
      require("nvim-sessionizer").attach_session(opts.fargs[2])
    elseif sub == "remove" then
      require("nvim-sessionizer").remove_session()
    elseif sub == "manage" then
      require("nvim-sessionizer").manage_sessions()
    elseif not sub then
      require("nvim-sessionizer").sessionizer()
    end
  end, {
    nargs = "*",
    complete = function(_, line)
      local words = vim.split(line, "%s+")
      local n = #words
      if n == 2 then
        return { "new", "attach", "remove", "manage" }
      elseif n == 3 and words[2] == "attach" then
        require("nvim-sessionizer").update_sessions()
        return require("nvim-sessionizer").sessions or {}
      end
      return {}
    end,
  })

