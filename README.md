# Nvim Sessionizer
Neovim Session Manager

## ⚠️ THIS PLUGIN IS IN VERY ALPHA STAGE ⚠️

> [!IMPORTANT]
> This is not a real plugin, at the moment it's more like a proof of concept, keep that in mind

> [!IMPORTANT]
> You need to use Neovim 0.12, and this is not a proper release. I highly recommend not switching to 0.12 until the official release, you might face problems

> [!IMPORTANT]
> This was tested only on [LazyVim](https://www.lazyvim.org/). That's important because Lazy makes some changes to `vim.ui.select` to change its behavior and work more like a fuzzy finder. I really recommend using it for a functional experience, or change this to your fuzzy finder of choice. I made it this way at the moment because I'm lazy and don't want to implement this now (yep). I really recommend changing it if you want to test it.

## Requirements

- Neovim 0.12
- [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) or [sharkdp/fd](https://github.com/sharkdp/fd) or find


## What is "sessionizer"?

This is a version of [ThePrimeagen/tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) for Neovim, using the new capabilities from the server/client architecture. 

This (not)plugin will be a way to manage sessions: create them, attach to them, and delete. It enables you to create sessions, which are Neovim servers running in the background, attach to them with the `--remote-ui` flag and `:connect` Ex-command.

## What This (Non)Plugin Doesn't Want to Be

My goal is not to create a terminal multiplexer on top of Neovim. It is just a session manager. This will only make it easier to switch between instances of Neovim.

## Install

### With [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "offGustavo/nvim-sessionizer",
  config = function()
require("nvim-sessionizer").setup({
    -- Disable Zoxide integration.
    -- Set this to true if:
    --   1. You don't have Zoxide installed, or
    --   2. You prefer not to use Zoxide for project selection.
    no_zoxide = false,

    -- A list of directories where Sessionizer will search for projects.
    -- Each entry should be an absolute path or use ~ for the home directory.
    -- Example:
    --   { "~/Projects", "~/Work" }
    search_dirs = { "~/my_dir" },

    -- Maximum search depth for fd or find when listing projects.
    -- This controls how many directory levels are scanned.
    -- Example:
    --   max_depth = 3 means: search up to 3 subdirectory levels deep.
    max_depth = 1,
})
    vim.keymap.set("n", "<A-o>", function()
      require("nvim-sessionizer").sessionizer()
    end, { silent = true, desc = "Create an new session wiht zoxide" })
    vim.keymap.set("n", "<A-n>", function()
      require("nvim-sessionizer").new_session()
    end, { silent = true, desc = "Create an new session in the current dir" })
    vim.keymap.set("n", "<A-u>", function()
      require("nvim-sessionizer").attach_session()
    end, { silent = true, desc = "Attach to and sessins with vim.ui.select" })
    vim.keymap.set("n", "<A-S-0>", function()
      require("nvim-sessionizer").attach_session("+1")
    end, { silent = true, desc = "Go to next session" })
    vim.keymap.set("n", "<A-S-9>", function()
      require("nvim-sessionizer").attach_session("-1")
    end, { silent = true, desc = "Go to previous session" })
    vim.keymap.set("n", "<A-x>", function()
      require("nvim-sessionizer").remove_session()
    end, { silent = true })
    vim.keymap.set("n", "<A-s>", function()
      require("nvim-sessionizer").get_sessions()
    end, { silent = true, desc = "List sessions" })
    vim.keymap.set("n", "<A-d>", ":detach<CR>", { silent = true, desc = "Detach current session" })
    for i = 1, 9, 1 do
      vim.keymap.set("n", "<C-" .. i .. ">", function()
        require("nvim-sessionizer").attach_session(i)
      end, { silent = true, desc = "Go to " .. i .. "session" })
    end

  end,
}
```
