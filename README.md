# Nvim Sessionizer

Neovim Session Manager

## ⚠️ THIS PLUGIN IS IN VERY ALPHA STAGE ⚠️

It may have breaking changes, so keep this in mind when updating.

> [!IMPORTANT]
> You need to use Neovim 0.12, and this is not a proper release. I highly recommend not switching to 0.12 until the official release, you might face some problems or breaking changes

## Requirements

- Neovim 0.12
- [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) or gnu/find

> [!IMPORTANT]
> This plugin was created to work with a plugin that modifies `vim.ui.select`. It changes its behavior to work more like a fuzzy finder. This is highly recommended for proper functionality.

### Fuzzy Finders (pick one)

- [folke/snacks.nvim](https://github.com/folke/snacks.nvim)
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) with [nvim-telescope/telescope-ui-select.nvim](https://github.com/nvim-telescope/telescope-ui-select.nvim)
- [nvim-mini/mini.nvim](https://github.com/nvim-mini/mini.nvim)
- Or any plugin that modifies `vim.ui.select` behavior

## What is "sessionizer"?

This is a version of [ThePrimeagen/tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) for Neovim, using the new server/client capabilities.  

It manages Neovim sessions: create, attach, and delete sessions, enabling background Neovim servers and attachment via `--remote-ui` and the `:connect` command.

## What This Plugin Doesn't Want to Be

This is **not** a terminal multiplexer. It’s strictly a session manager to make switching between Neovim instances easier.

## Install

### With [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "offGustavo/nvim-sessionizer",
  config = function()
    -- Required
    require("nvim-sessionizer").setup()
    
    -- Keymaps
    vim.keymap.set("n", "<A-o>", function()
      require("nvim-sessionizer").sessionizer()
    end, { silent = true, desc = "Create a new session with zoxide" })
    
    vim.keymap.set("n", "<A-n>", function()
      require("nvim-sessionizer").new_session()
    end, { silent = true, desc = "Create a new session in current dir" })
    
    vim.keymap.set("n", "<A-u>", function()
      require("nvim-sessionizer").attach_session()
    end, { silent = true, desc = "Attach to a session with vim.ui.select" })
    
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
      require("nvim-sessionizer").manage_sessions()
    end, { silent = true, desc = "Manage sessions" })
    
    vim.keymap.set("n", "<A-d>", ":detach<CR>", { silent = true, desc = "Detach current session" })
    
    for i = 1, 9 do
      vim.keymap.set("n", "<C-" .. i .. ">", function()
        require("nvim-sessionizer").attach_session(i)
      end, { silent = true, desc = "Go to session " .. i })
    end
  end,
}
```

### With `vim.pack`

```lua
vim.pack.add( { "https://github.com/offGustavo/nvim-sessionizer" })

-- Required
require("nvim-sessionizer").setup()

-- Keymaps
vim.keymap.set("n", "<A-o>", function()
  require("nvim-sessionizer").sessionizer()
end, { silent = true, desc = "Create a new session with zoxide" })

vim.keymap.set("n", "<A-n>", function()
  require("nvim-sessionizer").new_session()
end, { silent = true, desc = "Create a new session in current dir" })

vim.keymap.set("n", "<A-u>", function()
  require("nvim-sessionizer").attach_session()
end, { silent = true, desc = "Attach to a session with vim.ui.select" })

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
  require("nvim-sessionizer").manage_sessions()
end, { silent = true, desc = "Manage sessions" })

vim.keymap.set("n", "<A-d>", ":detach<CR>", { silent = true, desc = "Detach current session" })

for i = 1, 9 do
  vim.keymap.set("n", "<C-" .. i .. ">", function()
    require("nvim-sessionizer").attach_session(i)
  end, { silent = true, desc = "Go to session " .. i })
end

```

## Default Config

You can override only the options you want to change, there’s no need to copy everything here.

```lua
{
  -- Disable Zoxide integration.
  -- Set to true if you don't have Zoxide installed, or prefer not to use it.
  no_zoxide = false,

  -- A list of directories where Sessionizer will search for projects.
  -- Each entry should be an absolute path or use ~ for the home directory.
  -- Example:
  --   { "~/Projects", "~/Work" }
  search_dirs = { "~/my_dir" },

  -- Maximum depth to search for projects.
  -- Example: max_depth = 3 means scan up to 3 subdirectory levels.
  max_depth = 3,

  -- UI configuration
  ui = {
    keymap = {
      quit = "q",         -- Key to quit the session window
      attach = "<CR>",    -- Key to attach to a session
      delete = "<S-d>",   -- Key to delete a session
      move_up = "<S-k>",  -- Move session up
      move_down = "<S-j>",-- Move session down
    },
    win = {
      width = 0.6,        -- Window width ratio (0-1)
      height = 0.4,       -- Window height ratio (0-1)
      winbar = {
        hl_left = "Title",      -- Highlight for left section text
        hl_right = "Comment",   -- Highlight for right section text
        hl_separator = "Comment", -- Highlight for separators
        sep_left = "/",         -- Separator between left items
        sep_mid = "%=",         -- Separator for center alignment
        sep_right = "│",        -- Separator for right items
        format = function(config) -- Function to format winbar items
          return {
            left = {
              " " .. config.ui.keymap.quit .. " close",
              config.ui.keymap.delete .. " delete session",
            },
            right = {
              config.ui.keymap.attach .. " attach session",
              config.ui.keymap.move_up .. "/" .. config.ui.keymap.move_down .. " move session",
            },
          }
        end,
      },
    },
    current = {
      mark = ">",          -- Marker for the current session
      hl = "MatchParen",   -- Highlight group for the marker
    },
  },
}
```
