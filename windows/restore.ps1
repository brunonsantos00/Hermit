<#
    HERMIT - RESTORE THE BACKUP ON THE NEW COMPUTER
    ------------------------------------------------------------------------------
    Usage: connect the backup disk to the new computer and double-click "2-RESTORE-BACKUP.bat".
    Language: -Idioma pt | en (default: the one chosen in the panel, or the Windows language)
#>
param([string]$Idioma)

. (Join-Path $PSScriptRoot 'language.ps1')
$script:idioma = Get-Idioma $Idioma

# ---------- Run as administrator ----------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Idioma $script:idioma"
    } catch {
        Write-Host ''
        Write-Host (L '  [X] É preciso clicar em "SIM" na janela de permissão do Windows.' '  [X] You need to click "YES" on the Windows permission prompt.') -ForegroundColor Red
        Write-Host (L '      Rode o .bat de novo e aceite.' '      Run the .bat again and accept it.') -ForegroundColor Red
        Read-Host (L '  Pressione ENTER para fechar' '  Press ENTER to close') | Out-Null
    }
    exit
}

# Log of everything shown on screen (for troubleshooting)
$script:transcript = Join-Path $PSScriptRoot ("last-run-" + [IO.Path]::GetFileNameWithoutExtension($PSCommandPath) + ".txt")
try { Start-Transcript -Path $script:transcript -Force | Out-Null } catch {}

# On any serious error, show it and do NOT close the window
trap {
    Write-Host ''
    Write-Host "  [X] $(L 'ERRO' 'ERROR'): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      $(L 'Linha' 'Line') $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    Write-Host "      $(L 'Registro salvo em' 'Log saved to'): $script:transcript" -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    Read-Host (L '  Pressione ENTER para fechar' '  Press ENTER to close') | Out-Null
    exit 1
}

$ErrorActionPreference = 'Continue'
$Host.UI.RawUI.WindowTitle = (L 'Restaurar backup' 'Restore backup')

function Titulo([string]$t) { Write-Host ''; Write-Host ('=' * 70) -ForegroundColor Cyan; Write-Host "  $t" -ForegroundColor Cyan; Write-Host ('=' * 70) -ForegroundColor Cyan }
function Ok([string]$t)     { Write-Host "  [OK] $t" -ForegroundColor Green }
function Aviso([string]$t)  { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Erro([string]$t)   { Write-Host "  [X]  $t" -ForegroundColor Red }
function Msg([string]$t)    { Write-Host "  $t" }
function Perguntar([string]$t) {
    $sn = L '(S/N)' '(Y/N)'
    do { $r = (Read-Host "  $t $sn").Trim().ToUpper() } until ((Eh-Sim $r) -or (Eh-Nao $r))
    return (Eh-Sim $r)
}
function Escolher([string]$titulo, [object[]]$itens) {
    Msg $titulo
    for ($i = 0; $i -lt $itens.Count; $i++) { Msg ("   [{0}] {1}" -f ($i + 1), $itens[$i]) }
    do { $n = (Read-Host "  $(L 'Número' 'Number')").Trim() -as [int] } until ($n -ge 1 -and $n -le $itens.Count)
    return ($n - 1)
}
function Sair { Write-Host ''; try { Stop-Transcript | Out-Null } catch {}; Read-Host (L '  Pressione ENTER para fechar' '  Press ENTER to close') | Out-Null; exit }

Add-Type -Name Energia -Namespace Win32 -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
[Win32.Energia]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null

$script:arquivoLog = "$env:SystemRoot\Temp\restore-backup-log.txt"

function Copiar {
    param([string]$Origem, [string]$Destino, [string[]]$ExcluirPastas = @(), [switch]$NaoSobrescreverMaisNovos)
    if (-not (Test-Path -LiteralPath $Origem)) { return }
    Write-Host "  -> $Destino" -ForegroundColor DarkCyan
    $a = @($Origem, $Destino, '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/XJ', '/MT:16', '/B', '/NP', '/NDL', "/UNILOG+:$script:arquivoLog", '/TEE')
    if ($NaoSobrescreverMaisNovos) { $a += '/XO' }
    if ($ExcluirPastas.Count) { $a += '/XD'; $a += $ExcluirPastas }
    & robocopy.exe @a | Out-Host
    if ($LASTEXITCODE -ge 8) { Aviso (L "Alguns arquivos não foram copiados para '$Destino' (log: $script:arquivoLog)" "Some files were not copied to '$Destino' (log: $script:arquivoLog)") }
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
# Name without version/architecture, to match "7-Zip 23.01 (x64)" with "7-Zip 24.08 (x64)"
function Normalizar([string]$n) { (($n -replace '\(.*?\)', '' -replace 'v?\d+(\.\d+)+', '' -replace '\s+', ' ').Trim()).ToLower() }

# =====================================================================
Titulo (L 'RESTAURAR BACKUP' 'RESTORE BACKUP')

# Looks for backups on all connected disks
$backups = @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 } | ForEach-Object {
    foreach ($nomePasta in 'BACKUP_PC', 'BACKUP_NOTEBOOK') {
        $b = "$($_.DeviceID)\$nomePasta"
        if (Test-Path -LiteralPath $b) { Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue }
    }
} | Sort-Object LastWriteTime -Descending)
if (-not $backups.Count) { Erro (L 'Nenhum backup encontrado. Conecte o disco que tem a pasta BACKUP_PC e rode de novo.' 'No backup found. Connect the disk that has the BACKUP_PC folder and run again.'); Sair }
if ($backups.Count -eq 1) { $bk = $backups[0].FullName }
else { $bk = $backups[(Escolher (L 'Qual backup restaurar?' 'Which backup do you want to restore?') ($backups | ForEach-Object FullName))].FullName }
$discoHD = Split-Path -Qualifier $bk
Ok "Backup: $bk"

# Backup made on Linux: programs and settings do not work on Windows
$origem = "$bk\00_Info\origem.txt"
if ((Test-Path -LiteralPath $origem) -and ((Get-Content -LiteralPath $origem -TotalCount 1) -match 'linux')) {
    Erro (L 'Este backup foi feito em um computador com LINUX.' 'This backup was made on a LINUX computer.')
    Msg  (L 'Programas e configurações do Linux não funcionam no Windows, então não é possível restaurar por aqui.' 'Linux programs and settings do not work on Windows, so it cannot be restored here.')
    Msg  (L 'Use o script linux/restore.sh em um computador com Linux,' 'Use the linux/restore.sh script on a Linux computer,')
    Msg  (L "ou copie os seus arquivos manualmente de: $bk\02_Usuarios\<usuário>\Home" "or copy your files manually from: $bk\02_Usuarios\<user>\Home")
    Sair
}
if (Test-Path "$bk\00_Info\sistema.txt") { Get-Content "$bk\00_Info\sistema.txt" | Select-Object -First 6 | ForEach-Object { Msg "   $_" } }

# ---------- Check if it fits on this computer ----------
Msg (L 'Calculando o tamanho do backup...' 'Calculating the backup size...')
$falso = Join-Path $env:TEMP ('medir_' + [guid]::NewGuid().ToString('N'))
$saida = & robocopy.exe $bk $falso /E /L /BYTES /NFL /NDL /NJH /R:0 /W:0
$tamBk = [int64]0
$linha = $saida | Where-Object { $_ -match '^\s*Bytes\s*:\s*\d+' } | Select-Object -Last 1
if ($linha -match 'Bytes\s*:\s*(\d+)') { $tamBk = [int64]$Matches[1] }
$livreSis = [int64](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
$necessario = [int64]($tamBk * 1.05) + 5GB    # margin + room for the programs that will be installed
Msg ('{0} : {1:N1} GB' -f (L 'Tamanho do backup' 'Backup size      '), ($tamBk / 1GB))
Msg ('{0} {1} : {2:N1} GB' -f (L 'Livre no disco' 'Free on disk  '), $env:SystemDrive, ($livreSis / 1GB))
if ($livreSis -ge $necessario) {
    Ok (L 'Tem espaço suficiente.' 'There is enough space.')
} else {
    Erro ((L 'Pode NÃO caber: faltam cerca de {0:N1} GB no disco {1}.' 'It may NOT fit: about {0:N1} GB missing on disk {1}.') -f (($necessario - $livreSis) / 1GB), $env:SystemDrive)
    Msg (L 'Dica: restaure por partes pelo menu, ou mande os "outros discos" para outro disco.' 'Tip: restore in parts using the menu, or send the "other disks" to another disk.')
    if (-not (Perguntar (L 'Continuar mesmo assim?' 'Continue anyway?'))) { Sair }
}

# ---------- User selection (from -> to) ----------
$script:usuarioBk = $null
$script:alvo = $null
function Selecionar-Usuario {
    if ($script:usuarioBk) { return $true }
    $usuarios = @(Get-ChildItem -LiteralPath "$bk\02_Usuarios" -Directory -ErrorAction SilentlyContinue)
    if (-not $usuarios.Count) { Aviso (L 'Não há usuários neste backup.' 'There are no users in this backup.'); return $false }
    if ($usuarios.Count -eq 1) { $script:usuarioBk = $usuarios[0].FullName }
    else { $script:usuarioBk = $usuarios[(Escolher (L 'Restaurar os arquivos de qual usuário do computador antigo?' 'Restore the files of which user from the old computer?') ($usuarios | ForEach-Object Name))].FullName }
    $script:alvo = $env:USERPROFILE
    if (-not (Perguntar (L "Restaurar '$(Split-Path $script:usuarioBk -Leaf)' para '$script:alvo'?" "Restore '$(Split-Path $script:usuarioBk -Leaf)' to '$script:alvo'?"))) {
        $script:alvo = (Read-Host (L '  Digite a pasta do usuário de destino (ex: C:\Users\Fulano)' '  Type the destination user folder (e.g. C:\Users\John)')).Trim().Trim('"')
        if (-not (Test-Path -LiteralPath $script:alvo)) { Erro (L 'Pasta não existe.' 'Folder does not exist.'); $script:usuarioBk = $null; return $false }
    }
    return $true
}

# ---------- Steps ----------
function Restaurar-WiFi {
    Titulo (L 'Redes Wi-Fi' 'Wi-Fi networks')
    $xmls = @(Get-ChildItem "$bk\03_WiFi\*.xml" -ErrorAction SilentlyContinue)
    if (-not $xmls.Count) { Msg (L 'Nenhuma rede no backup.' 'No networks in the backup.'); return }
    $i = 0
    foreach ($x in $xmls) {
        $tmp = "$env:SystemRoot\Temp\wifi_$i.xml"; $i++
        Copy-Item -LiteralPath $x.FullName $tmp -Force
        & netsh.exe wlan add profile filename="$tmp" user=all | Out-Host
        Remove-Item $tmp -Force
    }
    Ok (L "$($xmls.Count) redes Wi-Fi adicionadas." "$($xmls.Count) Wi-Fi networks added.")
}

function Restaurar-Programas {
    Titulo (L 'Reinstalar programas' 'Reinstall programs')
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Erro (L 'winget não encontrado. Atualize o "Instalador de Aplicativo" na Microsoft Store e rode de novo.' 'winget not found. Update "App Installer" in the Microsoft Store and run again.')
        Start-Process 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1'
        return
    }
    $json = "$bk\01_Programas\programas-winget.json"
    if (Test-Path $json) {
        Aviso (L 'Isso precisa de internet e pode demorar. Algumas janelas de instalação podem aparecer.' 'This needs internet and may take a while. Some installer windows may appear.')
        & winget.exe import -i $json --accept-package-agreements --accept-source-agreements --ignore-unavailable --ignore-versions | Out-Host
        Ok (L 'Instalação automática finalizada.' 'Automatic installation finished.')
    } else { Aviso (L 'Este backup não tem lista do winget.' 'This backup has no winget list.') }

    # Compares with the full list from the old computer
    $csv = "$bk\01_Programas\programas-instalados.csv"
    if (Test-Path $csv) {
        $atuais = @(Get-ProgramasInstalados | ForEach-Object { Normalizar $_.DisplayName })
        $ruido = 'Microsoft Visual C\+\+|\.NET|Windows SDK|Update for|\(KB\d+\)|Runtime|Redistributable|Driver|Microsoft Edge WebView'
        $faltando = @(Import-Csv $csv | Where-Object { $_.DisplayName -notmatch $ruido -and $atuais -notcontains (Normalizar $_.DisplayName) })
        if ($faltando.Count) {
            $arq = Join-Path ([Environment]::GetFolderPath('Desktop')) (L 'PROGRAMAS QUE FALTAM INSTALAR.txt' 'PROGRAMS TO INSTALL MANUALLY.txt')
            @((L 'Estes programas estavam no computador antigo e não foram instalados automaticamente.' 'These programs were on the old computer and were not installed automatically.'),
              (L 'Baixe e instale manualmente os que você ainda usa:' 'Download and install the ones you still use:'), '') +
              ($faltando | ForEach-Object { '- {0}   ({1})' -f $_.DisplayName, $_.Publisher }) | Out-File $arq -Encoding utf8
            Aviso (L "$($faltando.Count) programas precisam ser instalados manualmente. Lista salva na Área de Trabalho." "$($faltando.Count) programs need to be installed manually. List saved on the Desktop.")
            Start-Process notepad.exe "`"$arq`""
        } else { Ok (L 'Todos os programas da lista parecem instalados.' 'All programs on the list seem to be installed.') }
    }
}

function Restaurar-Arquivos {
    Titulo (L 'Arquivos do usuário' 'User files')
    if (-not (Selecionar-Usuario)) { return }
    $perfilBk = "$script:usuarioBk\Perfil"
    if (-not (Test-Path -LiteralPath $perfilBk)) { Aviso (L 'Sem arquivos de perfil no backup.' 'No profile files in the backup.'); return }

    # Known folders go to their real location on the new computer (it may be inside OneDrive)
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

    # Old OneDrive folders go to a separate folder (so the new OneDrive is not messed up)
    $pastaOneDrive = L 'OneDrive do computador antigo' 'OneDrive from the old computer'
    foreach ($od in @(Get-ChildItem -LiteralPath $perfilBk -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue)) {
        Copiar $od.FullName (Join-Path $script:alvo "$pastaOneDrive\$($od.Name)") -NaoSobrescreverMaisNovos
        $excluir += $od.FullName
        Aviso (L "Arquivos do OneDrive antigo ficaram em '$script:alvo\$pastaOneDrive' (os da nuvem voltam ao entrar no OneDrive)." "Old OneDrive files were placed in '$script:alvo\$pastaOneDrive' (cloud files come back when you sign in to OneDrive).")
    }

    # Everything else in the user folder
    Copiar $perfilBk $script:alvo -ExcluirPastas $excluir -NaoSobrescreverMaisNovos
    Ok (L 'Arquivos restaurados.' 'Files restored.')
}

function Restaurar-AppData {
    Titulo (L 'Configurações dos programas (AppData)' 'Program settings (AppData)')
    if (-not (Selecionar-Usuario)) { return }
    Aviso (L 'Faça isto DEPOIS de reinstalar os programas. Isso substitui as configurações atuais deles.' 'Do this AFTER reinstalling the programs. It replaces their current settings.')
    Aviso (L 'Inclui favoritos/extensões/histórico dos navegadores. Senhas salvas no navegador NÃO funcionam' 'Includes browser bookmarks/extensions/history. Passwords saved in the browser do NOT work')
    Aviso (L 'em outro PC (o Windows criptografa) - para isso entre na sua conta Google/Microsoft no navegador.' 'on another PC (Windows encrypts them) - sign in to your Google/Microsoft account in the browser instead.')
    if (-not (Perguntar (L 'Restaurar configurações agora?' 'Restore settings now?'))) { return }

    $abertos = @(Get-Process chrome, msedge, brave, vivaldi, firefox, opera, outlook, discord, spotify, code -ErrorAction SilentlyContinue)
    if ($abertos.Count) {
        Aviso ((L 'Programas abertos: ' 'Open programs: ') + (($abertos | Select-Object -ExpandProperty Name -Unique) -join ', '))
        if (Perguntar (L 'Fechar esses programas agora?' 'Close these programs now?')) { $abertos | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
    }
    Copiar "$script:usuarioBk\AppData\Roaming" "$script:alvo\AppData\Roaming"
    Copiar "$script:usuarioBk\AppData\Local"   "$script:alvo\AppData\Local"
    Ok (L 'Configurações restauradas. Reinicie o computador depois.' 'Settings restored. Restart the computer afterwards.')
}

function Restaurar-OutrasPastas {
    Titulo (L 'Outras pastas e discos' 'Other folders and disks')
    $grupos = @(Get-ChildItem -LiteralPath "$bk\04_OutrasPastas" -Directory -ErrorAction SilentlyContinue)
    if (-not $grupos.Count) { Msg (L 'Nada para restaurar.' 'Nothing to restore.'); return }
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
        if ((Test-Path "$l`:\") -and "$l`:" -ne $discoHD -and (Perguntar (L "Restaurar o antigo disco $l`: para o disco $l`: deste computador? (N = $destPadrao)" "Restore the old disk $l`: to disk $l`: on this computer? (N = $destPadrao)"))) {
            Copiar $g.FullName "$l`:\" -NaoSobrescreverMaisNovos
        } else {
            Copiar $g.FullName $destPadrao -NaoSobrescreverMaisNovos
        }
    }
    Ok (L 'Outras pastas restauradas.' 'Other folders restored.')
}

# ---------- Backup 2.0: program folders ----------
$script:temProgramas = Test-Path -LiteralPath "$bk\05_Programas"

# Copies a program folder. If it already exists here, its files are REPLACED by the ones from the backup.
function Copiar-Programa([string]$origem, [string]$destino) {
    $nome = Split-Path $destino -Leaf
    if (Test-Path -LiteralPath $destino) {
        # Files in use cannot be replaced: close the program first
        $abertos = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($destino.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) })
        if ($abertos.Count) {
            Aviso ((L '{0} está aberto ({1}).' '{0} is open ({1}).') -f $nome, (($abertos | Select-Object -ExpandProperty Name -Unique) -join ', '))
            if (Perguntar (L 'Fechar para poder substituir?' 'Close it so it can be replaced?')) { $abertos | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
            else { Aviso ((L '{0} pulado.' '{0} skipped.') -f $nome); $script:pulados++; return }
        }
        Write-Host "  [$(L 'substituindo' 'replacing')] $nome" -ForegroundColor Yellow
        $script:substituidos++
    } else {
        Write-Host "  [$(L 'novo' 'new')] $nome" -ForegroundColor Green
        $script:novos++
    }
    # /IS /IT: rewrites even files that look identical, so it ends up exactly like the backup
    $a = @($origem, $destino, '/E', '/IS', '/IT', '/XJ', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/B', '/NP', '/NFL', '/NDL', '/NJH', '/NJS', "/UNILOG+:$script:arquivoLog")
    & robocopy.exe @a | Out-Null
    if ($LASTEXITCODE -ge 8) { Aviso ((L 'Alguns arquivos de {0} não foram copiados (log: {1}).' 'Some files of {0} were not copied (log: {1}).') -f $nome, $script:arquivoLog) }
}

function Restaurar-ProgramasCopiados {
    Titulo (L 'Programas copiados (backup 2.0)' 'Copied programs (backup 2.0)')
    $base = "$bk\05_Programas"
    if (-not $script:temProgramas) { Msg (L 'Este backup não tem pastas de programas (foi feito com o backup normal).' 'This backup has no program folders (it was made with the normal backup).'); return }
    Aviso (L 'As pastas dos programas serão colocadas de volta. Se um programa já existir neste computador, os arquivos dele serão SUBSTITUÍDOS pelos do backup.' 'Program folders will be put back. If a program already exists on this computer, its files will be REPLACED by the ones from the backup.')
    Aviso (L 'Programas que dependem de serviços, drivers ou ativação (Office, Adobe, antivírus...) podem não abrir: nesse caso use a opção [3] Reinstalar programas.' 'Programs that depend on services, drivers or activation (Office, Adobe, antivirus...) may not open: in that case use option [3] Reinstall programs.')
    if (-not (Perguntar (L 'Continuar?' 'Continue?'))) { return }

    $script:novos = 0; $script:substituidos = 0; $script:pulados = 0
    foreach ($par in @(@('ProgramFiles', $env:ProgramFiles), @('ProgramFilesX86', ${env:ProgramFiles(x86)}), @('ProgramData', $env:ProgramData))) {
        $orig = Join-Path $base $par[0]
        if (-not $par[1] -or -not (Test-Path -LiteralPath $orig)) { continue }
        foreach ($prog in @(Get-ChildItem -LiteralPath $orig -Directory)) { Copiar-Programa $prog.FullName (Join-Path $par[1] $prog.Name) }
    }

    # Programs installed only for the user (AppData\Local\Programs)
    $porUsuario = @(Get-ChildItem -LiteralPath $base -Directory -Filter 'Usuario_*' -ErrorAction SilentlyContinue)
    if ($porUsuario.Count -and (Selecionar-Usuario)) {
        $meu = $porUsuario | Where-Object { $_.Name -eq "Usuario_$(Split-Path $script:usuarioBk -Leaf)" } | Select-Object -First 1
        if (-not $meu -and $porUsuario.Count -eq 1) { $meu = $porUsuario[0] }
        if ($meu) { foreach ($prog in @(Get-ChildItem -LiteralPath $meu.FullName -Directory)) { Copiar-Programa $prog.FullName (Join-Path $script:alvo "AppData\Local\Programs\$($prog.Name)") } }
    }

    # Start Menu and public Desktop shortcuts
    Copiar "$base\MenuIniciar" "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    Copiar "$base\AreaDeTrabalhoPublica" "$env:PUBLIC\Desktop"

    Ok ((L 'Programas: {0} novos, {1} substituídos, {2} pulados.' 'Programs: {0} new, {1} replaced, {2} skipped.') -f $script:novos, $script:substituidos, $script:pulados)
    Msg (L 'Se algum programa não abrir, reinstale ele pela opção [3] (winget).' 'If a program does not open, reinstall it with option [3] (winget).')
}

# ---------- Menu ----------
while ($true) {
    Titulo (L 'O QUE VOCÊ QUER FAZER?' 'WHAT DO YOU WANT TO DO?')
    Msg (L '[1] TUDO (recomendado) - Wi-Fi, programas, arquivos, outras pastas e configurações' '[1] EVERYTHING (recommended) - Wi-Fi, programs, files, other folders and settings')
    Msg (L '[2] Só redes Wi-Fi' '[2] Wi-Fi networks only')
    Msg (L '[3] Só reinstalar programas' '[3] Reinstall programs only')
    Msg (L '[4] Só arquivos do usuário (Área de Trabalho, Documentos, Fotos...)' '[4] User files only (Desktop, Documents, Pictures...)')
    Msg (L '[5] Só outras pastas / discos' '[5] Other folders / disks only')
    Msg (L '[6] Só configurações dos programas (AppData)' '[6] Program settings only (AppData)')
    if ($script:temProgramas) { Msg (L '[7] Só os programas copiados (backup 2.0, substitui os que já existem)' '[7] Copied programs only (backup 2.0, replaces existing ones)') }
    Msg (L '[0] Sair' '[0] Exit')
    switch ((Read-Host "  $(L 'Opção' 'Option')").Trim()) {
        '1' { Restaurar-WiFi
              # Backup 2.0: puts the program folders back instead of reinstalling
              if ($script:temProgramas) { Restaurar-ProgramasCopiados } else { Restaurar-Programas }
              Restaurar-Arquivos; Restaurar-OutrasPastas; Restaurar-AppData
              Titulo (L 'TUDO PRONTO!' 'ALL DONE!'); Msg "Log: $script:arquivoLog"; Msg (L 'Reinicie o computador para finalizar.' 'Restart the computer to finish.') }
        '2' { Restaurar-WiFi }
        '3' { Restaurar-Programas }
        '4' { Restaurar-Arquivos }
        '5' { Restaurar-OutrasPastas }
        '6' { Restaurar-AppData }
        '7' { Restaurar-ProgramasCopiados }
        '0' { [Win32.Energia]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null; exit }
    }
}
