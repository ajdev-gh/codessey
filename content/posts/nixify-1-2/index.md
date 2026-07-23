---
date: '2026-07-23T22:24:16+05:30'
draft: false
title: 'Nixify #1.2: LSPs, Formatters & Hermetic Runtime Binaries'
tags: ['nixify']
series: ['nixify']
ShowToc: true
---

Welcome back to **Nixify**. In issue #1.2, we are diving deep into turning our 
bare Neovim wrapper into a full IDE. 

In a traditional Neovim setup, developers rely on plugins like `mason.nvim` to 
download binary language servers, formatters, and debuggers directly into 
`~/.local/share/nvim`. This introduces impure binary dependencies compiled for 
arbitrary glibc versions, breaks reproducibility across machines, and completely 
fails in immutable environments like NixOS.

Instead, we use Nix to handle binary distribution declaratively, keeping our 
editor hermetic, fast, and 100% reproducible.

---

## The Plumbing: How `runtimePkgs` Works

When configuring `modules/apps/nvim/default.nix`, `nix-wrapper-modules` allows us 
to declare external CLI dependencies inside `runtimePkgs`:

```nix
{
  self,
  inputs,
  ...
}: {
  perSystem = {pkgs, ...}: {
    packages.nvim = inputs.wrappers.wrappers.neovim.wrap ({config, ...}: {
      inherit pkgs;
      runtimePkgs = with pkgs; [
        # Search & Navigation Utilities
        ripgrep
        fd
        tree-sitter

        # Language Servers (IDE Intelligence)
        jdt-language-server
        lua-language-server
        basedpyright
        rust-analyzer
        nixd

        # Code Formatters
        alejandra
      ];
      # ...
    });
  };
}
```

### What Nix Does Under the Hood

When Nix builds the wrapper package, it creates an isolated symlink tree (a `symlinkJoin`) 
containing the binaries of every package in `runtimePkgs`. 

It then wraps the generated `nvim` executable shell script, prepending that store 
path directly to Neovim's `PATH` environment variable prior to execution:

```bash
# Conceptual view of the wrapper binary in /nix/store/...-nvim-wrapped/bin/nvim
export PATH="/nix/store/a81z...-neovim-runtime-deps/bin:$PATH"
exec /nix/store/f92x...-neovim-unwrapped/bin/nvim "$@"
```

Because this path prepending happens strictly inside the execution wrapper, 
running `nix run .#nvim` gives Neovim instant access to `rust-analyzer`, `nixd`, 
and `ripgrep`, without polluting your user profile or requiring these tools to 
exist globally on your operating system.

---

## Wiring Up Native LSP & Formatting

Because the binaries exist directly on Neovim's execution `PATH`, we do not need 
custom PATH detection logic inside Lua. In `modules/apps/nvim/lua/lsp.lua`, we 
interact directly with standard executables:

```lua
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { desc = "Format Local buffer" })
vim.keymap.set("n", "df", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

vim.diagnostic.config({ virtual_text = true })

-- Enable completion capabilities across servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend(
  "force", 
  capabilities, 
  require("mini.completion").get_lsp_capabilities()
)

vim.lsp.config("*", { capabilities = capabilities })

-- Nix Language Server setup with Alejandra formatting
vim.lsp.config('nixd', {
  cmd = { 'nixd' },
  filetypes = { 'nix' },
  root_markers = { 'flake.nix', 'shell.nix', 'git' },
  settings = {
    nixd = {
      formatting = {
        command = { "alejandra" },
      },
    },
  },
})

-- Enable language servers
vim.lsp.enable({
  "lua_ls",
  "basedpyright",
  "jdtls",
  "rust_analyzer",
  "nixd",
})
```

---

## Dynamic Tree-Sitter Strategy

Standard Nix patterns often bundle every Tree-Sitter grammar as an individual store 
derivation linked to `pkgs.vimPlugins.nvim-treesitter`. While purely functional, it 
can make updating individual parsers tedious.

We opt for a hybrid model: we bundle the `tree-sitter` CLI in `runtimePkgs` alongside 
the main `nvim-treesitter` plugin. In `modules/apps/nvim/lua/treesitter.lua`:

```lua
local treesitter = require("nvim-treesitter")

local ensure_installed = {
  "rust", "python", "java", "nix",
}

-- CLI handles parsing and compiling grammars on demand
treesitter.install(ensure_installed)

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function(args)
    local buf = args.buf
    local ft = vim.bo[buf].filetype

    local lang = vim.treesitter.language.get_lang(ft)
    if not lang then return end

    local ok_add = pcall(vim.treesitter.language.add, lang)
    if not ok_add then return end

    pcall(vim.treesitter.start, buf, lang)
  end,
})
```

Because `tree-sitter` and the compiler tools exist in `runtimePkgs`, `nvim-treesitter` 
can build parsers on first boot seamlessly, without breaking our declarative base.

See you in issue #1.3!
