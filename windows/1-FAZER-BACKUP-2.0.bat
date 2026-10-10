@echo off
rem Backup 2.0: igual ao backup normal, mas também copia as pastas dos programas instalados
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup.ps1" -ComProgramas
