@echo off
rem Backup 2.0: same as the normal backup, but also copies the folders of installed programs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup.ps1" -ComProgramas
