#!/usr/bin/env bash
# =====================================================================
#  HERMIT - RESTORE THE BACKUP (LINUX)
#  Ubuntu, Debian and Fedora
#  ----------------------------------------------------
#  Usage:   bash restore.sh [--idioma pt|en]
#  Works with backups made on Linux and also with backups made on Windows
#  (in that case it restores personal files and Wi-Fi networks).
# =====================================================================

set -o pipefail

SCRIPT="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT")"

# ---------- Language ----------
PEDIDO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --idioma|--lang) PEDIDO="${2:-}"; shift 2 ;;
        --idioma=*|--lang=*) PEDIDO="${1#*=}"; shift ;;
        *) shift ;;
    esac
done
# shellcheck source=language.sh
source "$SCRIPT_DIR/language.sh"
IDIOMA="$(detectar_idioma "$PEDIDO")"

if [ "$EUID" -ne 0 ]; then
    L "Este script precisa de permissão de administrador (digite sua senha)." "This script needs administrator permission (type your password)."; echo
    exec sudo bash "$SCRIPT" --idioma "$IDIOMA"
fi

if [ -z "${BACKUP_INIBIDO:-}" ] && command -v systemd-inhibit >/dev/null 2>&1 && systemd-inhibit --list >/dev/null 2>&1; then
    export BACKUP_INIBIDO=1
    exec systemd-inhibit --what=sleep:idle:handle-lid-switch --who="Backup" --why="Restore" bash "$SCRIPT" --idioma "$IDIOMA"
fi

TRANSCRIPT="$SCRIPT_DIR/last-run-restore.txt"
: > "$TRANSCRIPT" 2>/dev/null && exec > >(tee -a "$TRANSCRIPT") 2>&1

AZUL=$'\e[36m'; VERDE=$'\e[32m'; AMARELO=$'\e[33m'; VERMELHO=$'\e[31m'; CINZA=$'\e[90m'; N=$'\e[0m'
LINHA="$(printf '=%.0s' {1..70})"
titulo()    { echo; echo "${AZUL}${LINHA}${N}"; echo "${AZUL}  $*${N}"; echo "${AZUL}${LINHA}${N}"; }
ok()        { echo "${VERDE}  [OK] $*${N}"; }
aviso()     { echo "${AMARELO}  [!]  $*${N}"; }
erro()      { echo "${VERMELHO}  [X]  $*${N}"; }
msg()       { echo "  $*"; }
# Reads an answer; if input ends (no keyboard), exits instead of asking forever
entrada()   { read -r -p "$@" || { echo; erro "$(L 'Sem resposta (a entrada foi encerrada). Saindo.' 'No answer (input was closed). Exiting.')"; exit 1; }; }
perguntar() {
    local r sn; sn="$(L '(S/N)' '(Y/N)')"
    while true; do entrada "  $1 $sn " r; case "${r^^}" in S|Y) return 0 ;; N) return 1 ;; esac; done
}
sair()      { echo; read -r -p "  $(L 'Pressione ENTER para fechar' 'Press ENTER to close') " _; exit "${1:-0}"; }
gb()        { awk -v b="${1:-0}" 'BEGIN { printf "%.1f GB", b / 1073741824 }'; }
escolher()  {   # $1 = question; the rest = options. Sets ESCOLHA (zero-based index)
    local p="$1"; shift; local i n
    msg "$p"
    i=1; for o in "$@"; do msg "   [$i] $o"; i=$((i + 1)); done
    while true; do
        entrada "  $(L 'Número' 'Number'): " n
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$#" ] && break
    done
    ESCOLHA=$((n - 1))
}

# ---------- Current system ----------
ler_os_release() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2- | tr -d '"'; }
DISTRO_ID="$(ler_os_release /etc/os-release ID)"
DISTRO_PARECIDA="$(ler_os_release /etc/os-release ID_LIKE)"
DISTRO_NOME="$(ler_os_release /etc/os-release PRETTY_NAME)"
case " $DISTRO_ID $DISTRO_PARECIDA " in
    *" fedora "*|*" rhel "*)  FAMILIA=dnf ;;
    *" debian "*|*" ubuntu "*) FAMILIA=apt ;;
    *) FAMILIA=outro ;;
esac
instalar() { case "$FAMILIA" in apt) apt-get install -y "$@" ;; dnf) dnf install -y "$@" ;; esac; }

# Reads a line from a file that came from Windows (strips BOM and \r)
primeira_linha() { head -1 "$1" 2>/dev/null | tr -d '\r' | sed 's/^\xEF\xBB\xBF//'; }

# XDG folder (Desktop, Documents...) of a home. $1 = home, $2 = DESKTOP|DOCUMENTS|DOWNLOAD|MUSIC|PICTURES|VIDEOS
pasta_xdg() {
    local casa="$1" chave="$2" linha valor
    linha="$(grep -m1 "^XDG_${chave}_DIR=" "$casa/.config/user-dirs.dirs" 2>/dev/null)"
    valor="${linha#*=}"; valor="${valor//\"/}"; valor="${valor/\$HOME/$casa}"
    if [ -z "$linha" ] || [ "$valor" = "$casa" ] || [ "$valor" = "$casa/" ]; then
        case "$chave" in
            DESKTOP) valor="$casa/Desktop" ;; DOCUMENTS) valor="$casa/Documents" ;; DOWNLOAD) valor="$casa/Downloads" ;;
            MUSIC) valor="$casa/Music" ;; PICTURES) valor="$casa/Pictures" ;; VIDEOS) valor="$casa/Videos" ;;
        esac
    fi
    echo "$valor"
}

# =====================================================================
titulo "$(L 'RESTAURAR BACKUP (LINUX)' 'RESTORE BACKUP (LINUX)')"
msg "$(L 'Este computador' 'This computer'): $(hostname)   •   $DISTRO_NOME"
if [ "$FAMILIA" = outro ]; then erro "$(L 'Distribuição não suportada. Este script funciona no Ubuntu, Debian e Fedora.' 'Unsupported distribution. This script works on Ubuntu, Debian and Fedora.')"; sair 1; fi
if ! command -v rsync >/dev/null 2>&1; then
    msg "$(L 'Instalando o rsync...' 'Installing rsync...')"; [ "$FAMILIA" = apt ] && apt-get update -qq; instalar rsync >/dev/null
fi

# ---------- Look for backups on all mounted disks ----------
mapfile -t MONTAGENS < <( { findmnt -rn -o TARGET 2>/dev/null | while read -r m; do printf '%b\n' "$m"; done
                            findmnt -n -o TARGET --target "$SCRIPT_DIR" 2>/dev/null
                            dirname "$SCRIPT_DIR"; } |
                          grep -vE '^/(proc|sys|dev|run/user|snap)(/|$)' | sort -u)
mapfile -t BACKUPS < <(for m in "${MONTAGENS[@]}"; do
                           for p in "$m/BACKUP_PC" "$m/BACKUP_NOTEBOOK"; do
                               [ -d "$p" ] && find "$p" -mindepth 1 -maxdepth 1 -type d -printf '%T@\t%p\n' 2>/dev/null
                           done
                       done | sort -rn -u | cut -f2-)
if [ "${#BACKUPS[@]}" -eq 0 ]; then
    erro "$(L 'Nenhum backup encontrado. Conecte o disco com a pasta BACKUP_PC, abra ele no gerenciador de arquivos e rode de novo.' 'No backup found. Connect the disk with the BACKUP_PC folder, open it in the file manager and run again.')"
    sair 1
fi
if [ "${#BACKUPS[@]}" -eq 1 ]; then BK="${BACKUPS[0]}"; else escolher "$(L 'Qual backup restaurar?' 'Which backup do you want to restore?')" "${BACKUPS[@]}"; BK="${BACKUPS[$ESCOLHA]}"; fi
ok "Backup: $BK"
[ -f "$BK/00_Info/sistema.txt" ] && head -6 "$BK/00_Info/sistema.txt" | tr -d '\r' | sed 's/^\xEF\xBB\xBF//; s/^/     /'

# Where did the backup come from?
ORIGEM="windows"; BK_FAMILIA=""
if [ -f "$BK/00_Info/origem.txt" ] && [ "$(primeira_linha "$BK/00_Info/origem.txt")" = "linux" ]; then
    ORIGEM="linux"; BK_FAMILIA="$(sed -n 4p "$BK/00_Info/origem.txt")"
fi
if [ "$ORIGEM" = windows ]; then
    echo
    aviso "$(L 'Este backup foi feito no WINDOWS.' 'This backup was made on WINDOWS.')"
    msg "$(L 'Dá para restaurar os arquivos pessoais (Área de Trabalho, Documentos, Fotos...) e as redes Wi-Fi.' 'Personal files (Desktop, Documents, Pictures...) and Wi-Fi networks can be restored.')"
    msg "$(L 'Os programas do Windows não funcionam no Linux: a lista deles vai para a sua Área de Trabalho.' 'Windows programs do not work on Linux: their list goes to your Desktop.')"
fi

# ---------- Check if it fits ----------
echo
msg "$(L 'Calculando o tamanho do backup...' 'Calculating the backup size...')"
TAM_BK="$(du -sb "$BK" 2>/dev/null | cut -f1)"
LIVRE="$(df -B1 --output=avail /home 2>/dev/null | tail -1 | tr -d ' ')"
NECESSARIO=$(( TAM_BK + TAM_BK / 20 + 5368709120 ))     # margin + room for the programs
msg "$(L 'Tamanho do backup' 'Backup size      ') : $(gb "$TAM_BK")"
msg "$(L 'Livre em /home   ' 'Free on /home    ') : $(gb "$LIVRE")"
if [ "$LIVRE" -ge "$NECESSARIO" ]; then ok "$(L 'Tem espaço suficiente.' 'There is enough space.')"
else
    erro "$(L "Pode NÃO caber: faltam cerca de $(gb $(( NECESSARIO - LIVRE )))." "It may NOT fit: about $(gb $(( NECESSARIO - LIVRE ))) missing.")"
    msg "$(L 'Dica: restaure por partes pelo menu.' 'Tip: restore in parts using the menu.')"
    perguntar "$(L 'Continuar mesmo assim?' 'Continue anyway?')" || sair 0
fi

# A backup stored on a Linux disk (ext4...) keeps permissions; on NTFS/exFAT it does not
FS_BK="$(findmnt -n -o FSTYPE --target "$BK" 2>/dev/null)"
case "$FS_BK" in ext*|xfs|btrfs|f2fs) PERMS="-p" ;; *) PERMS="-p --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r" ;; esac

# Names of folders and files created on the new computer
PASTA_WINDOWS="$(L 'Arquivos do Windows' 'Windows files')"
ARQ_FALTAM="$(L 'PROGRAMAS QUE FALTAM INSTALAR.txt' 'PROGRAMS TO INSTALL MANUALLY.txt')"
ARQ_PROG_WIN="$(L 'Programas do Windows antigo.txt' 'Programs from the old Windows.txt')"

# ---------- User selection ----------
USUARIO_BK=""; ALVO_USER=""; ALVO_HOME=""
selecionar_usuario() {
    [ -n "$USUARIO_BK" ] && return 0
    mapfile -t US < <(find "$BK/02_Usuarios" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
    if [ "${#US[@]}" -eq 0 ]; then aviso "$(L 'Não há usuários neste backup.' 'There are no users in this backup.')"; return 1; fi
    if [ "${#US[@]}" -eq 1 ]; then USUARIO_BK="$BK/02_Usuarios/${US[0]}"
    else escolher "$(L 'Restaurar os arquivos de qual usuário do computador antigo?' 'Restore the files of which user from the old computer?')" "${US[@]}"; USUARIO_BK="$BK/02_Usuarios/${US[$ESCOLHA]}"; fi

    ALVO_USER="${SUDO_USER:-}"
    if [ -z "$ALVO_USER" ] || [ "$ALVO_USER" = root ] || ! perguntar "$(L "Restaurar '$(basename "$USUARIO_BK")' para o usuário '$ALVO_USER' deste computador?" "Restore '$(basename "$USUARIO_BK")' to the user '$ALVO_USER' on this computer?")"; then
        entrada "  $(L 'Digite o nome do usuário de destino' 'Type the destination user name'): " ALVO_USER
    fi
    ALVO_HOME="$(getent passwd "$ALVO_USER" | cut -d: -f6)"
    if [ -z "$ALVO_HOME" ] || [ ! -d "$ALVO_HOME" ]; then erro "$(L "Usuário '$ALVO_USER' não existe." "User '$ALVO_USER' does not exist.")"; USUARIO_BK=""; return 1; fi
    ALVO_GRUPO="$(id -gn "$ALVO_USER")"
    return 0
}

# Copies with rsync, setting the file owner to the destination user
copiar_para_usuario() {   # $1 source, $2 destination, the rest = extra options
    local o="$1" d="$2"; shift 2
    [ -e "$o" ] || return 0
    mkdir -p "$d" && chown "$ALVO_USER:$ALVO_GRUPO" "$d"
    echo "${CINZA}  -> $d${N}"
    # shellcheck disable=SC2086
    rsync -rlt -og $PERMS --chown="$ALVO_USER:$ALVO_GRUPO" --info=progress2 "$@" "$o/" "$d/" 2>> "$TRANSCRIPT"
    local rc=$?
    [ $rc -ne 0 ] && aviso "$(L "Alguns arquivos não foram copiados para '$d' (código $rc)." "Some files were not copied to '$d' (code $rc).")"
    return 0
}

# ---------- Steps ----------
restaurar_wifi() {
    titulo "$(L 'Redes Wi-Fi' 'Wi-Fi networks')"
    if ! command -v nmcli >/dev/null 2>&1; then aviso "$(L 'NetworkManager não encontrado: não dá para importar as redes.' 'NetworkManager not found: networks cannot be imported.')"; return; fi
    local n=0 f
    if [ "$ORIGEM" = linux ]; then
        local NM="/etc/NetworkManager/system-connections"
        mkdir -p "$NM"
        for f in "$BK/03_WiFi"/*; do
            [ -f "$f" ] && grep -q '^type=wifi' "$f" || continue
            # removes the old network adapter name, otherwise the network will not connect on the new adapter
            sed '/^interface-name=/d; /^mac-address=/d' "$f" > "$NM/$(basename "$f")"
            chmod 600 "$NM/$(basename "$f")"; chown root:root "$NM/$(basename "$f")"
            n=$((n + 1))
        done
        nmcli connection reload
    else
        # Profiles exported by Windows (XML)
        for f in "$BK/03_WiFi"/*.xml; do
            [ -f "$f" ] || continue
            local x ssid chave auth
            x="$(tr -d '\000\r' < "$f")"
            ssid="$(sed -n 's:.*<name>\(.*\)</name>.*:\1:p' <<< "$x" | head -1)"
            chave="$(sed -n 's:.*<keyMaterial>\(.*\)</keyMaterial>.*:\1:p' <<< "$x" | head -1)"
            auth="$(sed -n 's:.*<authentication>\(.*\)</authentication>.*:\1:p' <<< "$x" | head -1)"
            [ -n "$ssid" ] || continue
            nmcli connection delete id "$ssid" >/dev/null 2>&1
            case "$auth" in
                open) nmcli connection add type wifi con-name "$ssid" ssid "$ssid" >/dev/null && n=$((n + 1)) ;;
                WPA3SAE) nmcli connection add type wifi con-name "$ssid" ssid "$ssid" wifi-sec.key-mgmt sae wifi-sec.psk "$chave" >/dev/null && n=$((n + 1)) ;;
                WPA2PSK|WPAPSK) nmcli connection add type wifi con-name "$ssid" ssid "$ssid" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$chave" >/dev/null && n=$((n + 1)) ;;
                *) aviso "$(L "Rede '$ssid' usa login corporativo ($auth): configure manualmente." "Network '$ssid' uses enterprise login ($auth): set it up manually.")" ;;
            esac
        done
    fi
    ok "$n $(L 'redes Wi-Fi adicionadas.' 'Wi-Fi networks added.')"
}

restaurar_programas() {
    titulo "$(L 'Reinstalar programas' 'Reinstall programs')"
    selecionar_usuario || return
    local FALTAM=() p desktop
    desktop="$(pasta_xdg "$ALVO_HOME" DESKTOP)"; mkdir -p "$desktop"

    if [ "$ORIGEM" = windows ]; then
        cp "$BK/01_Programas/programas-instalados.txt" "$desktop/$ARQ_PROG_WIN" 2>/dev/null
        chown "$ALVO_USER:$ALVO_GRUPO" "$desktop/$ARQ_PROG_WIN" 2>/dev/null
        ok "$(L 'Lista dos programas do Windows salva na Área de Trabalho, para você procurar as versões de Linux.' 'List of Windows programs saved on the Desktop, so you can look for the Linux versions.')"
        return
    fi

    # System packages (only if the backup came from the same family: apt->apt or dnf->dnf)
    local lista="$BK/01_Programas/pacotes-$BK_FAMILIA.txt"
    if [ "$BK_FAMILIA" != "$FAMILIA" ]; then
        aviso "$(L "O backup veio de um sistema $BK_FAMILIA e este usa $FAMILIA: os nomes dos pacotes são diferentes." "The backup came from a $BK_FAMILIA system and this one uses $FAMILIA: package names are different.")"
        aviso "$(L 'Os pacotes vão para a lista de instalação manual (Flatpak e Snap funcionam normalmente).' 'The packages go to the manual installation list (Flatpak and Snap work normally).')"
        [ -f "$lista" ] && mapfile -t FALTAM < "$lista"
    elif [ -f "$lista" ]; then
        mapfile -t PACOTES < <(grep -v '^$' "$lista")
        msg "$(L "${#PACOTES[@]} pacotes no backup. Isso precisa de internet e pode demorar." "${#PACOTES[@]} packages in the backup. This needs internet and may take a while.")"
        if [ "$FAMILIA" = apt ]; then
            apt-get update
            local DISP=()
            for p in "${PACOTES[@]}"; do
                if dpkg -s "$p" >/dev/null 2>&1; then continue; fi
                if apt-cache show "$p" >/dev/null 2>&1; then DISP+=("$p"); else FALTAM+=("$p"); fi
            done
            if [ "${#DISP[@]}" -gt 0 ]; then
                msg "$(L "Instalando ${#DISP[@]} pacotes..." "Installing ${#DISP[@]} packages...")"
                DEBIAN_FRONTEND=noninteractive apt-get install -y "${DISP[@]}" ||
                    for p in "${DISP[@]}"; do DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" >/dev/null 2>&1 || FALTAM+=("$p"); done
            fi
        else
            if dnf --version 2>/dev/null | grep -qi dnf5; then dnf install -y --skip-unavailable "${PACOTES[@]}"
            else dnf install -y --setopt=strict=0 "${PACOTES[@]}"; fi
            for p in "${PACOTES[@]}"; do rpm -q "$p" >/dev/null 2>&1 || FALTAM+=("$p"); done
        fi
        ok "$(L 'Pacotes do sistema finalizados.' 'System packages finished.')"
    fi

    # Flatpak
    if [ -s "$BK/01_Programas/flatpak.txt" ]; then
        command -v flatpak >/dev/null 2>&1 || { msg "$(L 'Instalando o Flatpak...' 'Installing Flatpak...')"; instalar flatpak >/dev/null; }
        if command -v flatpak >/dev/null 2>&1; then
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            local app remoto
            while IFS=$'\t' read -r app remoto; do
                [ -n "$app" ] || continue
                flatpak remotes --columns=name | grep -qx "$remoto" || remoto=flathub
                msg "Flatpak: $app"
                flatpak install -y --noninteractive "$remoto" "$app" >/dev/null 2>&1 || FALTAM+=("flatpak: $app")
            done < "$BK/01_Programas/flatpak.txt"
            ok "$(L 'Aplicativos Flatpak finalizados.' 'Flatpak apps finished.')"
        fi
    fi

    # Snap (skips base packages, which snap installs by itself)
    if [ -s "$BK/01_Programas/snap.txt" ]; then
        if ! command -v snap >/dev/null 2>&1 && perguntar "$(L 'O backup tem pacotes Snap. Instalar o Snap neste computador?' 'The backup has Snap packages. Install Snap on this computer?')"; then
            instalar snapd >/dev/null
            [ "$FAMILIA" = dnf ] && ln -sf /var/lib/snapd/snap /snap
            systemctl enable --now snapd.socket >/dev/null 2>&1; sleep 5
        fi
        if command -v snap >/dev/null 2>&1; then
            local nome tipo
            while IFS=$'\t' read -r nome tipo; do
                case "$nome" in ''|core*|snapd|bare|gtk-common-themes|gnome-*|kde-*|mesa-*|gtk2-common-themes|snapd-desktop-integration) continue ;; esac
                msg "Snap: $nome"
                if [ "$tipo" = classic ]; then snap install "$nome" --classic >/dev/null 2>&1 || FALTAM+=("snap: $nome")
                else snap install "$nome" >/dev/null 2>&1 || FALTAM+=("snap: $nome"); fi
            done < "$BK/01_Programas/snap.txt"
            ok "$(L 'Pacotes Snap finalizados.' 'Snap packages finished.')"
        else
            while IFS=$'\t' read -r nome _; do FALTAM+=("snap: $nome"); done < "$BK/01_Programas/snap.txt"
        fi
    fi

    if [ "${#FALTAM[@]}" -gt 0 ]; then
        local arq="$desktop/$ARQ_FALTAM"
        { L 'Estes programas estavam no computador antigo e não foram instalados automaticamente.' 'These programs were on the old computer and were not installed automatically.'; echo
          L 'Procure por eles na loja de aplicativos ou no site de cada um:' 'Look for them in the app store or on their websites:'; echo
          echo
          printf -- '- %s\n' "${FALTAM[@]}"; } > "$arq"
        chown "$ALVO_USER:$ALVO_GRUPO" "$arq"
        aviso "$(L "${#FALTAM[@]} programas precisam ser instalados manualmente. Lista salva na Área de Trabalho." "${#FALTAM[@]} programs need to be installed manually. List saved on the Desktop.")"
    else
        ok "$(L 'Todos os programas foram instalados.' 'All programs were installed.')"
    fi
}

restaurar_arquivos() {
    titulo "$(L 'Arquivos do usuário' 'User files')"
    selecionar_usuario || return
    local EXCLUIR=() chave origem destino
    local CHAVES=(DESKTOP DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS)

    if [ "$ORIGEM" = linux ]; then
        local casa_bk="$USUARIO_BK/Home"
        [ -d "$casa_bk" ] || { aviso "$(L 'Sem arquivos no backup.' 'No files in the backup.')"; return; }
        # Desktop, Documents etc. go to the right folders even if the language changed
        for chave in "${CHAVES[@]}"; do
            origem="$(pasta_xdg "$casa_bk" "$chave")"
            destino="$(pasta_xdg "$ALVO_HOME" "$chave")"
            [ -d "$origem" ] || continue
            copiar_para_usuario "$origem" "$destino" -u
            EXCLUIR+=(--exclude="/${origem#"$casa_bk"/}/")
        done
        copiar_para_usuario "$casa_bk" "$ALVO_HOME" -u --exclude='/.*' "${EXCLUIR[@]}"
    else
        local perfil="$USUARIO_BK/Perfil"
        [ -d "$perfil" ] || { aviso "$(L 'Sem arquivos no backup.' 'No files in the backup.')"; return; }
        local -A WIN=([DESKTOP]=Desktop [DOCUMENTS]=Documents [DOWNLOAD]=Downloads [MUSIC]=Music [PICTURES]=Pictures [VIDEOS]=Videos)
        local LIXO=(--exclude='desktop.ini' --exclude='Thumbs.db' --exclude='*.lnk')
        for chave in "${CHAVES[@]}"; do
            origem="$perfil/${WIN[$chave]}"
            [ -d "$origem" ] || continue
            copiar_para_usuario "$origem" "$(pasta_xdg "$ALVO_HOME" "$chave")" -u "${LIXO[@]}"
            EXCLUIR+=(--exclude="/${WIN[$chave]}/")
        done
        # The rest of the Windows user folder is kept separately
        copiar_para_usuario "$perfil" "$ALVO_HOME/$PASTA_WINDOWS" -u "${EXCLUIR[@]}" "${LIXO[@]}"
        ok "$(L "O que não era Área de Trabalho/Documentos/Downloads/Fotos/Músicas/Vídeos ficou em '$ALVO_HOME/$PASTA_WINDOWS'." "Anything that was not Desktop/Documents/Downloads/Pictures/Music/Videos was placed in '$ALVO_HOME/$PASTA_WINDOWS'.")"
    fi
    ok "$(L 'Arquivos restaurados.' 'Files restored.')"
}

restaurar_config() {
    titulo "$(L 'Configurações dos programas' 'Program settings')"
    if [ "$ORIGEM" = windows ]; then msg "$(L 'Configurações do Windows não servem no Linux: etapa pulada.' 'Windows settings do not work on Linux: step skipped.')"; return; fi
    selecionar_usuario || return
    aviso "$(L 'Faça isto DEPOIS de reinstalar os programas. Isso substitui as configurações atuais deles.' 'Do this AFTER reinstalling the programs. It replaces their current settings.')"
    aviso "$(L 'Inclui favoritos, extensões e histórico dos navegadores, chaves SSH, configurações da área de trabalho...' 'Includes browser bookmarks, extensions and history, SSH keys, desktop settings...')"
    perguntar "$(L 'Restaurar configurações agora?' 'Restore settings now?')" || return
    local abertos
    abertos="$(pgrep -u "$ALVO_USER" -l -x 'firefox|chrome|chromium|brave|thunderbird|code|discord|spotify' 2>/dev/null | awk '{print $2}' | sort -u | tr '\n' ' ')"
    if [ -n "$abertos" ]; then
        aviso "$(L 'Programas abertos' 'Open programs'): $abertos"
        perguntar "$(L 'Fechar esses programas agora?' 'Close these programs now?')" && pkill -u "$ALVO_USER" -x 'firefox|chrome|chromium|brave|thunderbird|code|discord|spotify' && sleep 2
    fi
    copiar_para_usuario "$USUARIO_BK/Home" "$ALVO_HOME" --include='/.*' --exclude='/*'
    ok "$(L 'Configurações restauradas. Saia da sessão e entre de novo (ou reinicie) para aplicar.' 'Settings restored. Log out and back in (or restart) to apply them.')"
}

restaurar_outras() {
    titulo "$(L 'Outras pastas e discos' 'Other folders and disks')"
    local base="$BK/04_OutrasPastas" rel original
    if [ ! -d "$base" ] || [ -z "$(ls -A "$base" 2>/dev/null | grep -v '^caminhos.txt$')" ]; then msg "$(L 'Nada para restaurar.' 'Nothing to restore.')"; return; fi
    if [ "$ORIGEM" = linux ] && [ -f "$base/caminhos.txt" ]; then
        while IFS=$'\t' read -r rel original <&3; do
            [ -d "$base/$rel" ] || continue
            if [[ "$rel" == disco_* ]]; then
                selecionar_usuario || return
                copiar_para_usuario "$base/$rel" "$ALVO_HOME/$(L Restaurado Restored)/$rel" -u
            elif perguntar "$(L "Restaurar $original para o mesmo lugar? (N = guardar em /root/Restaurado$original)" "Restore $original to the same place? (N = save to /root/Restored$original)")"; then
                rsync -aHu --info=progress2 "$base/$rel/" "$original/"
            else
                rsync -aHu --info=progress2 "$base/$rel/" "/root/$(L Restaurado Restored)$original/"
            fi
        done 3< "$base/caminhos.txt"
    else
        selecionar_usuario || return
        local d
        for d in "$base"/*/; do
            [ -d "$d" ] || continue
            copiar_para_usuario "${d%/}" "$ALVO_HOME/$PASTA_WINDOWS/$(L Disco Disk) $(basename "$d")" -u
        done
    fi
    ok "$(L 'Outras pastas restauradas.' 'Other folders restored.')"
}

# ---------- Menu ----------
while true; do
    titulo "$(L 'O QUE VOCÊ QUER FAZER?' 'WHAT DO YOU WANT TO DO?')"
    if [ "$ORIGEM" = linux ]; then
        msg "$(L '[1] TUDO (recomendado) - Wi-Fi, programas, arquivos, outras pastas e configurações' '[1] EVERYTHING (recommended) - Wi-Fi, programs, files, other folders and settings')"
        msg "$(L '[2] Só redes Wi-Fi' '[2] Wi-Fi networks only')"
        msg "$(L '[3] Só reinstalar programas' '[3] Reinstall programs only')"
        msg "$(L '[4] Só arquivos do usuário' '[4] User files only')"
        msg "$(L '[5] Só outras pastas / discos' '[5] Other folders / disks only')"
        msg "$(L '[6] Só configurações dos programas' '[6] Program settings only')"
    else
        msg "$(L '[1] TUDO (recomendado) - Wi-Fi, arquivos, outras pastas e lista de programas do Windows' '[1] EVERYTHING (recommended) - Wi-Fi, files, other folders and the Windows program list')"
        msg "$(L '[2] Só redes Wi-Fi' '[2] Wi-Fi networks only')"
        msg "$(L '[3] Só a lista de programas do Windows' '[3] Windows program list only')"
        msg "$(L '[4] Só arquivos do usuário' '[4] User files only')"
        msg "$(L '[5] Só outras pastas / discos' '[5] Other folders / disks only')"
    fi
    msg "$(L '[0] Sair' '[0] Exit')"
    entrada "  $(L 'Opção' 'Option'): " op
    case "$op" in
        1) restaurar_wifi; restaurar_programas; restaurar_arquivos; restaurar_outras; restaurar_config
           titulo "$(L 'TUDO PRONTO!' 'ALL DONE!')"; msg "$(L 'Registro' 'Log'): $TRANSCRIPT"; msg "$(L 'Reinicie o computador para finalizar.' 'Restart the computer to finish.')" ;;
        2) restaurar_wifi ;;
        3) restaurar_programas ;;
        4) restaurar_arquivos ;;
        5) restaurar_outras ;;
        6) [ "$ORIGEM" = linux ] && restaurar_config ;;
        0) exit 0 ;;
    esac
done
