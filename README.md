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
> For now, only UEFI machines with Secure Boot off are supported. The configurations use unsigned systemd-boot, which is incompatible with legacy BIOS. To check a target before installing, run `[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS` on it.

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

- **Disk:** GPT, with a 1G EFI system partition at `/boot` and a btrfs root (label `nixos`, zstd compression) on the rest, optionally inside LUKS2 (`luks`, desktops only, opened as `/dev/mapper/crypted`). The root has these subvolumes:
  - `/root`, mounted at `/`
  - `/nix`
  - `/swap`, holding the swapfile
  - `/persist`, only when `impermanence` is on. It only creates the subvolume; resetting root on boot is left to iDN.
- **Data disk:** only when `data` is on. GPT with one btrfs partition (label `data`), inside LUKS2 with the same passphrase when `luks` is on. It stays unmounted until iDN takes over.
- **Boot loader:** systemd-boot
- **Console:** Hungarian keymap, also at the disk passphrase prompt.
- **Access:** `steve` over SSH, using the keys in [`access.nix`](access.nix), with passwordless sudo for the `wheel` group. Root can't log in over SSH, and SSH password login is off, so keys are the only way in.
- **Nix:** flakes enabled, plus curl, git, and msedit.
- **Firmware:** redistributable firmware, on `generic` only.

iDN takes over the machine afterwards, so its host configuration has to mount this same layout. Change [`disk-config.nix`](disk-config.nix) and iDN together.

## Usage

> [!WARNING]
> Installing wipes the target disk completely: disko repartitions and formats all of it. The Hetzner configurations always wipe `/dev/sda`, so detach any Volumes first.

### Before you run

1. Replace [`access.nix`](access.nix) with your own user and SSH keys. It's the only personal file here, and it's mine, so leaving it locks you out and lets me in.
2. In [`flake.nix`](flake.nix), replace your configuration's `# per machine:` comments with the target's hostname (its host name in iDN) and, for `generic`, its disk (and its data disk, with `data` on). List the disks with `ls -l /dev/disk/by-id` on the target. The build fails until these are set. On Hetzner, also fill in the IPv6 line: an IPv6-only server is unreachable without it.
3. Review `swapSize` (at least your RAM if you hibernate), `impermanence`, `luks` and `data` in [`disk-config.nix`](disk-config.nix). Turn `impermanence` and `luks` on exactly when the iDN host includes the aspect of the same name, and `data` when it includes `disko-btrfs-data`. `luks` is for desktops only; servers stay unencrypted.

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

With `luks` on, also pass the passphrase. nixos-anywhere copies the file to the target, and disko only reads it while formatting:

```
--disk-encryption-keys /tmp/secret.key <local file holding the passphrase>
```

Every boot then asks for it on the console, until iDN sets up the TPM.

### After install

The installed system has new SSH host keys, so your next `ssh` stops with a "REMOTE HOST IDENTIFICATION HAS CHANGED" warning. Remove the old key with `ssh-keygen -R <ip address>`, or add `--copy-host-keys` to the install command to keep the keys the target had before.

Then hand the machine over to [iDN](https://github.com/istvnurbn/idn). Its host needs this install's hostname, disks, `swapSize`, `impermanence`, `luks` and `data` choices and, on `generic`, the contents of the generated `hardware-configuration.nix` (afterwards, restore the placeholder here with `git restore hardware-configuration.nix`). On the target, as `steve`:

If the iDN host includes `luks-ssh-unlock` (the SSH fallback for encrypted desktops), first create the initrd's own host key: the rebuild copies it into the initrd, and fails without it. Without impermanence, use `/etc/secrets/initrd` instead:

```sh
sudo install -d -m 700 /persist/etc/secrets/initrd
sudo ssh-keygen -t ed25519 -N "" -f /persist/etc/secrets/initrd/ssh_host_ed25519_key
```

With `luks` and `data` both on, give the data disk the keyfile iDN opens it with (it asks for the passphrase once). Without impermanence, use `/etc/secrets` instead:

```sh
sudo install -d -m 700 /persist/etc/secrets
sudo dd if=/dev/urandom of=/persist/etc/secrets/data.key bs=64 count=1 status=none
sudo chmod 400 /persist/etc/secrets/data.key
sudo cryptsetup luksAddKey /dev/disk/by-partlabel/disk-data-data /persist/etc/secrets/data.key
```

Then clone iDN and apply it:

```sh
git clone https://github.com/istvnurbn/idn ~/idn
nixos-rebuild boot --flake ~/idn#<hostname> --sudo
```

With `impermanence` on, copy what iDN keeps in `/persist` before rebooting, or the first boot comes up with new SSH host keys, a new machine ID and no `~/idn`:

```sh
sudo mkdir -p /persist/etc/ssh /persist/var/lib /persist/home
sudo cp -a /etc/ssh/ssh_host_* /persist/etc/ssh/
sudo cp -a /etc/machine-id /persist/etc/
sudo cp -a /var/lib/nixos /persist/var/lib/
sudo install -d -o "$USER" -g "$(id -gn)" -m 700 "/persist$HOME"
cp -a ~/idn "/persist$HOME/"
```

Then `sudo reboot`. Use `boot`, not `switch`, for this first apply: the network stack and, with impermanence, the mounts change, and those only apply cleanly on a fresh boot.

## AI Notice

The idea and the initial design of the work presented here are my own. However, I was assisted by Claude in catching mistakes and working through the trickier parts as I'm learning this.

## License

[MIT](LICENSE)
