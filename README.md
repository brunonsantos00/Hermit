# Windows Backup and Migration

Scripts em PowerShell para fazer **backup completo de um computador Windows** em um HD externo e **restaurar tudo em outro computador**: arquivos, configurações, redes Wi-Fi e a reinstalação automática dos programas.

Não precisa instalar nada: usa só ferramentas que já vêm no Windows 10/11 (`robocopy`, `winget`, `netsh`).

## Como usar

O jeito mais fácil: dê dois cliques em **`0-ABRIR-PAINEL.bat`**. Abre uma janela com botões para fazer backup, restaurar, ver os discos conectados (com espaço livre e backups encontrados) e abrir o guia. O painel percebe sozinho quando um HD é conectado.

Se preferir, dá para rodar cada etapa direto pelos `.bat`:

### 1. No computador antigo
1. Copie esta pasta para o HD externo.
2. Feche os programas abertos (navegador, Outlook, etc.).
3. Dê dois cliques em **`1-FAZER-BACKUP.bat`** e aceite a permissão de administrador.
4. Escolha o disco de destino e responda as perguntas.

O script mede o tamanho do backup **antes de copiar** e avisa se não couber. Se não couber, dá pra trocar de disco ou tirar itens.

O backup fica em `<DISCO>:\BACKUP_PC\<NOME-DO-PC>_<data>\`.

### 2. No computador novo
1. Ligue o HD externo.
2. Dê dois cliques em **`2-RESTAURAR-BACKUP.bat`**.
3. Escolha **[1] TUDO**, ou restaure por partes pelo menu.

O script encontra o backup sozinho em qualquer disco conectado e verifica se há espaço.

## O que é salvo

| Item | Como é restaurado |
|---|---|
| Arquivos dos usuários (Área de Trabalho, Documentos, Downloads, Imagens, Vídeos, Músicas…) | Copiados para as pastas certas, inclusive se estiverem no OneDrive |
| Configurações dos programas (`AppData\Roaming`) | Copiadas de volta (opcional, depois de reinstalar os programas) |
| Navegadores: Chrome, Edge, Brave, Vivaldi, Firefox | Favoritos, extensões e histórico |
| Programas instalados | Reinstalados pelo `winget`. Os que não estão nele vão para uma lista de instalação manual |
| Redes Wi-Fi e senhas | Importadas automaticamente |
| Pastas extras na raiz do `C:` e outros discos | Opcional, você escolhe o que entra |
| Informações do sistema, chave do Windows (BIOS), impressoras | Ficam salvas para consulta |

## Limitações

- **Programas** não são copiados, são **reinstalados** (o `winget` instala a versão mais recente).
- **Senhas salvas no navegador** não funcionam em outro PC, porque o Windows as criptografa por computador. Use a sincronização da conta Google/Microsoft.
- **Licenças** de programas pagos precisam ser ativadas de novo.
- **Arquivos do OneDrive que só estão na nuvem** não são baixados, porque já estão salvos online.
- Em discos **FAT32**, arquivos maiores que 4 GB não cabem. Prefira NTFS ou exFAT.

## Estrutura do backup

```
BACKUP_PC\<PC>_<data>\
├── 00_Info\          sistema, impressoras, variáveis de ambiente, log da cópia
├── 01_Programas\     lista do winget (.json) + lista completa (.csv/.txt)
├── 02_Usuarios\      <usuário>\Perfil  e  <usuário>\AppData
├── 03_WiFi\          perfis de rede (.xml)
├── 04_OutrasPastas\  pastas extras e outros discos
└── RESUMO.txt
```

## Arquivos

| Arquivo | Função |
|---|---|
| `0-ABRIR-PAINEL.bat` | Abre o painel com botões (`painel.ps1`) |
| `1-FAZER-BACKUP.bat` | Atalho que roda `backup.ps1` |
| `2-RESTAURAR-BACKUP.bat` | Atalho que roda `restaurar.ps1` |
| `backup.ps1` | Faz o backup |
| `restaurar.ps1` | Restaura o backup (menu interativo) |
| `painel.ps1` | Janela gráfica (WPF) que chama os scripts acima |
| `LEIA-ME.txt` | Guia rápido para quem vai usar o HD |

## Requisitos

- Windows 10 ou 11
- Permissão de administrador
- Internet no computador novo (para reinstalar os programas)
