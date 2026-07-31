---
title: "Nixify #2.3: Integrating Custom Wrapped Neovim into System Flakes"
date: 2026-07-31T21:00:00+05:30
draft: false
tags: ["nix", "nixos", "neovim", "wrappers", "nixify"]
series: ["Nixify"]
math: false
---

Welcome to **Nixify #2.3**. In previous issues, we established our virtual machine infrastructure with Disko, bootstrapped the OS using `nixos-anywhere`, and wired up remote updates via `deploy-rs`. 

Now, we return to the editor environment we designed back in **Nixify #1.x**.

In our first series, we explored how to wrap Neovim declaratively using custom wrappers rather than relying on heavy monolithic framework managers. However, that setup lived as an isolated proof-of-concept. In this issue, we will refactor that wrapped Neovim configuration into our dendritic architecture, expose it as a reusable NixOS module, and deploy it directly onto our `nixos-vm` target.

---

## Evolution of the Neovim Module

Back in Nixify #1.x, our focus was strictly per-system package wrapping. We used `wrappers.neovim.wrap` to build an isolated Neovim derivation containing runtime dependencies and Lua configurations.

To make this editor setup available host-wide across our NixOS machines, we evolved `modules/apps/nvim/default.nix` in two major ways:
1. **Module Exposure**: We introduced `flake.nixosModules.custom-nvim` to allow any system host in our flake to enable our custom Neovim package natively.
2. **Grammars & Runtime Tooling**: We injected runtime system binaries like `git` directly into the package wrapper and bundled `nvim-treesitter.withAllGrammars` into the plugin specs.

---

## Deep Dive: `modules/apps/nvim/default.nix`

Let us examine how the refactored Neovim module is structured inside our repository:

```nix
{
  self,
  inputs,
  ...
}: {
  # 1. Expose a NixOS module for host configurations
  flake.nixosModules.custom-nvim = { pkgs, lib, ... }: {
    programs.neovim = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.nvim;
    };
  };

  # 2. Build the wrapped Neovim package per architecture
  perSystem = {pkgs, ...}: {
    packages.nvim = inputs.wrappers.wrappers.neovim.wrap ({config, ...}: {
      inherit pkgs;

      # External CLI tools available inside Neovim's PATH
      runtimePkgs = with pkgs; [
        git
        ripgrep
        fd
        tree-sitter
        lua-language-server
        nil
        stylua
        alejandra
      ];

      # Vim plugins & language parsers
      specs.general = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
        gruvbox-nvim
        mini-nvim
        which-key-nvim
      ];
    });
  };
}
```

### Key Enhancements from Nixify #1.x

#### The `custom-nvim` NixOS Module
Instead of manually adding our wrapped package to `environment.systemPackages` or user package lists on every machine, we defined `flake.nixosModules.custom-nvim`. 

When imported into a NixOS configuration:
* `programs.neovim.enable = true` sets up basic system integration (such as desktop entry handlers and default system editor symlinks).
* `package = self.packages.${pkgs.stdenv.hostPlatform.system}.nvim` overrides the default `pkgs.neovim` package with our fully custom, pre-wrapped Neovim derivation built by `perSystem`.

#### Runtime Binaries (`runtimePkgs`)
Editor functionality often breaks because binaries like `git` or `ripgrep` are missing on a minimal target host. By adding `git` directly to `runtimePkgs`, the wrapper automatically patches Neovim's executable environment. Commands like `:Gdiffsplit` or plugin features reliant on Git work out of the box on `nixos-vm`, even if `git` is not installed system-wide on the guest OS.

#### Pre-compiled Treesitter Grammars (`nvim-treesitter.withAllGrammars`)
In standard Neovim setups, Treesitter attempts to download and compile C parsers for languages dynamically using `gcc` or `clang`. In a pure NixOS environment, this often fails due to missing C toolchains or unpatched dynamic libraries.

By declaring `nvim-treesitter.withAllGrammars` in `specs.general`, Nix pre-compiles all syntax tree parsers at build time and embeds them directly into the store path. Syntax highlighting for Nix, Lua, C, Rust, and dozens of other languages works instantly upon launch with zero network requests or runtime compiler requirements.

---

## Integrating into the `nixos-vm` Target

With `flake.nixosModules.custom-nvim` exposed, attaching our tailored editor setup to our virtual machine requires just one line in `modules/hosts/vm/default.nix`:

```nix
{ inputs, self, ... }:
{
  flake.nixosConfigurations.nixos-vm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.qemu-vm
      self.nixosModules.base
      self.nixosModules.qemuGuest
      self.nixosModules.nixos-vm-config
      self.nixosModules.custom-nvim # <--- Integrated custom Neovim
    ];
  };
}
```

Because our host definition uses a modular list under `modules = [...]`, `custom-nvim` seamlessly blends into the host composition alongside `disko`, `base`, and `qemuGuest`.

---

## Deploying the Updated Configuration

To push these updates to our running VM, we trigger `deploy-rs` from our host machine:

```bash
nix run github:serokell/deploy-rs -- .#nixos-vm
```

### What Happens During Deployment?

1. **Local Evaluation & Build**: Your local machine evaluates the updated flake, builds the custom Neovim package (including the embedded Treesitter grammars and Lua configs), and prepares the new NixOS system closure.
2. **Store Transfer**: `deploy-rs` copies the missing Nix store paths over SSH directly to `nixos-vm`.
3. **Atomic Switch**: The remote host activates the new system generation. 

Once activated, logging into `nixos-vm` and launching `nvim` drops you immediately into your fully configured development environment—retaining your custom Lua keymaps, statusline, and Treesitter highlights seamlessly inside the virtual machine.

---

## Conclusion

By modularizing our Neovim wrapper, we achieved full alignment with our dendritic architecture principles:
* **Separation of Concerns**: Neovim configuration logic remains isolated in `modules/apps/nvim/`.
* **Reusability**: `flake.nixosModules.custom-nvim` can be reused by future bare-metal hosts or containers in the same flake.
* **Hermetic Environment**: Dependencies like `git`, language servers, and Treesitter grammars are deterministically bound to the editor package itself.

In the next entry of **Nixify**, we will begin expanding our system configurations, exploring Home Manager integration and user-space management across machines!
