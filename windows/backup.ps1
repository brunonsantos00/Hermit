<#
    HERMIT - COMPUTER BACKUP
    --------------------------------------
    Usage: copy this folder to the external drive (or another disk) and double-click "1-BACKUP.bat".
    The backup is saved to <DISK>:\BACKUP_PC\<PC-NAME>_<date>\
    Language: -Idioma pt | en (default: the one chosen in the panel, or the Windows language)
    -ComProgramas: backup 2.0, also copies the folders of installed programs ("1-BACKUP-2.0.bat")
#>
param([string]$Idioma, [switch]$ComProgramas)

. (Join-Path $PSScriptRoot 'language.ps1')
$script:idioma = Get-Idioma $Idioma

# ---------- Run as administrator ----------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Idioma $script:idioma$(if ($ComProgramas) { ' -ComProgramas' })"
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
$Host.UI.RawUI.WindowTitle = (L 'Backup do computador' 'Computer backup')

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
function Sair { Write-Host ''; try { Stop-Transcript | Out-Null } catch {}; Read-Host (L '  Pressione ENTER para fechar' '  Press ENTER to close') | Out-Null; exit }
function GB([double]$bytes) { '{0:N1} GB' -f ($bytes / 1GB) }

# Keeps the computer from sleeping during the backup
Add-Type -Name Energia -Namespace Win32 -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
[Win32.Energia]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null

$script:resumo = New-Object System.Collections.ArrayList
$script:arquivoLog = $null

# Builds the common robocopy arguments for a task
function Args-Robocopy($t, [string]$destino) {
    $a = @($t.Origem, $destino, '/E', '/XJ', '/B', '/XA:O')
    if ($t.XD.Count) { $a += '/XD'; $a += $t.XD }
    if ($t.XF.Count) { $a += '/XF'; $a += $t.XF }
    return $a
}

# Calculates how many bytes a task will copy (robocopy in "list only" mode, copies nothing)
function Medir($t) {
    if (-not (Test-Path -LiteralPath $t.Origem)) { return [int64]0 }
    $falso = Join-Path $env:TEMP ('medir_' + [guid]::NewGuid().ToString('N'))
    $a = (Args-Robocopy $t $falso) + @('/L', '/BYTES', '/NFL', '/NDL', '/NJH', '/R:0', '/W:0')
    $saida = & robocopy.exe @a
    $linha = $saida | Where-Object { $_ -match '^\s*Bytes\s*:\s*\d+' } | Select-Object -Last 1
    if ($linha -match 'Bytes\s*:\s*(\d+)') { return [int64]$Matches[1] }
    return [int64]0
}

# Actually copies a task
function Copiar($t, [string]$raizDestino) {
    if (-not (Test-Path -LiteralPath $t.Origem)) { return }
    $dest = Join-Path $raizDestino $t.Rel
    Write-Host "  -> $($t.Origem)" -ForegroundColor DarkCyan
    $a = (Args-Robocopy $t $dest) + @('/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/NP', '/NDL', "/UNILOG+:$script:arquivoLog", '/TEE')
    & robocopy.exe @a | Out-Host
    if ($t.RaizDeDisco) { & attrib.exe -s -h "$dest" | Out-Null }   # robocopy makes the folder hidden when copying a disk root
    if ($LASTEXITCODE -ge 8) {
        Aviso (L "Alguns arquivos de '$($t.Origem)' não puderam ser copiados (veja o log)." "Some files from '$($t.Origem)' could not be copied (see the log).")
        [void]$script:resumo.Add("[!]  $($t.Origem) $(L '(com erros, ver log)' '(with errors, see log)')")
    } else {
        [void]$script:resumo.Add("[OK] $($t.Origem)")
    }
}

# Finds out whether a disk has an operating system installed. Returns the system name or $null.
function Detectar-SO([string]$letra) {
    if ($letra -eq $env:SystemDrive) { return ((Get-CimInstance Win32_OperatingSystem).Caption -replace '^Microsoft ', '') }
    $kernel = "$letra\Windows\System32\ntoskrnl.exe"
    if (Test-Path -LiteralPath $kernel) {
        $v = (Get-Item -LiteralPath $kernel).VersionInfo
        if ($v.FileMajorPart -ge 10) { if ($v.FileBuildPart -ge 22000) { $n = 'Windows 11' } else { $n = 'Windows 10' } }
        elseif ($v.FileMajorPart -eq 6 -and $v.FileMinorPart -eq 3) { $n = 'Windows 8.1' }
        elseif ($v.FileMajorPart -eq 6 -and $v.FileMinorPart -eq 2) { $n = 'Windows 8' }
        elseif ($v.FileMajorPart -eq 6 -and $v.FileMinorPart -eq 1) { $n = 'Windows 7' }
        else { $n = 'Windows' }
        return "$n (build $($v.FileBuildPart))"
    }
    $osRelease = "$letra\etc\os-release"
    if (Test-Path -LiteralPath $osRelease) {
        $nome = (Get-Content -LiteralPath $osRelease -ErrorAction SilentlyContinue | Where-Object { $_ -like 'PRETTY_NAME=*' } | Select-Object -First 1)
        if ($nome) { return ($nome -replace '^PRETTY_NAME=', '').Trim('"') }
        return 'Linux'
    }
    if (Test-Path -LiteralPath "$letra\System\Library\CoreServices\SystemVersion.plist") { return 'macOS' }
    return $null
}

function Tipo-Disco($d) {
    try {
        $bus = (Get-Partition -DriveLetter $d.DeviceID.TrimEnd(':') -ErrorAction Stop | Get-Disk -ErrorAction Stop).BusType
        if ("$bus" -eq 'USB') { return (L 'USB/externo' 'USB/external') }
        return "$(L 'interno' 'internal') ($bus)"
    } catch {
        if ($d.DriveType -eq 2) { return (L 'removível' 'removable') }
        return ''
    }
}

# Lists the disks and lets the user choose where to save the backup
function Escolher-Destino([string]$padrao, [string[]]$proibidos) {
    $discos = @(Get-CimInstance Win32_LogicalDisk | Where-Object {
        ($_.DriveType -eq 2 -or $_.DriveType -eq 3) -and $_.Size -and $_.DeviceID -ne $discoSistema -and $proibidos -notcontains $_.DeviceID
    } | Sort-Object DeviceID)
    if (-not $discos.Count) { Erro (L 'Nenhum outro disco encontrado. Conecte o HD externo e rode de novo.' 'No other disk found. Connect the external drive and run again.'); Sair }

    Msg (L 'Em qual disco salvar o backup?' 'Which disk should the backup be saved to?')
    $idxPadrao = -1
    for ($i = 0; $i -lt $discos.Count; $i++) {
        $d = $discos[$i]
        $marca = ''
        if ($d.DeviceID -eq $padrao) { $idxPadrao = $i; $marca = (L '  <- onde estão os scripts' '  <- where the scripts are') }
        Msg ('   [{0}] {1}  {2,-18} {3}: {4,9} {5} {6,9}  {7,-6} {8}{9}' -f ($i + 1), $d.DeviceID, $d.VolumeName, (L 'livre' 'free'),
             (GB $d.FreeSpace), (L 'de' 'of'), (GB $d.Size), $d.FileSystem, (Tipo-Disco $d), $marca)
        $so = Detectar-SO $d.DeviceID
        if ($so) { Write-Host "         $(L 'Sistema instalado' 'Installed system'): $so" -ForegroundColor DarkYellow }
        else     { Write-Host (L '         Sem sistema operacional (bom para guardar backups)' '         No operating system (good for storing backups)') -ForegroundColor DarkGray }
    }
    $dica = if ($idxPadrao -ge 0) { " (ENTER = $($idxPadrao + 1))" } else { '' }
    do {
        $r = (Read-Host "  $(L 'Número do disco' 'Disk number')$dica").Trim()
        if (-not $r -and $idxPadrao -ge 0) { $n = $idxPadrao + 1 } else { $n = $r -as [int] }
    } until ($n -ge 1 -and $n -le $discos.Count)
    $escolhido = $discos[$n - 1]
    if ($escolhido.FileSystem -eq 'FAT32') {
        Aviso (L 'Este disco é FAT32: arquivos maiores que 4 GB NÃO cabem nele (vídeos grandes, ISOs...).' 'This disk is FAT32: files larger than 4 GB will NOT fit (large videos, ISOs...).')
        Aviso (L 'O ideal é formatar o HD em NTFS ou exFAT antes.' 'Ideally, format the drive as NTFS or exFAT first.')
    }
    return $escolhido.DeviceID
}

function Get-ProgramasInstalados {
    $chaves = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $chaves -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and -not $_.ParentKeyName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Sort-Object DisplayName -Unique
}

# Cache folders not worth copying (they are recreated automatically)
$pastasCache = 'Cache', 'Cache_Data', 'Code Cache', 'GPUCache', 'DawnCache', 'DawnGraphiteCache', 'DawnWebGPUCache',
               'GrShaderCache', 'ShaderCache', 'CachedData', 'CacheStorage', 'Crashpad', 'CrashDumps', 'Temp', 'tmp'

# AppData\Local items worth copying (browsers, fonts, notes...)
$locaisImportantes = 'Google\Chrome\User Data',
                     'Microsoft\Edge\User Data',
                     'BraveSoftware\Brave-Browser\User Data',
                     'Vivaldi\User Data',
                     'Microsoft\Windows\Fonts',
                     'Microsoft\Outlook',
                     'Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState',
                     'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'

# Root folders of C: that belong to Windows/programs (not backed up)
# Program Files folders that belong to Windows or drivers (not included in backup 2.0)
$ignorarProgramas = 'Common Files', 'Internet Explorer', 'Microsoft Update Health Tools', 'ModifiableWindowsApps', 'Windows Defender',
                    'Windows Defender Advanced Threat Protection', 'Windows Mail', 'Windows Media Player', 'Windows Multimedia Platform',
                    'Windows NT', 'Windows Photo Viewer', 'Windows Portable Devices', 'Windows Security', 'Windows Sidebar', 'WindowsApps',
                    'WindowsPowerShell', 'Reference Assemblies', 'MSBuild', 'Microsoft.NET', 'dotnet', 'Uninstall Information',
                    'PCHealthCheck', 'Microsoft OneDrive', 'Intel', 'NVIDIA Corporation', 'AMD', 'Realtek', 'Synaptics', 'ELAN',
                    'Dolby', 'Conexant', 'Waves', 'Hyper-V', 'WSL', 'Microsoft', 'Microsoft SDKs', 'Windows Kits', 'Temp',
                    'InstallShield Installation Information', 'Package Cache'

$ignorarRaiz = 'Windows', 'Windows.old', 'Program Files', 'Program Files (x86)', 'ProgramData', 'Users', 'Documents and Settings',
               '$Recycle.Bin', '$WinREAgent', '$Windows.~BT', '$Windows.~WS', '$SysReset', '$GetCurrent', '$AV_ASW',
               'System Volume Information', 'Recovery', 'PerfLogs', 'Config.Msi', 'OneDriveTemp', 'MSOCache',
               'Intel', 'AMD', 'NVIDIA', 'Drivers', 'inetpub', 'ESD', 'XboxGames', 'BACKUP_PC', 'BACKUP_NOTEBOOK', 'SCRIPTS_BACKUP'

# =====================================================================
if ($ComProgramas) { Titulo (L 'BACKUP DO COMPUTADOR 2.0 (com as pastas dos programas)' 'COMPUTER BACKUP 2.0 (with program folders)') }
else { Titulo (L 'BACKUP DO COMPUTADOR' 'COMPUTER BACKUP') }
$discoSistema = $env:SystemDrive
Msg "$(L 'Computador' 'Computer'): $env:COMPUTERNAME"
Write-Host ''

# ---------- 1. Where to save ----------
$discoDestino = Escolher-Destino (Split-Path -Qualifier $PSScriptRoot) @()
Ok (L "Backup será salvo no disco $discoDestino" "Backup will be saved to disk $discoDestino")

# ---------- 2. What to copy ----------
Titulo (L 'O QUE VAI ENTRAR NO BACKUP' 'WHAT WILL BE BACKED UP')

$perfis = @(Get-CimInstance Win32_UserProfile | Where-Object {
    -not $_.Special -and $_.LocalPath -like "$discoSistema\Users\*" -and (Test-Path -LiteralPath $_.LocalPath)
})
Msg (L 'Usuários encontrados (todos entram no backup):' 'Users found (all of them will be backed up):')
$perfis | ForEach-Object { Msg "   - $($_.LocalPath)" }

$pastasRaiz = @(Get-ChildItem "$discoSistema\" -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
    $ignorarRaiz -notcontains $_.Name -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
})
$pastasRaizEscolhidas = @()
if ($pastasRaiz.Count) {
    Write-Host ''
    Msg (L "Pastas extras na raiz do $discoSistema (fora da pasta do usuário):" "Extra folders at the root of $discoSistema (outside the user folder):")
    $pastasRaiz | ForEach-Object { Msg "   - $($_.FullName)" }
    if (Perguntar (L 'Copiar TODAS essas pastas?' 'Copy ALL of these folders?')) { $pastasRaizEscolhidas = $pastasRaiz }
    else { foreach ($p in $pastasRaiz) { if (Perguntar "   $(L 'Copiar' 'Copy') $($p.FullName)?") { $pastasRaizEscolhidas += $p } } }
}

$outrosDiscos = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.DeviceID -ne $discoSistema -and $_.DeviceID -ne $discoDestino })
$discosEscolhidos = @()
foreach ($d in $outrosDiscos) {
    Write-Host ''
    $so = Detectar-SO $d.DeviceID
    if ($so) { Aviso (L "O disco $($d.DeviceID) tem outro sistema instalado ($so). Só os arquivos dele podem ser copiados, não o sistema." "Disk $($d.DeviceID) has another system installed ($so). Only its files can be copied, not the system.") }
    else     { Msg (L "O disco $($d.DeviceID) não tem nenhum sistema operacional: só arquivos." "Disk $($d.DeviceID) has no operating system: files only.") }
    if (Perguntar ((L 'Copiar o disco {0} ({1}) inteiro? Usado: {2}' 'Copy the whole disk {0} ({1})? Used: {2}') -f $d.DeviceID, $d.VolumeName, (GB ($d.Size - $d.FreeSpace)))) { $discosEscolhidos += $d.DeviceID }
}

# ---------- Backup 2.0: program folders ----------
$programasEscolhidos = @()
if ($ComProgramas) {
    Write-Host ''
    Titulo (L 'PROGRAMAS (BACKUP 2.0)' 'PROGRAMS (BACKUP 2.0)')
    Aviso (L 'As pastas dos programas serão copiadas para serem colocadas de volta no computador novo, sem reinstalar.' 'Program folders will be copied so they can be put back on the new computer without reinstalling.')
    Aviso (L 'Programas que dependem de serviços, drivers ou ativação (Office, Adobe, antivírus...) podem não abrir assim.' 'Programs that depend on services, drivers or activation (Office, Adobe, antivirus...) may not open this way.')
    $locaisProgramas = @(@($env:ProgramFiles, 'ProgramFiles'), @(${env:ProgramFiles(x86)}, 'ProgramFilesX86'))
    foreach ($p in $perfis) { $locaisProgramas += , @((Join-Path $p.LocalPath 'AppData\Local\Programs'), "Usuario_$(Split-Path $p.LocalPath -Leaf)") }
    $encontrados = @()
    foreach ($local in $locaisProgramas) {
        if (-not $local[0] -or -not (Test-Path -LiteralPath $local[0])) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $local[0] -Directory -Force -ErrorAction SilentlyContinue)) {
            if ($ignorarProgramas -contains $d.Name -or ($d.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
            $encontrados += [pscustomobject]@{ Nome = $d.Name; Caminho = $d.FullName; Rel = "05_Programas\$($local[1])\$($d.Name)" }
        }
    }
    Msg ((L '{0} programas encontrados:' '{0} programs found:') -f $encontrados.Count)
    Msg ('   ' + (($encontrados | ForEach-Object Nome | Sort-Object -Unique) -join ', '))
    if ($encontrados.Count) {
        if (Perguntar (L 'Copiar as pastas de TODOS esses programas?' 'Copy the folders of ALL these programs?')) { $programasEscolhidos = $encontrados }
        else { foreach ($e in $encontrados) { if (Perguntar "   $(L 'Copiar' 'Copy') $($e.Caminho)?") { $programasEscolhidos += $e } } }
    }
}

# ---------- 3. Build the task list ----------
$tarefas = New-Object System.Collections.ArrayList
function Nova-Tarefa([string]$grupo, [string]$origem, [string]$rel, [string[]]$xd = @(), [string[]]$xf = @(), [switch]$raizDeDisco) {
    [void]$tarefas.Add([pscustomobject]@{ Grupo = $grupo; Origem = $origem; Rel = $rel; XD = $xd; XF = $xf; RaizDeDisco = [bool]$raizDeDisco; Bytes = [int64]0 })
}
foreach ($p in $perfis) {
    $lp = $p.LocalPath; $nome = Split-Path $lp -Leaf
    # Whole user folder (Desktop, Documents, Downloads, Pictures, Videos, Music, etc.), except AppData
    Nova-Tarefa (L "Usuário $nome - arquivos" "User $nome - files") $lp "02_Usuarios\$nome\Perfil" @("$lp\AppData") @('NTUSER.DAT*', 'ntuser.*', 'UsrClass.dat*')
    # Program settings
    Nova-Tarefa (L "Usuário $nome - configurações" "User $nome - settings") "$lp\AppData\Roaming" "02_Usuarios\$nome\AppData\Roaming" $pastasCache
    foreach ($rel in $locaisImportantes) {
        Nova-Tarefa (L "Usuário $nome - configurações" "User $nome - settings") "$lp\AppData\Local\$rel" "02_Usuarios\$nome\AppData\Local\$rel" $pastasCache @('*.ost')
    }
}
$letraSis = $discoSistema.TrimEnd(':')
foreach ($p in $pastasRaizEscolhidas) { Nova-Tarefa "$(L 'Pasta' 'Folder') $($p.FullName)" $p.FullName "04_OutrasPastas\$letraSis\$($p.Name)" }
foreach ($e in $programasEscolhidos) {
    Nova-Tarefa "$(L 'Programa' 'Program'): $($e.Nome)" $e.Caminho $e.Rel
    # Many programs keep data and licenses in ProgramData\<same name>
    $dados = Join-Path $env:ProgramData $e.Nome
    if ((Test-Path -LiteralPath $dados) -and $e.Rel -notlike '05_Programas\Usuario_*') { Nova-Tarefa "$(L 'Programa' 'Program'): $($e.Nome)" $dados "05_Programas\ProgramData\$($e.Nome)" $pastasCache }
}
if ($programasEscolhidos.Count) {
    Nova-Tarefa (L 'Atalhos dos programas (Menu Iniciar e Área de Trabalho pública)' 'Program shortcuts (Start Menu and public Desktop)') "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" '05_Programas\MenuIniciar'
    Nova-Tarefa (L 'Atalhos dos programas (Menu Iniciar e Área de Trabalho pública)' 'Program shortcuts (Start Menu and public Desktop)') "$env:PUBLIC\Desktop" '05_Programas\AreaDeTrabalhoPublica' @() @('desktop.ini')
}
foreach ($d in $discosEscolhidos) {
    Nova-Tarefa (L "Disco $d inteiro" "Whole disk $d") "$d\" "04_OutrasPastas\$($d.TrimEnd(':'))" @('$RECYCLE.BIN', 'System Volume Information') -raizDeDisco
}

# ---------- 4. Check if it fits ----------
Titulo (L 'CALCULANDO O TAMANHO DO BACKUP' 'CALCULATING THE BACKUP SIZE')
Msg (L 'Isso não copia nada, só mede. Pode levar alguns minutos...' 'Nothing is copied yet, this only measures. It may take a few minutes...')
foreach ($t in $tarefas) {
    Write-Host "  $(L 'medindo' 'measuring') $($t.Origem)" -ForegroundColor DarkGray
    $t.Bytes = Medir $t
}

$forcar = $false
while ($true) {
    $grupos = @($tarefas | Group-Object Grupo | ForEach-Object {
        [pscustomobject]@{ Nome = $_.Name; Bytes = [int64](($_.Group | Measure-Object Bytes -Sum).Sum) }
    })
    $total = [int64](($grupos | Measure-Object Bytes -Sum).Sum)
    $necessario = [int64]($total * 1.05) + 1GB   # 5% + 1 GB margin (lists, Wi-Fi, space lost on the disk)
    $livre = [int64](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$discoDestino'").FreeSpace

    Write-Host ''
    for ($i = 0; $i -lt $grupos.Count; $i++) { Msg ('[{0}] {1,10}   {2}' -f ($i + 1), (GB $grupos[$i].Bytes), $grupos[$i].Nome) }
    Msg ('-' * 60)
    Msg ('    {0,10}   {1}' -f (GB $total), (L 'TOTAL do backup' 'backup TOTAL'))
    Msg ('    {0,10}   {1}' -f (GB $necessario), (L 'necessário com margem de segurança' 'needed with safety margin'))
    Msg ('    {0,10}   {1} {2}' -f (GB $livre), (L 'livre no disco' 'free on disk'), $discoDestino)
    Write-Host ''

    if ($livre -ge $necessario) {
        Ok ((L 'Cabe! Vão sobrar {0} no disco {1}.' 'It fits! {0} will be left on disk {1}.') -f (GB ($livre - $necessario)), $discoDestino)
        break
    }
    if ($forcar) { break }

    Erro ((L 'NÃO CABE: faltam {0} no disco {1}.' 'DOES NOT FIT: {0} missing on disk {1}.') -f (GB ($necessario - $livre)), $discoDestino)
    Msg (L '[1] Escolher outro disco' '[1] Choose another disk')
    Msg (L '[2] Tirar itens do backup' '[2] Remove items from the backup')
    Msg (L '[3] Continuar mesmo assim (vai parar quando o disco encher)' '[3] Continue anyway (it will stop when the disk is full)')
    Msg (L '[0] Cancelar' '[0] Cancel')
    switch ((Read-Host "  $(L 'Opção' 'Option')").Trim()) {
        '1' { $discoDestino = Escolher-Destino '' ($discosEscolhidos) }
        '2' {
            $r = Read-Host (L '  Números dos itens para tirar, separados por vírgula (ex: 3,4)' '  Numbers of the items to remove, separated by commas (e.g. 3,4)')
            $tirar = @($r -split '[,; ]+' | Where-Object { ($_ -as [int]) -ge 1 -and ($_ -as [int]) -le $grupos.Count } | ForEach-Object { $grupos[[int]$_ - 1].Nome })
            foreach ($t in @($tarefas | Where-Object { $tirar -contains $_.Grupo })) { $tarefas.Remove($t) }
        }
        '3' { $forcar = $true }
        '0' { Sair }
    }
    if ($forcar) { break }
}

Write-Host ''
Aviso (L 'FECHE todos os programas (navegadores, Outlook, WhatsApp, jogos...) antes de continuar.' 'CLOSE all programs (browsers, Outlook, WhatsApp, games...) before continuing.')
Aviso (L 'Se for notebook, deixe ligado na tomada. Pode demorar bastante.' 'If this is a laptop, keep it plugged in. This may take a while.')
if (-not (Perguntar (L 'Começar o backup agora?' 'Start the backup now?'))) { Sair }

# ---------- Destination folders ----------
$inicio = Get-Date
$destino = "$discoDestino\BACKUP_PC\$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
$dInfo = "$destino\00_Info"; $dProg = "$destino\01_Programas"; $dWifi = "$destino\03_WiFi"
New-Item -ItemType Directory -Force $dInfo, $dProg, $dWifi | Out-Null
$script:arquivoLog = "$dInfo\log-copia.txt"

# ---------- 1. System information ----------
Titulo (L '1/5  Informações do sistema' '1/5  System information')
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$chave = (Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey
@(
    "$(L 'Data do backup ' 'Backup date    ') : $(Get-Date)"
    "$(L 'Computador     ' 'Computer       ') : $env:COMPUTERNAME"
    "$(L 'Usuário        ' 'User           ') : $env:USERNAME"
    "$(L 'Fabricante     ' 'Manufacturer   ') : $($cs.Manufacturer) $($cs.Model)"
    "$(L 'Nº de série    ' 'Serial number  ') : $($bios.SerialNumber)"
    "Windows         : $($os.Caption) $($os.Version)"
    "$(L 'Chave Windows  ' 'Windows key    ') : $(if ($chave) { $chave } else { L '(não encontrada na BIOS)' '(not found in BIOS)' })"
    "$(L 'Memória        ' 'Memory         ') : $([math]::Round($cs.TotalPhysicalMemory / 1GB)) GB"
) | Out-File "$dInfo\sistema.txt" -Encoding utf8
# Origin marker: the restore uses it to know whether the backup came from Windows or Linux
@('windows', $os.Caption, $os.Version) | Out-File "$dInfo\origem.txt" -Encoding utf8
Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName | Format-Table -AutoSize | Out-String -Width 300 | Out-File "$dInfo\impressoras.txt" -Encoding utf8
& reg.exe export 'HKCU\Environment' "$dInfo\variaveis-ambiente-usuario.reg" /y | Out-Null
Ok (L 'Informações salvas.' 'Information saved.')

# ---------- 2. Program list ----------
Titulo (L '2/5  Lista de programas instalados' '2/5  List of installed programs')
$progs = Get-ProgramasInstalados
$progs | Export-Csv "$dProg\programas-instalados.csv" -NoTypeInformation -Encoding UTF8
$progs | Format-Table -AutoSize | Out-String -Width 300 | Out-File "$dProg\programas-instalados.txt" -Encoding utf8
Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } |
    Select-Object Name, Version | Sort-Object Name | Format-Table -AutoSize | Out-String -Width 300 | Out-File "$dProg\apps-microsoft-store.txt" -Encoding utf8
Ok (L "$($progs.Count) programas listados." "$($progs.Count) programs listed.")

if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Msg (L 'Gerando lista para reinstalação automática (winget)...' 'Creating the list for automatic reinstallation (winget)...')
    & winget.exe export -o "$dProg\programas-winget.json" --accept-source-agreements | Out-Host
    & winget.exe list --accept-source-agreements | Out-File "$dProg\winget-list.txt" -Encoding utf8
    if (Test-Path "$dProg\programas-winget.json") { Ok (L 'Lista do winget criada.' 'winget list created.'); [void]$script:resumo.Add("[OK] $(L 'Lista de programas (winget)' 'Program list (winget)')") }
    else { Aviso (L 'Não foi possível gerar a lista do winget.' 'Could not create the winget list.') }
} else {
    Aviso (L 'winget não encontrado: só a lista em texto foi salva (reinstalação será manual).' 'winget not found: only the text list was saved (reinstallation will be manual).')
}

# ---------- 3. Wi-Fi ----------
Titulo (L '3/5  Redes Wi-Fi e senhas' '3/5  Wi-Fi networks and passwords')
& netsh.exe wlan export profile key=clear folder="$dWifi" | Out-Host
$nWifi = @(Get-ChildItem "$dWifi\*.xml" -ErrorAction SilentlyContinue).Count
Ok (L "$nWifi redes Wi-Fi salvas." "$nWifi Wi-Fi networks saved.")
[void]$script:resumo.Add("[OK] $nWifi $(L 'redes Wi-Fi' 'Wi-Fi networks')")

# ---------- 4. Files ----------
Titulo ('{0} ({1})' -f (L '4/5  Copiando arquivos' '4/5  Copying files'), (GB $total))
$n = 0
foreach ($t in $tarefas) {
    $n++
    Write-Host ''
    Write-Host ("  [{0}/{1}] {2}" -f $n, $tarefas.Count, $t.Grupo) -ForegroundColor Cyan
    Copiar $t $destino
}

# ---------- 5. Finish ----------
Titulo (L '5/5  Finalizando' '5/5  Finishing')
$duracao = (Get-Date) - $inicio
$tamanho = (Get-ChildItem -LiteralPath $destino -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
$texto = @("$(L 'BACKUP CONCLUÍDO' 'BACKUP COMPLETE') - $(Get-Date)", ('{0}: {1:hh\:mm\:ss}' -f (L 'Duração' 'Duration'), $duracao), "$(L 'Tamanho' 'Size'): $(GB $tamanho)", '') + $script:resumo
$texto | Out-File "$destino\RESUMO.txt" -Encoding utf8

Titulo (L 'BACKUP CONCLUÍDO' 'BACKUP COMPLETE')
$script:resumo | ForEach-Object { if ($_.StartsWith('[!')) { Aviso $_.Substring(5) } else { Msg $_ } }
Write-Host ''
Ok ('{0}: {1:hh\:mm\:ss}   {2}: {3}' -f (L 'Tempo' 'Time'), $duracao, (L 'Tamanho' 'Size'), (GB $tamanho))
Ok "$(L 'Salvo em' 'Saved to'): $destino"
if ($programasEscolhidos.Count) { Msg (L 'Backup 2.0: na restauração, as pastas dos programas são colocadas de volta (opção [7]).' 'Backup 2.0: on restore, the program folders are put back (option [7]).') }
Msg (L 'Para passar para o outro computador: ligue o disco nele e rode "2-RESTORE-BACKUP.bat".' 'To move it to the other computer: connect the disk there and run "2-RESTORE-BACKUP.bat".')
[Win32.Energia]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null
Start-Process explorer.exe $destino
Sair
