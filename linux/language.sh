#!/usr/bin/env bash
# Language (Portuguese / English) used by the Linux scripts.
# Usage:  source language.sh ; IDIOMA="$(detectar_idioma "$pedido")" ; msg "$(L 'Olá' 'Hello')"

ARQUIVO_IDIOMA="${HOME:-/root}/.config/hermit/language"

# Order: --idioma > BM_IDIOMA variable > saved choice > system language
detectar_idioma() {
    local v
    for v in "${1:-}" "${BM_IDIOMA:-}"; do
        case "$v" in pt|en) echo "$v"; return ;; esac
    done
    if [ -n "${SUDO_USER:-}" ]; then
        local casa; casa="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        [ -n "$casa" ] && ARQUIVO_IDIOMA="$casa/.config/hermit/language"
    fi
    v="$(head -1 "$ARQUIVO_IDIOMA" 2>/dev/null)"
    case "$v" in pt|en) echo "$v"; return ;; esac
    case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in pt*) echo pt ;; *) echo en ;; esac
}

salvar_idioma() { mkdir -p "$(dirname "$ARQUIVO_IDIOMA")" 2>/dev/null && echo "$1" > "$ARQUIVO_IDIOMA" 2>/dev/null; }

# Picks the text for the current language
L() { if [ "${IDIOMA:-pt}" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
