---
date: '2026-07-19T19:49:07+05:30'
draft: false
title: 'Nixify #1.0: Blueprinting a Portable, Pure Neovim Wrapper'
tags: ['nixify','neovim']
series: ['nixify']
ShowToc: true
---

I am moving my entire Arch Linux setup over to Nix. The goal is absolute 
reproducibility - no more missing system dependencies, no manual plugin git 
clones, and zero host contamination. 

We are starting with the tool I spend the most time in: **Neovim**. 

Right now, my configuration relies on Neovim's native package management, a 
handful of Lua files, and raw ecosystem binaries (`zsh`, compilers, language 
servers). It works fine on my Arch machine, but if I pull it down on a bare 
Ubuntu server or a macOS box, it blows up instantly. 

This post lays out the architectural roadmap for **Part 1** of this mini-series: 
converting a vanilla, multi-file Lua configuration into a single, highly 
isolated, deterministic Nix package. 

---

## Wait, What Actually is Nix?

Before we tear apart the text configuration, we need to baseline what Nix actually
is, because the community terminology gets confusing fast. When people say "Nix,"
they are usually talking about three distinct things:

1. **The Nix Expression Language:** A purely functional programming language 
   built specifically for writing system package configurations.
2. **The Nix Package Manager:** A tool that installs packages into a unique, 
   read-only directory structure located at `/nix/store/`. Every item gets a 
   cryptographic hash based on its exact source code and dependencies. 
3. **NixOS:** An entire Linux distribution built from the ground up to be 
   configured completely via the Nix language.

For this editor conversion process, we are focusing on **Flakes** - a modern 
standard feature of the package manager that acts like a global lockfile, 
trapping all repository source references so that builds are identical 
across any machine.

---

## The Target Architecture: What We Are Building

Instead of dropping files into `~/.config/nvim` and hoping the host system has 
the correct binaries installed, the end state of this series will generate a 
wrapped Neovim derivation (a Nix-compiled package blueprint). 

When executed, this wrapper will expose a standard `nvim` binary that carries 
its entire environment inside the Nix store:
```
Host System (Arch / Debian / macOS)
└── nix run github:user/dotfiles#nvim
    └── [Isolated Sandbox Layer]
        ├── Neovim Binary (Pinned Version)
        ├── Embedded Config Tree (init.lua + modules)
        ├── Hermetic Plugins (Pinned SHAs via Nix)
        └── Toolchain Runtime (LSP/Parsers trapped inside PATH)
```
Here is exactly how the current Lua modules will translate into Nix primitives 
by the end of the series.

---

## Feature Roadmap & Nix Mappings

### 1. Unified Entry Point (`init.lua`)
*   **Current State:** A clean entry file orchestrating execution order by 
    requiring the options, keymaps, auto-commands, vim.pack to load the plugins 
    installed by nix, treesitter and configuration.
*   **The Nix Approach:** We will preserve the current multi-file module separation 
    rather than flattening it into a massive string block. Nix will inject this 
    entire directory structure cleanly into the runtime data path using 
    something options like `xdg.configFile."nvim".source`.

### 2. Dependency Pinned Runtime Tools (`lsp.lua` & `options.lua`)
*   **Current State:** Native LSP hooks targeting `lua_ls`, `basedpyright`, 
    `jdtls`, and `rust_analyzer`. It also hardcodes a reliance on `/usr/bin/zsh`.
*   **The Nix Approach:** This is where things usually break across machines. We 
    will modify the wrapper's `extraPackages` array to inject the exact 
    underlying binaries (`pkgs.basedpyright`, `pkgs.rust-analyzer`, etc.) 
    directly into Neovim’s internal `PATH`. The host machine won't even know they 
    exist, but Neovim will find them instantly.

### 3. Immutable Plugin Lockfile (`pack.lua` & `nvim-pack-lock.json`)
*   **Current State:** Tracking plugins like `which-key.nvim`, 
    and `render-markdown.nvim` using `vim.pack`'s JSON revision manifests.
*   **The Nix Approach:** We are replacing the manual JSON locks with native 
    Nix derivation inputs. Plugins will be treated as immutable build inputs fetched 
    via Nix flakes or `pkgs.vimPlugins`. This drops startup time since Nix pre-links 
    everything down into the store.

### 4. Lazy-Loaded Core Utilities (`keymaps.lua` & `commands.lua`)
*   **Current State:** Custom keystrokes for terminal isolation, safe reloads, 
    and conditional runtime package loading (like `packadd("nvim.undotree")`).
*   **The Nix Approach:** The keybinds and user commands will remain pure Lua. 
    However, optional packages like `undotree` will be made available directly via 
    the wrapper's internal runtime path so the `packadd` hook never fails to find 
    the directory source.

---

## Why Avoid Tools Like Mason?

A common path in the Neovim ecosystem (and in my current configuration)
is using plugins like Mason to download and manage binary servers inside
`~/.local/share`. 

While convenient on mutation-friendly distributions, Mason completely breaks the 
core ethos of Nix: **Immutability and Purity**. 
*   Mason fetches unlinked, pre-compiled binaries from the web that frequently 
    fail to execute on NixOS due to missing dynamic linker paths (`ld-linux`).
*   It introduces hidden state. If you spin up the config on a new machine, you 
    have to wait for external networks to fetch binaries again.

By shifting dependency tracking directly into a Flake, our build graph becomes 
totally transparent. If the flake builds locally, it will build identically 
anywhere.

---

## The Immediate Next Steps

I will actively experimenting with the structural layout. In the next part, we will dig 
straight into the practical implementation of **Part 1.1**:
*   Setting up the foundation flake template (`flake.nix`).
*   Writing the wrapper structure.
*   Handling local directory file imports purely without breaking the sandbox.

If you have built wrapped versions of your editors before or have opinions on 
nesting complex configuration trees inside a Nix module, let me know how you 
structured yours.
