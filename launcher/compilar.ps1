<#
    Compila o BackupMigracao.exe (na raiz do projeto) com o ícone de assets\icone.ico.
    Usa o compilador C# que já vem no Windows (.NET Framework 4).
    Para gerar a versão portátil e o .zip da Release, use gerar-release.ps1.
#>
param(
    [string]$Saida,        # padrão: BackupMigracao.exe na raiz
    [string]$Embutir       # .zip do projeto para embutir (versão portátil)
)

$raiz = Split-Path $PSScriptRoot -Parent
if (-not $Saida) { $Saida = Join-Path $raiz 'BackupMigracao.exe' }
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (-not (Test-Path $csc)) { Write-Host 'Compilador C# (.NET Framework 4) não encontrado.' -ForegroundColor Red; exit 1 }

$opcoes = @('/nologo', '/target:winexe', '/optimize+', '/codepage:65001',
            "/win32icon:$raiz\assets\icone.ico", "/out:$Saida",
            '/reference:System.Windows.Forms.dll', '/reference:System.IO.Compression.dll', '/reference:System.IO.Compression.FileSystem.dll')
if ($Embutir) { $opcoes += "/resource:$Embutir,hermit.zip" }

& $csc @opcoes "$PSScriptRoot\BackupMigracao.cs"

if ($LASTEXITCODE -eq 0) { Write-Host "Gerado: $Saida" -ForegroundColor Green }
exit $LASTEXITCODE
