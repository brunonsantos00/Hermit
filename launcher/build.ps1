<#
    Builds Hermit.exe (at the project root) with the icon from assets\icon.ico.
    Uses the C# compiler that ships with Windows (.NET Framework 4).
    To build the portable version and the Release .zip, use build-release.ps1.
#>
param(
    [string]$Saida,        # default: Hermit.exe at the root
    [string]$Embutir,      # project .zip to embed (portable version)
    [switch]$Comparador    # builds Hermit-Compare.exe instead of Hermit.exe
)

$raiz = Split-Path $PSScriptRoot -Parent
if (-not $Saida) { $Saida = Join-Path $raiz $(if ($Comparador) { 'Hermit-Compare.exe' } else { 'Hermit.exe' }) }
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (-not (Test-Path $csc)) { Write-Host 'Compilador C# (.NET Framework 4) não encontrado.' -ForegroundColor Red; exit 1 }

$opcoes = @('/nologo', '/target:winexe', '/optimize+', '/codepage:65001',
            "/win32icon:$raiz\assets\icon.ico", "/out:$Saida",
            '/reference:System.Windows.Forms.dll', '/reference:System.IO.Compression.dll', '/reference:System.IO.Compression.FileSystem.dll')
if ($Embutir) { $opcoes += "/resource:$Embutir,hermit.zip" }
if ($Comparador) { $opcoes += '/define:COMPARADOR' }

& $csc @opcoes "$PSScriptRoot\Hermit.cs"

if ($LASTEXITCODE -eq 0) { Write-Host "Gerado: $Saida" -ForegroundColor Green }
exit $LASTEXITCODE
