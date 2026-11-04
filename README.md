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

## Choose a layout

Three switches in [`disk-config.nix`](disk-config.nix) decide the layout. iDN mounts the same layout after the handoff, so each one has to match the iDN host:

| Switch         | Turn it on when the iDN host includes            | What it adds                                                                                                                                            |
| -------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `impermanence` | `impermanence`                                   | A `/persist` subvolume for what survives iDN resetting root on every boot                                                                               |
| `luks`         | `luks` (desktops only; servers stay unencrypted) | LUKS2 around the root, opened as `/dev/mapper/crypted`. Every boot asks for the passphrase until iDN sets up the TPM                                    |
| `data`         | `disko-btrfs-data`                               | A second disk with one btrfs partition (label `data`), inside LUKS2 with the same passphrase when `luks` is on. It stays unmounted until iDN takes over |

Also check `swapSize` there: at least your RAM if you hibernate.

## What gets installed

- **Disk:** GPT, with a 1G EFI system partition at `/boot` and a btrfs root (label `nixos`, zstd compression) on the rest, inside LUKS2 with `luks` on. The root has these subvolumes:
  - `/root`, mounted at `/`
  - `/nix`
  - `/swap`, holding the swapfile
  - `/persist`, with `impermanence` on. It only creates the subvolume; resetting root on boot is left to iDN.
- **Data disk:** with `data` on, as above.
- **Boot loader:** systemd-boot
- **Console:** Hungarian keymap, also at the disk passphrase prompt.
- **Access:** `steve` over SSH, using the keys in [`access.nix`](access.nix), with passwordless sudo for the `wheel` group. Root can't log in over SSH, and SSH password login is off, so keys are the only way in.
- **Nix:** flakes enabled, plus curl, git, and msedit.
- **Firmware:** redistributable firmware, on `generic` only.

iDN takes over the machine afterwards, so its host configuration has to mount this same layout. Change [`disk-config.nix`](disk-config.nix) and iDN together.

## Usage

> [!WARNING]
> Installing wipes the target's disks completely: disko repartitions and formats the system disk, and the data disk with `data` on. The Hetzner configurations always wipe `/dev/sda`, so detach any Volumes first.

### 1. Prepare this repo

1. Replace [`access.nix`](access.nix) with your own user and SSH keys. It's the only personal file here, and it's mine, so leaving it locks you out and lets me in.
2. In [`flake.nix`](flake.nix), replace your configuration's `# per machine:` comments with the target's hostname (its host name in iDN) and, for `generic`, its disk (and its data disk, with `data` on). List the disks with `ls -l /dev/disk/by-id` on the target. The build fails until these are set. On Hetzner, also fill in the IPv6 line: an IPv6-only server is unreachable without it.
3. Set the switches and `swapSize` in [`disk-config.nix`](disk-config.nix), as in [Choose a layout](#choose-a-layout).

### 2. Get root SSH on the target

nixos-anywhere needs root over SSH. A running Linux works: it kexecs into its own installer from there. For a desktop, boot the [NixOS minimal ISO](https://nixos.org/download/#nixos-iso) instead. On its console, `sudo loadkeys hu`, then `sudo passwd root`. Then, from your machine:

```sh
ssh-copy-id root@<ip address>
ssh root@<ip address> 'hostname; lsblk -dno NAME,SERIAL'
```

The second command lists the target's disks: check they're the ones you mean to wipe.

### 3. Install

Run **nixos-anywhere** with `<configuration name>` one of the [configurations](#configurations) above and `<ip address>` the target's address:

```
nix run github:nix-community/nixos-anywhere -- --flake .#<configuration name> --target-host root@<ip address>
```

On generic hardware, also generate the hardware configuration:

```
nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --flake .#generic --target-host root@<ip address>
```

**Encrypted (`luks` on):** write the passphrase to a local file and add it to the command. nixos-anywhere copies it to the target, and disko only reads it while formatting, so it never lands on the installed system:

```
--disk-encryption-keys /tmp/secret.key <local file holding the passphrase>
```

### 4. First boot

- **Unencrypted:** the target boots straight up.
- **Encrypted:** every boot asks for the passphrase on the console until iDN sets up the TPM.

The installed system has new SSH host keys, so your next `ssh` stops with a "REMOTE HOST IDENTIFICATION HAS CHANGED" warning. Remove the old key with `ssh-keygen -R <ip address>`, or add `--copy-host-keys` to the install command to keep the keys the target had before.

### 5. Hand over to iDN

The iDN host needs this install's hostname, disks, `swapSize` and switches and, on `generic`, the contents of the generated `hardware-configuration.nix` (afterwards, restore the placeholder here with `git restore hardware-configuration.nix`). Then, on the target as `steve`, go through these steps in order, skipping the ones that don't match your layout:

1. **Encrypted, with the SSH fallback** (the iDN host includes `luks-ssh-unlock`): create the initrd's own host key. The rebuild copies it into the initrd, and fails without it. Without impermanence, use `/etc/secrets/initrd` instead:

   ```sh
   sudo install -d -m 700 /persist/etc/secrets/initrd
   sudo ssh-keygen -t ed25519 -N "" -f /persist/etc/secrets/initrd/ssh_host_ed25519_key
   ```

2. **Encrypted, with a data disk:** give the data disk the keyfile iDN opens it with. It asks for the passphrase once. Without impermanence, use `/etc/secrets` instead:

   ```sh
   sudo install -d -m 700 /persist/etc/secrets
   sudo dd if=/dev/urandom of=/persist/etc/secrets/data.key bs=64 count=1 status=none
   sudo chmod 400 /persist/etc/secrets/data.key
   sudo cryptsetup luksAddKey /dev/disk/by-partlabel/disk-data-data /persist/etc/secrets/data.key
   ```

3. **Every layout:** clone iDN and apply it:

   ```sh
   git clone https://github.com/istvnurbn/idn ~/idn
   nixos-rebuild boot --flake ~/idn#<hostname> --sudo
   ```

4. **With impermanence:** copy what iDN keeps in `/persist` before rebooting, or the first boot comes up with new SSH host keys, a new machine ID and no `~/idn`:

   ```sh
   sudo mkdir -p /persist/etc/ssh /persist/var/lib /persist/home
   sudo cp -a /etc/ssh/ssh_host_* /persist/etc/ssh/
   sudo cp -a /etc/machine-id /persist/etc/
   sudo cp -a /var/lib/nixos /persist/var/lib/
   sudo install -d -o "$USER" -g "$(id -gn)" -m 700 "/persist$HOME"
   cp -a ~/idn "/persist$HOME/"
   ```

5. **Every layout:** `sudo reboot`. Use `boot`, not `switch`, for this first apply: the network stack and, with impermanence, the mounts change, and those only apply cleanly on a fresh boot.

### 6. Encrypted: Secure Boot and the TPM

The iDN host's `secure-boot` aspect creates the Secure Boot keys on its first boot and stages them on the ESP. Until the TPM is enrolled, every boot asks for the passphrase on the console. With `luks-ssh-unlock`, you can also answer it from the LAN with `ssh -p 2222 root@<ip address>`.

1. **Check the staged keys:** `sudo bootctl status` shows Secure Boot in Setup Mode or disabled, and `sudo ls /boot/loader/keys/auto` lists the keys.
2. **Enroll them:** in the firmware, enable Secure Boot and reset it to Setup Mode (keep the dbx), then reboot. systemd-boot enrolls the keys and restarts. Afterwards, `sudo bootctl status` says `Secure Boot: enabled (user)`.
3. **Seal the disk key to the TPM**, bound to the Secure Boot state (PCR 7) and an empty PCR 15:

   ```sh
   sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-root \
     --tpm2-device=auto \
     --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000
   ```

   After a reboot there's no prompt, and `journalctl -b -u systemd-cryptsetup@crypted` shows the TPM unlock.

4. **Optional, a PIN:** to type a short PIN at every boot, run step 3 again with `--wipe-slot=tpm2 --tpm2-with-pin=yes` added.
5. **A recovery key:** `sudo systemd-cryptenroll --recovery-key /dev/disk/by-partlabel/disk-main-root` prints one; keep it off the machine. The passphrase keeps working too.

If the TPM ever refuses, after a dbx or firmware update or with Secure Boot off, the passphrase prompt is back. Answer it on the console or over SSH, then repeat step 3 with `--wipe-slot=tpm2` added.

## AI Notice

The idea and the initial design of the work presented here are my own. However, I was assisted by Claude in catching mistakes and working through the trickier parts as I'm learning this.

## License

[MIT](LICENSE)
