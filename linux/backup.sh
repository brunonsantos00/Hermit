#!/usr/bin/env bash
# =====================================================================
#  BACKUP DO COMPUTADOR (LINUX) - Ubuntu, Debian e Fedora
#  COMPUTER BACKUP (LINUX)      - Ubuntu, Debian and Fedora
#  ------------------------------------------------------
#  Uso / Usage:   bash backup.sh [--idioma pt|en]
#  O backup é salvo em <DISCO>/BACKUP_PC/<NOME-DO-PC>_<data>/
# =====================================================================

set -o pipefail

SCRIPT="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT")"

# ---------- Idioma ----------
PEDIDO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --idioma|--lang) PEDIDO="${2:-}"; shift 2 ;;
        --idioma=*|--lang=*) PEDIDO="${1#*=}"; shift ;;
        *) shift ;;
    esac
done
# shellcheck source=idioma.sh
source "$SCRIPT_DIR/idioma.sh"
IDIOMA="$(detectar_idioma "$PEDIDO")"

# ---------- Rodar como administrador ----------
if [ "$EUID" -ne 0 ]; then
    L "Este script precisa de permissão de administrador (digite sua senha)." "This script needs administrator permission (type your password)."; echo
    exec sudo bash "$SCRIPT" --idioma "$IDIOMA"
fi

# Impede o computador de suspender durante o backup
if [ -z "${BACKUP_INIBIDO:-}" ] && command -v systemd-inhibit >/dev/null 2>&1 && systemd-inhibit --list >/dev/null 2>&1; then
    export BACKUP_INIBIDO=1
    exec systemd-inhibit --what=sleep:idle:handle-lid-switch --who="Backup" --why="Backup" bash "$SCRIPT" --idioma "$IDIOMA"
fi

# Registro de tudo que aparece na tela (para descobrir problemas)
TRANSCRIPT="$SCRIPT_DIR/ultima-execucao-backup.txt"
: > "$TRANSCRIPT" 2>/dev/null && exec > >(tee -a "$TRANSCRIPT") 2>&1

# ---------- Aparência ----------
AZUL=$'\e[36m'; VERDE=$'\e[32m'; AMARELO=$'\e[33m'; VERMELHO=$'\e[31m'; CINZA=$'\e[90m'; N=$'\e[0m'
LINHA="$(printf '=%.0s' {1..70})"
titulo()    { echo; echo "${AZUL}${LINHA}${N}"; echo "${AZUL}  $*${N}"; echo "${AZUL}${LINHA}${N}"; }
ok()        { echo "${VERDE}  [OK] $*${N}"; }
aviso()     { echo "${AMARELO}  [!]  $*${N}"; }
erro()      { echo "${VERMELHO}  [X]  $*${N}"; }
msg()       { echo "  $*"; }
# Lê uma resposta; se a entrada acabar (sem teclado), encerra em vez de perguntar para sempre
entrada()   { read -r -p "$@" || { echo; erro "$(L 'Sem resposta (a entrada foi encerrada). Saindo.' 'No answer (input was closed). Exiting.')"; exit 1; }; }
perguntar() {
    local r sn; sn="$(L '(S/N)' '(Y/N)')"
    while true; do entrada "  $1 $sn " r; case "${r^^}" in S|Y) return 0 ;; N) return 1 ;; esac; done
}
sair()      { echo; read -r -p "  $(L 'Pressione ENTER para fechar' 'Press ENTER to close') " _; exit "${1:-0}"; }
gb()        { awk -v b="${1:-0}" 'BEGIN { printf "%.1f GB", b / 1073741824 }'; }

# ---------- Sistema atual ----------
ler_os_release() {   # $1 = arquivo os-release; $2 = campo. Lê sem executar o arquivo.
    grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2- | tr -d '"'
}
DISTRO_ID="$(ler_os_release /etc/os-release ID)"
DISTRO_PARECIDA="$(ler_os_release /etc/os-release ID_LIKE)"
DISTRO_NOME="$(ler_os_release /etc/os-release PRETTY_NAME)"
DISTRO_VERSAO="$(ler_os_release /etc/os-release VERSION_ID)"
case " $DISTRO_ID $DISTRO_PARECIDA " in
    *" fedora "*|*" rhel "*)  FAMILIA=dnf ;;
    *" debian "*|*" ubuntu "*) FAMILIA=apt ;;
    *) FAMILIA=outro ;;
esac

instalar() { case "$FAMILIA" in apt) apt-get install -y "$@" ;; dnf) dnf install -y "$@" ;; esac; }

# Descobre se um ponto de montagem tem sistema operacional. Imprime o nome ou nada.
detectar_so() {
    local m="$1"
    if [ "$m" = "/" ]; then echo "$DISTRO_NOME ($(L 'este sistema' 'this system'))"; return; fi
    if [ -f "$m/etc/os-release" ]; then
        local n; n="$(ler_os_release "$m/etc/os-release" PRETTY_NAME)"; echo "${n:-Linux}"; return
    fi
    if [ -d "$m/Windows/System32" ] || [ -d "$m/WINDOWS/system32" ]; then echo "Windows"; return; fi
    if [ -f "$m/System/Library/CoreServices/SystemVersion.plist" ]; then echo "macOS"; return; fi
}

# Discos montados que podem receber o backup (formato: caminho|dispositivo|sistema-de-arquivos)
listar_discos() {
    findmnt -rn -o TARGET,SOURCE,FSTYPE -t ext4,ext3,ext2,xfs,btrfs,f2fs,vfat,exfat,ntfs,ntfs3,fuseblk,9p,drvfs 2>/dev/null |
    while read -r alvo origem fs; do
        alvo="$(printf '%b' "$alvo")"     # findmnt troca espaços por \x20
        case "$alvo" in
            /|/boot|/boot/*|/efi|/home|/var|/var/*|/usr|/usr/*|/opt|/srv|/tmp|/snap/*|/mnt/wsl*|/usr/lib/wsl*) continue ;;
        esac
        echo "$alvo|$origem|$fs"
    done
}

livre_bytes() { df -B1 --output=avail "$1" 2>/dev/null | tail -1 | tr -d ' '; }
total_bytes() { df -B1 --output=size  "$1" 2>/dev/null | tail -1 | tr -d ' '; }
tipo_disco() {
    local pai; pai="$(lsblk -no PKNAME "$1" 2>/dev/null | head -1)"
    if [ -n "$pai" ] && [ "$(lsblk -dno TRAN "/dev/$pai" 2>/dev/null)" = "usb" ]; then L "USB/externo" "USB/external"; else L "interno" "internal"; fi
}

# Lista os discos e deixa escolher. Define DEST_MNT e DEST_FS.
escolher_destino() {
    local padrao="$1"; shift
    local proibidos=" $* " a o f i n r idx_padrao=-1
    mapfile -t DISCOS < <(listar_discos | while IFS='|' read -r a o f; do [[ "$proibidos" == *" $a "* ]] || echo "$a|$o|$f"; done)
    if [ "${#DISCOS[@]}" -eq 0 ]; then
        erro "$(L 'Nenhum disco encontrado. Conecte o HD externo e abra ele no gerenciador de arquivos (para ser montado).' 'No disk found. Connect the external drive and open it in the file manager (so it gets mounted).')"
        sair 1
    fi
    msg "$(L 'Em qual disco salvar o backup?' 'Which disk should the backup be saved to?')"
    for i in "${!DISCOS[@]}"; do
        IFS='|' read -r a o f <<< "${DISCOS[$i]}"
        local marca="" rotulo so
        rotulo="$(lsblk -no LABEL "$o" 2>/dev/null | head -1)"
        if [ "$a" = "$padrao" ]; then marca="  $(L '<- onde estão os scripts' '<- where the scripts are')"; idx_padrao=$i; fi
        printf "   [%d] %-30s %-14s %s: %9s %s %9s  %-6s %s%s\n" $((i + 1)) "$a" "$rotulo" "$(L livre free)" \
            "$(gb "$(livre_bytes "$a")")" "$(L de of)" "$(gb "$(total_bytes "$a")")" "$f" "$(tipo_disco "$o")" "$marca"
        so="$(detectar_so "$a")"
        if [ -n "$so" ]; then echo "${AMARELO}         $(L 'Sistema instalado' 'Installed system'): $so${N}"
        else echo "${CINZA}         $(L 'Sem sistema operacional (bom para guardar backups)' 'No operating system (good for storing backups)')${N}"; fi
    done
    local dica=""; [ "$idx_padrao" -ge 0 ] && dica=" (ENTER = $((idx_padrao + 1)))"
    while true; do
        entrada "  $(L 'Número do disco' 'Disk number')$dica: " r
        if [ -z "$r" ] && [ "$idx_padrao" -ge 0 ]; then n=$((idx_padrao + 1)); else n="$r"; fi
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#DISCOS[@]}" ] && break
    done
    IFS='|' read -r DEST_MNT o DEST_FS <<< "${DISCOS[$((n - 1))]}"
    case "$DEST_FS" in
        vfat) aviso "$(L 'Este disco é FAT32: arquivos maiores que 4 GB NÃO cabem e as permissões não são guardadas.' 'This disk is FAT32: files larger than 4 GB will NOT fit and permissions are not kept.')"
              aviso "$(L 'O ideal é formatar o HD em ext4, NTFS ou exFAT.' 'Ideally, format the drive as ext4, NTFS or exFAT.')" ;;
        exfat|ntfs|ntfs3|fuseblk|9p|drvfs)
              aviso "$(L "Disco $DEST_FS: os arquivos são copiados, mas as permissões do Linux (dono, chmod) não são guardadas." "$DEST_FS disk: files are copied, but Linux permissions (owner, chmod) are not kept.")" ;;
    esac
}

opcoes_rsync() {
    case "$1" in
        ext*|xfs|btrfs|f2fs)    echo "-aH" ;;
        ntfs|ntfs3|fuseblk)     echo "-rlt" ;;
        *)                      echo "-rt --modify-window=2" ;;
    esac
}

# =====================================================================
titulo "$(L 'BACKUP DO COMPUTADOR (LINUX)' 'COMPUTER BACKUP (LINUX)')"
msg "$(L 'Computador' 'Computer'): $(hostname)   •   $DISTRO_NOME"
case "$DISTRO_ID" in
    ubuntu|debian|fedora) ;;
    *)  if [ "$FAMILIA" = outro ]; then
            erro "$(L 'Distribuição não suportada. Este script funciona no Ubuntu, Debian e Fedora.' 'Unsupported distribution. This script works on Ubuntu, Debian and Fedora.')"; sair 1
        fi
        aviso "$(L "$DISTRO_NOME não é oficialmente suportado, mas é parecido com ${DISTRO_PARECIDA}: vou tentar." "$DISTRO_NOME is not officially supported, but it is similar to ${DISTRO_PARECIDA}: trying anyway.")" ;;
esac

if ! command -v rsync >/dev/null 2>&1; then
    msg "$(L 'Instalando o rsync (necessário para copiar)...' 'Installing rsync (needed to copy)...')"
    [ "$FAMILIA" = apt ] && apt-get update -qq
    instalar rsync >/dev/null || { erro "$(L 'Não foi possível instalar o rsync.' 'Could not install rsync.')"; sair 1; }
fi
echo

# ---------- 1. Onde salvar ----------
escolher_destino "$(findmnt -n -o TARGET --target "$SCRIPT_DIR" 2>/dev/null)"
ok "$(L "Backup será salvo em $DEST_MNT" "Backup will be saved to $DEST_MNT")"

# ---------- 2. O que copiar ----------
titulo "$(L 'O QUE VAI ENTRAR NO BACKUP' 'WHAT WILL BE BACKED UP')"

mapfile -t USUARIOS < <(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1 ":" $6 }' |
                        while IFS=: read -r u h; do [ -d "$h" ] && echo "$u:$h"; done)
msg "$(L 'Usuários encontrados (todos entram no backup):' 'Users found (all of them will be backed up):')"
for u in "${USUARIOS[@]}"; do msg "   - ${u%%:*}  (${u#*:})"; done

EXTRAS_CANDIDATOS=(/opt /srv /var/www /usr/local)
EXTRAS=()
echo
msg "$(L 'Pastas do sistema que costumam ter coisas instaladas por você:' 'System folders that usually have things you installed:')"
for p in "${EXTRAS_CANDIDATOS[@]}"; do
    [ -d "$p" ] && [ -n "$(ls -A "$p" 2>/dev/null)" ] || continue
    if perguntar "   $(L 'Copiar' 'Copy') $p?"; then EXTRAS+=("$p"); fi
done

OUTROS=()
mapfile -t _outros < <(listar_discos | cut -d'|' -f1 | grep -vxF "$DEST_MNT")
for d in "${_outros[@]}"; do
    [ -n "$d" ] || continue
    echo
    so="$(detectar_so "$d")"
    if [ -n "$so" ]; then aviso "$(L "O disco $d tem outro sistema instalado ($so). Só os arquivos dele podem ser copiados, não o sistema." "Disk $d has another system installed ($so). Only its files can be copied, not the system.")"
    else msg "$(L "O disco $d não tem nenhum sistema operacional: só arquivos." "Disk $d has no operating system: files only.")"; fi
    usado=$(( $(total_bytes "$d") - $(livre_bytes "$d") ))
    if perguntar "$(L "Copiar o disco $d inteiro? Usado: $(gb "$usado")" "Copy the whole disk $d? Used: $(gb "$usado")")"; then OUTROS+=("$d"); fi
done

# ---------- 3. Montar a lista de tarefas ----------
T_GRUPO=(); T_ORIGEM=(); T_REL=(); T_FILTRO=(); T_BYTES=()
nova_tarefa() { T_GRUPO+=("$1"); T_ORIGEM+=("$2"); T_REL+=("$3"); T_FILTRO+=("$4"); T_BYTES+=(0); }

EXCL_CACHE=(--exclude='Cache/' --exclude='Cache_Data/' --exclude='GPUCache/' --exclude='Code Cache/' --exclude='CachedData/'
            --exclude='ShaderCache/' --exclude='GrShaderCache/' --exclude='DawnCache/' --exclude='CacheStorage/')
EXCL_CONFIG=(--exclude='/.cache/' --exclude='/.local/share/Trash/' --exclude='/.thumbnails/' --exclude='/.gvfs' --exclude='/.dbus/'
             --exclude='/.local/share/Steam/steamapps/common/' --exclude='/.var/app/*/cache/'
             --exclude='/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/')

# Define FILTROS para cada tipo de tarefa
filtros() {
    case "$1" in
        home_arquivos) FILTROS=(--exclude='/.*') ;;                                            # tudo menos os arquivos ocultos
        home_config)   FILTROS=("${EXCL_CONFIG[@]}" "${EXCL_CACHE[@]}" --include='/.*' --exclude='/*') ;;  # só os ocultos (configurações)
        disco)         FILTROS=(--exclude='/lost+found/' --exclude='/.Trash-*/' --exclude='/$RECYCLE.BIN/'
                                --exclude='/System Volume Information/' --exclude='/BACKUP_PC/') ;;
        *)             FILTROS=() ;;
    esac
}

for u in "${USUARIOS[@]}"; do
    nome="${u%%:*}"; casa="${u#*:}"
    nova_tarefa "$(L "Usuário $nome - arquivos" "User $nome - files")"         "$casa" "02_Usuarios/$nome/Home" home_arquivos
    nova_tarefa "$(L "Usuário $nome - configurações" "User $nome - settings")" "$casa" "02_Usuarios/$nome/Home" home_config
done
for p in "${EXTRAS[@]}"; do nova_tarefa "$(L Pasta Folder) $p" "$p" "04_OutrasPastas/$(echo "${p#/}" | tr '/' '_')" nenhum; done
for d in "${OUTROS[@]}"; do nova_tarefa "$(L "Disco $d inteiro" "Whole disk $d")" "$d" "04_OutrasPastas/disco_$(basename "$d")" disco; done
nova_tarefa "$(L 'Configurações do sistema (/etc, só para consulta)' 'System settings (/etc, for reference only)')" /etc "00_Info/etc" nenhum

# ---------- 4. Verificar se cabe ----------
titulo "$(L 'CALCULANDO O TAMANHO DO BACKUP' 'CALCULATING THE BACKUP SIZE')"
msg "$(L 'Isso não copia nada, só mede. Pode levar alguns minutos...' 'Nothing is copied yet, this only measures. It may take a few minutes...')"
medir() {
    filtros "${T_FILTRO[$1]}"
    [ -e "${T_ORIGEM[$1]}" ] || { echo 0; return; }
    local v
    v="$(LC_ALL=C rsync -rn --stats "${FILTROS[@]}" "${T_ORIGEM[$1]}/" "/tmp/medir_inexistente_$$/" 2>/dev/null |
         awk -F': ' '/^Total file size/ { gsub(/[^0-9]/, "", $2); print $2; exit }')"
    echo "${v:-0}"
}
for i in "${!T_GRUPO[@]}"; do
    echo "${CINZA}  $(L medindo measuring) ${T_GRUPO[$i]}${N}"
    T_BYTES[$i]="$(medir "$i")"
done

FORCAR=0
while true; do
    # Soma por grupo, mantendo a ordem
    GRUPOS=(); declare -A SOMA=()
    for i in "${!T_GRUPO[@]}"; do
        g="${T_GRUPO[$i]}"
        [ -z "${SOMA[$g]+x}" ] && { GRUPOS+=("$g"); SOMA[$g]=0; }
        SOMA[$g]=$(( SOMA[$g] + T_BYTES[$i] ))
    done
    TOTAL=0; for g in "${GRUPOS[@]}"; do TOTAL=$(( TOTAL + SOMA[$g] )); done
    NECESSARIO=$(( TOTAL + TOTAL / 20 + 1073741824 ))     # margem de 5% + 1 GB
    LIVRE="$(livre_bytes "$DEST_MNT")"

    echo
    for i in "${!GRUPOS[@]}"; do printf "  [%d] %10s   %s\n" $((i + 1)) "$(gb "${SOMA[${GRUPOS[$i]}]}")" "${GRUPOS[$i]}"; done
    msg "------------------------------------------------------------"
    printf "      %10s   %s\n" "$(gb "$TOTAL")" "$(L 'TOTAL do backup' 'backup TOTAL')"
    printf "      %10s   %s\n" "$(gb "$NECESSARIO")" "$(L 'necessário com margem de segurança' 'needed with safety margin')"
    printf "      %10s   %s %s\n" "$(gb "$LIVRE")" "$(L 'livre em' 'free on')" "$DEST_MNT"
    echo

    if [ "$LIVRE" -ge "$NECESSARIO" ]; then ok "$(L "Cabe! Vão sobrar $(gb $(( LIVRE - NECESSARIO ))) em $DEST_MNT." "It fits! $(gb $(( LIVRE - NECESSARIO ))) will be left on $DEST_MNT.")"; break; fi
    [ "$FORCAR" = 1 ] && break

    erro "$(L "NÃO CABE: faltam $(gb $(( NECESSARIO - LIVRE ))) em $DEST_MNT." "DOES NOT FIT: $(gb $(( NECESSARIO - LIVRE ))) missing on $DEST_MNT.")"
    msg "$(L '[1] Escolher outro disco' '[1] Choose another disk')"
    msg "$(L '[2] Tirar itens do backup' '[2] Remove items from the backup')"
    msg "$(L '[3] Continuar mesmo assim (vai parar quando o disco encher)' '[3] Continue anyway (it will stop when the disk is full)')"
    msg "$(L '[0] Cancelar' '[0] Cancel')"
    entrada "  $(L 'Opção' 'Option'): " op
    case "$op" in
        1) escolher_destino "" "${OUTROS[@]}" ;;
        2) entrada "  $(L 'Números dos itens para tirar, separados por vírgula (ex: 3,4)' 'Numbers of the items to remove, separated by commas (e.g. 3,4)'): " r
           TIRAR=()
           for n in ${r//,/ }; do
               [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#GRUPOS[@]}" ] && TIRAR+=("${GRUPOS[$((n - 1))]}")
           done
           for i in "${!T_GRUPO[@]}"; do
               for g in "${TIRAR[@]}"; do
                   [ "${T_GRUPO[$i]}" = "$g" ] && unset 'T_GRUPO[i]' 'T_ORIGEM[i]' 'T_REL[i]' 'T_FILTRO[i]' 'T_BYTES[i]'
               done
           done ;;
        3) FORCAR=1 ;;
        0) sair 0 ;;
    esac
    unset SOMA
done
RSYNC_OPTS="$(opcoes_rsync "$DEST_FS")"

echo
aviso "$(L 'FECHE os programas abertos (navegador, e-mail, jogos...) antes de continuar.' 'CLOSE open programs (browser, e-mail, games...) before continuing.')"
aviso "$(L 'Se for notebook, deixe ligado na tomada. Pode demorar bastante.' 'If this is a laptop, keep it plugged in. This may take a while.')"
perguntar "$(L 'Começar o backup agora?' 'Start the backup now?')" || sair 0

# ---------- Pastas de destino ----------
INICIO=$(date +%s)
DESTINO="$DEST_MNT/BACKUP_PC/$(hostname)_$(date +%Y-%m-%d_%H-%M)"
DINFO="$DESTINO/00_Info"; DPROG="$DESTINO/01_Programas"; DWIFI="$DESTINO/03_WiFi"
mkdir -p "$DINFO" "$DPROG" "$DWIFI" "$DESTINO/04_OutrasPastas" || { erro "$(L "Não foi possível criar a pasta em $DEST_MNT." "Could not create the folder on $DEST_MNT.")"; sair 1; }
LOG="$DINFO/log-copia.txt"
RESUMO=()

# ---------- 1. Informações do sistema ----------
titulo "$(L '1/5  Informações do sistema' '1/5  System information')"
{
    echo "$(L 'Data do backup ' 'Backup date    ') : $(date)"
    echo "$(L 'Computador     ' 'Computer       ') : $(hostname)"
    echo "$(L 'Usuário        ' 'User           ') : ${SUDO_USER:-root}"
    echo "$(L 'Sistema        ' 'System         ') : $DISTRO_NOME"
    echo "Kernel          : $(uname -r)"
    echo "$(L 'Fabricante     ' 'Manufacturer   ') : $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
    echo "$(L 'Processador    ' 'Processor      ') : $(LC_ALL=C lscpu 2>/dev/null | awk -F': +' '/Model name/ { print $2; exit }')"
    echo "$(L 'Memória        ' 'Memory         ') : $(free -h 2>/dev/null | awk '/^Mem/ { print $2 }')"
    echo
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null
} > "$DINFO/sistema.txt"
# Marca de origem: o restaurar usa para saber de onde veio o backup
printf 'linux\n%s\n%s\n%s\n' "$DISTRO_ID" "$DISTRO_VERSAO" "$FAMILIA" > "$DINFO/origem.txt"
for u in "${USUARIOS[@]}"; do crontab -l -u "${u%%:*}" > "$DINFO/crontab-${u%%:*}.txt" 2>/dev/null || rm -f "$DINFO/crontab-${u%%:*}.txt"; done
ok "$(L 'Informações salvas.' 'Information saved.')"

# ---------- 2. Lista de programas ----------
titulo "$(L '2/5  Lista de programas instalados' '2/5  List of installed programs')"
if [ "$FAMILIA" = apt ]; then
    apt-mark showmanual 2>/dev/null | sort -u > "$DPROG/pacotes-apt.txt"
    dpkg-query -W -f='${Package}\t${Version}\n' > "$DPROG/todos-os-pacotes.txt" 2>/dev/null
    mkdir -p "$DPROG/fontes-apt" && cp -a /etc/apt/sources.list /etc/apt/sources.list.d "$DPROG/fontes-apt/" 2>/dev/null
    ok "$(wc -l < "$DPROG/pacotes-apt.txt") $(L 'pacotes instalados por você (apt).' 'packages installed by you (apt).')"
else
    dnf repoquery --userinstalled --queryformat '%{name}\n' 2>/dev/null | grep -v '^$' | sort -u > "$DPROG/pacotes-dnf.txt"
    rpm -qa --qf '%{NAME}\t%{VERSION}\n' 2>/dev/null | sort > "$DPROG/todos-os-pacotes.txt"
    mkdir -p "$DPROG/fontes-dnf" && cp -a /etc/yum.repos.d "$DPROG/fontes-dnf/" 2>/dev/null
    ok "$(wc -l < "$DPROG/pacotes-dnf.txt") $(L 'pacotes instalados por você (dnf).' 'packages installed by you (dnf).')"
fi
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application,origin 2>/dev/null > "$DPROG/flatpak.txt"
    flatpak remotes --columns=name,url 2>/dev/null > "$DPROG/flatpak-remotes.txt"
    ok "$(wc -l < "$DPROG/flatpak.txt") $(L 'aplicativos Flatpak.' 'Flatpak apps.')"
fi
if command -v snap >/dev/null 2>&1; then
    snap list 2>/dev/null | awk 'NR > 1 { print $1 "\t" ($6 ~ /classic/ ? "classic" : "") }' > "$DPROG/snap.txt"
    ok "$(wc -l < "$DPROG/snap.txt") $(L 'pacotes Snap.' 'Snap packages.')"
fi
RESUMO+=("[OK] $(L 'Lista de programas' 'Program list')")

# ---------- 3. Wi-Fi ----------
titulo "$(L '3/5  Redes Wi-Fi e senhas' '3/5  Wi-Fi networks and passwords')"
NM="/etc/NetworkManager/system-connections"
if [ -d "$NM" ]; then
    cp -a "$NM"/. "$DWIFI"/ 2>/dev/null
    NWIFI=$(grep -ls '^type=wifi' "$DWIFI"/* 2>/dev/null | wc -l)
    ok "$NWIFI $(L 'redes Wi-Fi salvas.' 'Wi-Fi networks saved.')"
    RESUMO+=("[OK] $NWIFI $(L 'redes Wi-Fi' 'Wi-Fi networks')")
else
    msg "$(L 'NetworkManager não encontrado: nenhuma rede salva.' 'NetworkManager not found: no networks saved.')"
fi

# ---------- 4. Arquivos ----------
titulo "$(L '4/5  Copiando arquivos' '4/5  Copying files') ($(gb "$TOTAL"))"
: > "$DESTINO/04_OutrasPastas/caminhos.txt"
n=0; QTD=${#T_GRUPO[@]}
for i in "${!T_GRUPO[@]}"; do
    n=$((n + 1))
    echo; echo "${AZUL}  [$n/$QTD] ${T_GRUPO[$i]}${N}"
    origem="${T_ORIGEM[$i]}"; dest="$DESTINO/${T_REL[$i]}"
    [ -e "$origem" ] || continue
    mkdir -p "$dest"
    [[ "${T_REL[$i]}" == 04_OutrasPastas/* ]] && printf '%s\t%s\n' "${T_REL[$i]#04_OutrasPastas/}" "$origem" >> "$DESTINO/04_OutrasPastas/caminhos.txt"
    filtros "${T_FILTRO[$i]}"
    # shellcheck disable=SC2086
    rsync $RSYNC_OPTS --info=progress2 "${FILTROS[@]}" "$origem/" "$dest/" 2>> "$LOG"
    rc=$?
    case $rc in
        0)     RESUMO+=("[OK] ${T_GRUPO[$i]}") ;;
        23|24) aviso "$(L 'Alguns arquivos não puderam ser copiados (veja o log).' 'Some files could not be copied (see the log).')"; RESUMO+=("[!]  ${T_GRUPO[$i]} $(L '(com erros, ver log)' '(with errors, see log)')") ;;
        *)     erro "$(L "Erro $rc ao copiar (veja o log)." "Error $rc while copying (see the log).")"; RESUMO+=("[!]  ${T_GRUPO[$i]} ($(L erro error) $rc)") ;;
    esac
done

# ---------- 5. Fim ----------
titulo "$(L '5/5  Finalizando' '5/5  Finishing')"
DURACAO=$(( $(date +%s) - INICIO ))
TEMPO="$(printf '%02d:%02d:%02d' $((DURACAO / 3600)) $((DURACAO % 3600 / 60)) $((DURACAO % 60)))"
TAMANHO="$(du -sb "$DESTINO" 2>/dev/null | cut -f1)"
{
    echo "$(L 'BACKUP CONCLUÍDO' 'BACKUP COMPLETE') - $(date)"
    echo "$(L 'Duração' 'Duration'): $TEMPO"
    echo "$(L 'Tamanho' 'Size'): $(gb "$TAMANHO")"
    echo
    printf '%s\n' "${RESUMO[@]}"
} > "$DESTINO/RESUMO.txt"

titulo "$(L 'BACKUP CONCLUÍDO' 'BACKUP COMPLETE')"
for r in "${RESUMO[@]}"; do
    if [[ "$r" == "[!]"* ]]; then aviso "${r:5}"; else msg "$r"; fi
done
echo
ok "$(L 'Tempo' 'Time'): $TEMPO   $(L 'Tamanho' 'Size'): $(gb "$TAMANHO")"
ok "$(L 'Salvo em' 'Saved to'): $DESTINO"
msg "$(L 'Para passar para o outro computador: ligue o disco nele e rode  bash restaurar.sh' 'To move it to the other computer: connect the disk there and run  bash restaurar.sh')"
sync
sair 0
