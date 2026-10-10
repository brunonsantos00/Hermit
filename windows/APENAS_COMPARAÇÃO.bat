@echo off
rem Apenas compara o backup com este computador e mostra o que falta (não copia nada)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0comparar.ps1" -ApenasComparar
