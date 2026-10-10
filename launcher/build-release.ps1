<#
    Builds the Release files in the dist\ folder:
      Hermit-v<version>.zip   full project (Windows + Linux), to extract on the external drive
      Hermit-v<version>.exe   portable Windows version: a single file with the project embedded
      SHA256SUMS.txt          checksums
    Uses the latest commit (HEAD), so commit before running it.
#>
param([string]$Versao = '2.1')

$raiz = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $raiz 'dist'
$git = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = "$env:ProgramFiles\Git\cmd\git.exe" }
if (-not (Test-Path $git)) { Write-Host 'git não encontrado.' -ForegroundColor Red; exit 1 }

New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist "Hermit-v$Versao.zip"
$embutido = Join-Path $dist '_embutido.zip'
$exe = Join-Path $dist "Hermit-v$Versao.exe"
Remove-Item $zip, $embutido, $exe -ErrorAction SilentlyContinue

# .zip for download (with a Hermit-v<version>\ folder inside) and .zip to embed in the .exe (no folder)
& $git -C $raiz archive --format=zip --prefix="Hermit-v$Versao/" -o $zip HEAD
& $git -C $raiz archive --format=zip -o $embutido HEAD
if (-not (Test-Path $zip) -or -not (Test-Path $embutido)) { Write-Host 'Falha ao gerar o .zip.' -ForegroundColor Red; exit 1 }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build.ps1') -Saida $exe -Embutir $embutido
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Remove-Item $embutido

# LF line endings, so Linux "sha256sum -c" can read it
$somas = Get-ChildItem $zip, $exe | ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name }
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'), (($somas -join "`n") + "`n"), (New-Object System.Text.ASCIIEncoding))

Write-Host ''
Get-ChildItem $dist | ForEach-Object { Write-Host ('  {0,-22} {1,8:N0} KB' -f $_.Name, ($_.Length / 1KB)) }
Write-Host "Arquivos da Release em: $dist" -ForegroundColor Green
