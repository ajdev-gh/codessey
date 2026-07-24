---
date: '2026-07-24T19:44:18+05:30'
draft: false
title: 'Nixify #1.3: Plugins, Non-Flake Inputs & mini.nvim Architecture'
tags: ['nixify','neovim']
series: ['nixify']
ShowToc: true
---
Welcome back to **Nixify**. In issue #1.3, we explore how to manage Neovim 
plugins declaratively, convert raw GitHub inputs into Nix derivations, and use 
`mini.nvim` to build a fast IDE experience.

---

## Declarative Plugin Specs

In standard Neovim setups, plugin managers like `lazy.nvim` clone repositories directly 
into your home directory at runtime. In our Nix setup, plugins are built into read-only 
Nix store paths and attached to Neovim's `packpath`.

Inside `modules/apps/nvim/default.nix`:

```nix
specs.general = with pkgs.vimPlugins; [
  gruvbox-nvim
  mini-nvim
  which-key-nvim
  render-markdown-nvim
  nvim-treesitter
  friendly-snippets
  nvim-lspconfig
];
```

When evaluated, `nix-wrapper-modules` generates a `start` pack directory containing 
symlinks to every specified derivation in `/nix/store/`, ensuring instantaneous 
startup times without network requests.

---

## Packaging Non-Flake Inputs with `mkPlugin`

What happens when a plugin is not packaged in `nixpkgs` yet? 

Instead of waiting for an upstream PR, we declare the repository as a non-flake 
input inside `flake.nix`:

```nix
inputs = {
  mini-pick-preview = {
    url = "github:sh1Nome/mini-pick-preview.nvim";
    flake = false; # Raw repository source, not a flake
  };
};
```

Then, inside `modules/apps/nvim/default.nix`, we transform that raw source into a 
valid Vim plugin derivation using `config.nvim-lib.mkPlugin`:

```nix
specs.mini-pick-preview =
  config.nvim-lib.mkPlugin "mini-pick-preview"
  inputs.mini-pick-preview;
```

Under the hood, `mkPlugin` wraps `pkgs.vimUtils.buildVimPlugin`, taking the raw 
Git tree from `/nix/store/...-source` and creating a structured plugin package 
containing the necessary `doc/`, `plugin/`, and `lua/` directories.

---

## Building the IDE Surface with `mini.nvim`

To avoid plugin bloat, we use `mini.nvim` as the backbone of our editor UI. 
Instead of maintaining 15 distinct plugins for icons, git diffs, status lines, file 
explorers, and pickers, `mini.nvim` provides modular building blocks written in clean Lua.

Here is a snippet from `modules/apps/nvim/lua/ui.lua`:

```lua
local MiniSession = require("mini.sessions")
local MiniFiles = require("mini.files")
local MiniStarter = require("mini.starter")
local MiniStatus = require("mini.statusline")
local MiniPick = require("mini.pick")
local MiniPickPreview = require("mini-pick-preview")
local MiniExtra = require("mini.extra")

vim.cmd.colorscheme("gruvbox")

require("mini.icons").setup()
require("mini.git").setup()
require("mini.diff").setup()

--- File Explorer Integration ---
MiniFiles.setup({
  windows = {
    preview = true,
    width_preview = 80
  }
})

vim.keymap.set("n", "<leader>e", "<cmd>lua MiniFiles.open()<CR>", { 
  desc = "Toggle mini file explorer" 
})

--- Search & Pickers ---
MiniPick.setup()
MiniPickPreview.setup()
MiniExtra.setup()

vim.keymap.set("n", "<leader>ff", function() MiniPick.builtin.files() end, { 
  desc = "Search files" 
})
vim.keymap.set("n", "<leader>fg", function() MiniPick.builtin.grep_live() end, { 
  desc = "Search by word" 
})
```

By pairing `mini.nvim` with custom non-flake inputs, we achieve an IDE-grade 
developer experience while keeping startup times below 15ms.

See you in issue #1.4!
