---
date: '2026-07-27T21:40:30+05:30'
title: "Nixify #2.0: Setting Up a Dendritic NixOS Testbed VM"
draft: false
tags: ["nixos", "nixify"]
series: ["nixify"]
math: false
---

Welcome to **Nixify #2.0**. Now that we have established our wrapped CLI 
applications, it is time to move up the abstraction layer from user binaries to 
the operating system itself.

Before applying our declarative modules directly to bare-metal hardware, we need 
a completely isolated, reproducible sandbox. In this issue, we lay out the 
high-level design for a local NixOS virtual machine built using a **dendritic 
module structure**, formatted via **Disko**, provisioned through 
**`nixos-anywhere`**, and hosted on **libvirt**.

---

## Why a Dendritic Module Structure?

As a NixOS configuration grows, monolithic files become unmaintainable. 
A **dendritic pattern** mimics a branching tree: every system responsibility—from 
disk partitioning to desktop environments and hardware profiles—branches off into 
focused, isolated nodes.

```text
modules/
├── apps/         # Application wrappers (e.g., Neovim, foot)
├── profiles/     # High-level system roles (e.g., work, testing, desktop)
├── system/       # Core OS configurations (networking, users, boot)
└── hosts/        # Machine-specific targets (e.g., test-vm, laptop)
```

By pairing this tree-like hierarchy with `import-tree`, adding a new feature or 
testing node is as simple as dropping a `.nix` file into a folder. The flake 
discovers and imports it automatically.

---

## The Provisioning Pipeline

To test our system modules under realistic conditions, we do not manually step 
through the standard NixOS graphical installer. Instead, we use an automated, 
two-step provisioning workflow targeting a local `libvirt` QEMU/KVM virtual machine 
running on an Arch Linux host.

### 1. Declarative Storage with Disko
Instead of manually creating partitions with `gparted` or `fdisk`, we describe 
the VM's storage layout purely in Nix code using **Disko**. Disko handles partition 
tables, file systems (Btrfs/Ext4), and mount points declaratively during the 
installation phase.

### 2. Automated Deployment via `nixos-anywhere`
With `libvirt` serving the virtual hardware layer on our host, we execute 
**`nixos-anywhere`**. It connects to the running VM target over SSH, executes 
Disko to format the virtual drives, evaluates our flake's system configuration, 
and installs NixOS cleanly from scratch.

---

## Validating Wrapped Packages

The primary objective of this testbed VM is to validate how our custom application 
wrappers interact with the broader operating system environment.

Our flake exposes wrapped packages—such as our hermetic `.#nvim` IDE from the 1.x 
series—and injects them directly into the NixOS system environment:

* **`environment.systemPackages`**: Exposing wrapped tools globally across the OS.
* **`users.users.<name>.packages`**: Binding isolated tools strictly to specific user accounts.

This allows us to test environment variables, system-level dependencies, and 
user permissions inside a clean OS environment before pushing any configuration 
changes to our primary machines.

---

## What’s Next?

With the architectural blueprint in place, the upcoming articles in the 2.x series 
will break down the exact implementation details step-by-step:

* **Nixify #2.1**: Designing the Disko Disk Layout & Libvirt Setup
* **Nixify #2.2**: Provisioning with `nixos-anywhere` & Flake Integration
* **Nixify #2.3**: Injecting Wrapped App Packages into System Modules

See you in issue #2.1!
