<#
    RESTAURAR O BACKUP NO COMPUTADOR NOVO
    -----------------------------------
    Como usar: ligue o disco do backup no computador novo e dê dois cliques em "2-RESTAURAR-BACKUP.bat".
#>

# ---------- Rodar como administrador ----------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } catch {
        Write-Host ''
        Write-Host '  [X] É preciso clicar em "SIM" na janela de permissão do Windows.' -ForegroundColor Red
        Write-Host '      Rode o .bat de novo e aceite.' -ForegroundColor Red
        Read-Host '  Pressione ENTER para fechar' | Out-Null
    }
    exit
}

# Registro de tudo que aparece na tela (para descobrir problemas)
$script:transcript = Join-Path $PSScriptRoot ("ultima-execucao-" + [IO.Path]::GetFileNameWithoutExtension($PSCommandPath) + ".txt")
try { Start-Transcript -Path $script:transcript -Force | Out-Null } catch {}

# Se acontecer qualquer erro grave, mostra na tela e NÃO fecha a janela
trap {
    Write-Host ''
    Write-Host "  [X] ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      Linha $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    Write-Host "      Registro salvo em: $script:transcript" -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    Read-Host '  Pressione ENTER para fechar' | Out-Null
    exit 1
}

$ErrorActionPreference = 'Continue'
$Host.UI.RawUI.WindowTitle = 'Restaurar backup'

function Titulo([string]$t) { Write-Host ''; Write-Host ('=' * 70) -ForegroundColor Cyan; Write-Host "  $t" -ForegroundColor Cyan; Write-Host ('=' * 70) -ForegroundColor Cyan }
function Ok([string]$t)     { Write-Host "  [OK] $t" -ForegroundColor Green }
function Aviso([string]$t)  { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Erro([string]$t)   { Write-Host "  [X]  $t" -ForegroundColor Red }
function Msg([string]$t)    { Write-Host "  $t" }
function Perguntar([string]$t) {
    do { $r = (Read-Host "  $t (S/N)").Trim().ToUpper() } until ($r -eq 'S' -or $r -eq 'N')
    return ($r -eq 'S')
}
function Escolher([string]$titulo, [object[]]$itens) {
    Msg $titulo
    for ($i = 0; $i -lt $itens.Count; $i++) { Msg ("   [{0}] {1}" -f ($i + 1), $itens[$i]) }
    do { $n = (Read-Host '  Número').Trim() -as [int] } until ($n -ge 1 -and $n -le $itens.Count)
    return ($n - 1)
}
function Sair { Write-Host ''; try { Stop-Transcript | Out-Null } catch {}; Read-Host '  Pressione ENTER para fechar' | Out-Null; exit }

Add-Type -Name Energia -Namespace Win32 -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
[Win32.Energia]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null

$script:arquivoLog = "$env:SystemRoot\Temp\restaurar-backup-log.txt"

function Copiar {
    param([string]$Origem, [string]$Destino, [string[]]$ExcluirPastas = @(), [switch]$NaoSobrescreverMaisNovos)
    if (-not (Test-Path -LiteralPath $Origem)) { return }
    Write-Host "  -> $Destino" -ForegroundColor DarkCyan
    $a = @($Origem, $Destino, '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/XJ', '/MT:16', '/B', '/NP', '/NDL', "/UNILOG+:$script:arquivoLog", '/TEE')
    if ($NaoSobrescreverMaisNovos) { $a += '/XO' }
    if ($ExcluirPastas.Count) { $a += '/XD'; $a += $ExcluirPastas }
    & robocopy.exe @a | Out-Host
    if ($LASTEXITCODE -ge 8) { Aviso "Alguns arquivos não foram copiados para '$Destino' (log: $script:arquivoLog)" }
}

function Get-ProgramasInstalados {
    $chaves = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $chaves -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and -not $_.ParentKeyName } |
        Select-Object DisplayName, DisplayVersion, Publisher |
        Sort-Object DisplayName -Unique
}
# Nome sem versão/arquitetura, para comparar "7-Zip 23.01 (x64)" com "7-Zip 24.08 (x64)"
function Normalizar([string]$n) { (($n -replace '\(.*?\)', '' -replace 'v?\d+(\.\d+)+', '' -replace '\s+', ' ').Trim()).ToLower() }

# =====================================================================
Titulo 'RESTAURAR BACKUP'

# Procura backups em todos os discos conectados
$backups = @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 } | ForEach-Object {
    foreach ($nomePasta in 'BACKUP_PC', 'BACKUP_NOTEBOOK') {
        $b = "$($_.DeviceID)\$nomePasta"
        if (Test-Path -LiteralPath $b) { Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue }
    }
} | Sort-Object LastWriteTime -Descending)
if (-not $backups.Count) { Erro 'Nenhum backup encontrado. Conecte o disco que tem a pasta BACKUP_PC e rode de novo.'; Sair }
if ($backups.Count -eq 1) { $bk = $backups[0].FullName }
else { $bk = $backups[(Escolher 'Qual backup restaurar?' ($backups | ForEach-Object FullName))].FullName }
$discoHD = Split-Path -Qualifier $bk
Ok "Backup: $bk"

# Backup feito no Linux: programas e configurações não servem no Windows
$origem = "$bk\00_Info\origem.txt"
if ((Test-Path -LiteralPath $origem) -and ((Get-Content -LiteralPath $origem -TotalCount 1) -match 'linux')) {
    Erro 'Este backup foi feito em um computador com LINUX.'
    Msg  'Programas e configurações do Linux não funcionam no Windows, então não é possível restaurar por aqui.'
    Msg  'Use o script linux/restaurar.sh em um computador com Linux,'
    Msg  "ou copie os seus arquivos manualmente de: $bk\02_Usuarios\<usuário>\Home"
    Sair
}
if (Test-Path "$bk\00_Info\sistema.txt") { Get-Content "$bk\00_Info\sistema.txt" | Select-Object -First 6 | ForEach-Object { Msg "   $_" } }

# ---------- Verificar se cabe neste computador ----------
Msg 'Calculando o tamanho do backup...'
$falso = Join-Path $env:TEMP ('medir_' + [guid]::NewGuid().ToString('N'))
$saida = & robocopy.exe $bk $falso /E /L /BYTES /NFL /NDL /NJH /R:0 /W:0
$tamBk = [int64]0
$linha = $saida | Where-Object { $_ -match '^\s*Bytes\s*:\s*\d+' } | Select-Object -Last 1
if ($linha -match 'Bytes\s*:\s*(\d+)') { $tamBk = [int64]$Matches[1] }
$livreSis = [int64](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
$necessario = [int64]($tamBk * 1.05) + 5GB    # margem + espaço para os programas que vão ser instalados
Msg ('Tamanho do backup : {0:N1} GB' -f ($tamBk / 1GB))
Msg ('Livre no disco {0} : {1:N1} GB' -f $env:SystemDrive, ($livreSis / 1GB))
if ($livreSis -ge $necessario) {
    Ok 'Tem espaço suficiente.'
} else {
    Erro ('Pode NÃO caber: faltam cerca de {0:N1} GB no disco {1}.' -f (($necessario - $livreSis) / 1GB), $env:SystemDrive)
    Msg 'Dica: restaure por partes pelo menu, ou mande os "outros discos" para outro disco.'
    if (-not (Perguntar 'Continuar mesmo assim?')) { Sair }
}

# ---------- Escolha do usuário (de onde -> para onde) ----------
$script:usuarioBk = $null
$script:alvo = $null
function Selecionar-Usuario {
    if ($script:usuarioBk) { return $true }
    $usuarios = @(Get-ChildItem -LiteralPath "$bk\02_Usuarios" -Directory -ErrorAction SilentlyContinue)
    if (-not $usuarios.Count) { Aviso 'Não há usuários neste backup.'; return $false }
    if ($usuarios.Count -eq 1) { $script:usuarioBk = $usuarios[0].FullName }
    else { $script:usuarioBk = $usuarios[(Escolher 'Restaurar os arquivos de qual usuário do computador antigo?' ($usuarios | ForEach-Object Name))].FullName }
    $script:alvo = $env:USERPROFILE
    if (-not (Perguntar "Restaurar '$(Split-Path $script:usuarioBk -Leaf)' para '$script:alvo'?")) {
        $script:alvo = (Read-Host '  Digite a pasta do usuário de destino (ex: C:\Users\Fulano)').Trim().Trim('"')
        if (-not (Test-Path -LiteralPath $script:alvo)) { Erro 'Pasta não existe.'; $script:usuarioBk = $null; return $false }
    }
    return $true
}

# ---------- Etapas ----------
function Restaurar-WiFi {
    Titulo 'Redes Wi-Fi'
    $xmls = @(Get-ChildItem "$bk\03_WiFi\*.xml" -ErrorAction SilentlyContinue)
    if (-not $xmls.Count) { Msg 'Nenhuma rede no backup.'; return }
    $i = 0
    foreach ($x in $xmls) {
        $tmp = "$env:SystemRoot\Temp\wifi_$i.xml"; $i++
        Copy-Item -LiteralPath $x.FullName $tmp -Force
        & netsh.exe wlan add profile filename="$tmp" user=all | Out-Host
        Remove-Item $tmp -Force
    }
    Ok "$($xmls.Count) redes Wi-Fi adicionadas."
}

function Restaurar-Programas {
    Titulo 'Reinstalar programas'
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Erro 'winget não encontrado. Atualize o "Instalador de Aplicativo" na Microsoft Store e rode de novo.'
        Start-Process 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1'
        return
    }
    $json = "$bk\01_Programas\programas-winget.json"
    if (Test-Path $json) {
        Aviso 'Isso precisa de internet e pode demorar. Algumas janelas de instalação podem aparecer.'
        & winget.exe import -i $json --accept-package-agreements --accept-source-agreements --ignore-unavailable --ignore-versions | Out-Host
        Ok 'Instalação automática finalizada.'
    } else { Aviso 'Este backup não tem lista do winget.' }

    # Compara com a lista completa do computador antigo
    $csv = "$bk\01_Programas\programas-instalados.csv"
    if (Test-Path $csv) {
        $atuais = @(Get-ProgramasInstalados | ForEach-Object { Normalizar $_.DisplayName })
        $ruido = 'Microsoft Visual C\+\+|\.NET|Windows SDK|Update for|\(KB\d+\)|Runtime|Redistributable|Driver|Microsoft Edge WebView'
        $faltando = @(Import-Csv $csv | Where-Object { $_.DisplayName -notmatch $ruido -and $atuais -notcontains (Normalizar $_.DisplayName) })
        if ($faltando.Count) {
            $arq = Join-Path ([Environment]::GetFolderPath('Desktop')) 'PROGRAMAS QUE FALTAM INSTALAR.txt'
            @('Estes programas estavam no computador antigo e não foram instalados automaticamente.',
              'Baixe e instale manualmente os que você ainda usa:', '') +
              ($faltando | ForEach-Object { '- {0}   ({1})' -f $_.DisplayName, $_.Publisher }) | Out-File $arq -Encoding utf8
            Aviso "$($faltando.Count) programas precisam ser instalados manualmente. Lista salva na Área de Trabalho."
            Start-Process notepad.exe "`"$arq`""
        } else { Ok 'Todos os programas da lista parecem instalados.' }
    }
}

function Restaurar-Arquivos {
    Titulo 'Arquivos do usuário'
    if (-not (Selecionar-Usuario)) { return }
    $perfilBk = "$script:usuarioBk\Perfil"
    if (-not (Test-Path -LiteralPath $perfilBk)) { Aviso 'Sem arquivos de perfil no backup.'; return }

    # Pastas conhecidas vão para o local real delas no computador novo (pode ser dentro do OneDrive)
    $mapa = [ordered]@{ 'Desktop' = 'Desktop'; 'Documents' = 'Personal'; 'Downloads' = '{374DE290-123F-4565-9164-39C4925E467B}'
                        'Pictures' = 'My Pictures'; 'Music' = 'My Music'; 'Videos' = 'My Video'; 'Favorites' = 'Favorites' }
    $usf = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue
    $excluir = @()
    foreach ($k in $mapa.Keys) {
        $orig = Join-Path $perfilBk $k
        if (-not (Test-Path -LiteralPath $orig)) { continue }
        $v = $usf.($mapa[$k])
        $dest = if ($script:alvo -eq $env:USERPROFILE -and $v) { [Environment]::ExpandEnvironmentVariables($v) } else { Join-Path $script:alvo $k }
        Copiar $orig $dest -NaoSobrescreverMaisNovos
        $excluir += $orig
    }

    # Pastas do OneDrive antigo vão para uma pasta separada (para não bagunçar o OneDrive novo)
    foreach ($od in @(Get-ChildItem -LiteralPath $perfilBk -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue)) {
        Copiar $od.FullName (Join-Path $script:alvo "OneDrive do computador antigo\$($od.Name)") -NaoSobrescreverMaisNovos
        $excluir += $od.FullName
        Aviso "Arquivos do OneDrive antigo ficaram em '$script:alvo\OneDrive do computador antigo' (os da nuvem voltam ao entrar no OneDrive)."
    }

    # Todo o resto da pasta do usuário
    Copiar $perfilBk $script:alvo -ExcluirPastas $excluir -NaoSobrescreverMaisNovos
    Ok 'Arquivos restaurados.'
}

function Restaurar-AppData {
    Titulo 'Configurações dos programas (AppData)'
    if (-not (Selecionar-Usuario)) { return }
    Aviso 'Faça isto DEPOIS de reinstalar os programas. Isso substitui as configurações atuais deles.'
    Aviso 'Inclui favoritos/extensões/histórico dos navegadores. Senhas salvas no navegador NÃO funcionam'
    Aviso 'em outro PC (o Windows criptografa) - para isso entre na sua conta Google/Microsoft no navegador.'
    if (-not (Perguntar 'Restaurar configurações agora?')) { return }

    $abertos = @(Get-Process chrome, msedge, brave, vivaldi, firefox, opera, outlook, discord, spotify, code -ErrorAction SilentlyContinue)
    if ($abertos.Count) {
        Aviso ('Programas abertos: ' + (($abertos | Select-Object -ExpandProperty Name -Unique) -join ', '))
        if (Perguntar 'Fechar esses programas agora?') { $abertos | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
    }
    Copiar "$script:usuarioBk\AppData\Roaming" "$script:alvo\AppData\Roaming"
    Copiar "$script:usuarioBk\AppData\Local"   "$script:alvo\AppData\Local"
    Ok 'Configurações restauradas. Reinicie o computador depois.'
}

function Restaurar-OutrasPastas {
    Titulo 'Outras pastas e discos'
    $grupos = @(Get-ChildItem -LiteralPath "$bk\04_OutrasPastas" -Directory -ErrorAction SilentlyContinue)
    if (-not $grupos.Count) { Msg 'Nada para restaurar.'; return }
    $letraSis = $env:SystemDrive.TrimEnd(':')
    foreach ($g in $grupos) {
        $l = $g.Name
        if ($l -eq $letraSis) {
            foreach ($p in @(Get-ChildItem -LiteralPath $g.FullName -Directory)) {
                Copiar $p.FullName "$env:SystemDrive\$($p.Name)" -NaoSobrescreverMaisNovos
            }
            continue
        }
        $destPadrao = "$env:SystemDrive\Restaurado_disco_$l"
        if ((Test-Path "$l`:\") -and "$l`:" -ne $discoHD -and (Perguntar "Restaurar o antigo disco $l`: para o disco $l`: deste computador? (N = $destPadrao)")) {
            Copiar $g.FullName "$l`:\" -NaoSobrescreverMaisNovos
        } else {
            Copiar $g.FullName $destPadrao -NaoSobrescreverMaisNovos
        }
    }
    Ok 'Outras pastas restauradas.'
}

# ---------- Menu ----------
while ($true) {
    Titulo 'O QUE VOCÊ QUER FAZER?'
    Msg '[1] TUDO (recomendado) - Wi-Fi, programas, arquivos, outras pastas e configurações'
    Msg '[2] Só redes Wi-Fi'
    Msg '[3] Só reinstalar programas'
    Msg '[4] Só arquivos do usuário (Área de Trabalho, Documentos, Fotos...)'
    Msg '[5] Só outras pastas / discos'
    Msg '[6] Só configurações dos programas (AppData)'
    Msg '[0] Sair'
    switch ((Read-Host '  Opção').Trim()) {
        '1' { Restaurar-WiFi; Restaurar-Programas; Restaurar-Arquivos; Restaurar-OutrasPastas; Restaurar-AppData
              Titulo 'TUDO PRONTO!'; Msg "Log: $script:arquivoLog"; Msg 'Reinicie o computador para finalizar.' }
        '2' { Restaurar-WiFi }
        '3' { Restaurar-Programas }
        '4' { Restaurar-Arquivos }
        '5' { Restaurar-OutrasPastas }
        '6' { Restaurar-AppData }
        '0' { [Win32.Energia]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null; exit }
    }
}
