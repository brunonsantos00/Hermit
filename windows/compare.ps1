<#
    HERMIT - COMPARE THE BACKUP WITH THIS COMPUTER
    ----------------------------------------------------------------------------
    Shows what is in the backup and did NOT reach this computer (missing files or files that
    are newer in the backup). Read-only: it deletes or changes nothing, unless you ask it to
    copy what is missing at the end.

    Usage: double-click "3-COMPARE-BACKUP.bat".
    Options: -Idioma pt|en   -Backup <backup folder>   -Usuario <name in the backup>
             -IncluirConfiguracoes   -SemPerguntas (asks nothing and copies nothing)
             -ApenasComparar ("COMPARE-ONLY.bat": shows the list of what is missing and offers no copy)
             -SaidaJson <file> (used by Hermit-Compare.exe: writes the result and exits)
#>
param([string]$Idioma, [string]$Backup, [string]$Usuario, [switch]$IncluirConfiguracoes, [switch]$SemPerguntas,
      [switch]$ApenasComparar, [string]$SaidaJson)
if ($SaidaJson) { $SemPerguntas = [switch]$true }

. (Join-Path $PSScriptRoot 'language.ps1')
$script:idioma = Get-Idioma $Idioma

$script:transcript = Join-Path $PSScriptRoot 'last-run-compare.txt'
try { Start-Transcript -Path $script:transcript -Force | Out-Null } catch {}
trap {
    Write-Host ''
    Write-Host "  [X] $(L 'ERRO' 'ERROR'): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      $(L 'Linha' 'Line') $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    if (-not $SemPerguntas) { Read-Host (L '  Pressione ENTER para fechar' '  Press ENTER to close') | Out-Null }
    exit 1
}

$ErrorActionPreference = 'Continue'
$Host.UI.RawUI.WindowTitle = (L 'Comparar backup' 'Compare backup')

function Titulo([string]$t) { Write-Host ''; Write-Host ('=' * 70) -ForegroundColor Cyan; Write-Host "  $t" -ForegroundColor Cyan; Write-Host ('=' * 70) -ForegroundColor Cyan }
function Ok([string]$t)     { Write-Host "  [OK] $t" -ForegroundColor Green }
function Aviso([string]$t)  { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Erro([string]$t)   { Write-Host "  [X]  $t" -ForegroundColor Red }
function Msg([string]$t)    { Write-Host "  $t" }
function Perguntar([string]$t) {
    if ($SemPerguntas) { return $false }
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
function Sair([int]$codigo = 0) {
    Write-Host ''; try { Stop-Transcript | Out-Null } catch {}
    if (-not $SemPerguntas) { Read-Host (L '  Pressione ENTER para fechar' '  Press ENTER to close') | Out-Null }
    exit $codigo
}
function GB([double]$bytes) { if ($bytes -lt 1MB) { '{0:N0} KB' -f [math]::Ceiling($bytes / 1KB) } elseif ($bytes -lt 1GB) { '{0:N1} MB' -f ($bytes / 1MB) } else { '{0:N2} GB' -f ($bytes / 1GB) } }

# Files that do not matter for the comparison
$lixo = 'desktop.ini', 'Thumbs.db', '~$*', '*.tmp', 'NTUSER.DAT*', 'ntuser.*', 'UsrClass.dat*'
$pastasCache = 'Cache', 'Cache_Data', 'Code Cache', 'GPUCache', 'DawnCache', 'GrShaderCache', 'ShaderCache', 'CachedData', 'CacheStorage', 'Crashpad', 'CrashDumps', 'Temp', 'tmp'

# Lists (without copying) the files robocopy would copy. Returns the full paths in the backup.
function Listar([string]$origem, [string]$destino, [string[]]$filtro, [string[]]$xd) {
    $log = Join-Path $env:TEMP ('comparar_' + [guid]::NewGuid().ToString('N') + '.txt')
    # /XX: does not list files that exist only on this computer (extras)
    $a = @($origem, $destino, '/L', '/E', '/XJ', '/XX', '/R:0', '/W:0', '/FP', '/NC', '/NS', '/NDL', '/NJH', '/NJS', '/NP', "/UNILOG:$log") + $filtro
    $a += '/XF'; $a += $lixo
    if ($xd.Count) { $a += '/XD'; $a += $xd }
    & robocopy.exe @a | Out-Null
    $saida = @()
    if (Test-Path -LiteralPath $log) {
        $saida = @(Get-Content -LiteralPath $log -Encoding Unicode | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith($origem.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) })
        Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
    }
    return , $saida
}

# =====================================================================
Titulo (L 'COMPARAR BACKUP COM ESTE COMPUTADOR' 'COMPARE BACKUP WITH THIS COMPUTER')
Msg (L 'Mostra o que está no backup e não chegou neste computador. Nada é apagado ou alterado.' 'Shows what is in the backup but did not reach this computer. Nothing is deleted or changed.')

# ---------- Choose the backup ----------
if ($Backup) {
    if (-not (Test-Path -LiteralPath $Backup)) { Erro (L "Pasta não encontrada: $Backup" "Folder not found: $Backup"); Sair 1 }
    $bk = (Resolve-Path -LiteralPath $Backup).Path
} else {
    $backups = @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 } | ForEach-Object {
        foreach ($nomePasta in 'BACKUP_PC', 'BACKUP_NOTEBOOK') {
            $b = "$($_.DeviceID)\$nomePasta"
            if (Test-Path -LiteralPath $b) { Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue }
        }
    } | Sort-Object LastWriteTime -Descending)
    if (-not $backups.Count) { Erro (L 'Nenhum backup encontrado. Conecte o disco que tem a pasta BACKUP_PC e rode de novo.' 'No backup found. Connect the disk that has the BACKUP_PC folder and run again.'); Sair 1 }
    if ($backups.Count -eq 1) { $bk = $backups[0].FullName }
    else { $bk = $backups[(Escolher (L 'Qual backup comparar?' 'Which backup do you want to compare?') ($backups | ForEach-Object FullName))].FullName }
}
Ok "Backup: $bk"

$origemTxt = "$bk\00_Info\origem.txt"
if ((Test-Path -LiteralPath $origemTxt) -and ((Get-Content -LiteralPath $origemTxt -TotalCount 1) -match 'linux')) {
    Erro (L 'Este backup foi feito no Linux: a comparação só funciona com backups do Windows.' 'This backup was made on Linux: the comparison only works with Windows backups.')
    Sair 1
}

# ---------- Choose the user ----------
$usuarios = @(Get-ChildItem -LiteralPath "$bk\02_Usuarios" -Directory -ErrorAction SilentlyContinue)
if (-not $usuarios.Count) { Erro (L 'Não há usuários neste backup.' 'There are no users in this backup.'); Sair 1 }
if ($Usuario) { $ub = $usuarios | Where-Object { $_.Name -eq $Usuario } | Select-Object -First 1 }
elseif ($usuarios.Count -eq 1) { $ub = $usuarios[0] }
else { $ub = $usuarios[(Escolher (L 'Comparar os arquivos de qual usuário do backup?' 'Compare the files of which user from the backup?') ($usuarios | ForEach-Object Name))] }
if (-not $ub) { Erro (L "Usuário '$Usuario' não está no backup." "User '$Usuario' is not in the backup."); Sair 1 }
$usuarioBk = $ub.FullName
$alvo = $env:USERPROFILE
Msg ((L 'Comparando "{0}" (backup) com "{1}" (este computador).' 'Comparing "{0}" (backup) with "{1}" (this computer).') -f $ub.Name, $alvo)

$comConfig = $IncluirConfiguracoes
if (-not $comConfig -and -not $SemPerguntas) {
    Write-Host ''
    $comConfig = Perguntar (L 'Comparar também as configurações dos programas (AppData)? Costuma ter muitas diferenças normais.' 'Also compare program settings (AppData)? It usually has many normal differences.')
}

# ---------- Build the backup -> computer pairs (same mapping as the restore) ----------
$pares = New-Object System.Collections.ArrayList
function Par([string]$nome, [string]$origem, [string]$destino, [string[]]$xd = @()) {
    if (Test-Path -LiteralPath $origem) { [void]$pares.Add([pscustomobject]@{ Nome = $nome; Origem = $origem; Destino = $destino; XD = $xd }) }
}

$perfilBk = "$usuarioBk\Perfil"
$mapa = [ordered]@{
    'Desktop'   = @('Desktop', (L 'Área de Trabalho' 'Desktop'))
    'Documents' = @('Personal', (L 'Documentos' 'Documents'))
    'Downloads' = @('{374DE290-123F-4565-9164-39C4925E467B}', 'Downloads')
    'Pictures'  = @('My Pictures', (L 'Imagens' 'Pictures'))
    'Music'     = @('My Music', (L 'Músicas' 'Music'))
    'Videos'    = @('My Video', (L 'Vídeos' 'Videos'))
    'Favorites' = @('Favorites', (L 'Favoritos' 'Favorites'))
}
$usf = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue
$excluirPerfil = @()
foreach ($k in $mapa.Keys) {
    $v = $usf.($mapa[$k][0])
    $dest = if ($v) { [Environment]::ExpandEnvironmentVariables($v) } else { Join-Path $alvo $k }
    Par $mapa[$k][1] (Join-Path $perfilBk $k) $dest
    $excluirPerfil += Join-Path $perfilBk $k
}
# Old OneDrive: the restore puts it in a separate folder (the name depends on the language used during the restore)
foreach ($od in @(Get-ChildItem -LiteralPath $perfilBk -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue)) {
    $dest = Join-Path $alvo "OneDrive do computador antigo\$($od.Name)"
    $destEn = Join-Path $alvo "OneDrive from the old computer\$($od.Name)"
    if (-not (Test-Path -LiteralPath $dest) -and (Test-Path -LiteralPath $destEn)) { $dest = $destEn }
    Par "OneDrive ($($od.Name))" $od.FullName $dest
    $excluirPerfil += $od.FullName
}
Par (L 'Resto da pasta do usuário' 'Rest of the user folder') $perfilBk $alvo $excluirPerfil

if ($comConfig) {
    Par (L 'Configurações (AppData\Roaming)' 'Settings (AppData\Roaming)') "$usuarioBk\AppData\Roaming" "$alvo\AppData\Roaming" $pastasCache
    Par (L 'Configurações (AppData\Local)' 'Settings (AppData\Local)') "$usuarioBk\AppData\Local" "$alvo\AppData\Local" $pastasCache
}

# Extra folders and other disks
$letraSis = $env:SystemDrive.TrimEnd(':')
foreach ($g in @(Get-ChildItem -LiteralPath "$bk\04_OutrasPastas" -Directory -ErrorAction SilentlyContinue)) {
    if ($g.Name -eq $letraSis) {
        foreach ($p in @(Get-ChildItem -LiteralPath $g.FullName -Directory)) { Par "$env:SystemDrive\$($p.Name)" $p.FullName "$env:SystemDrive\$($p.Name)" }
    } else {
        $dest = "$env:SystemDrive\Restaurado_disco_$($g.Name)"
        if (-not (Test-Path -LiteralPath $dest) -and (Test-Path "$($g.Name):\")) { $dest = "$($g.Name):\" }
        Par ((L 'Disco {0} (antigo)' 'Disk {0} (old)') -f $g.Name) $g.FullName $dest @('$RECYCLE.BIN', 'System Volume Information')
    }
}

# Backup 2.0: program folders
$progBk = "$bk\05_Programas"
foreach ($par in @(@('ProgramFiles', $env:ProgramFiles), @('ProgramFilesX86', ${env:ProgramFiles(x86)}), @('ProgramData', $env:ProgramData))) {
    if (-not $par[1]) { continue }
    foreach ($prog in @(Get-ChildItem -LiteralPath "$progBk\$($par[0])" -Directory -ErrorAction SilentlyContinue)) {
        Par "$(L 'Programa' 'Program'): $($prog.Name)" $prog.FullName (Join-Path $par[1] $prog.Name)
    }
}
foreach ($prog in @(Get-ChildItem -LiteralPath "$progBk\Usuario_$($ub.Name)" -Directory -ErrorAction SilentlyContinue)) {
    Par "$(L 'Programa' 'Program'): $($prog.Name)" $prog.FullName (Join-Path $alvo "AppData\Local\Programs\$($prog.Name)")
}

# ---------- Compare ----------
Titulo (L 'COMPARANDO' 'COMPARING')
Msg (L 'Isso só lê os arquivos. Pode levar alguns minutos em backups grandes...' 'This only reads the files. It may take a few minutes on large backups...')
$resultados = foreach ($p in $pares) {
    Write-Host "  $(L 'comparando' 'comparing') $($p.Nome)" -ForegroundColor DarkGray
    $base = $p.Origem.TrimEnd('\').Length
    $faltam = foreach ($f in (Listar $p.Origem $p.Destino @('/XC', '/XN', '/XO') $p.XD)) {     # exist only in the backup
        $tam = [int64]0; try { $tam = (Get-Item -LiteralPath $f -Force -ErrorAction Stop).Length } catch {}
        [pscustomobject]@{ Arquivo = $f.Substring($base).TrimStart('\'); Bytes = $tam }
    }
    $novos = foreach ($f in (Listar $p.Origem $p.Destino @('/XL', '/XO') $p.XD)) {             # exist on both, but the backup is newer/different
        $tam = [int64]0; try { $tam = (Get-Item -LiteralPath $f -Force -ErrorAction Stop).Length } catch {}
        [pscustomobject]@{ Arquivo = $f.Substring($base).TrimStart('\'); Bytes = $tam }
    }
    $faltam = @($faltam); $novos = @($novos)
    [pscustomobject]@{ Par = $p; Faltam = $faltam; Novos = $novos; Bytes = [int64](($faltam | Measure-Object Bytes -Sum).Sum) }
}
$resultados = @($resultados)
$totalFaltam = 0; $totalNovos = 0; $totalBytes = [int64]0
foreach ($r in $resultados) { $totalFaltam += $r.Faltam.Count; $totalNovos += $r.Novos.Count; $totalBytes += $r.Bytes }

# ---------- Report (text, on the Desktop) ----------
$relatorio = Join-Path ([Environment]::GetFolderPath('Desktop')) (L 'COMPARACAO DO BACKUP.txt' 'BACKUP COMPARISON.txt')
$linhas = New-Object System.Collections.ArrayList
[void]$linhas.Add("$(L 'COMPARAÇÃO DO BACKUP COM ESTE COMPUTADOR' 'BACKUP COMPARISON WITH THIS COMPUTER') - $(Get-Date)")
[void]$linhas.Add("Backup: $bk")
[void]$linhas.Add("$(L 'Computador' 'Computer'): $env:COMPUTERNAME ($alvo)")
[void]$linhas.Add(('{0}: {1} ({2})   {3}: {4}' -f (L 'Faltam' 'Missing'), $totalFaltam, (GB $totalBytes), (L 'Mais novos no backup' 'Newer in the backup'), $totalNovos))
foreach ($r in $resultados) {
    if (-not $r.Faltam.Count -and -not $r.Novos.Count) { continue }
    [void]$linhas.Add('')
    [void]$linhas.Add('=' * 70)
    [void]$linhas.Add("$($r.Par.Nome)")
    [void]$linhas.Add("  $(L 'Backup' 'Backup')    : $($r.Par.Origem)")
    [void]$linhas.Add("  $(L 'Computador' 'Computer'): $($r.Par.Destino)")
    [void]$linhas.Add('=' * 70)
    if ($r.Faltam.Count) {
        [void]$linhas.Add("$(L 'FALTAM' 'MISSING') ($($r.Faltam.Count), $(GB $r.Bytes)):")
        foreach ($f in $r.Faltam) { [void]$linhas.Add(('  {0}   ({1})' -f $f.Arquivo, (GB $f.Bytes))) }
    }
    if ($r.Novos.Count) {
        [void]$linhas.Add("$(L 'MAIS NOVOS NO BACKUP' 'NEWER IN THE BACKUP') ($($r.Novos.Count)):")
        foreach ($f in $r.Novos) { [void]$linhas.Add('  ' + $f.Arquivo) }
    }
}
$linhas | Out-File -LiteralPath $relatorio -Encoding utf8

# ---------- Window mode: writes the result for Hermit-Compare.exe and exits ----------
if ($SaidaJson) {
    $dados = [pscustomobject]@{
        Backup = $bk; Usuario = $ub.Name; Computador = $env:COMPUTERNAME; Destino = $alvo
        Data = (Get-Date).ToString('dd/MM/yyyy HH:mm'); Relatorio = $relatorio
        TotalFaltam = $totalFaltam; TotalBytes = $totalBytes; TotalNovos = $totalNovos
        Itens = @($resultados | ForEach-Object {
            [pscustomobject]@{ Nome = $_.Par.Nome; Origem = $_.Par.Origem; Destino = $_.Par.Destino; Bytes = $_.Bytes
                               Faltam = @($_.Faltam); Novos = @($_.Novos) }
        })
    }
    [IO.File]::WriteAllText($SaidaJson, ($dados | ConvertTo-Json -Depth 6 -Compress), (New-Object System.Text.UTF8Encoding($false)))
    try { Stop-Transcript | Out-Null } catch {}
    exit 0
}

# ---------- Result on screen ----------
Titulo (L 'RESULTADO' 'RESULT')
Msg ('{0,-34} {1,10} {2,12} {3,12}' -f (L 'Item' 'Item'), (L 'Faltam' 'Missing'), (L 'Tamanho' 'Size'), (L 'Mais novos' 'Newer'))
Msg ('-' * 72)
foreach ($r in $resultados) {
    $cor = if ($r.Faltam.Count) { 'Red' } elseif ($r.Novos.Count) { 'Yellow' } else { 'Green' }
    Write-Host ('  {0,-34} {1,10} {2,12} {3,12}' -f $r.Par.Nome, $r.Faltam.Count, (GB $r.Bytes), $r.Novos.Count) -ForegroundColor $cor
}
Msg ('-' * 72)
Msg ('{0,-34} {1,10} {2,12} {3,12}' -f 'TOTAL', $totalFaltam, (GB $totalBytes), $totalNovos)
Write-Host ''
Write-Host ('  {0,-9}' -f (L 'Vermelho' 'Red')) -ForegroundColor Red -NoNewline; Msg (L '= tem arquivos faltando neste computador' '= has files missing on this computer')
Write-Host ('  {0,-9}' -f (L 'Amarelo' 'Yellow')) -ForegroundColor Yellow -NoNewline; Msg (L '= nada falta, mas o backup tem versões mais novas' '= nothing missing, but the backup has newer versions')
Write-Host ('  {0,-9}' -f (L 'Verde' 'Green')) -ForegroundColor Green -NoNewline; Msg (L '= tudo certo' '= all good')

# ---------- "Compare only" mode: shows the list of what is missing, clearly ----------
if ($ApenasComparar) {
    $limite = 25
    foreach ($r in $resultados) {
        Write-Host ''
        if (-not $r.Faltam.Count -and -not $r.Novos.Count) {
            Write-Host "  [ OK ] $($r.Par.Nome)" -ForegroundColor Green
            continue
        }
        Write-Host ('  ' + ('-' * 68)) -ForegroundColor DarkGray
        Write-Host "  $($r.Par.Nome)" -ForegroundColor White
        Write-Host "  $(L 'no computador' 'on this computer'): $($r.Par.Destino)" -ForegroundColor DarkGray
        if ($r.Faltam.Count) {
            Write-Host ("  {0}: {1} ({2})" -f (L 'FALTAM' 'MISSING'), $r.Faltam.Count, (GB $r.Bytes)) -ForegroundColor Red
            foreach ($f in ($r.Faltam | Select-Object -First $limite)) {
                Write-Host '    [-] ' -ForegroundColor Red -NoNewline
                Write-Host ('{0,-56} {1,10}' -f $f.Arquivo, (GB $f.Bytes))
            }
            if ($r.Faltam.Count -gt $limite) { Write-Host ("    ... {0}" -f ((L 'e mais {0} (lista completa no relatório)' 'and {0} more (full list in the report)') -f ($r.Faltam.Count - $limite))) -ForegroundColor DarkGray }
        }
        if ($r.Novos.Count) {
            Write-Host ("  {0}: {1}" -f (L 'MAIS NOVOS NO BACKUP' 'NEWER IN THE BACKUP'), $r.Novos.Count) -ForegroundColor Yellow
            foreach ($f in ($r.Novos | Select-Object -First $limite)) {
                Write-Host '    [~] ' -ForegroundColor Yellow -NoNewline
                Write-Host $f.Arquivo
            }
            if ($r.Novos.Count -gt $limite) { Write-Host ("    ... {0}" -f ((L 'e mais {0} (lista completa no relatório)' 'and {0} more (full list in the report)') -f ($r.Novos.Count - $limite))) -ForegroundColor DarkGray }
        }
    }
    Write-Host ''
    if ($totalFaltam -eq 0 -and $totalNovos -eq 0) { Ok (L 'Tudo o que está no backup já está neste computador.' 'Everything in the backup is already on this computer.') }
    else { Aviso (L "Relatório completo: $relatorio" "Full report: $relatorio") }
    Sair 0
}

if ($totalFaltam -eq 0 -and $totalNovos -eq 0) {
    Ok (L 'Tudo o que está no backup já está neste computador.' 'Everything in the backup is already on this computer.')
} else {
    Aviso (L "Relatório completo salvo na Área de Trabalho: $relatorio" "Full report saved on the Desktop: $relatorio")
    if (-not $SemPerguntas) { Start-Process notepad.exe "`"$relatorio`"" }

    # ---------- Copy what is missing ----------
    if ($totalFaltam -gt 0) {
        Write-Host ''
        if (Perguntar ((L 'Copiar agora os {0} arquivos que faltam ({1})? Nada que já existe aqui será substituído.' 'Copy the {0} missing files ({1}) now? Nothing that already exists here will be replaced.') -f $totalFaltam, (GB $totalBytes))) {
            $log = Join-Path $PSScriptRoot 'last-copy-compare.txt'
            foreach ($r in $resultados | Where-Object { $_.Faltam.Count }) {
                Write-Host "  -> $($r.Par.Destino)" -ForegroundColor DarkCyan
                $a = @($r.Par.Origem, $r.Par.Destino, '/E', '/XJ', '/XC', '/XN', '/XO', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/NP', '/NDL', '/NJH', "/UNILOG+:$log", '/TEE')
                $a += '/XF'; $a += $lixo
                if ($r.Par.XD.Count) { $a += '/XD'; $a += $r.Par.XD }
                & robocopy.exe @a | Out-Host
                if ($LASTEXITCODE -ge 8) { Aviso (L "Alguns arquivos não foram copiados para '$($r.Par.Destino)'. Pastas fora do seu usuário podem precisar de administrador." "Some files were not copied to '$($r.Par.Destino)'. Folders outside your user may need administrator rights.") }
            }
            Ok (L "Cópia finalizada. Log: $log" "Copy finished. Log: $log")
        }
    }
}
Sair 0
