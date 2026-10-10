<#
    Compila o BackupMigracao.exe (na raiz do projeto) com o ícone de assets\icone.ico.
    Usa o compilador C# que já vem no Windows (.NET Framework 4).
#>

$raiz = Split-Path $PSScriptRoot -Parent
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (-not (Test-Path $csc)) { Write-Host 'Compilador C# (.NET Framework 4) não encontrado.' -ForegroundColor Red; exit 1 }

& $csc /nologo /target:winexe /optimize+ /codepage:65001 `
    "/win32icon:$raiz\assets\icone.ico" `
    "/out:$raiz\BackupMigracao.exe" `
    /reference:System.Windows.Forms.dll `
    "$PSScriptRoot\BackupMigracao.cs"

if ($LASTEXITCODE -eq 0) { Write-Host "Gerado: $raiz\BackupMigracao.exe" -ForegroundColor Green }
exit $LASTEXITCODE
