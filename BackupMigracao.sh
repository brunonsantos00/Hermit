#!/usr/bin/env bash
# =====================================================================
#  BACKUP E MIGRAÇÃO - iniciador  /  BACKUP AND MIGRATION - launcher
#  Linux (Ubuntu, Debian, Fedora): abre o menu com backup e restauração.
#  Windows (Git Bash): abre o painel gráfico.
#  Uso / Usage:  bash BackupMigracao.sh [--idioma pt|en]
# =====================================================================

DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# No Windows (Git Bash / MSYS), abre o painel
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$(cygpath -w "$DIR/windows/painel.ps1")" ;;
esac

PEDIDO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --idioma|--lang) PEDIDO="${2:-}"; shift 2 ;;
        --idioma=*|--lang=*) PEDIDO="${1#*=}"; shift ;;
        *) shift ;;
    esac
done
# shellcheck source=linux/idioma.sh
source "$DIR/linux/idioma.sh"
IDIOMA="$(detectar_idioma "$PEDIDO")"

# Aberto com clique duplo (sem terminal): abre um terminal rodando este script
if [ ! -t 0 ] && [ -z "${BM_NO_TERMINAL:-}" ]; then
    export BM_NO_TERMINAL=1
    for t in gnome-terminal kgx konsole xfce4-terminal mate-terminal x-terminal-emulator xterm; do
        command -v "$t" >/dev/null 2>&1 || continue
        case "$t" in
            gnome-terminal)  exec gnome-terminal -- bash "$DIR/BackupMigracao.sh" --idioma "$IDIOMA" ;;
            kgx)             exec kgx -- bash "$DIR/BackupMigracao.sh" --idioma "$IDIOMA" ;;
            xfce4-terminal)  exec xfce4-terminal -x bash "$DIR/BackupMigracao.sh" --idioma "$IDIOMA" ;;
            *)               exec "$t" -e bash "$DIR/BackupMigracao.sh" --idioma "$IDIOMA" ;;
        esac
    done
fi

AZUL=$'\e[36m'; VERDE=$'\e[32m'; AMARELO=$'\e[33m'; N=$'\e[0m'
LINHA="$(printf '=%.0s' {1..70})"

SO="$(grep -m1 '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')"
ID_SO="$(grep -m1 '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')"

voltar() { read -r -p "  $(L 'Pressione ENTER para voltar' 'Press ENTER to go back') " _; }

criar_atalho() {
    local apps="$HOME/.local/share/applications" arq desk
    mkdir -p "$apps"
    arq="$apps/backup-e-migracao.desktop"
    cat > "$arq" <<EOF
[Desktop Entry]
Type=Application
Name=Backup e Migração
Name[en]=Backup and Migration
Comment=Backup e migração de computadores Windows e Linux
Comment[en]=Backup and migration for Windows and Linux computers
Exec=bash "$DIR/BackupMigracao.sh"
Icon=$DIR/assets/icone.png
Terminal=true
Categories=System;Utility;
EOF
    chmod +x "$arq"
    echo "${VERDE}  [OK] $(L 'Atalho criado no menu de aplicativos.' 'Shortcut created in the applications menu.')${N}"
    desk="$(xdg-user-dir DESKTOP 2>/dev/null)"; desk="${desk:-$HOME/Desktop}"
    if [ -d "$desk" ]; then
        cp "$arq" "$desk/" && chmod +x "$desk/backup-e-migracao.desktop"
        gio set "$desk/backup-e-migracao.desktop" metadata::trusted true 2>/dev/null
        echo "${VERDE}  [OK] $(L 'Atalho criado na Área de Trabalho.' 'Shortcut created on the Desktop.')${N}"
    fi
    echo "${AMARELO}  [!]  $(L "O atalho aponta para esta pasta ($DIR). Se o HD mudar de lugar, crie de novo." "The shortcut points to this folder ($DIR). If the drive moves, create it again.")${N}"
}

while true; do
    clear 2>/dev/null
    echo "${AZUL}${LINHA}${N}"
    echo "${AZUL}  $(L 'BACKUP E MIGRAÇÃO' 'BACKUP AND MIGRATION')${N}"
    echo "${AZUL}${LINHA}${N}"
    echo "  $(L 'Computador' 'Computer'): $(hostname)   •   ${SO:-Linux}"
    case "$ID_SO" in
        ubuntu|debian|fedora) ;;
        *) echo "${AMARELO}  [!]  $(L 'Sistema não testado: os scripts foram feitos para Ubuntu, Debian e Fedora.' 'Untested system: the scripts were made for Ubuntu, Debian and Fedora.')${N}" ;;
    esac
    echo
    echo "  $(L '[1] Fazer backup deste computador' '[1] Back up this computer')"
    echo "  $(L '[2] Restaurar um backup neste computador' '[2] Restore a backup on this computer')"
    echo "  $(L '[3] Criar atalho com ícone (menu de aplicativos e Área de Trabalho)' '[3] Create a shortcut with icon (applications menu and Desktop)')"
    echo "  $(L '[4] Ler o guia rápido' '[4] Read the quick guide')"
    echo "  $(L '[5] Language: English' '[5] Idioma: Português')"
    echo "  $(L '[0] Sair' '[0] Exit')"
    echo
    read -r -p "  $(L 'Opção' 'Option'): " op || exit 0
    case "$op" in
        1) bash "$DIR/linux/backup.sh" --idioma "$IDIOMA" ;;
        2) bash "$DIR/linux/restaurar.sh" --idioma "$IDIOMA" ;;
        3) criar_atalho; voltar ;;
        4) guia="$DIR/linux/$(L LEIA-ME.txt README-EN.txt)"
           less "$guia" 2>/dev/null || cat "$guia"; voltar ;;
        5) if [ "$IDIOMA" = pt ]; then IDIOMA=en; else IDIOMA=pt; fi
           salvar_idioma "$IDIOMA" ;;
        0) exit 0 ;;
    esac
done
