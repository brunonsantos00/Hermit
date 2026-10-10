<#
    BACKUP DO COMPUTADOR
    --------------------
    Como usar: copie esta pasta para o HD externo (ou outro disco) e dê dois cliques em "1-FAZER-BACKUP.bat".
    O backup é salvo em <DISCO>:\BACKUP_PC\<NOME-DO-PC>_<data>\
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
$Host.UI.RawUI.WindowTitle = 'Backup do computador'

function Titulo([string]$t) { Write-Host ''; Write-Host ('=' * 70) -ForegroundColor Cyan; Write-Host "  $t" -ForegroundColor Cyan; Write-Host ('=' * 70) -ForegroundColor Cyan }
function Ok([string]$t)     { Write-Host "  [OK] $t" -ForegroundColor Green }
function Aviso([string]$t)  { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Erro([string]$t)   { Write-Host "  [X]  $t" -ForegroundColor Red }
function Msg([string]$t)    { Write-Host "  $t" }
function Perguntar([string]$t) {
    do { $r = (Read-Host "  $t (S/N)").Trim().ToUpper() } until ($r -eq 'S' -or $r -eq 'N')
    return ($r -eq 'S')
}
function Sair { Write-Host ''; try { Stop-Transcript | Out-Null } catch {}; Read-Host '  Pressione ENTER para fechar' | Out-Null; exit }
function GB([double]$bytes) { '{0:N1} GB' -f ($bytes / 1GB) }

# Impede o computador de dormir durante o backup
Add-Type -Name Energia -Namespace Win32 -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
[Win32.Energia]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null

$script:resumo = New-Object System.Collections.ArrayList
$script:arquivoLog = $null

# Monta os argumentos comuns do robocopy para uma tarefa
function Args-Robocopy($t, [string]$destino) {
    $a = @($t.Origem, $destino, '/E', '/XJ', '/B', '/XA:O')
    if ($t.XD.Count) { $a += '/XD'; $a += $t.XD }
    if ($t.XF.Count) { $a += '/XF'; $a += $t.XF }
    return $a
}

# Calcula quantos bytes uma tarefa vai copiar (robocopy em modo "só listar", não copia nada)
function Medir($t) {
    if (-not (Test-Path -LiteralPath $t.Origem)) { return [int64]0 }
    $falso = Join-Path $env:TEMP ('medir_' + [guid]::NewGuid().ToString('N'))
    $a = (Args-Robocopy $t $falso) + @('/L', '/BYTES', '/NFL', '/NDL', '/NJH', '/R:0', '/W:0')
    $saida = & robocopy.exe @a
    $linha = $saida | Where-Object { $_ -match '^\s*Bytes\s*:\s*\d+' } | Select-Object -Last 1
    if ($linha -match 'Bytes\s*:\s*(\d+)') { return [int64]$Matches[1] }
    return [int64]0
}

# Copia uma tarefa de verdade
function Copiar($t, [string]$raizDestino) {
    if (-not (Test-Path -LiteralPath $t.Origem)) { return }
    $dest = Join-Path $raizDestino $t.Rel
    Write-Host "  -> $($t.Origem)" -ForegroundColor DarkCyan
    $a = (Args-Robocopy $t $dest) + @('/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/NP', '/NDL', "/UNILOG+:$script:arquivoLog", '/TEE')
    & robocopy.exe @a | Out-Host
    if ($t.RaizDeDisco) { & attrib.exe -s -h "$dest" | Out-Null }   # robocopy deixa a pasta oculta ao copiar a raiz de um disco
    if ($LASTEXITCODE -ge 8) {
        Aviso "Alguns arquivos de '$($t.Origem)' não puderam ser copiados (veja o log)."
        [void]$script:resumo.Add("[!]  $($t.Origem) (com erros, ver log)")
    } else {
        [void]$script:resumo.Add("[OK] $($t.Origem)")
    }
}

function Tipo-Disco($d) {
    try {
        $bus = (Get-Partition -DriveLetter $d.DeviceID.TrimEnd(':') -ErrorAction Stop | Get-Disk -ErrorAction Stop).BusType
        if ("$bus" -eq 'USB') { return 'USB/externo' }
        return "interno ($bus)"
    } catch {
        if ($d.DriveType -eq 2) { return 'removível' }
        return ''
    }
}

# Lista os discos e deixa escolher onde salvar o backup
function Escolher-Destino([string]$padrao, [string[]]$proibidos) {
    $discos = @(Get-CimInstance Win32_LogicalDisk | Where-Object {
        ($_.DriveType -eq 2 -or $_.DriveType -eq 3) -and $_.Size -and $_.DeviceID -ne $discoSistema -and $proibidos -notcontains $_.DeviceID
    } | Sort-Object DeviceID)
    if (-not $discos.Count) { Erro 'Nenhum outro disco encontrado. Conecte o HD externo e rode de novo.'; Sair }

    Msg 'Em qual disco salvar o backup?'
    $idxPadrao = -1
    for ($i = 0; $i -lt $discos.Count; $i++) {
        $d = $discos[$i]
        $marca = ''
        if ($d.DeviceID -eq $padrao) { $idxPadrao = $i; $marca = '  <- onde estão os scripts' }
        Msg ('   [{0}] {1}  {2,-18} livre: {3,9} de {4,9}  {5,-6} {6}{7}' -f ($i + 1), $d.DeviceID, $d.VolumeName,
             (GB $d.FreeSpace), (GB $d.Size), $d.FileSystem, (Tipo-Disco $d), $marca)
    }
    $dica = if ($idxPadrao -ge 0) { " (ENTER = $($idxPadrao + 1))" } else { '' }
    do {
        $r = (Read-Host "  Número do disco$dica").Trim()
        if (-not $r -and $idxPadrao -ge 0) { $n = $idxPadrao + 1 } else { $n = $r -as [int] }
    } until ($n -ge 1 -and $n -le $discos.Count)
    $escolhido = $discos[$n - 1]
    if ($escolhido.FileSystem -eq 'FAT32') {
        Aviso 'Este disco é FAT32: arquivos maiores que 4 GB NÃO cabem nele (vídeos grandes, ISOs...).'
        Aviso 'O ideal é formatar o HD em NTFS ou exFAT antes.'
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

# Pastas de cache que não vale a pena copiar (são recriadas sozinhas)
$pastasCache = 'Cache', 'Cache_Data', 'Code Cache', 'GPUCache', 'DawnCache', 'DawnGraphiteCache', 'DawnWebGPUCache',
               'GrShaderCache', 'ShaderCache', 'CachedData', 'CacheStorage', 'Crashpad', 'CrashDumps', 'Temp', 'tmp'

# Itens de AppData\Local que valem a pena (navegadores, fontes, notas...)
$locaisImportantes = 'Google\Chrome\User Data',
                     'Microsoft\Edge\User Data',
                     'BraveSoftware\Brave-Browser\User Data',
                     'Vivaldi\User Data',
                     'Microsoft\Windows\Fonts',
                     'Microsoft\Outlook',
                     'Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState',
                     'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'

# Pastas da raiz do C: que são do Windows/programas (não entram no backup)
$ignorarRaiz = 'Windows', 'Windows.old', 'Program Files', 'Program Files (x86)', 'ProgramData', 'Users', 'Documents and Settings',
               '$Recycle.Bin', '$WinREAgent', '$Windows.~BT', '$Windows.~WS', '$SysReset', '$GetCurrent', '$AV_ASW',
               'System Volume Information', 'Recovery', 'PerfLogs', 'Config.Msi', 'OneDriveTemp', 'MSOCache',
               'Intel', 'AMD', 'NVIDIA', 'Drivers', 'inetpub', 'ESD', 'XboxGames', 'BACKUP_PC', 'BACKUP_NOTEBOOK', 'SCRIPTS_BACKUP'

# =====================================================================
Titulo 'BACKUP DO COMPUTADOR'
$discoSistema = $env:SystemDrive
Msg "Computador: $env:COMPUTERNAME"
Write-Host ''

# ---------- 1. Onde salvar ----------
$discoDestino = Escolher-Destino (Split-Path -Qualifier $PSScriptRoot) @()
Ok "Backup será salvo no disco $discoDestino"

# ---------- 2. O que copiar ----------
Titulo 'O QUE VAI ENTRAR NO BACKUP'

$perfis = @(Get-CimInstance Win32_UserProfile | Where-Object {
    -not $_.Special -and $_.LocalPath -like "$discoSistema\Users\*" -and (Test-Path -LiteralPath $_.LocalPath)
})
Msg 'Usuários encontrados (todos entram no backup):'
$perfis | ForEach-Object { Msg "   - $($_.LocalPath)" }

$pastasRaiz = @(Get-ChildItem "$discoSistema\" -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
    $ignorarRaiz -notcontains $_.Name -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
})
$pastasRaizEscolhidas = @()
if ($pastasRaiz.Count) {
    Write-Host ''
    Msg "Pastas extras na raiz do $discoSistema (fora da pasta do usuário):"
    $pastasRaiz | ForEach-Object { Msg "   - $($_.FullName)" }
    if (Perguntar 'Copiar TODAS essas pastas?') { $pastasRaizEscolhidas = $pastasRaiz }
    else { foreach ($p in $pastasRaiz) { if (Perguntar "   Copiar $($p.FullName)?") { $pastasRaizEscolhidas += $p } } }
}

$outrosDiscos = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.DeviceID -ne $discoSistema -and $_.DeviceID -ne $discoDestino })
$discosEscolhidos = @()
foreach ($d in $outrosDiscos) {
    Write-Host ''
    if (Perguntar ('Copiar o disco {0} ({1}) inteiro? Usado: {2}' -f $d.DeviceID, $d.VolumeName, (GB ($d.Size - $d.FreeSpace)))) { $discosEscolhidos += $d.DeviceID }
}

# ---------- 3. Montar a lista de tarefas ----------
$tarefas = New-Object System.Collections.ArrayList
function Nova-Tarefa([string]$grupo, [string]$origem, [string]$rel, [string[]]$xd = @(), [string[]]$xf = @(), [switch]$raizDeDisco) {
    [void]$tarefas.Add([pscustomobject]@{ Grupo = $grupo; Origem = $origem; Rel = $rel; XD = $xd; XF = $xf; RaizDeDisco = [bool]$raizDeDisco; Bytes = [int64]0 })
}
foreach ($p in $perfis) {
    $lp = $p.LocalPath; $nome = Split-Path $lp -Leaf
    # Pasta do usuário inteira (Desktop, Documentos, Downloads, Imagens, Vídeos, Músicas, etc.), menos AppData
    Nova-Tarefa "Usuário $nome - arquivos" $lp "02_Usuarios\$nome\Perfil" @("$lp\AppData") @('NTUSER.DAT*', 'ntuser.*', 'UsrClass.dat*')
    # Configurações dos programas
    Nova-Tarefa "Usuário $nome - configurações" "$lp\AppData\Roaming" "02_Usuarios\$nome\AppData\Roaming" $pastasCache
    foreach ($rel in $locaisImportantes) {
        Nova-Tarefa "Usuário $nome - configurações" "$lp\AppData\Local\$rel" "02_Usuarios\$nome\AppData\Local\$rel" $pastasCache @('*.ost')
    }
}
$letraSis = $discoSistema.TrimEnd(':')
foreach ($p in $pastasRaizEscolhidas) { Nova-Tarefa "Pasta $($p.FullName)" $p.FullName "04_OutrasPastas\$letraSis\$($p.Name)" }
foreach ($d in $discosEscolhidos) {
    Nova-Tarefa "Disco $d inteiro" "$d\" "04_OutrasPastas\$($d.TrimEnd(':'))" @('$RECYCLE.BIN', 'System Volume Information') -raizDeDisco
}

# ---------- 4. Verificar se cabe ----------
Titulo 'CALCULANDO O TAMANHO DO BACKUP'
Msg 'Isso não copia nada, só mede. Pode levar alguns minutos...'
foreach ($t in $tarefas) {
    Write-Host "  medindo $($t.Origem)" -ForegroundColor DarkGray
    $t.Bytes = Medir $t
}

$forcar = $false
while ($true) {
    $grupos = @($tarefas | Group-Object Grupo | ForEach-Object {
        [pscustomobject]@{ Nome = $_.Name; Bytes = [int64](($_.Group | Measure-Object Bytes -Sum).Sum) }
    })
    $total = [int64](($grupos | Measure-Object Bytes -Sum).Sum)
    $necessario = [int64]($total * 1.05) + 1GB   # margem de 5% + 1 GB (listas, Wi-Fi, espaço perdido no disco)
    $livre = [int64](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$discoDestino'").FreeSpace

    Write-Host ''
    for ($i = 0; $i -lt $grupos.Count; $i++) { Msg ('[{0}] {1,10}   {2}' -f ($i + 1), (GB $grupos[$i].Bytes), $grupos[$i].Nome) }
    Msg ('-' * 60)
    Msg ('    {0,10}   TOTAL do backup' -f (GB $total))
    Msg ('    {0,10}   necessário com margem de segurança' -f (GB $necessario))
    Msg ('    {0,10}   livre no disco {1}' -f (GB $livre), $discoDestino)
    Write-Host ''

    if ($livre -ge $necessario) {
        Ok ('Cabe! Vão sobrar {0} no disco {1}.' -f (GB ($livre - $necessario)), $discoDestino)
        break
    }

    Erro ('NÃO CABE: faltam {0} no disco {1}.' -f (GB ($necessario - $livre)), $discoDestino)
    Msg '[1] Escolher outro disco'
    Msg '[2] Tirar itens do backup'
    Msg '[3] Continuar mesmo assim (vai parar quando o disco encher)'
    Msg '[0] Cancelar'
    switch ((Read-Host '  Opção').Trim()) {
        '1' { $discoDestino = Escolher-Destino '' ($discosEscolhidos) }
        '2' {
            $r = Read-Host '  Números dos itens para tirar, separados por vírgula (ex: 3,4)'
            $tirar = @($r -split '[,; ]+' | Where-Object { ($_ -as [int]) -ge 1 -and ($_ -as [int]) -le $grupos.Count } | ForEach-Object { $grupos[[int]$_ - 1].Nome })
            foreach ($t in @($tarefas | Where-Object { $tirar -contains $_.Grupo })) { $tarefas.Remove($t) }
        }
        '3' { $forcar = $true }
        '0' { Sair }
    }
    if ($forcar) { break }
}

Write-Host ''
Aviso 'FECHE todos os programas (navegadores, Outlook, WhatsApp, jogos...) antes de continuar.'
Aviso 'Se for notebook, deixe ligado na tomada. Pode demorar bastante.'
if (-not (Perguntar 'Começar o backup agora?')) { Sair }

# ---------- Pastas de destino ----------
$inicio = Get-Date
$destino = "$discoDestino\BACKUP_PC\$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
$dInfo = "$destino\00_Info"; $dProg = "$destino\01_Programas"; $dWifi = "$destino\03_WiFi"
New-Item -ItemType Directory -Force $dInfo, $dProg, $dWifi | Out-Null
$script:arquivoLog = "$dInfo\log-copia.txt"

# ---------- 1. Informações do sistema ----------
Titulo '1/5  Informações do sistema'
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$chave = (Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey
@"
Data do backup  : $(Get-Date)
Computador      : $env:COMPUTERNAME
Usuário         : $env:USERNAME
Fabricante      : $($cs.Manufacturer) $($cs.Model)
Nº de série     : $($bios.SerialNumber)
Windows         : $($os.Caption) $($os.Version)
Chave Windows   : $(if ($chave) { $chave } else { '(não encontrada na BIOS)' })
Memória         : $([math]::Round($cs.TotalPhysicalMemory / 1GB)) GB
"@ | Out-File "$dInfo\sistema.txt" -Encoding utf8
Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName | Format-Table -AutoSize | Out-String -Width 300 | Out-File "$dInfo\impressoras.txt" -Encoding utf8
& reg.exe export 'HKCU\Environment' "$dInfo\variaveis-ambiente-usuario.reg" /y | Out-Null
Ok 'Informações salvas.'

# ---------- 2. Lista de programas ----------
Titulo '2/5  Lista de programas instalados'
$progs = Get-ProgramasInstalados
$progs | Export-Csv "$dProg\programas-instalados.csv" -NoTypeInformation -Encoding UTF8
$progs | Format-Table -AutoSize | Out-String -Width 300 | Out-File "$dProg\programas-instalados.txt" -Encoding utf8
Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } |
    Select-Object Name, Version | Sort-Object Name | Format-Table -AutoSize | Out-String -Width 300 | Out-File "$dProg\apps-microsoft-store.txt" -Encoding utf8
Ok "$($progs.Count) programas listados."

if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Msg 'Gerando lista para reinstalação automática (winget)...'
    & winget.exe export -o "$dProg\programas-winget.json" --accept-source-agreements | Out-Host
    & winget.exe list --accept-source-agreements | Out-File "$dProg\winget-list.txt" -Encoding utf8
    if (Test-Path "$dProg\programas-winget.json") { Ok 'Lista do winget criada.'; [void]$script:resumo.Add('[OK] Lista de programas (winget)') }
    else { Aviso 'Não foi possível gerar a lista do winget.' }
} else {
    Aviso 'winget não encontrado: só a lista em texto foi salva (reinstalação será manual).'
}

# ---------- 3. Wi-Fi ----------
Titulo '3/5  Redes Wi-Fi e senhas'
& netsh.exe wlan export profile key=clear folder="$dWifi" | Out-Host
$nWifi = @(Get-ChildItem "$dWifi\*.xml" -ErrorAction SilentlyContinue).Count
Ok "$nWifi redes Wi-Fi salvas."
[void]$script:resumo.Add("[OK] $nWifi redes Wi-Fi")

# ---------- 4. Arquivos ----------
Titulo ('4/5  Copiando arquivos ({0})' -f (GB $total))
$n = 0
foreach ($t in $tarefas) {
    $n++
    Write-Host ''
    Write-Host ("  [{0}/{1}] {2}" -f $n, $tarefas.Count, $t.Grupo) -ForegroundColor Cyan
    Copiar $t $destino
}

# ---------- 5. Fim ----------
Titulo '5/5  Finalizando'
$duracao = (Get-Date) - $inicio
$tamanho = (Get-ChildItem -LiteralPath $destino -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
$texto = @("BACKUP CONCLUÍDO - $(Get-Date)", ('Duração: {0:hh\:mm\:ss}' -f $duracao), "Tamanho: $(GB $tamanho)", '') + $script:resumo
$texto | Out-File "$destino\RESUMO.txt" -Encoding utf8

Titulo 'BACKUP CONCLUÍDO'
$script:resumo | ForEach-Object { if ($_.StartsWith('[!')) { Aviso $_.Substring(5) } else { Msg $_ } }
Write-Host ''
Ok ('Tempo: {0:hh\:mm\:ss}   Tamanho: {1}' -f $duracao, (GB $tamanho))
Ok "Salvo em: $destino"
Msg 'Para passar para o outro computador: ligue o disco nele e rode "2-RESTAURAR-BACKUP.bat".'
[Win32.Energia]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null
Start-Process explorer.exe $destino
Sair
