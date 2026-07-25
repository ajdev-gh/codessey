---
date: '2026-07-25T16:44:18+05:30'
draft: false
title: 'Nixify #1.4: Options, ergonomics and state isolation'
tags: ['nixify','neovim']
series: ['nixify']
---
Welcome back to **Nixify**. In issue #1.4, we complete our Neovim architecture 
by focusing on state isolation, buffer ergonomics, and keymaps.

---

## The Power of `NVIM_APPNAME` Environment Isolation

One major issue with running custom Neovim wrappers alongside system Neovim 
installations is state collision. They often fight over the same 
`~/.local/share/nvim` directory for undo trees, swap files, and shada records.

We eliminate this in `modules/apps/nvim/default.nix` by setting `NVIM_APPNAME`:

```nix
env = {
  "CONFIG_ROOT" = ./.;
  "NVIM_APPNAME" = "nixvim";
};
```

When Neovim launches, `NVIM_APPNAME` changes the base directory names across all standard paths:
* **Config:** `~/.config/nixvim`
* **Data:** `~/.local/share/nixvim`
* **State:** `~/.local/state/nixvim`
* **Cache:** `~/.cache/nixvim`

In `modules/apps/nvim/lua/options.lua`, we set our persistent undo directory safely:

```lua
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.stdpath("data") .. "/undodir"
vim.opt.undofile = true
```

Because `stdpath("data")` points to `~/.local/share/nixvim`, our undo history remains 
isolated and persistent without polluting standard system directories.

---

## Editor Ergonomics & Buffer Dynamics

Our options file includes tweaks to keep editing smooth:

```lua
vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.laststatus = 3 -- Global statusline across all windows

-- Keep cursor vertically centered during navigation
vim.opt.scrolloff = math.ceil(vim.api.nvim_win_get_height(0) / 2 + 6)

vim.opt.clipboard:append("unnamedplus")
```

---

## Essential Keymaps & Clipboard Protection

In `modules/apps/nvim/lua/keymaps.lua`, we establish bindings that solve common editing pain points:

```lua
vim.g.mapleader = " "

-- Paste over selection without overriding yank buffer
vim.keymap.set("x", "p", [["_dP]], { 
  desc = "Paste without losing yanked text" 
})

-- Delete into blackhole register by default
vim.keymap.set({ "n", "v" }, "d", [["_d]], { desc = "Delete without yanking" })
vim.keymap.set({ "n", "v" }, "c", [["_c]], { desc = "Delete without yanking" })

-- Move highlighted lines up and down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move lines down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move lines up" })

-- Keep cursor centered during half-page scrolling and search navigation
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Move down centered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Move up centered" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search match centered" })

-- Builtin Undotree integration
vim.keymap.set("n", "<leader>u", function()
  vim.cmd.packadd("nvim.undotree")
  require("undotree").open()
end, { desc = "Toggle Builtin Undotree" })
``` 

---

## Running the Final Engine

With `flake-parts`, `import-tree`, `nix-wrapper-modules`, and our modular Lua configuration in place, we can launch our declarative Neovim environment on any machine:

```bash
nix run .#nvim
```

Our Neovim setup is reproducible, fast, isolated, and completely configured as a modern IDE.

This concludes the Neovim application phase of the Nixify series. Stay tuned for the next entry!
