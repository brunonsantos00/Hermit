=====================================================
  COMPUTER BACKUP AND MIGRATION (LINUX)
  Ubuntu, Debian and Fedora
=====================================================

EASIEST WAY: run  bash BackupMigracao.sh  (project root) and use the menu.
Option [5] switches the language (Português / English).
Scripts also accept  --idioma pt  or  --idioma en.

STEP 1 - ON THE OLD COMPUTER
  1. Copy this folder to the external drive.
  2. Open the drive in the file manager (so it gets mounted).
  3. Close open programs (browser, e-mail...).
  4. Open a terminal in this folder (right click > "Open in Terminal") and run:
         bash backup.sh
  5. Type your password, choose the disk and answer the questions.
     The script MEASURES the size and warns you if it does not fit.
  6. The backup is saved to  <DRIVE>/BACKUP_PC/<PC-NAME>_<date>/

STEP 2 - ON THE NEW COMPUTER
  1. Connect to the internet.
  2. Connect the drive, open a terminal in this folder and run:
         bash restaurar.sh
  3. Choose option [1] EVERYTHING.
  4. Open "PROGRAMS TO INSTALL MANUALLY.txt" on the Desktop and install
     whatever is missing.
  5. Restart the computer.

WHAT IS SAVED
  - Home folder of each user (Desktop, Documents, Downloads, Pictures,
    Videos, Music...)
  - Settings (hidden files: browsers, SSH keys, theme, programs)
  - Packages you installed (apt or dnf), Flatpak and Snap
  - Wi-Fi networks with passwords (NetworkManager)
  - Optional: /opt, /srv, /var/www, /usr/local and other disks
  - Copy of /etc, crontab and computer information (for reference only)

BACKUP MADE ON WINDOWS?
  restaurar.sh also accepts backups from the Windows script: it copies the
  Desktop, Documents, Pictures etc. to the right folders, imports the Wi-Fi
  networks and saves the list of Windows programs on the Desktop.

LIMITATIONS
  - apt and dnf packages have different names: from Ubuntu/Debian to Fedora
    (or the other way around) they go to the manual list. Flatpak and Snap
    work everywhere.
  - On NTFS/exFAT/FAT32 drives Linux permissions are not kept
    (the restore fixes the file owner automatically).
  - On FAT32, files larger than 4 GB do not fit. Prefer ext4, NTFS or exFAT.
  - Steam games are not copied (reinstall them from Steam).

IF SOMETHING GOES WRONG
  - Copy log: 00_Info/log-copia.txt inside the backup.
  - Everything shown on screen: ultima-execucao-backup.txt / ultima-execucao-restaurar.txt
