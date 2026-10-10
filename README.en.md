# Hermit

**Backup and migration for Windows and Linux computers** · [Versão em português](README.md)

> **Notice:** this project was moved here. It started in the
> [`brunonsantos00/windows-backup-and-migration`](https://github.com/brunonsantos00/windows-backup-and-migration)
> repository, which no longer receives updates. The full commit history was brought along.

Scripts to make a **full backup of a computer** to an external drive and **restore everything on another computer**: files, settings, Wi-Fi networks and automatic reinstallation of programs.

| System | Versions | Folder |
|---|---|---|
| **Windows** | 10 and 11 | [`windows/`](windows/) |
| **Linux** | Ubuntu, Debian and Fedora | [`linux/`](linux/) |

Nothing to install: the scripts only use tools that come with the system (`robocopy`, `winget` and `netsh` on Windows; `rsync`, `apt`/`dnf` and `nmcli` on Linux).

## Features

- **Choose the destination disk** and **check free space before copying**. If it does not fit, you can switch disks or remove items.
- **Operating system detection** on each disk: Windows, Linux or macOS. Devices without a system are marked as suitable only for storing backups.
- **Automatic program reinstallation**: `winget` on Windows; `apt`/`dnf`, Flatpak and Snap on Linux. Anything that cannot be installed goes to a list on the Desktop.
- **Windows → Linux migration**: the Linux restore accepts backups made on Windows (personal files and Wi-Fi networks).
- **Graphical panel on Windows**: window with buttons, a device list showing each disk's system, free space and backups found.
- **Portuguese and English** everywhere: panel, scripts and menus.

## Quick start

The launchers are at the project root and share the same icon:

| System | Open with | What it does |
|---|---|---|
| Windows | **`BackupMigracao.exe`** (double-click) | Opens the graphical panel |
| Linux | **`BackupMigracao.sh`** (double-click or `bash BackupMigracao.sh`) | Opens the menu with backup and restore. Option 3 creates a shortcut with icon in the applications menu |

> The `.exe` is not digitally signed. The first time, Windows may show "Windows protected your PC": click **More info → Run anyway**. The source code is in [`launcher/`](launcher/) and you can rebuild it with `launcher/compilar.ps1`.

## Language

| Where | How to switch |
|---|---|
| Windows panel | **PT \| EN** button at the top of the window. The choice is saved and also applies to the scripts |
| Linux menu | Option **[5]** of `BackupMigracao.sh` |
| Scripts directly | `-Idioma pt` / `-Idioma en` on Windows, `--idioma pt` / `--idioma en` on Linux |

The first time, the language follows the system language: Portuguese if the system is in Portuguese, English otherwise. Folder names inside the backup are the same in both languages, so a backup made in one language restores normally in the other.

## Windows

Easiest way: double-click **`BackupMigracao.exe`**, or **`windows/0-ABRIR-PAINEL.bat`**.

The panel shows the connected devices and has **Back up** and **Restore backup** buttons. It notices automatically when a drive is connected. You can also run each step directly with the `.bat` files:

1. **On the old computer:** `1-FAZER-BACKUP.bat`. Choose the disk and answer the questions.
2. **On the new computer:** `2-RESTAURAR-BACKUP.bat`. Choose **[1] EVERYTHING**.

## Linux

Open a terminal in the drive's `linux/` folder:

```bash
bash backup.sh       # on the old computer
bash restaurar.sh    # on the new computer
```

The scripts ask for the administrator password, keep the computer from sleeping during the copy and work with drives formatted as ext4, NTFS, exFAT or FAT32.

## What is saved

| Item | Windows | Linux |
|---|---|---|
| User files | Whole user folder | Whole home folder |
| Program settings | `AppData\Roaming` + browsers | Hidden files (`~/.config`, `~/.mozilla`, `~/.ssh`…) |
| Programs | `winget` list | `apt`/`dnf` packages + Flatpak + Snap |
| Wi-Fi networks and passwords | `netsh` | NetworkManager |
| Extras (optional) | Folders at the root of `C:` and other disks | `/opt`, `/srv`, `/var/www`, `/usr/local` and other disks |
| Information | System, Windows key, printers | System, `/etc`, crontab |

Caches and trash are skipped. They are recreated automatically.

## Limitations

- **Programs** are not copied, they are **reinstalled** in their latest version.
- **Passwords saved in the browser** do not work on another Windows computer, because they are encrypted per machine. Use Google/Microsoft/Firefox account sync.
- **Linux packages across different families** (Ubuntu/Debian ↔ Fedora) have different names, so they go to the manual list. Flatpak and Snap work on any distribution.
- **Licenses** of paid programs need to be activated again.
- **FAT32** does not accept files larger than 4 GB. Prefer NTFS, exFAT or ext4.

## Backup structure

The format is the same on both systems:

```
BACKUP_PC/<PC>_<date>/
├── 00_Info/          system, origin (windows/linux), copy log
├── 01_Programas/     program lists for reinstallation
├── 02_Usuarios/      files and settings of each user
├── 03_WiFi/          Wi-Fi networks
├── 04_OutrasPastas/  extra folders and other disks
└── RESUMO.txt
```

## Branches

| Branch | Content |
|---|---|
| `main` | Stable version. Receives the other branches through merges |
| `feature/windows` | Windows scripts and panel |
| `feature/linux` | Linux scripts |
| `feature/launcher` | Icon and launchers (`.exe` and `.sh`) |
