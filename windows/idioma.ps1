<#
    Idioma (português / inglês) usado pelo painel e pelos scripts.
    Uso:  . (Join-Path $PSScriptRoot 'idioma.ps1')
          $script:idioma = Get-Idioma $Idioma
          Msg (L 'Olá' 'Hello')
#>

$script:arquivoIdioma = Join-Path $env:LOCALAPPDATA 'BackupMigracao\idioma.txt'

# Ordem: parâmetro -Idioma > variável BM_IDIOMA > escolha salva no painel > idioma do Windows
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

# Escolhe o texto do idioma atual
function L([string]$pt, [string]$en) { if ($script:idioma -eq 'en') { return $en } return $pt }

# Resposta de sim/não nos dois idiomas
function Eh-Sim([string]$r) { return ($r -eq 'S' -or $r -eq 'Y') }
function Eh-Nao([string]$r) { return ($r -eq 'N') }
