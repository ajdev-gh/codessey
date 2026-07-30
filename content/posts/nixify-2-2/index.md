---
title: "Nixify #2.2: Zero-Touch Deployment with nixos-anywhere and deploy-rs"
date: 2026-07-30T20:30:00+05:30
draft: false
tags: ["nix", "nixos", "deploy-rs", "nixos-anywhere", "disko", "nixify"]
series: ["Nixify"]
math: false
---

Welcome to **Nixify #2.2**. In our previous issue, we declared our Disko 
partitioning scheme and configured our Libvirt virtual machine. Now, we move 
to provisioning and remote execution.

Deploying a NixOS machine traditionally requires booting an installer image, 
manually formatting the disk, cloning your flake repository, running 
`nixos-install`, and setting up SSH access.

We are skipping that entire manual pipeline.

In this issue, we will demonstrate how to take a fresh, blank VM and transform 
it into a fully configured NixOS system using **`nixos-anywhere`**. Then, we 
will wire up **`deploy-rs`** directly into our dendritic flake to handle remote, 
atomic system rebuilds over SSH without re-provisioning.

---

## Architectural Growth: Expanding the Dendritic Tree

Our flake tree has evolved to support shared system baselines, remote deployment 
definitions, and guest configurations across modular files:

```text
.
├── flake.lock
├── flake.nix
├── modules/
│   ├── apps/
│   │   └── nvim/
│   │       └── default.nix       # Custom Neovim package exposure
│   ├── hosts/
│   │   └── vm/
│   │       ├── config.nix        # VM system preferences & users
│   │       ├── default.nix       # NixOS host composition
│   │       ├── deploy.nix        # deploy-rs node definition
│   │       └── disko.nix         # Disko drive partition spec
│   ├── qemu/
│   │   └── default.nix           # QEMU guest profiles & VirtIO modules
│   └── sys/
│       └── base.nix              # Global Nix daemon & core defaults
└── README.md
```

Notice how `modules/hosts/vm/` breaks responsibilities into clear, single-purpose 
files. `disko.nix` handles disk layouts, `config.nix` manages user privileges, 
and `deploy.nix` exports our remote deployment targets.

---

## Module Deep Dive: The Core Engine

Before provisioning, let us break down the configuration changes driving our system.

### 1. Global Baseline (`modules/sys/base.nix`)

Every machine running under our flake requires fundamental settings like Flakes 
support, Garbage Collection policies, and locale configurations. We extract 
this logic into a shared module exposed through `flake.nixosModules.base`:

```nix
{ self, inputs, ... }: {
  flake.nixosModules.base = {
    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        trusted-users = [ "root" "@wheel" ];
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };
    time.timeZone = "Asia/Kolkata";
    nixpkgs.config.allowUnfree = true;
  };
}
```

* **`trusted-users`**: Setting `root` and `@wheel` as trusted users enables non-root 
  privileged accounts to query the Nix daemon and perform binary cache operations.
* **`gc.automatic`**: Enforces weekly garbage collection sweeps, dropping generations 
  older than 7 days to maintain clean virtual disk usage.

---

### 2. VM System Identity & Access (`modules/hosts/vm/config.nix`)

Next, we establish authorization parameters for remote administration:

```nix
{ pkgs, ... }:
{
  security.sudo.wheelNeedsPassword = false;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXcI7ftmBn6N33Au3JMYJQOC8NJGfvRKP69Nk+vwTk8 ajirequi@metis"
    ];
  };

  users.users.ajirequi = {
    description = "Ajai Dev";
    isNormalUser = true;
    enable = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXcI7ftmBn6N33Au3JMYJQOC8NJGfvRKP69Nk+vwTk8 ajirequi@metis"
    ];
    packages = with pkgs; [
      tree
    ];
  };

  system.stateVersion = "26.05";
}
```

* **`wheelNeedsPassword = false`**: Allows smooth automated deployments via `sudo` 
  without interactive password prompts interrupting `deploy-rs`.
* **Authorized SSH Keys**: Injecting public keys into both `root` and `ajirequi` 
  guarantees direct passwordless access for provisioning and ongoing host management.

---

### 3. Assembly with System Composition (`modules/hosts/vm/default.nix`)

We wire everything together inside the `nixosSystem` definition by importing our 
custom flake modules:

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
    ];
  };
}
```

---

### 4. Declarative Deployments (`modules/hosts/vm/deploy.nix`)

To execute updates after the initial setup, we declare a deployment node using 
**`deploy-rs`**:

```nix
{ self, inputs, ... }: {
  flake.deploy.nodes.nixos-vm = {
    hostname = "nixos-vm";
    sshUser = "ajirequi";
    fastConnection = true;
    profiles.system = {
      user = "root";
      path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.nixos-vm;
    };
  };
}
```

* **`hostname`**: The SSH alias or IP address of the target VM.
* **`sshUser`**: Connects as our unprivileged user `ajirequi`.
* **`profiles.system.user`**: Elevates to `root` on the target machine to activate 
  the new system profile.
* **`activate.nixos`**: Builds the system profile locally or on a builder, transfers 
  the closures, and safely switches the running system generation.

---

## Phase 1: Bootstrapping with `nixos-anywhere`

With our configurations written, we perform the initial zero-touch provisioning.

`nixos-anywhere` operates by SSHing into a live installer system (such as a 
standard NixOS Minimal ISO running in our VM), running Disko to partition and format 
the storage remotely, installing the NixOS closure, and rebooting into our final 
system setup.

### Step 1: Boot the Live Environment
1. Attach a standard NixOS ISO to our VM in `virt-manager` and power it on.
2. Note the temporary IP assigned to the live environment (e.g., `192.168.122.140`).
3. Ensure root SSH access is available in the live environment.

### Step 2: Execute Provisioning

From our host terminal, run `nixos-anywhere` pointing directly at our flake target:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nixos-vm \
  root@192.168.122.140
```

### What Happens Under the Hood?

1. **Remote Memory Inspection**: `nixos-anywhere` connects over SSH and analyzes 
   the live target machine.
2. **Kexec into Installer**: It loads a temporary installer kernel directly into 
   RAM if necessary.
3. **Disko Invocation**: It transfers our `disko.nix` specification, builds the GPT 
   partition table, creates the EFI system partition, formats the root device with 
   Btrfs, and mounts subvolumes (`@`, `@home`, `@nix`, `@log`, `@swap`).
4. **Closure Deployment**: It builds our `nixos-vm` profile locally and copies the 
   required store paths over SSH.
5. **Bootloader Installation**: GRUB is installed onto `/dev/vda` with EFI support.
6. **Reboot**: The machine reboots directly into our fresh, declarative NixOS install.

---

## Phase 2: Day-2 Operations with `deploy-rs`

Now that the system is running live at hostname `nixos-vm`, we no longer need 
`nixos-anywhere`. Any future changes to our modules, packages, or configurations 
are deployed seamlessly via `deploy-rs`.

### Making System Modifications

Suppose we want to install `tree` or update system options. We simply make our 
edits in `modules/hosts/vm/config.nix` and commit our changes.

### Running the Deployment

To deploy updates to our live host:

```bash
nix run github:serokell/deploy-rs -- .#nixos-vm
```

### Key Advantages of `deploy-rs` over `nixos-rebuild`:

* **Atomic Rollbacks**: If activation fails on the remote host (e.g., SSH connection 
  drops or a boot module fails), `deploy-rs` automatically rolls back to the 
  previous working generation.
* **Remote Activation**: Build operations can happen on your powerful host machine, 
  pushing compiled store paths to lightweight VMs or remote servers without 
  taxing guest resources.
* **Flake Native**: Integrates cleanly with flake outputs without requiring manual 
  SSH wrapper scripts.

---

## Conclusion & Next Steps

We now have an automated lifecycle for our systems:
1. **Disko** declares how drive hardware is structured.
2. **`nixos-anywhere`** provisions new machines from scratch in one command.
3. **`deploy-rs`** maintains and updates our running nodes over SSH.

In **Nixify #2.3**, we will integrate our custom neovim wrapper made in part
1.x of the series, configuring custom Lua modules and integrating editor profiles 
into our declarative workflow.
