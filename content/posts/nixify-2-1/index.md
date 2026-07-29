---
date: 2026-07-29T08:00:00+05:30
title: "Nixify #2.1: Disko Btrfs Layout & Libvirt VM Prep"
draft: false
tags: ["nixos", "disko", "libvirt", "nixify"]
series: ["Nixify"]
math: false
---

Welcome back to **Nixify**. In issue #2.1, we are moving from theory to execution 
by building the foundation for our testbed Virtual Machine.

Installing NixOS traditionally involves booting an ISO, manually partitioning 
disks with `fdisk`, formatting filesystems, and mounting subvolumes. In our setup, 
we replace manual disk operations entirely with **Disko**, describing our disk 
layout as pure Nix code that automatically executes during deployment.

---

## The Dendritic File Structure

In keeping with our dendritic module architecture, our host configuration, 
storage specifications, and virtualization profiles live in dedicated, isolated 
modules under `modules/`:

```text
modules/
├── hosts/
│   └── vm/
│       ├── default.nix   # System definition & SSH/User configuration
│       └── disko.nix     # Declarative GPT & Btrfs disk layout
└── qemu/
    └── default.nix       # Reusable QEMU guest profile & VirtIO drivers
```

---

## Declarative Storage Architecture with Disko

Inside `modules/hosts/vm/disko.nix`, we declare our target drive (`/dev/vda`) using 
a GPT partition scheme containing a BIOS boot partition, an EFI System Partition (ESP), 
and a Btrfs root partition with subvolumes:

```nix
{ inputs, ... }:
{
  flake.diskoConfigurations.qemu-vm = {
    disko.devices = {
      disk = {
        vda = {
          type = "disk";
          device = "/dev/vda";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "1M";
                type = "EF02"; # BIOS boot partition
              };
              ESP = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "@" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@log" = {
                      mountpoint = "/var/log";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@swap" = {
                      mountpoint = "/.swapvolume";
                      swap.swapfile.size = "2G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
```

### Why This Btrfs Layout?

* **`compress=zstd`**: Enables transparent file compression, reducing disk IO 
  and saving virtual disk space without performance penalties.
* **Isolated Subvolumes**: Separating `@`, `@home`, `@nix`, `@log`, and `@swap` 
  prepares our system for future features like state rollback and atomic snapshots.
* **Declarative Swap**: Disko handles the creation and size allocation of 
  `swapfile` within a dedicated subvolume automatically.

---

## Reusable QEMU Guest Module

To ensure the VM boots smoothly on virtualized hardware, `modules/qemu/default.nix` 
defines a reusable module exposed under `flake.nixosModules.qemuGuest`.

It enables essential VirtIO kernel modules, configures GRUB for `/dev/vda`, 
enables `qemuGuest` for host interactions, and routes kernel output to serial console:

```nix
{ ... }:
{
  flake.nixosModules.qemuGuest = { config, lib, pkgs, ... }: {
    options.profiles.qemuGuest = {
      enable = lib.mkEnableOption "common QEMU VM guest configurations";
    };

    config = lib.mkIf config.profiles.qemuGuest.enable {
      boot.initrd.availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_net"
        "virtio_scsi"
        "virtio_console"
        "9p"
        "9pnet_virtio"
      ];

      boot.loader.grub = {
        enable = true;
        device = "/dev/vda";
        efiSupport = lib.mkDefault true;
        efiInstallAsRemovable = lib.mkDefault true;
      };

      services.qemuGuest.enable = true;
      boot.kernelParams = [ "console=ttyS0,115200n8" ];
    };
  };
}
```

---

## Libvirt Host Environment Setup

On our Arch Linux host machine, we prepare the virtual hardware environment using 
`libvirt`, `virt-manager`, and `qemu-desktop`:

```bash
sudo pacman -S libvirt virt-manager qemu-desktop
sudo systemctl enable --now libvirtd
```

Through Virt-Manager, we create a new QEMU/KVM Virtual Machine tailored for testing:

1. **Storage**: Allocated a **50GB** virtual disk image (`/dev/vda`).
2. **CPU**: Assigned **4 vCPUs** (1 socket, 4 threads).
3. **Memory & 3D Acceleration**: Shared memory enabled, Video model set to **Virtio** 
   with 3D acceleration enabled.
4. **Display**: SPICE listen type set to **None** with OpenGL enabled to support 
   future desktop environments.

With our Disko configuration defined in code and virtual hardware ready in Libvirt, 
we are set to perform a headless installation.

In **Nixify #2.2**, we will trigger `nixos-anywhere` to format the VM's disk and 
deploy NixOS over SSH!
