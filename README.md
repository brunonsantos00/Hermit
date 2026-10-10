# Hermit

**Backup e migração de computadores Windows e Linux** · [English version](README.en.md)

> **Aviso:** este projeto foi transferido para cá. Ele começou no repositório
> [`brunonsantos00/windows-backup-and-migration`](https://github.com/brunonsantos00/windows-backup-and-migration),
> que não recebe mais atualizações. Todo o histórico de commits foi trazido junto.

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
- **Português e inglês** em tudo: painel, scripts e menus.

## Início rápido

Os iniciadores ficam na raiz do projeto e usam o mesmo ícone:

| Sistema | Abrir com | O que faz |
|---|---|---|
| Windows | **`Hermit.exe`** (dois cliques) | Abre o painel gráfico |
| Linux | **`hermit.sh`** (dois cliques ou `bash hermit.sh`) | Abre o menu com backup e restauração. A opção 3 cria um atalho com ícone no menu de aplicativos |

> O `.exe` não é assinado digitalmente. Na primeira vez o Windows pode mostrar o aviso "O Windows protegeu o computador": clique em **Mais informações → Executar assim mesmo**. O código-fonte está em [`launcher/`](launcher/) e dá pra compilar de novo com `launcher/build.ps1`.

## Idioma

| Onde | Como trocar |
|---|---|
| Painel do Windows | Botão **PT \| EN** no canto superior da janela. A escolha fica salva e vale também para os scripts |
| Menu do Linux | Opção **[5]** do `hermit.sh` |
| Scripts direto | `-Idioma pt` / `-Idioma en` no Windows, `--idioma pt` / `--idioma en` no Linux |

Na primeira vez, o idioma é escolhido pelo idioma do sistema: português se o sistema estiver em português, inglês nos outros casos. As pastas dentro do backup têm os mesmos nomes nos dois idiomas, então um backup feito em um idioma restaura normalmente no outro.

## Windows

O jeito mais fácil: dê dois cliques em **`Hermit.exe`**, ou em **`windows/0-OPEN-PANEL.bat`**.

O painel mostra os dispositivos conectados e tem botões para **Fazer backup** e **Restaurar backup**. Ele percebe sozinho quando um HD é conectado. Também dá pra rodar cada etapa direto pelos `.bat`:

1. **No computador antigo:** `1-BACKUP.bat`. Escolha o disco e responda as perguntas.
2. **No computador novo:** `2-RESTORE-BACKUP.bat`. Escolha **[1] TUDO**.

### Backup 2.0: levar os programas sem reinstalar

**`1-BACKUP-2.0.bat`** faz o mesmo backup e também copia as **pastas dos programas instalados** (`Program Files`, `Program Files (x86)`, `AppData\Local\Programs`, os dados deles em `ProgramData` e os atalhos do Menu Iniciar).

Na restauração (**[1] TUDO** ou **[7]**), as pastas voltam para o mesmo lugar. **Se o programa já existir no computador novo, os arquivos dele são substituídos** pelos do backup. Antes, o Hermit fecha o programa se ele estiver aberto, desde que você deixe.

> Programas que dependem de serviços, drivers ou ativação (Office, Adobe, antivírus, drivers de vídeo) podem não abrir assim. Para esses, use a opção **[3] Reinstalar programas** (winget).

### Comparar o backup com o computador

**`3-COMPARE-BACKUP.bat`** mostra o que está no backup e **não chegou** neste computador:
- **Faltam:** estão no backup e não existem aqui.
- **Mais novos:** existem aqui, mas a versão do backup é mais nova.

Ele salva o relatório `COMPARACAO DO BACKUP.txt` na Área de Trabalho e, no final, oferece copiar o que falta, sem substituir nada que já existe. Só lê: nunca apaga nada.

Para **só ver a diferença**, sem nenhuma oferta de cópia, há duas opções:

| Opção | Como é |
|---|---|
| **`Hermit-Compare.exe`** (raiz) | Janela: escolha o backup e clique em **Comparar**. Mostra cartões com os totais, as pastas com diferença primeiro, os arquivos que faltam com o tamanho de cada um e uma busca por nome |
| **`COMPARE-ONLY.bat`** | Terminal: lista colorida por pasta (vermelho = falta, amarelo = mais novo no backup, verde = tudo certo) |

## Linux

Abra um terminal na pasta `linux/` do HD:

```bash
bash backup.sh       # no computador antigo
bash restore.sh    # no computador novo
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
Hermit.exe          iniciador do Windows (abre o painel)
Hermit-Compare.exe              janela que compara o backup com o computador
hermit.sh           iniciador do Linux (menu + atalho com ícone)
assets/
├── icon.ico / icon.png   ícone do projeto
└── generate-icon.ps1         desenha o ícone
launcher/
├── Hermit.cs       código-fonte do .exe
└── build.ps1            compila o .exe com o ícone
windows/
├── 0-OPEN-PANEL.bat      abre o painel gráfico
├── 1-BACKUP.bat      atalho para backup.ps1
├── 1-BACKUP-2.0.bat  backup 2.0 (também copia as pastas dos programas)
├── 2-RESTORE-BACKUP.bat  atalho para restore.ps1
├── 3-COMPARE-BACKUP.bat   compara o backup com o computador (e oferece copiar o que falta)
├── COMPARE-ONLY.bat   só compara e mostra a lista do que falta
├── panel.ps1              janela gráfica (WPF)
├── compare-window.ps1          janela do comparador (aberta pelo Hermit-Compare.exe)
├── backup.ps1              faz o backup (normal ou 2.0)
├── restore.ps1           restaura o backup
├── compare.ps1            mostra o que está no backup e falta no computador
├── language.ps1              textos em português e inglês
└── README-PT.txt / README-EN.txt   guia rápido
linux/
├── backup.sh               faz o backup
├── restore.sh            restaura o backup (também aceita backups do Windows)
├── language.sh               textos em português e inglês
└── README-PT.txt / README-EN.txt   guia rápido
```

## Branches

| Branch | Conteúdo |
|---|---|
| `main` | Versão estável, publicada nas Releases |
| `staging` | Homologação: versão em teste. Recebe as branches de feature e vai para a `main` depois de aprovada |
| `feature/windows` | Scripts e painel do Windows |
| `feature/linux` | Scripts do Linux |
| `feature/launcher` | Ícone e iniciadores (`.exe` e `.sh`) |

Fluxo: `feature/*` → `staging` (homologação) → `main` (estável).
