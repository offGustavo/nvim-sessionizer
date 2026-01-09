# Nvim Sessionizer

Neovim Session Manager

## ⚠️ THIS PLUGIN IS IN ALPHA STAGE ⚠️

It may have breaking changes, so keep this in mind when updating.

> [!IMPORTANT]
> You need to use Neovim 0.12, and this is not a proper release. I highly recommend not switching to 0.12 until the official release, you might face some problems or breaking changes

> [!WARNING]
> **Windows is not currently supported.** This plugin only works on Linux/Unix.

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

> [!TIP]
> **Alternative to `vim.ui.select`:** If you prefer not to use `vim.ui.select`, the `:Sessionizer` Ex commands offer the same features with built-in Vim completion.

## What is "sessionizer"?

This is a version of [ThePrimeagen/tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) for Neovim, using the new server/client capabilities.  

It manages Neovim sessions: create, attach, and delete sessions, enabling background Neovim servers and attachment via `--remote-ui` and the `:connect` command.

## What This Plugin Doesn't Want to Be

- This is **not** a terminal multiplexer. It’s strictly a session manager to make switching between Neovim instances easier.
- Not an **"state-session"** plugin: While some plugins save editor state (windows, buffers), Sessionizer helps you manage and switch between separate Neovim processes.

## Install

### With [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "offGustavo/nvim-sessionizer",
    -- Lazy loading isn't necessary: the plugin initializes efficiently at startup
    -- by registering Ex commands, then loads fully when features are first used
    lazy = false,
    config = function()

    vim.g.sessionizer = { 
      -- Add your custom settings here
      -- All available options with their defaults are shown below
    }
    
    -- Keymaps
    -- NOTE: These keybindings are just examples. Customize them to fit your workflow.
    vim.keymap.set("n", "<leader>So", function()
      require("nvim-sessionizer").sessionizer()
    end, { silent = true, desc = "Create a new session" })
    
    vim.keymap.set("n", "<leader>Sn", function()
      require("nvim-sessionizer").new_session()
    end, { silent = true, desc = "Create a new session in current dir" })
    
    vim.keymap.set("n", "<leader>Su", function()
      require("nvim-sessionizer").attach_session()
    end, { silent = true, desc = "Attach to a session with vim.ui.select" })
    
    vim.keymap.set("n", "<leader>S+", function()
      require("nvim-sessionizer").attach_session("+1")
    end, { silent = true, desc = "Go to next session" })
    
    vim.keymap.set("n", "<leader>S-", function()
      require("nvim-sessionizer").attach_session("-1")
    end, { silent = true, desc = "Go to previous session" })
    
    vim.keymap.set("n", "<leader>Sx", function()
      require("nvim-sessionizer").remove_session()
    end, { silent = true })
    
    vim.keymap.set("n", "<leader>Ss", function()
      require("nvim-sessionizer").manage_sessions()
    end, { silent = true, desc = "Manage sessions" })
    
    vim.keymap.set("n", "<leader>Sd", ":detach<CR>", { silent = true, desc = "Detach current session" })
    
    for i = 1, 9 do
      vim.keymap.set("n", "<leader>S" .. i, function()
        require("nvim-sessionizer").attach_session(i)
      end, { silent = true, desc = "Go to session " .. i })
    end
  end,
}
```

## Default Config

You can override only the options you want to change. There's no need to copy everything - just maintain the overall structure and modify what you need.

```lua
vim.g.sessionizer = {
  -- Disable Zoxide integration.
  -- Set to true if prefer not to use it. 
  -- If Zoxide isn't installed, this setting has no effect.
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

## EX Commands

Sessionizer provides several `:Sessionizer` commands for managing your Neovim sessions. These commands offer tab-completion and flexible argument handling for smooth workflow integration.

### Command Reference

#### `:Sessionizer` (without arguments)
Opens an interactive project selector using `vim.ui.select()`. Select a project to create or attach to its session.

**Example:**
```vim
:Sessionizer
```

#### `:Sessionizer new [path]`
Creates a new session from a project directory.

- **Without argument:** Prompts for a session name in the current working directory, then creates and attaches to the new session.
- **With path argument:** Creates a session directly from the specified path.

**Examples:**
```vim
:Sessionizer new                    " Prompt for session name in current directory
:Sessionizer new ~/projects/my-app  " Create session from specific path
```

**Tab Completion:** When typing `:Sessionizer new `, suggestions will show available project directories.

#### `:Sessionizer attach [session]`
Attaches to an existing session.

- **Without argument:** Shows an interactive session picker.
- **With session name:** Attaches directly to the named session.
- **With `+1`/`-1`:** Cycles to next/previous session in the list.
- **With numeric index:** Attaches to session at that position.

**Examples:**
```vim
:Sessionizer attach                " Show session picker
:Sessionizer attach my-project     " Attach to 'my-project' session
:Sessionizer attach +1             " Attach to next session
:Sessionizer attach 3              " Attach to 3rd session in list
```

**Tab Completion:** When typing `:Sessionizer attach `, suggestions will show available session names.

#### `:Sessionizer remove [session]`
Removes a session and closes its Neovim instance.

- **Without argument:** Shows an interactive session picker for removal.
- **With session name:** Removes the specified session.
- **With numeric index:** Removes the session at that position.

**Examples:**
```vim
:Sessionizer remove                " Show session picker for removal
:Sessionizer remove my-project     " Remove 'my-project' session
:Sessionizer remove 2              " Remove 2nd session in list
```

**Tab Completion:** When typing `:Sessionizer remove `, suggestions will show available session names.

#### `:Sessionizer manage`

Opens an interactive session management window with additional features:
- View all sessions with visual indicator for current session
- Reorder sessions using keybindings
- Delete sessions directly from the interface
- Attach to sessions

**Default Keybindings in Management Window:**
- `<CR>` - Attach to selected session
- `<S-d>` - Delete selected session  
- `<S-k>` - Move session up in list
- `<S-j>` - Move session down in list
- `q` - Close management window

**Example:**
```vim
:Sessionizer manage
```

### Tab Completion

The `:Sessionizer` command includes intelligent tab completion:

| Command State | Suggestions Provided |
|--------------|---------------------|
| `:Sessionizer ` | `new`, `attach`, `remove`, `manage` |
| `:Sessionizer new ` | Project directories from zoxide/search paths |
| `:Sessionizer attach ` | Available session names |
| `:Sessionizer remove ` | Available session names |


#### Using Tab Completion with Keymaps

You can create keymaps that open the `:Sessionizer` command with the cursor ready for tab completion. Simply leave a space after the command in the mapping.

**In Vimscript:**
```vim
" Map Ctrl+f to open :Sessionizer with tab completion ready
" Note the space after the command - this positions the cursor for completion
nmap <C-f> :Sessionizer 
```

**In Lua:**
```lua
-- Map Ctrl+f to open :Sessionizer with tab completion ready
-- Note the space after the command - this positions the cursor for completion
vim.keymap.set("n", "<C-f>", ":Sessionizer ")
```
**Important Notes:**
- The trailing space is crucial - it positions your cursor after the command, ready to use `<Tab>` for suggestions
- **Don't** include `<CR>` (Enter) in the mapping, as this would execute the command immediately instead of letting you choose options
- After pressing your keymap, simply press `<Tab>` to cycle through available completions (new, attach, remove, manage) or start typing for filtered suggestions
