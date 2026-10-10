#!/usr/bin/env bash
# =====================================================================
#  BACKUP DO COMPUTADOR (LINUX) - Ubuntu, Debian e Fedora
#  ------------------------------------------------------
#  Como usar: copie esta pasta para o HD externo, abra um terminal nela e rode
#      bash backup.sh
#  O backup é salvo em <DISCO>/BACKUP_PC/<NOME-DO-PC>_<data>/
# =====================================================================

set -o pipefail

# ---------- Rodar como administrador ----------
SCRIPT="$(readlink -f "$0")"
if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa de permissão de administrador (digite sua senha)."
    exec sudo bash "$SCRIPT" "$@"
fi
SCRIPT_DIR="$(dirname "$SCRIPT")"

# Impede o computador de suspender durante o backup
if [ -z "${BACKUP_INIBIDO:-}" ] && command -v systemd-inhibit >/dev/null 2>&1 && systemd-inhibit --list >/dev/null 2>&1; then
    export BACKUP_INIBIDO=1
    exec systemd-inhibit --what=sleep:idle:handle-lid-switch --who="Backup" --why="Backup em andamento" bash "$SCRIPT" "$@"
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
perguntar() { local r; while true; do entrada "  $1 (S/N) " r; case "${r^^}" in S) return 0 ;; N) return 1 ;; esac; done; }
sair()      { echo; read -r -p "  Pressione ENTER para fechar " _; exit "${1:-0}"; }
# Lê uma resposta; se a entrada acabar (sem teclado), encerra em vez de perguntar para sempre
entrada()   { read -r -p "$@" || { echo; erro "Sem resposta (a entrada foi encerrada). Saindo."; exit 1; }; }
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
    if [ "$m" = "/" ]; then echo "$DISTRO_NOME (este sistema)"; return; fi
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
    if [ -n "$pai" ] && [ "$(lsblk -dno TRAN "/dev/$pai" 2>/dev/null)" = "usb" ]; then echo "USB/externo"; else echo "interno"; fi
}

# Lista os discos e deixa escolher. Define DEST_MNT e DEST_FS.
escolher_destino() {
    local padrao="$1"; shift
    local proibidos=" $* " a o f i n r idx_padrao=-1
    mapfile -t DISCOS < <(listar_discos | while IFS='|' read -r a o f; do [[ "$proibidos" == *" $a "* ]] || echo "$a|$o|$f"; done)
    if [ "${#DISCOS[@]}" -eq 0 ]; then
        erro "Nenhum disco encontrado. Conecte o HD externo e abra ele no gerenciador de arquivos (para ser montado)."
        sair 1
    fi
    msg "Em qual disco salvar o backup?"
    for i in "${!DISCOS[@]}"; do
        IFS='|' read -r a o f <<< "${DISCOS[$i]}"
        local marca="" rotulo so
        rotulo="$(lsblk -no LABEL "$o" 2>/dev/null | head -1)"
        if [ "$a" = "$padrao" ]; then marca="  <- onde estão os scripts"; idx_padrao=$i; fi
        printf "   [%d] %-30s %-14s livre: %9s de %9s  %-6s %s%s\n" $((i + 1)) "$a" "$rotulo" \
            "$(gb "$(livre_bytes "$a")")" "$(gb "$(total_bytes "$a")")" "$f" "$(tipo_disco "$o")" "$marca"
        so="$(detectar_so "$a")"
        if [ -n "$so" ]; then echo "${AMARELO}         Sistema instalado: $so${N}"
        else echo "${CINZA}         Sem sistema operacional (bom para guardar backups)${N}"; fi
    done
    local dica=""; [ "$idx_padrao" -ge 0 ] && dica=" (ENTER = $((idx_padrao + 1)))"
    while true; do
        entrada "  Número do disco$dica: " r
        if [ -z "$r" ] && [ "$idx_padrao" -ge 0 ]; then n=$((idx_padrao + 1)); else n="$r"; fi
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#DISCOS[@]}" ] && break
    done
    IFS='|' read -r DEST_MNT o DEST_FS <<< "${DISCOS[$((n - 1))]}"
    case "$DEST_FS" in
        vfat) aviso "Este disco é FAT32: arquivos maiores que 4 GB NÃO cabem e as permissões não são guardadas."
              aviso "O ideal é formatar o HD em ext4, NTFS ou exFAT." ;;
        exfat|ntfs|ntfs3|fuseblk|9p|drvfs)
              aviso "Disco $DEST_FS: os arquivos são copiados, mas as permissões do Linux (dono, chmod) não são guardadas." ;;
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
titulo "BACKUP DO COMPUTADOR (LINUX)"
msg "Computador: $(hostname)   •   $DISTRO_NOME"
case "$DISTRO_ID" in
    ubuntu|debian|fedora) ;;
    *)  if [ "$FAMILIA" = outro ]; then
            erro "Distribuição não suportada. Este script funciona no Ubuntu, Debian e Fedora."; sair 1
        fi
        aviso "$DISTRO_NOME não é oficialmente suportado, mas é parecido com ${DISTRO_PARECIDA}: vou tentar." ;;
esac

if ! command -v rsync >/dev/null 2>&1; then
    msg "Instalando o rsync (necessário para copiar)..."
    [ "$FAMILIA" = apt ] && apt-get update -qq
    instalar rsync >/dev/null || { erro "Não foi possível instalar o rsync."; sair 1; }
fi
echo

# ---------- 1. Onde salvar ----------
escolher_destino "$(findmnt -n -o TARGET --target "$SCRIPT_DIR" 2>/dev/null)"
ok "Backup será salvo em $DEST_MNT"

# ---------- 2. O que copiar ----------
titulo "O QUE VAI ENTRAR NO BACKUP"

mapfile -t USUARIOS < <(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1 ":" $6 }' |
                        while IFS=: read -r u h; do [ -d "$h" ] && echo "$u:$h"; done)
msg "Usuários encontrados (todos entram no backup):"
for u in "${USUARIOS[@]}"; do msg "   - ${u%%:*}  (${u#*:})"; done

EXTRAS_CANDIDATOS=(/opt /srv /var/www /usr/local)
EXTRAS=()
echo
msg "Pastas do sistema que costumam ter coisas instaladas por você:"
for p in "${EXTRAS_CANDIDATOS[@]}"; do
    [ -d "$p" ] && [ -n "$(ls -A "$p" 2>/dev/null)" ] || continue
    if perguntar "   Copiar $p?"; then EXTRAS+=("$p"); fi
done

OUTROS=()
mapfile -t _outros < <(listar_discos | cut -d'|' -f1 | grep -vxF "$DEST_MNT")
for d in "${_outros[@]}"; do
    [ -n "$d" ] || continue
    echo
    so="$(detectar_so "$d")"
    if [ -n "$so" ]; then aviso "O disco $d tem outro sistema instalado ($so). Só os arquivos dele podem ser copiados, não o sistema."
    else msg "O disco $d não tem nenhum sistema operacional: só arquivos."; fi
    usado=$(( $(total_bytes "$d") - $(livre_bytes "$d") ))
    if perguntar "Copiar o disco $d inteiro? Usado: $(gb "$usado")"; then OUTROS+=("$d"); fi
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
    nova_tarefa "Usuário $nome - arquivos"      "$casa" "02_Usuarios/$nome/Home" home_arquivos
    nova_tarefa "Usuário $nome - configurações" "$casa" "02_Usuarios/$nome/Home" home_config
done
for p in "${EXTRAS[@]}"; do nova_tarefa "Pasta $p" "$p" "04_OutrasPastas/$(echo "${p#/}" | tr '/' '_')" nenhum; done
for d in "${OUTROS[@]}"; do nova_tarefa "Disco $d inteiro" "$d" "04_OutrasPastas/disco_$(basename "$d")" disco; done
nova_tarefa "Configurações do sistema (/etc, só para consulta)" /etc "00_Info/etc" nenhum

# ---------- 4. Verificar se cabe ----------
titulo "CALCULANDO O TAMANHO DO BACKUP"
msg "Isso não copia nada, só mede. Pode levar alguns minutos..."
medir() {
    filtros "${T_FILTRO[$1]}"
    [ -e "${T_ORIGEM[$1]}" ] || { echo 0; return; }
    local v
    v="$(LC_ALL=C rsync -rn --stats "${FILTROS[@]}" "${T_ORIGEM[$1]}/" "/tmp/medir_inexistente_$$/" 2>/dev/null |
         awk -F': ' '/^Total file size/ { gsub(/[^0-9]/, "", $2); print $2; exit }')"
    echo "${v:-0}"
}
for i in "${!T_GRUPO[@]}"; do
    echo "${CINZA}  medindo ${T_GRUPO[$i]}${N}"
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
    printf "      %10s   TOTAL do backup\n" "$(gb "$TOTAL")"
    printf "      %10s   necessário com margem de segurança\n" "$(gb "$NECESSARIO")"
    printf "      %10s   livre em %s\n" "$(gb "$LIVRE")" "$DEST_MNT"
    echo

    if [ "$LIVRE" -ge "$NECESSARIO" ]; then ok "Cabe! Vão sobrar $(gb $(( LIVRE - NECESSARIO ))) em $DEST_MNT."; break; fi
    [ "$FORCAR" = 1 ] && break

    erro "NÃO CABE: faltam $(gb $(( NECESSARIO - LIVRE ))) em $DEST_MNT."
    msg "[1] Escolher outro disco"
    msg "[2] Tirar itens do backup"
    msg "[3] Continuar mesmo assim (vai parar quando o disco encher)"
    msg "[0] Cancelar"
    entrada "  Opção: " op
    case "$op" in
        1) escolher_destino "" "${OUTROS[@]}" ;;
        2) entrada "  Números dos itens para tirar, separados por vírgula (ex: 3,4): " r
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
aviso "FECHE os programas abertos (navegador, e-mail, jogos...) antes de continuar."
aviso "Se for notebook, deixe ligado na tomada. Pode demorar bastante."
perguntar "Começar o backup agora?" || sair 0

# ---------- Pastas de destino ----------
INICIO=$(date +%s)
DESTINO="$DEST_MNT/BACKUP_PC/$(hostname)_$(date +%Y-%m-%d_%H-%M)"
DINFO="$DESTINO/00_Info"; DPROG="$DESTINO/01_Programas"; DWIFI="$DESTINO/03_WiFi"
mkdir -p "$DINFO" "$DPROG" "$DWIFI" "$DESTINO/04_OutrasPastas" || { erro "Não foi possível criar a pasta em $DEST_MNT."; sair 1; }
LOG="$DINFO/log-copia.txt"
RESUMO=()

# ---------- 1. Informações do sistema ----------
titulo "1/5  Informações do sistema"
{
    echo "Data do backup  : $(date)"
    echo "Computador      : $(hostname)"
    echo "Usuário         : ${SUDO_USER:-root}"
    echo "Sistema         : $DISTRO_NOME"
    echo "Kernel          : $(uname -r)"
    echo "Fabricante      : $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
    echo "Processador     : $(LC_ALL=C lscpu 2>/dev/null | awk -F': +' '/Model name/ { print $2; exit }')"
    echo "Memória         : $(free -h 2>/dev/null | awk '/^Mem/ { print $2 }')"
    echo
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null
} > "$DINFO/sistema.txt"
# Marca de origem: o restaurar usa para saber de onde veio o backup
printf 'linux\n%s\n%s\n%s\n' "$DISTRO_ID" "$DISTRO_VERSAO" "$FAMILIA" > "$DINFO/origem.txt"
for u in "${USUARIOS[@]}"; do crontab -l -u "${u%%:*}" > "$DINFO/crontab-${u%%:*}.txt" 2>/dev/null || rm -f "$DINFO/crontab-${u%%:*}.txt"; done
ok "Informações salvas."

# ---------- 2. Lista de programas ----------
titulo "2/5  Lista de programas instalados"
if [ "$FAMILIA" = apt ]; then
    apt-mark showmanual 2>/dev/null | sort -u > "$DPROG/pacotes-apt.txt"
    dpkg-query -W -f='${Package}\t${Version}\n' > "$DPROG/todos-os-pacotes.txt" 2>/dev/null
    mkdir -p "$DPROG/fontes-apt" && cp -a /etc/apt/sources.list /etc/apt/sources.list.d "$DPROG/fontes-apt/" 2>/dev/null
    ok "$(wc -l < "$DPROG/pacotes-apt.txt") pacotes instalados por você (apt)."
else
    dnf repoquery --userinstalled --queryformat '%{name}\n' 2>/dev/null | grep -v '^$' | sort -u > "$DPROG/pacotes-dnf.txt"
    rpm -qa --qf '%{NAME}\t%{VERSION}\n' 2>/dev/null | sort > "$DPROG/todos-os-pacotes.txt"
    mkdir -p "$DPROG/fontes-dnf" && cp -a /etc/yum.repos.d "$DPROG/fontes-dnf/" 2>/dev/null
    ok "$(wc -l < "$DPROG/pacotes-dnf.txt") pacotes instalados por você (dnf)."
fi
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application,origin 2>/dev/null > "$DPROG/flatpak.txt"
    flatpak remotes --columns=name,url 2>/dev/null > "$DPROG/flatpak-remotes.txt"
    ok "$(wc -l < "$DPROG/flatpak.txt") aplicativos Flatpak."
fi
if command -v snap >/dev/null 2>&1; then
    snap list 2>/dev/null | awk 'NR > 1 { print $1 "\t" ($6 ~ /classic/ ? "classic" : "") }' > "$DPROG/snap.txt"
    ok "$(wc -l < "$DPROG/snap.txt") pacotes Snap."
fi
RESUMO+=("[OK] Lista de programas")

# ---------- 3. Wi-Fi ----------
titulo "3/5  Redes Wi-Fi e senhas"
NM="/etc/NetworkManager/system-connections"
if [ -d "$NM" ]; then
    cp -a "$NM"/. "$DWIFI"/ 2>/dev/null
    NWIFI=$(grep -ls '^type=wifi' "$DWIFI"/* 2>/dev/null | wc -l)
    ok "$NWIFI redes Wi-Fi salvas."
    RESUMO+=("[OK] $NWIFI redes Wi-Fi")
else
    msg "NetworkManager não encontrado: nenhuma rede salva."
fi

# ---------- 4. Arquivos ----------
titulo "4/5  Copiando arquivos ($(gb "$TOTAL"))"
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
        23|24) aviso "Alguns arquivos não puderam ser copiados (veja o log)."; RESUMO+=("[!]  ${T_GRUPO[$i]} (com erros, ver log)") ;;
        *)     erro "Erro $rc ao copiar (veja o log)."; RESUMO+=("[!]  ${T_GRUPO[$i]} (erro $rc, ver log)") ;;
    esac
done

# ---------- 5. Fim ----------
titulo "5/5  Finalizando"
DURACAO=$(( $(date +%s) - INICIO ))
TEMPO="$(printf '%02d:%02d:%02d' $((DURACAO / 3600)) $((DURACAO % 3600 / 60)) $((DURACAO % 60)))"
TAMANHO="$(du -sb "$DESTINO" 2>/dev/null | cut -f1)"
{
    echo "BACKUP CONCLUÍDO - $(date)"
    echo "Duração: $TEMPO"
    echo "Tamanho: $(gb "$TAMANHO")"
    echo
    printf '%s\n' "${RESUMO[@]}"
} > "$DESTINO/RESUMO.txt"

titulo "BACKUP CONCLUÍDO"
for r in "${RESUMO[@]}"; do
    if [[ "$r" == "[!]"* ]]; then aviso "${r:5}"; else msg "$r"; fi
done
echo
ok "Tempo: $TEMPO   Tamanho: $(gb "$TAMANHO")"
ok "Salvo em: $DESTINO"
msg "Para passar para o outro computador: ligue o disco nele e rode  bash restaurar.sh"
sync
sair 0
