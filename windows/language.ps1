<#
    Language (Portuguese / English) used by the panel and the scripts.
    Usage:  . (Join-Path $PSScriptRoot 'language.ps1')
          $script:idioma = Get-Idioma $Idioma
          Msg (L 'Olá' 'Hello')
#>

$script:arquivoIdioma = Join-Path $env:LOCALAPPDATA 'Hermit\language.txt'

# Order: -Idioma parameter > BM_IDIOMA variable > choice saved in the panel > Windows language
function Get-Idioma([string]$pedido) {
    foreach ($v in $pedido, $env:BM_IDIOMA) { if ($v -eq 'pt' -or $v -eq 'en') { return $v } }
    try {
        if (Test-Path -LiteralPath $script:arquivoIdioma) {
            $v = (Get-Content -LiteralPath $script:arquivoIdioma -TotalCount 1).Trim()
            if ($v -eq 'pt' -or $v -eq 'en') { return $v }
        }
    } catch {}
    if ((Get-UICulture).Name -like 'pt*') { return 'pt' }
    return 'en'
}

function Set-Idioma([string]$v) {
    try {
        New-Item -ItemType Directory -Force (Split-Path $script:arquivoIdioma) | Out-Null
        Set-Content -LiteralPath $script:arquivoIdioma -Value $v -Encoding ascii
    } catch {}
}

# Picks the text for the current language
function L([string]$pt, [string]$en) { if ($script:idioma -eq 'en') { return $en } return $pt }

# Yes/no answer in both languages
function Eh-Sim([string]$r) { return ($r -eq 'S' -or $r -eq 'Y') }
function Eh-Nao([string]$r) { return ($r -eq 'N') }
