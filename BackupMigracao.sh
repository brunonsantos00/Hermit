#!/usr/bin/env bash
# =====================================================================
#  BACKUP E MIGRAÇÃO - iniciador
#  Linux (Ubuntu, Debian, Fedora): abre o menu com backup e restauração.
#  Windows (Git Bash): abre o painel gráfico.
#  Uso:  bash BackupMigracao.sh
# =====================================================================

DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# No Windows (Git Bash / MSYS), abre o painel
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$(cygpath -w "$DIR/windows/painel.ps1")" ;;
esac

# Aberto com clique duplo (sem terminal): abre um terminal rodando este script
if [ ! -t 0 ] && [ -z "${BM_NO_TERMINAL:-}" ]; then
    export BM_NO_TERMINAL=1
    for t in gnome-terminal kgx konsole xfce4-terminal mate-terminal x-terminal-emulator xterm; do
        command -v "$t" >/dev/null 2>&1 || continue
        case "$t" in
            gnome-terminal)  exec gnome-terminal -- bash "$DIR/BackupMigracao.sh" ;;
            kgx)             exec kgx -- bash "$DIR/BackupMigracao.sh" ;;
            xfce4-terminal)  exec xfce4-terminal -x bash "$DIR/BackupMigracao.sh" ;;
            *)               exec "$t" -e bash "$DIR/BackupMigracao.sh" ;;
        esac
    done
fi

AZUL=$'\e[36m'; VERDE=$'\e[32m'; AMARELO=$'\e[33m'; N=$'\e[0m'
LINHA="$(printf '=%.0s' {1..70})"

SO="$(grep -m1 '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')"
ID_SO="$(grep -m1 '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')"

criar_atalho() {
    local apps="$HOME/.local/share/applications" arq desk
    mkdir -p "$apps"
    arq="$apps/backup-e-migracao.desktop"
    cat > "$arq" <<EOF
[Desktop Entry]
Type=Application
Name=Backup e Migração
Comment=Backup e migração de computadores Windows e Linux
Exec=bash "$DIR/BackupMigracao.sh"
Icon=$DIR/assets/icone.png
Terminal=true
Categories=System;Utility;
EOF
    chmod +x "$arq"
    echo "${VERDE}  [OK] Atalho criado no menu de aplicativos.${N}"
    desk="$(xdg-user-dir DESKTOP 2>/dev/null)"; desk="${desk:-$HOME/Desktop}"
    if [ -d "$desk" ]; then
        cp "$arq" "$desk/" && chmod +x "$desk/backup-e-migracao.desktop"
        gio set "$desk/backup-e-migracao.desktop" metadata::trusted true 2>/dev/null
        echo "${VERDE}  [OK] Atalho criado na Área de Trabalho.${N}"
    fi
    echo "${AMARELO}  [!]  O atalho aponta para esta pasta ($DIR). Se o HD mudar de lugar, crie de novo.${N}"
}

while true; do
    clear 2>/dev/null
    echo "${AZUL}${LINHA}${N}"
    echo "${AZUL}  BACKUP E MIGRAÇÃO${N}"
    echo "${AZUL}${LINHA}${N}"
    echo "  Computador: $(hostname)   •   ${SO:-Linux}"
    case "$ID_SO" in
        ubuntu|debian|fedora) ;;
        *) echo "${AMARELO}  [!]  Sistema não testado: os scripts foram feitos para Ubuntu, Debian e Fedora.${N}" ;;
    esac
    echo
    echo "  [1] Fazer backup deste computador"
    echo "  [2] Restaurar um backup neste computador"
    echo "  [3] Criar atalho com ícone (menu de aplicativos e Área de Trabalho)"
    echo "  [4] Ler o guia rápido"
    echo "  [0] Sair"
    echo
    read -r -p "  Opção: " op || exit 0
    case "$op" in
        1) bash "$DIR/linux/backup.sh" ;;
        2) bash "$DIR/linux/restaurar.sh" ;;
        3) criar_atalho; read -r -p "  Pressione ENTER para voltar " _ ;;
        4) less "$DIR/linux/LEIA-ME.txt" 2>/dev/null || cat "$DIR/linux/LEIA-ME.txt"; read -r -p "  Pressione ENTER para voltar " _ ;;
        0) exit 0 ;;
    esac
done
