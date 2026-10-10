# Windows Backup and Migration

Scripts para fazer **backup completo de um computador** em um HD externo e **restaurar tudo em outro computador**: arquivos, configurações, redes Wi-Fi e a reinstalação automática dos programas.

| Sistema | Versões | Pasta |
|---|---|---|
| **Windows** | 10 e 11 | [`windows/`](windows/) |
| **Linux** | Ubuntu, Debian e Fedora | [`linux/`](linux/) |

Não precisa instalar nada: os scripts usam só ferramentas que já vêm no sistema (`robocopy`, `winget` e `netsh` no Windows; `rsync`, `apt`/`dnf` e `nmcli` no Linux).

## Recursos

- **Escolha do disco de destino** e **verificação de espaço antes de copiar**. Se não couber, dá pra trocar de disco ou tirar itens.
- **Detecção de sistema operacional** em cada disco: Windows, Linux ou macOS. Dispositivos sem sistema aparecem marcados como próprios só para guardar backups.
- **Reinstalação automática dos programas**: `winget` no Windows; `apt`/`dnf`, Flatpak e Snap no Linux. O que não der pra instalar vai para uma lista na Área de Trabalho.
- **Migração Windows → Linux**: o restaurar do Linux aceita backups feitos no Windows (arquivos pessoais e redes Wi-Fi).
- **Painel gráfico no Windows**: janela com botões, lista de dispositivos com o sistema de cada um, espaço livre e backups encontrados.

## Windows

O jeito mais fácil: dê dois cliques em **`windows/0-ABRIR-PAINEL.bat`**.

O painel mostra os dispositivos conectados e tem botões para **Fazer backup** e **Restaurar backup**. Ele percebe sozinho quando um HD é conectado. Também dá pra rodar cada etapa direto pelos `.bat`:

1. **No computador antigo:** `1-FAZER-BACKUP.bat`. Escolha o disco e responda as perguntas.
2. **No computador novo:** `2-RESTAURAR-BACKUP.bat`. Escolha **[1] TUDO**.

## Linux

Abra um terminal na pasta `linux/` do HD:

```bash
bash backup.sh       # no computador antigo
bash restaurar.sh    # no computador novo
```

Os scripts pedem a senha de administrador, impedem o computador de suspender durante a cópia e funcionam com HD em ext4, NTFS, exFAT ou FAT32.

## O que é salvo

| Item | Windows | Linux |
|---|---|---|
| Arquivos dos usuários | Pasta do usuário inteira | Pasta pessoal inteira |
| Configurações dos programas | `AppData\Roaming` + navegadores | Arquivos ocultos (`~/.config`, `~/.mozilla`, `~/.ssh`…) |
| Programas | Lista do `winget` | Pacotes `apt`/`dnf` + Flatpak + Snap |
| Redes Wi-Fi e senhas | `netsh` | NetworkManager |
| Extras (opcional) | Pastas na raiz do `C:` e outros discos | `/opt`, `/srv`, `/var/www`, `/usr/local` e outros discos |
| Informações | Sistema, chave do Windows, impressoras | Sistema, `/etc`, crontab |

Caches e lixeira ficam de fora. Eles são recriados sozinhos.

## Limitações

- **Programas** não são copiados, são **reinstalados** na versão mais recente.
- **Senhas salvas no navegador** não funcionam em outro computador no Windows, porque são criptografadas por máquina. Use a sincronização da conta Google/Microsoft/Firefox.
- **Pacotes de Linux entre famílias diferentes** (Ubuntu/Debian ↔ Fedora) têm nomes diferentes, então vão para a lista manual. Flatpak e Snap funcionam em qualquer distribuição.
- **Licenças** de programas pagos precisam ser ativadas de novo.
- **FAT32** não aceita arquivos maiores que 4 GB. Prefira NTFS, exFAT ou ext4.

## Estrutura do backup

O formato é o mesmo nos dois sistemas:

```
BACKUP_PC/<PC>_<data>/
├── 00_Info/          sistema, origem (windows/linux), log da cópia
├── 01_Programas/     listas de programas para reinstalar
├── 02_Usuarios/      arquivos e configurações de cada usuário
├── 03_WiFi/          redes Wi-Fi
├── 04_OutrasPastas/  pastas extras e outros discos
└── RESUMO.txt
```

## Arquivos

```
windows/
├── 0-ABRIR-PAINEL.bat      abre o painel gráfico
├── 1-FAZER-BACKUP.bat      atalho para backup.ps1
├── 2-RESTAURAR-BACKUP.bat  atalho para restaurar.ps1
├── painel.ps1              janela gráfica (WPF)
├── backup.ps1              faz o backup
├── restaurar.ps1           restaura o backup
└── LEIA-ME.txt             guia rápido
linux/
├── backup.sh               faz o backup
├── restaurar.sh            restaura o backup (também aceita backups do Windows)
└── LEIA-ME.txt             guia rápido
```
