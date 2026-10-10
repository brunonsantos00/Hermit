@echo off
rem Only compares the backup with this computer and shows what is missing (copies nothing)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0compare.ps1" -ApenasComparar
