<div align="center">
  <img src="/assets/nixos-logomark-rainbow-gradient-minimal.png" width="128" alt="NixOS logomark"/>
  <br/>
  <h1>iDN Primer</h1>
  <p>
    <b>nixos-anywhere templates for <a href="https://github.com/istvnurbn/idn">iDN</a></b>
    <br/>
    <i>The first layer to apply on a new system.</i>
  </p>
</div>

## About

This is a template repository for initiating a NixOS installation on a new system, based on [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples). It installs a minimal NixOS system which is then set up by my main repo, [iDN](https://github.com/istvnurbn/idn).

> [!NOTE]
> For now, only UEFI machines are supported. The configurations use systemd-boot, which is incompatible with legacy BIOS. To check a target before installing, run `[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS` on it.

## Requirements

- **Your machine:** Linux or macOS with [Nix](https://nixos.org/download/) installed.
- **The target:**
  - x86-64 or aarch64 Linux with kexec support, or already booted into a NixOS installer
  - at least 1.5 GB of RAM, not counting swap
  - SSH access as root over a wired connection (nixos-anywhere doesn't support Wi-Fi)

See [nixos-anywhere's requirements](https://github.com/nix-community/nixos-anywhere/blob/main/docs/requirements.md) for details.

## Configurations

| Name                    | Target                                                                                                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `hetzner-cloud`         | Hetzner Cloud x86 servers                                                                                                                                                            |
| `hetzner-cloud-aarch64` | Hetzner Cloud Arm servers                                                                                                                                                            |
| `generic`               | Any other UEFI machine, x86_64 or aarch64. Set its disk in [`flake.nix`](flake.nix) first; the install generates its `hardware-configuration.nix`, which also sets the architecture. |

## What gets installed

- **Disk:** GPT, with a 1G EFI system partition at `/boot` and a btrfs root (label `nixos`, zstd compression) on the rest. The root has these subvolumes:
  - `/root`, mounted at `/`
  - `/nix`
  - `/swap`, holding the swapfile
  - `/persist`, only when `impermanence` is on. It only creates the subvolume; resetting root on boot is left to iDN.
- **Boot loader:** systemd-boot
- **Access:** `steve` over SSH, using the keys in [`access.nix`](access.nix), with passwordless sudo for the `wheel` group. Root can't log in over SSH, and SSH password login is off, so keys are the only way in.
- **Nix:** flakes enabled, plus curl, git, and msedit.

iDN takes over the machine afterwards, so its host configuration has to mount this same layout. Change [`disk-config.nix`](disk-config.nix) and iDN together.

## Usage

> [!WARNING]
> Installing wipes the target disk completely: disko repartitions and formats all of it. The Hetzner configurations always wipe `/dev/sda`.

### Before you run

1. Replace [`access.nix`](access.nix) with your own user and SSH keys. It's the only personal file here, and it's mine, so leaving it locks you out and lets me in.
2. In [`flake.nix`](flake.nix), replace your configuration's `# per machine:` comments with the target's hostname and, for `generic`, its disk. List the disks with `ls -l /dev/disk/by-id` on the target. The build fails until these are set.
3. Review `swapSize` (at least your RAM if you hibernate) and `impermanence` in [`disk-config.nix`](disk-config.nix).

### Install

Run **nixos-anywhere** from the command line as shown below, where:

- `<configuration name>` is one of the [configurations](#configurations) above.
- `<ip address>` is the IP address of the target machine.

```
nix run github:nix-community/nixos-anywhere -- --flake .#<configuration name> --target-host root@<ip address>
```

On generic hardware, where you also need to generate the hardware configuration, add the flags for nixos-generate-config:

```
nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --flake .#generic --target-host root@<ip address>
```

### After install

The installed system has new SSH host keys, so your next `ssh` stops with a "REMOTE HOST IDENTIFICATION HAS CHANGED" warning. Remove the old key with `ssh-keygen -R <ip address>`, or add `--copy-host-keys` to the install command to keep the keys the target had before.

Then set the machine up with [iDN](https://github.com/istvnurbn/idn).

## AI Notice

The idea and the initial design of the work presented here are my own. However, I was assisted by Claude in catching mistakes and working through the trickier parts as I'm learning this.

## License

[MIT](LICENSE)
