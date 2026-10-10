#!/usr/bin/env bash
# =====================================================================
#  RESTAURAR O BACKUP (LINUX) - Ubuntu, Debian e Fedora
#  ----------------------------------------------------
#  Como usar: ligue o disco do backup, abra um terminal nesta pasta e rode
#      bash restaurar.sh
#  Funciona com backups feitos no Linux e também com backups feitos no Windows
#  (nesse caso restaura os arquivos pessoais e as redes Wi-Fi).
# =====================================================================

set -o pipefail

SCRIPT="$(readlink -f "$0")"
if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa de permissão de administrador (digite sua senha)."
    exec sudo bash "$SCRIPT" "$@"
fi
SCRIPT_DIR="$(dirname "$SCRIPT")"

if [ -z "${BACKUP_INIBIDO:-}" ] && command -v systemd-inhibit >/dev/null 2>&1 && systemd-inhibit --list >/dev/null 2>&1; then
    export BACKUP_INIBIDO=1
    exec systemd-inhibit --what=sleep:idle:handle-lid-switch --who="Backup" --why="Restauração em andamento" bash "$SCRIPT" "$@"
fi

TRANSCRIPT="$SCRIPT_DIR/ultima-execucao-restaurar.txt"
: > "$TRANSCRIPT" 2>/dev/null && exec > >(tee -a "$TRANSCRIPT") 2>&1

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
escolher()  {   # $1 = pergunta; demais = opções. Define ESCOLHA (índice a partir de 0)
    local p="$1"; shift; local i n
    msg "$p"
    i=1; for o in "$@"; do msg "   [$i] $o"; i=$((i + 1)); done
    while true; do
        entrada "  Número: " n
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$#" ] && break
    done
    ESCOLHA=$((n - 1))
}

# ---------- Sistema atual ----------
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

# Lê uma linha de arquivo vindo do Windows (tira BOM e \r)
primeira_linha() { head -1 "$1" 2>/dev/null | tr -d '\r' | sed 's/^\xEF\xBB\xBF//'; }

# Pasta XDG (Área de Trabalho, Documentos...) de uma home. $1 = home, $2 = DESKTOP|DOCUMENTS|DOWNLOAD|MUSIC|PICTURES|VIDEOS
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
titulo "RESTAURAR BACKUP (LINUX)"
msg "Este computador: $(hostname)   •   $DISTRO_NOME"
if [ "$FAMILIA" = outro ]; then erro "Distribuição não suportada. Este script funciona no Ubuntu, Debian e Fedora."; sair 1; fi
if ! command -v rsync >/dev/null 2>&1; then
    msg "Instalando o rsync..."; [ "$FAMILIA" = apt ] && apt-get update -qq; instalar rsync >/dev/null
fi

# ---------- Procurar backups em todos os discos montados ----------
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
    erro "Nenhum backup encontrado. Conecte o disco com a pasta BACKUP_PC, abra ele no gerenciador de arquivos e rode de novo."
    sair 1
fi
if [ "${#BACKUPS[@]}" -eq 1 ]; then BK="${BACKUPS[0]}"; else escolher "Qual backup restaurar?" "${BACKUPS[@]}"; BK="${BACKUPS[$ESCOLHA]}"; fi
ok "Backup: $BK"
[ -f "$BK/00_Info/sistema.txt" ] && head -6 "$BK/00_Info/sistema.txt" | tr -d '\r' | sed 's/^\xEF\xBB\xBF//; s/^/     /'

# De onde veio o backup?
ORIGEM="windows"; BK_FAMILIA=""
if [ -f "$BK/00_Info/origem.txt" ] && [ "$(primeira_linha "$BK/00_Info/origem.txt")" = "linux" ]; then
    ORIGEM="linux"; BK_FAMILIA="$(sed -n 4p "$BK/00_Info/origem.txt")"
fi
if [ "$ORIGEM" = windows ]; then
    echo
    aviso "Este backup foi feito no WINDOWS."
    msg "Dá para restaurar os arquivos pessoais (Área de Trabalho, Documentos, Fotos...) e as redes Wi-Fi."
    msg "Os programas do Windows não funcionam no Linux: a lista deles vai para a sua Área de Trabalho."
fi

# ---------- Verificar se cabe ----------
echo
msg "Calculando o tamanho do backup..."
TAM_BK="$(du -sb "$BK" 2>/dev/null | cut -f1)"
LIVRE="$(df -B1 --output=avail /home 2>/dev/null | tail -1 | tr -d ' ')"
NECESSARIO=$(( TAM_BK + TAM_BK / 20 + 5368709120 ))     # margem + espaço para os programas
msg "Tamanho do backup : $(gb "$TAM_BK")"
msg "Livre em /home    : $(gb "$LIVRE")"
if [ "$LIVRE" -ge "$NECESSARIO" ]; then ok "Tem espaço suficiente."
else
    erro "Pode NÃO caber: faltam cerca de $(gb $(( NECESSARIO - LIVRE )))."
    msg "Dica: restaure por partes pelo menu."
    perguntar "Continuar mesmo assim?" || sair 0
fi

# Backup guardado em disco do Linux (ext4...) mantém permissões; em NTFS/exFAT não
FS_BK="$(findmnt -n -o FSTYPE --target "$BK" 2>/dev/null)"
case "$FS_BK" in ext*|xfs|btrfs|f2fs) PERMS="-p" ;; *) PERMS="-p --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r" ;; esac

# ---------- Escolha do usuário ----------
USUARIO_BK=""; ALVO_USER=""; ALVO_HOME=""
selecionar_usuario() {
    [ -n "$USUARIO_BK" ] && return 0
    mapfile -t US < <(find "$BK/02_Usuarios" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
    if [ "${#US[@]}" -eq 0 ]; then aviso "Não há usuários neste backup."; return 1; fi
    if [ "${#US[@]}" -eq 1 ]; then USUARIO_BK="$BK/02_Usuarios/${US[0]}"
    else escolher "Restaurar os arquivos de qual usuário do computador antigo?" "${US[@]}"; USUARIO_BK="$BK/02_Usuarios/${US[$ESCOLHA]}"; fi

    ALVO_USER="${SUDO_USER:-}"
    if [ -z "$ALVO_USER" ] || [ "$ALVO_USER" = root ] || ! perguntar "Restaurar '$(basename "$USUARIO_BK")' para o usuário '$ALVO_USER' deste computador?"; then
        entrada "  Digite o nome do usuário de destino: " ALVO_USER
    fi
    ALVO_HOME="$(getent passwd "$ALVO_USER" | cut -d: -f6)"
    if [ -z "$ALVO_HOME" ] || [ ! -d "$ALVO_HOME" ]; then erro "Usuário '$ALVO_USER' não existe."; USUARIO_BK=""; return 1; fi
    ALVO_GRUPO="$(id -gn "$ALVO_USER")"
    return 0
}

# Copia com rsync já ajustando o dono dos arquivos para o usuário de destino
copiar_para_usuario() {   # $1 origem, $2 destino, demais = opções extras
    local o="$1" d="$2"; shift 2
    [ -e "$o" ] || return 0
    mkdir -p "$d" && chown "$ALVO_USER:$ALVO_GRUPO" "$d"
    echo "${CINZA}  -> $d${N}"
    # shellcheck disable=SC2086
    rsync -rlt -og $PERMS --chown="$ALVO_USER:$ALVO_GRUPO" --info=progress2 "$@" "$o/" "$d/" 2>> "$TRANSCRIPT"
    local rc=$?
    [ $rc -ne 0 ] && aviso "Alguns arquivos não foram copiados para '$d' (código $rc)."
    return 0
}

# ---------- Etapas ----------
restaurar_wifi() {
    titulo "Redes Wi-Fi"
    if ! command -v nmcli >/dev/null 2>&1; then aviso "NetworkManager não encontrado: não dá para importar as redes."; return; fi
    local n=0 f
    if [ "$ORIGEM" = linux ]; then
        local NM="/etc/NetworkManager/system-connections"
        mkdir -p "$NM"
        for f in "$BK/03_WiFi"/*; do
            [ -f "$f" ] && grep -q '^type=wifi' "$f" || continue
            # tira o nome da placa de rede antiga, senão a rede não conecta na placa nova
            sed '/^interface-name=/d; /^mac-address=/d' "$f" > "$NM/$(basename "$f")"
            chmod 600 "$NM/$(basename "$f")"; chown root:root "$NM/$(basename "$f")"
            n=$((n + 1))
        done
        nmcli connection reload
    else
        # Perfis exportados pelo Windows (XML)
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
                *) aviso "Rede '$ssid' usa login corporativo ($auth): configure manualmente." ;;
            esac
        done
    fi
    ok "$n redes Wi-Fi adicionadas."
}

restaurar_programas() {
    titulo "Reinstalar programas"
    selecionar_usuario || return
    local FALTAM=() p desktop
    desktop="$(pasta_xdg "$ALVO_HOME" DESKTOP)"; mkdir -p "$desktop"

    if [ "$ORIGEM" = windows ]; then
        cp "$BK/01_Programas/programas-instalados.txt" "$desktop/Programas do Windows antigo.txt" 2>/dev/null
        chown "$ALVO_USER:$ALVO_GRUPO" "$desktop/Programas do Windows antigo.txt" 2>/dev/null
        ok "Lista dos programas do Windows salva na Área de Trabalho, para você procurar as versões de Linux."
        return
    fi

    # Pacotes do sistema (só se o backup veio da mesma família: apt->apt ou dnf->dnf)
    local lista="$BK/01_Programas/pacotes-$BK_FAMILIA.txt"
    if [ "$BK_FAMILIA" != "$FAMILIA" ]; then
        aviso "O backup veio de um sistema $BK_FAMILIA e este usa $FAMILIA: os nomes dos pacotes são diferentes."
        aviso "Os pacotes vão para a lista de instalação manual (Flatpak e Snap funcionam normalmente)."
        [ -f "$lista" ] && mapfile -t FALTAM < "$lista"
    elif [ -f "$lista" ]; then
        mapfile -t PACOTES < <(grep -v '^$' "$lista")
        msg "${#PACOTES[@]} pacotes no backup. Isso precisa de internet e pode demorar."
        if [ "$FAMILIA" = apt ]; then
            apt-get update
            local DISP=()
            for p in "${PACOTES[@]}"; do
                if dpkg -s "$p" >/dev/null 2>&1; then continue; fi
                if apt-cache show "$p" >/dev/null 2>&1; then DISP+=("$p"); else FALTAM+=("$p"); fi
            done
            if [ "${#DISP[@]}" -gt 0 ]; then
                msg "Instalando ${#DISP[@]} pacotes..."
                DEBIAN_FRONTEND=noninteractive apt-get install -y "${DISP[@]}" ||
                    for p in "${DISP[@]}"; do DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" >/dev/null 2>&1 || FALTAM+=("$p"); done
            fi
        else
            if dnf --version 2>/dev/null | grep -qi dnf5; then dnf install -y --skip-unavailable "${PACOTES[@]}"
            else dnf install -y --setopt=strict=0 "${PACOTES[@]}"; fi
            for p in "${PACOTES[@]}"; do rpm -q "$p" >/dev/null 2>&1 || FALTAM+=("$p"); done
        fi
        ok "Pacotes do sistema finalizados."
    fi

    # Flatpak
    if [ -s "$BK/01_Programas/flatpak.txt" ]; then
        command -v flatpak >/dev/null 2>&1 || { msg "Instalando o Flatpak..."; instalar flatpak >/dev/null; }
        if command -v flatpak >/dev/null 2>&1; then
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            local app remoto
            while IFS=$'\t' read -r app remoto; do
                [ -n "$app" ] || continue
                flatpak remotes --columns=name | grep -qx "$remoto" || remoto=flathub
                msg "Flatpak: $app"
                flatpak install -y --noninteractive "$remoto" "$app" >/dev/null 2>&1 || FALTAM+=("flatpak: $app")
            done < "$BK/01_Programas/flatpak.txt"
            ok "Aplicativos Flatpak finalizados."
        fi
    fi

    # Snap (pula os pacotes base, que o snap instala sozinho)
    if [ -s "$BK/01_Programas/snap.txt" ]; then
        if ! command -v snap >/dev/null 2>&1 && perguntar "O backup tem pacotes Snap. Instalar o Snap neste computador?"; then
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
            ok "Pacotes Snap finalizados."
        else
            while IFS=$'\t' read -r nome _; do FALTAM+=("snap: $nome"); done < "$BK/01_Programas/snap.txt"
        fi
    fi

    if [ "${#FALTAM[@]}" -gt 0 ]; then
        local arq="$desktop/PROGRAMAS QUE FALTAM INSTALAR.txt"
        { echo "Estes programas estavam no computador antigo e não foram instalados automaticamente."
          echo "Procure por eles na loja de aplicativos ou no site de cada um:"
          echo
          printf -- '- %s\n' "${FALTAM[@]}"; } > "$arq"
        chown "$ALVO_USER:$ALVO_GRUPO" "$arq"
        aviso "${#FALTAM[@]} programas precisam ser instalados manualmente. Lista salva na Área de Trabalho."
    else
        ok "Todos os programas foram instalados."
    fi
}

restaurar_arquivos() {
    titulo "Arquivos do usuário"
    selecionar_usuario || return
    local EXCLUIR=() chave origem destino
    local CHAVES=(DESKTOP DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS)

    if [ "$ORIGEM" = linux ]; then
        local casa_bk="$USUARIO_BK/Home"
        [ -d "$casa_bk" ] || { aviso "Sem arquivos no backup."; return; }
        # Área de Trabalho, Documentos etc. vão para as pastas certas mesmo se o idioma mudou
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
        [ -d "$perfil" ] || { aviso "Sem arquivos no backup."; return; }
        local -A WIN=([DESKTOP]=Desktop [DOCUMENTS]=Documents [DOWNLOAD]=Downloads [MUSIC]=Music [PICTURES]=Pictures [VIDEOS]=Videos)
        local LIXO=(--exclude='desktop.ini' --exclude='Thumbs.db' --exclude='*.lnk')
        for chave in "${CHAVES[@]}"; do
            origem="$perfil/${WIN[$chave]}"
            [ -d "$origem" ] || continue
            copiar_para_usuario "$origem" "$(pasta_xdg "$ALVO_HOME" "$chave")" -u "${LIXO[@]}"
            EXCLUIR+=(--exclude="/${WIN[$chave]}/")
        done
        # O resto da pasta do usuário do Windows fica separado
        copiar_para_usuario "$perfil" "$ALVO_HOME/Arquivos do Windows" -u "${EXCLUIR[@]}" "${LIXO[@]}"
        ok "O que não era Área de Trabalho/Documentos/Downloads/Fotos/Músicas/Vídeos ficou em '$ALVO_HOME/Arquivos do Windows'."
    fi
    ok "Arquivos restaurados."
}

restaurar_config() {
    titulo "Configurações dos programas"
    if [ "$ORIGEM" = windows ]; then msg "Configurações do Windows não servem no Linux: etapa pulada."; return; fi
    selecionar_usuario || return
    aviso "Faça isto DEPOIS de reinstalar os programas. Isso substitui as configurações atuais deles."
    aviso "Inclui favoritos, extensões e histórico dos navegadores, chaves SSH, configurações da área de trabalho..."
    perguntar "Restaurar configurações agora?" || return
    local abertos
    abertos="$(pgrep -u "$ALVO_USER" -l -x 'firefox|chrome|chromium|brave|thunderbird|code|discord|spotify' 2>/dev/null | awk '{print $2}' | sort -u | tr '\n' ' ')"
    if [ -n "$abertos" ]; then
        aviso "Programas abertos: $abertos"
        perguntar "Fechar esses programas agora?" && pkill -u "$ALVO_USER" -x 'firefox|chrome|chromium|brave|thunderbird|code|discord|spotify' && sleep 2
    fi
    copiar_para_usuario "$USUARIO_BK/Home" "$ALVO_HOME" --include='/.*' --exclude='/*'
    ok "Configurações restauradas. Saia da sessão e entre de novo (ou reinicie) para aplicar."
}

restaurar_outras() {
    titulo "Outras pastas e discos"
    local base="$BK/04_OutrasPastas" rel original
    if [ ! -d "$base" ] || [ -z "$(ls -A "$base" 2>/dev/null | grep -v '^caminhos.txt$')" ]; then msg "Nada para restaurar."; return; fi
    if [ "$ORIGEM" = linux ] && [ -f "$base/caminhos.txt" ]; then
        while IFS=$'\t' read -r rel original <&3; do
            [ -d "$base/$rel" ] || continue
            if [[ "$rel" == disco_* ]]; then
                selecionar_usuario || return
                copiar_para_usuario "$base/$rel" "$ALVO_HOME/Restaurado/$rel" -u
            elif perguntar "Restaurar $original para o mesmo lugar? (N = guardar em /root/Restaurado$original)"; then
                rsync -aHu --info=progress2 "$base/$rel/" "$original/"
            else
                rsync -aHu --info=progress2 "$base/$rel/" "/root/Restaurado$original/"
            fi
        done 3< "$base/caminhos.txt"
    else
        selecionar_usuario || return
        local d
        for d in "$base"/*/; do
            [ -d "$d" ] || continue
            copiar_para_usuario "${d%/}" "$ALVO_HOME/Arquivos do Windows/Disco $(basename "$d")" -u
        done
    fi
    ok "Outras pastas restauradas."
}

# ---------- Menu ----------
while true; do
    titulo "O QUE VOCÊ QUER FAZER?"
    if [ "$ORIGEM" = linux ]; then
        msg "[1] TUDO (recomendado) - Wi-Fi, programas, arquivos, outras pastas e configurações"
        msg "[2] Só redes Wi-Fi"
        msg "[3] Só reinstalar programas"
        msg "[4] Só arquivos do usuário"
        msg "[5] Só outras pastas / discos"
        msg "[6] Só configurações dos programas"
    else
        msg "[1] TUDO (recomendado) - Wi-Fi, arquivos, outras pastas e lista de programas do Windows"
        msg "[2] Só redes Wi-Fi"
        msg "[3] Só a lista de programas do Windows"
        msg "[4] Só arquivos do usuário"
        msg "[5] Só outras pastas / discos"
    fi
    msg "[0] Sair"
    entrada "  Opção: " op
    case "$op" in
        1) restaurar_wifi; restaurar_programas; restaurar_arquivos; restaurar_outras; restaurar_config
           titulo "TUDO PRONTO!"; msg "Registro: $TRANSCRIPT"; msg "Reinicie o computador para finalizar." ;;
        2) restaurar_wifi ;;
        3) restaurar_programas ;;
        4) restaurar_arquivos ;;
        5) restaurar_outras ;;
        6) [ "$ORIGEM" = linux ] && restaurar_config ;;
        0) exit 0 ;;
    esac
done
