=====================================================
  COMPUTER BACKUP AND MIGRATION (WINDOWS)
=====================================================

EASIEST WAY: double-click "BackupMigracao.exe" (project root) or
"0-ABRIR-PAINEL.bat" and use the buttons. The PT | EN button at the top
of the window changes the language of the panel and of the scripts.

STEP 1 - ON THE OLD COMPUTER
  1. Copy this whole folder to the external drive (or another disk).
  2. Close all programs (browser, Outlook, WhatsApp...).
  3. If it is a laptop, plug it in.
  4. Double-click "1-FAZER-BACKUP.bat" and click "Yes" on the permission prompt.
  5. Choose which disk to save the backup to.
  6. Answer the questions. The script MEASURES the backup size and warns
     you if it does not fit (you can switch disks or remove items).
  7. Then it runs on its own. The backup is saved to
       <DISK>:\BACKUP_PC\<PC-NAME>_<date>\

STEP 2 - ON THE NEW COMPUTER
  1. Connect to the internet (or let the script restore the Wi-Fi).
  2. Connect the backup disk and double-click "2-RESTAURAR-BACKUP.bat".
     It finds the backup on any connected disk and checks if it fits.
  3. Choose option [1] EVERYTHING.
  4. At the end, open "PROGRAMS TO INSTALL MANUALLY.txt" on the Desktop
     and install whatever is missing.
  5. Restart the computer.

BACKUP 2.0 - WITH PROGRAM FOLDERS
  "1-FAZER-BACKUP-2.0.bat" makes the same backup and also copies the folders of the
  installed programs (Program Files, Program Files (x86), AppData\Local\Programs and
  their data in ProgramData), plus the Start Menu shortcuts.
  On restore, option [1] EVERYTHING or [7]: the folders go back to the same place,
  without reinstalling. If the program already exists on the new computer, its files
  are REPLACED by the ones from the backup (open programs are closed first, if you allow).
  Note: programs that depend on services, drivers or activation (Office, Adobe,
  antivirus, video drivers) may not open this way. In that case, use option [3]
  Reinstall programs (winget).

COMPARE THE BACKUP WITH THE COMPUTER
  "3-COMPARAR-BACKUP.bat" shows what is in the backup but did NOT reach this computer:
  - "Missing": files in the backup that do not exist here;
  - "Newer": files that exist here, but the backup version is newer.
  It saves the report "BACKUP COMPARISON.txt" on the Desktop and, at the end, offers
  to copy what is missing (without replacing anything that already exists). Read-only:
  it never deletes anything.
COMPARE ONLY (WITHOUT COPYING ANYTHING)
  "APENAS_COMPARAÇÃO.bat" compares and shows on screen, in colors, the list of what is
  missing in each folder (red = missing, yellow = newer in the backup, green = all good).
  It does not offer to copy anything.
  There is also a window version: "Comparador.exe" (project root). Choose the backup,
  click Compare and see the totals, the folders and the missing files, with search.
WHAT IS SAVED
  - All user files (Desktop, Documents, Downloads, Pictures, Videos, Music,
    and any other folder inside C:\Users\<you>)
  - Program settings (AppData\Roaming)
  - Chrome/Edge/Brave/Vivaldi/Firefox data (bookmarks, extensions, history)
  - Installed fonts, Sticky Notes, Outlook (.pst)
  - List of programs + automatic reinstallation with winget
  - Wi-Fi networks with passwords
  - Extra folders at the root of C: (e.g. C:\Projects) and other disks, if you want
  - PC information, Windows key (if stored in the BIOS), printers

WHAT CANNOT BE MOVED
  - The programs themselves: they are REINSTALLED (newest version). Programs
    that are not in winget show up on the list for manual installation.
  - Passwords saved in the browser: Windows encrypts them per computer.
    Sign in to your Google/Microsoft account in the browser to sync them.
  - Licenses of paid programs (Office, Adobe, games): sign in again.
  - OneDrive files that were only in the cloud (they come back when you sign in).
  - Steam/Epic games: reinstall them from the store.

NOTE: if the drive is formatted as FAT32, files larger than 4 GB do not fit.
The script warns you. Prefer NTFS or exFAT.

IF SOMETHING GOES WRONG
  - Copy log: 00_Info\log-copia.txt inside the backup.
  - Everything shown on screen: ultima-execucao-backup.txt / ultima-execucao-restaurar.txt
    (in the same folder as the scripts).
