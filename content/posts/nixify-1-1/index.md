---
date: '2026-07-22T23:28:39+05:30'
draft: false
title: 'Nixify #1.1: Building a modular Neovim Wrapper'
tags: ['nixify','neovim']
series: ['nixify']
ShowToc: true
---

Welcome back to **Nixify**. In issue #1.1, we are laying down the core 
architecture for our Neovim wrapper using `flake-parts`, `import-tree`, and 
`nix-wrapper-modules`.

This setup will serve as the exact structural blueprint for wrapping all future 
CLI applications throughout the rest of the Nixify series.

---

## The Directory Layout

Instead of dumping everything into a monolithic `flake.nix`, we keep a clean, 
modular folder layout using `import-tree`. Each application lives inside its own 
isolated subdirectory:

```text
.
├── flake.lock
├── flake.nix
└── modules
    └── apps
        └── nvim
            ├── default.nix
            └── init.lua
```

---

## The Configuration Logic

Inside `modules/apps/nvim/default.nix`, we define the wrapper using 
`nix-wrapper-modules`. We pass the current directory as the configuration root 
and inject standalone runtime dependencies.

```nix
{ self, inputs, ... }: {
  perSystem = { pkgs, ... }: {
    packages.nvim = inputs.wrappers.wrappers.neovim.wrap {
      inherit pkgs;
      env = {
        "CONFIG_ROOT" = ./.;
        "NVIM_APPNAME" = "nixvim";
      };
      runtimePkgs = with pkgs; [
        hello
      ];
      settings.config_directory = ./.;
    };
  };
}
```

By defining `runtimePkgs = [ pkgs.hello ]`, the wrapped Neovim binary has 
isolated, guaranteed runtime access to `hello` without needing it installed globally 
on the host machine.

---

## Testing in Lua

Our `init.lua` sets basic editor options and immediately calls the injected 
`hello` package to verify the hermetic path integration:

```lua
vim.opt.number = true
vim.opt.relativenumber = true

-- Verify that runtimePkgs injection works
vim.cmd("!hello")
```

---

## The Gotcha: Git File Tracking

When testing the initial build via `nix run .#nvim`, Nix might fail to locate your 
`init.lua` even if it exists in your local folder.

Because Nix flakes evaluate using a clean Git tree abstraction, **any newly created 
file must be tracked by Git** to be copied into the Nix store environment.

```bash
# Stage the file so Nix can evaluate the path
git add modules/apps/nvim/init.lua

# Build and execute the wrapped package
nix run .#nvim
```

With `flake-parts` and `import-tree` exposing the module to our outputs, running 
`nix run .#nvim` instantly launches our fully isolated, self-contained Neovim 
sandbox.

![nvim build](nixify-1-1-build.gif)

You can check the files talked about in this post (and upcoming posts of this
series) at [ajdev-gh/nix](https://github.com/ajdev-gh/nix).

See you in issue #1.2!
