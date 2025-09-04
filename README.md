# Nvim Sessionizer
Neovim Session Manager

⚠️ THIS IS NOT A PROPER RELEASE — THIS PLUGIN IS IN VERY ALPHA STAGE ⚠️

# READ THE NOTES

> [!IMPORTANT]
> This is not a real plugin, at the moment it's more like a proof of concept, keep that in mind

> [!IMPORTANT]
> You need to use Neovim 0.12, and this is not a proper release. I highly recommend not switching to 0.12 until the official release, you might face problems

> [!IMPORTANT]
> This was tested only on [LazyVim](https://www.lazyvim.org/). That's important because Lazy makes some changes to `vim.ui.select` to change its behavior and work more like a fuzzy finder. I really recommend using it for a functional experience, or change this to your fuzzy finder of choice. I made it this way at the moment because I'm lazy and don't want to implement this now (yep). I really recommend changing it if you want to test it.

## Requirements

- Neovim 0.12
- [ajeetdsouza/zoxide: A smarter cd command. Supports all major shells.](https://github.com/ajeetdsouza/zoxide)

## What is "sessionizer"?

This is a version of [ThePrimeagen/tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) for Neovim, using the new capabilities from the server/client architecture. At the moment it uses zoxide to create sessions (because that's what I use), but it should offer `fd` or `find` like tmux-sessionizer.

This (not)plugin will be a way to manage sessions: create them, attach to them, and delete. It enables you to create sessions, which are Neovim servers running in the background, attach to them with the `--remote-ui` flag and `:connect` Ex-command.

And again, this is not a proper plugin, and it may have some breaking changes during development or with the 0.12 release.


## What This (Non)Plugin Doesn't Want to Be

My goal is not to create a terminal multiplexer on top of Neovim. It is just a session manager. This will only make it easier to switch between instances of Neovim.

## Install

### With [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  "offGustavo/nvim-sessionizer",
  lazy = false,
  cmd = "Sessionizer",
  config = function()
    require("nvim-sessionizer").setup()
    vim.keymap.set("n", "<A-o>", ":Sessionizer<CR>", { silent = true, desc = "Create a new session with zoxide" })
    vim.keymap.set("n", "<A-n>", ":Sessionizer new<CR>", { silent = true, desc = "Create a new session in the current dir" })
    vim.keymap.set("n", "<A-u>", ":Sessionizer attach<CR>", { silent = true, desc = "Attach to a session with vim.ui.select" })
    vim.keymap.set("n", "<A-S-0>", ":Sessionizer attach +1<CR>", { silent = true, desc = "Go to next session" })
    vim.keymap.set("n", "<A-S-9>", ":Sessionizer attach -1<CR>", { silent = true, desc = "Go to previous session" })
    vim.keymap.set("n", "<A-x>", ":Sessionizer remove<CR>", { silent = true })
    vim.keymap.set("n", "<A-s>", ":Sessionizer list<CR>", { silent = true, desc = "List sessions" })
    vim.keymap.set("n", "<A-d>", ":detach<CR>", { silent = true, desc = "Detach current session" })
  end,
}
```
