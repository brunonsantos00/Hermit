<#
    HERMIT COMPARE - window that compares the backup with this computer
    ------------------------------------------------------------
    Shows, in an organized way, what is in the backup but did not reach this computer.
    Open it with "Hermit-Compare.exe" (project root). The comparison itself is done by compare.ps1.
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

try {
    Add-Type -Namespace Win32 -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string id);'
    [void][Win32.Shell]::SetCurrentProcessExplicitAppUserModelID('Hermit.Compare')
} catch {}

. (Join-Path $PSScriptRoot 'language.ps1')
$script:idioma = Get-Idioma ''
$limiteLinhas = 300     # files shown per folder (the rest is in the report)

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="1040" Height="800" MinWidth="820" MinHeight="560" WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="CanResizeWithGrip"
        FontFamily="Segoe UI" TextOptions.TextFormattingMode="Display" UseLayoutRounding="True">
  <Window.Resources>
    <Style x:Key="Rotulo" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#5B6B7F"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="BotaoPrimario" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="#1F6FB2" CornerRadius="3" Padding="22,8">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#185C94"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Background" Value="#134A78"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Background" Value="#A9BCD0"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BotaoRodape" TargetType="Button">
      <Setter Property="Foreground" Value="#1B2A3A"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="White" BorderBrush="#C3CCD7" BorderThickness="1" CornerRadius="3" Padding="12,6">
              <ContentPresenter HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="BorderBrush" Value="#1F6FB2"/>
                <Setter TargetName="b" Property="Background" Value="#F4F8FC"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BotaoJanela" TargetType="Button">
      <Setter Property="Foreground" Value="#C9D6E3"/>
      <Setter Property="Width" Value="44"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent" CornerRadius="3">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1D4268"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border Margin="12" CornerRadius="6" Background="#F3F5F8" BorderBrush="#B8C3D0" BorderThickness="1">
    <Border.Effect><DropShadowEffect BlurRadius="20" ShadowDepth="2" Opacity="0.35" Color="#0F2B46"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Header -->
      <Border x:Name="BarraTitulo" Background="#0F2B46" CornerRadius="5,5,0,0" Padding="20,12,10,12">
        <Grid>
          <StackPanel Orientation="Horizontal">
            <Border Width="34" Height="34" Background="#1F6FB2" CornerRadius="3">
              <TextBlock Text="&#xE9D5;" FontFamily="Segoe MDL2 Assets" FontSize="16" Foreground="White"
                         HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock x:Name="TxtTitulo" Foreground="White" FontSize="15" FontWeight="SemiBold"/>
              <TextBlock x:Name="TxtSubtitulo" Foreground="#9FB3C8" FontSize="11.5"/>
            </StackPanel>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top">
            <Button x:Name="BtnMinimizar" Style="{StaticResource BotaoJanela}" Content="&#xE921;"/>
            <Button x:Name="BtnFechar" Style="{StaticResource BotaoJanela}" Content="&#xE8BB;"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Choices -->
      <Border Grid.Row="1" Background="White" BorderBrush="#D5DCE5" BorderThickness="0,0,0,1" Padding="24,14">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel>
            <TextBlock x:Name="TxtRotBackup" Style="{StaticResource Rotulo}"/>
            <ComboBox x:Name="CmbBackup" Margin="0,5,0,0" Height="30" FontSize="12.5" VerticalContentAlignment="Center"/>
          </StackPanel>
          <StackPanel Grid.Column="1" Margin="14,0,0,0" Width="170">
            <TextBlock x:Name="TxtRotUsuario" Style="{StaticResource Rotulo}"/>
            <ComboBox x:Name="CmbUsuario" Margin="0,5,0,0" Height="30" FontSize="12.5" VerticalContentAlignment="Center"/>
          </StackPanel>
          <StackPanel Grid.Column="2" Margin="14,0,0,0" VerticalAlignment="Bottom">
            <CheckBox x:Name="ChkConfig" FontSize="12" Foreground="#1B2A3A" Margin="0,0,0,8"/>
            <Button x:Name="BtnComparar" Style="{StaticResource BotaoPrimario}">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE9D5;" FontFamily="Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center"/>
                <TextBlock x:Name="TxtComparar" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Body -->
      <Grid Grid.Row="2" Margin="24,18,24,14">
        <!-- Initial state / messages -->
        <StackPanel x:Name="PainelMensagem" VerticalAlignment="Center" HorizontalAlignment="Center" MaxWidth="560">
          <TextBlock x:Name="IcoMensagem" Text="&#xE9D5;" FontFamily="Segoe MDL2 Assets" FontSize="40" Foreground="#A9BCD0" HorizontalAlignment="Center"/>
          <TextBlock x:Name="TxtMensagem" FontSize="16" FontWeight="SemiBold" Foreground="#1B2A3A" TextAlignment="Center" Margin="0,14,0,0" TextWrapping="Wrap"/>
          <TextBlock x:Name="TxtMensagem2" FontSize="12.5" Foreground="#5B6B7F" TextAlignment="Center" Margin="0,6,0,0" TextWrapping="Wrap"/>
          <ProgressBar x:Name="Progresso" IsIndeterminate="True" Height="4" Width="320" Margin="0,18,0,0" Visibility="Collapsed"
                       Foreground="#1F6FB2" Background="#E4E9EF" BorderThickness="0"/>
        </StackPanel>

        <!-- Result -->
        <Grid x:Name="PainelResultado" Visibility="Collapsed">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid x:Name="Cartoes">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="14"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="14"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
          </Grid>
          <Grid Grid.Row="1" Margin="0,18,0,8">
            <TextBlock x:Name="TxtRotDetalhes" Style="{StaticResource Rotulo}" VerticalAlignment="Center"/>
            <Border HorizontalAlignment="Right" Width="280" Background="White" BorderBrush="#C3CCD7" BorderThickness="1" CornerRadius="3">
              <Grid>
                <TextBlock Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#8A97A8" Margin="9,0,0,0" VerticalAlignment="Center"/>
                <TextBox x:Name="TxtFiltro" BorderThickness="0" Background="Transparent" Margin="28,0,6,0" Height="28"
                         VerticalContentAlignment="Center" FontSize="12.5"/>
                <TextBlock x:Name="TxtFiltroDica" IsHitTestVisible="False" Foreground="#A3AEBB" FontSize="12.5" Margin="31,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Border>
          </Grid>
          <ScrollViewer x:Name="Rolagem" Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="ListaSecoes"/>
          </ScrollViewer>
        </Grid>
      </Grid>

      <!-- Footer -->
      <Border Grid.Row="3" Background="#E9EDF2" BorderBrush="#D5DCE5" BorderThickness="0,1,0,0" CornerRadius="0,0,5,5" Padding="24,10">
        <Grid>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="BtnRelatorio" Style="{StaticResource BotaoRodape}" IsEnabled="False">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE8A5;" FontFamily="Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Foreground="#5B6B7F"/>
                <TextBlock x:Name="TxtRelatorio" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
            <Button x:Name="BtnCopiar" Style="{StaticResource BotaoRodape}" IsEnabled="False">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Foreground="#5B6B7F"/>
                <TextBlock x:Name="TxtCopiar" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
            <Button x:Name="BtnPastaBackup" Style="{StaticResource BotaoRodape}" IsEnabled="False">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Foreground="#5B6B7F"/>
                <TextBlock x:Name="TxtPastaBackup" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
          </StackPanel>
          <TextBlock x:Name="TxtStatus" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#5B6B7F" FontSize="12"
                     MaxWidth="360" TextTrimming="CharacterEllipsis" Margin="0,0,14,0"/>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Window>
'@

try { $janela = [Windows.Markup.XamlReader]::Parse($xaml) }
catch {
    [Windows.MessageBox]::Show("$(L 'Não foi possível abrir o comparador' 'Could not open the comparison tool'):`n$($_.Exception.Message)", 'Hermit', 'OK', 'Error') | Out-Null
    exit 1
}
function Ctrl([string]$nome) { $janela.FindName($nome) }
$arquivoIcone = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\icon.ico'
if (Test-Path -LiteralPath $arquivoIcone) { try { $janela.Icon = [Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri $arquivoIcone)) } catch {} }

$conversor = New-Object Windows.Media.BrushConverter
function Cor([string]$hex) { $conversor.ConvertFromString($hex) }
function Status([string]$texto, [string]$cor = '#5B6B7F') { $s = Ctrl 'TxtStatus'; $s.Text = $texto; $s.Foreground = Cor $cor }
# Counts items of a list coming from JSON (an empty list may become $null)
function Cont($x) { @($x | Where-Object { $_ }).Count }
function Tamanho([double]$b) { if ($b -lt 1MB) { '{0:N0} KB' -f [math]::Ceiling($b / 1KB) } elseif ($b -lt 1GB) { '{0:N1} MB' -f ($b / 1MB) } else { '{0:N2} GB' -f ($b / 1GB) } }
function Texto([string]$t, [double]$tam = 12.5, [string]$cor = '#1B2A3A', [string]$peso = 'Normal') {
    $b = New-Object Windows.Controls.TextBlock
    $b.Text = $t; $b.FontSize = $tam; $b.Foreground = Cor $cor; $b.FontWeight = $peso
    $b.VerticalAlignment = 'Center'; $b.TextTrimming = 'CharacterEllipsis'
    return $b
}
function Icone([int]$codigo, [double]$tam = 12, [string]$cor = '#5B6B7F') {
    $b = New-Object Windows.Controls.TextBlock
    $b.Text = [char]$codigo; $b.FontFamily = 'Segoe MDL2 Assets'; $b.FontSize = $tam; $b.Foreground = Cor $cor; $b.VerticalAlignment = 'Center'
    return $b
}
function Colunas($grid, [string[]]$larguras) {
    $conv = New-Object Windows.GridLengthConverter
    foreach ($w in $larguras) { $c = New-Object Windows.Controls.ColumnDefinition; $c.Width = $conv.ConvertFromString($w); $grid.ColumnDefinitions.Add($c) }
}
function Colocar($grid, $el, [int]$col) { [Windows.Controls.Grid]::SetColumn($el, $col); [void]$grid.Children.Add($el) }
function Selo([string]$texto, [string]$fundo, [string]$borda, [string]$cor) {
    $s = New-Object Windows.Controls.Border
    $s.Background = Cor $fundo; $s.BorderBrush = Cor $borda; $s.BorderThickness = 1; $s.CornerRadius = 3; $s.Padding = '8,1'; $s.Margin = '8,0,0,0'
    $s.VerticalAlignment = 'Center'; $s.Child = Texto $texto 11.5 $cor 'SemiBold'
    return $s
}

# ---------- Texts ----------
$janela.Title = L 'Comparador de backup' 'Backup comparison'
(Ctrl 'TxtTitulo').Text = L 'Comparador de backup' 'Backup comparison'
(Ctrl 'TxtSubtitulo').Text = L 'Mostra o que está no backup e não chegou neste computador' 'Shows what is in the backup but did not reach this computer'
(Ctrl 'TxtRotBackup').Text = L 'BACKUP' 'BACKUP'
(Ctrl 'TxtRotUsuario').Text = L 'USUÁRIO DO BACKUP' 'BACKUP USER'
(Ctrl 'ChkConfig').Content = L 'Incluir configurações (AppData)' 'Include settings (AppData)'
(Ctrl 'TxtComparar').Text = L 'Comparar' 'Compare'
(Ctrl 'TxtRotDetalhes').Text = L 'DETALHES POR PASTA' 'DETAILS BY FOLDER'
(Ctrl 'TxtFiltroDica').Text = L 'Filtrar arquivos...' 'Filter files...'
(Ctrl 'TxtRelatorio').Text = L 'Abrir relatório' 'Open report'
(Ctrl 'TxtCopiar').Text = L 'Copiar o que falta' 'Copy what is missing'
(Ctrl 'TxtPastaBackup').Text = L 'Abrir pasta do backup' 'Open backup folder'

function Mensagem([int]$icone, [string]$cor, [string]$t1, [string]$t2, [bool]$carregando = $false) {
    (Ctrl 'PainelResultado').Visibility = 'Collapsed'
    (Ctrl 'PainelMensagem').Visibility = 'Visible'
    $i = Ctrl 'IcoMensagem'; $i.Text = [char]$icone; $i.Foreground = Cor $cor
    (Ctrl 'TxtMensagem').Text = $t1
    (Ctrl 'TxtMensagem2').Text = $t2
    (Ctrl 'Progresso').Visibility = $(if ($carregando) { 'Visible' } else { 'Collapsed' })
}

# ---------- Backups and users ----------
function Get-Backups {
    @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 } | ForEach-Object {
        foreach ($nomePasta in 'BACKUP_PC', 'BACKUP_NOTEBOOK') {
            $b = "$($_.DeviceID)\$nomePasta"
            if (Test-Path -LiteralPath $b) { Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue }
        }
    } | Sort-Object LastWriteTime -Descending)
}

function Carregar-Backups {
    $cmb = Ctrl 'CmbBackup'
    $cmb.Items.Clear()
    $script:listaBackups = @(Get-Backups)
    foreach ($b in $script:listaBackups) {
        $item = New-Object Windows.Controls.ComboBoxItem
        $item.Content = '{0}    ({1:dd/MM/yyyy HH:mm})' -f $b.FullName, $b.LastWriteTime
        $item.Tag = $b.FullName
        [void]$cmb.Items.Add($item)
    }
    if ($script:listaBackups.Count) {
        $cmb.SelectedIndex = 0
        Mensagem 0xE9D5 '#A9BCD0' (L 'Escolha o backup e clique em Comparar' 'Choose the backup and click Compare') (L 'A comparação só lê os arquivos: nada é apagado ou alterado.' 'The comparison only reads files: nothing is deleted or changed.')
    } else {
        Carregar-Usuarios
        Mensagem 0xE7BA '#C77700' (L 'Nenhum backup encontrado' 'No backup found') (L 'Conecte o disco que tem a pasta BACKUP_PC. A lista atualiza sozinha.' 'Connect the disk that has the BACKUP_PC folder. The list refreshes automatically.')
    }
    $script:assinatura = (Get-CimInstance Win32_LogicalDisk | ForEach-Object DeviceID) -join ','
}

function Carregar-Usuarios {
    $cmb = Ctrl 'CmbUsuario'
    $cmb.Items.Clear()
    $sel = (Ctrl 'CmbBackup').SelectedItem
    if ($sel) {
        foreach ($u in @(Get-ChildItem -LiteralPath "$($sel.Tag)\02_Usuarios" -Directory -ErrorAction SilentlyContinue)) { [void]$cmb.Items.Add($u.Name) }
        $igual = $cmb.Items.IndexOf($env:USERNAME)
        $cmb.SelectedIndex = $(if ($igual -ge 0) { $igual } elseif ($cmb.Items.Count) { 0 } else { -1 })
    }
    (Ctrl 'BtnComparar').IsEnabled = [bool]($sel -and $cmb.SelectedIndex -ge 0)
    (Ctrl 'BtnPastaBackup').IsEnabled = [bool]$sel
}

# ---------- Draw the result ----------
function Cartao([int]$coluna, [int]$icone, [string]$cor, [string]$fundo, [string]$rotulo, [string]$numero, [string]$detalhe) {
    $b = New-Object Windows.Controls.Border
    $b.Background = Cor 'White'; $b.BorderBrush = Cor '#D5DCE5'; $b.BorderThickness = 1; $b.CornerRadius = 4
    $g = New-Object Windows.Controls.Grid
    Colunas $g @('4', '*')
    $barra = New-Object Windows.Controls.Border; $barra.Background = Cor $cor; $barra.CornerRadius = '4,0,0,4'
    Colocar $g $barra 0
    $conteudo = New-Object Windows.Controls.Grid; $conteudo.Margin = '18,14'
    Colunas $conteudo @('Auto', '*')
    $ic = New-Object Windows.Controls.Border; $ic.Width = 42; $ic.Height = 42; $ic.CornerRadius = 3; $ic.Background = Cor $fundo; $ic.VerticalAlignment = 'Center'
    $gl = Icone $icone 19 $cor; $gl.HorizontalAlignment = 'Center'; $ic.Child = $gl
    Colocar $conteudo $ic 0
    $txt = New-Object Windows.Controls.StackPanel; $txt.Margin = '14,0,0,0'; $txt.VerticalAlignment = 'Center'
    [void]$txt.Children.Add((Texto $rotulo 10.5 '#5B6B7F' 'SemiBold'))
    [void]$txt.Children.Add((Texto $numero 24 '#1B2A3A' 'SemiBold'))
    [void]$txt.Children.Add((Texto $detalhe 11.5 '#5B6B7F'))
    Colocar $conteudo $txt 1
    Colocar $g $conteudo 1
    $b.Child = $g
    [Windows.Controls.Grid]::SetColumn($b, $coluna)
    [void](Ctrl 'Cartoes').Children.Add($b)
}

function Linha-Arquivo($f, [bool]$falta) {
    $g = New-Object Windows.Controls.Grid
    $g.Margin = '0,0,0,0'
    Colunas $g @('26', '*', '90', '100')
    Colocar $g (Icone 0xE8A5 12 $(if ($falta) { '#C0392B' } else { '#C77700' })) 0
    $nome = Texto $f.Arquivo 12.5 '#1B2A3A'; $nome.ToolTip = $f.Arquivo
    Colocar $g $nome 1
    $t = Texto (Tamanho $f.Bytes) 12 '#5B6B7F'; $t.HorizontalAlignment = 'Right'; $t.Margin = '0,0,14,0'
    Colocar $g $t 2
    $s = if ($falta) { Selo (L 'Falta' 'Missing') '#FDECEA' '#F5C6C0' '#B03A2E' } else { Selo (L 'Mais novo' 'Newer') '#FFF4E0' '#F0D9A8' '#8A5A00' }
    $s.HorizontalAlignment = 'Left'
    Colocar $g $s 3
    $borda = New-Object Windows.Controls.Border
    $borda.Padding = '14,6'; $borda.BorderBrush = Cor '#EEF1F5'; $borda.BorderThickness = '0,1,0,0'
    $borda.Child = $g
    return $borda
}

function Secao($item, [string]$filtro) {
    $faltam = @($item.Faltam | Where-Object { $_ -and (-not $filtro -or $_.Arquivo -like "*$filtro*") })
    $novos = @($item.Novos | Where-Object { $_ -and (-not $filtro -or $_.Arquivo -like "*$filtro*") })
    if ($filtro -and -not $faltam.Count -and -not $novos.Count) { return $null }
    $temDif = ($faltam.Count + $novos.Count) -gt 0
    $cor = if ($faltam.Count) { '#C0392B' } elseif ($novos.Count) { '#C77700' } else { '#2E7D5B' }

    $caixa = New-Object Windows.Controls.Border
    $caixa.Background = Cor 'White'; $caixa.BorderBrush = Cor '#D5DCE5'; $caixa.BorderThickness = 1; $caixa.CornerRadius = 4; $caixa.Margin = '0,0,0,10'
    $pilha = New-Object Windows.Controls.StackPanel

    # Section header (click to expand/collapse)
    $cab = New-Object Windows.Controls.Grid
    Colunas $cab @('4', '*')
    $barra = New-Object Windows.Controls.Border; $barra.Background = Cor $cor; $barra.CornerRadius = $(if ($temDif) { '4,0,0,0' } else { '4,0,0,4' })
    Colocar $cab $barra 0
    $linha = New-Object Windows.Controls.Grid; $linha.Margin = '14,10'
    Colunas $linha @('Auto', '*', 'Auto')
    $seta = Icone $(if ($temDif) { 0xE70D } else { 0xE73E }) 11 $(if ($temDif) { '#5B6B7F' } else { '#2E7D5B' }); $seta.Margin = '0,0,12,0'
    Colocar $linha $seta 0
    $nomes = New-Object Windows.Controls.StackPanel
    [void]$nomes.Children.Add((Texto $item.Nome 13.5 '#1B2A3A' 'SemiBold'))
    [void]$nomes.Children.Add((Texto "$(L 'neste computador' 'on this computer'): $($item.Destino)" 11 '#8A97A8'))
    Colocar $linha $nomes 1
    $selos = New-Object Windows.Controls.StackPanel; $selos.Orientation = 'Horizontal'; $selos.VerticalAlignment = 'Center'
    if ($faltam.Count) {
        $txtFalta = '{0} {1} · {2}' -f $faltam.Count, $(if ($faltam.Count -eq 1) { L 'falta' 'missing' } else { L 'faltam' 'missing' }), (Tamanho (($faltam | Measure-Object Bytes -Sum).Sum))
        [void]$selos.Children.Add((Selo $txtFalta '#FDECEA' '#F5C6C0' '#B03A2E'))
    }
    if ($novos.Count) { [void]$selos.Children.Add((Selo ('{0} {1}' -f $novos.Count, $(if ($novos.Count -eq 1) { L 'mais novo' 'newer' } else { L 'mais novos' 'newer' })) '#FFF4E0' '#F0D9A8' '#8A5A00')) }
    if (-not $temDif) { [void]$selos.Children.Add((Selo (L 'Tudo certo' 'All good') '#E6F2EC' '#B7D8C6' '#2E7D5B')) }
    Colocar $linha $selos 2
    Colocar $cab $linha 1
    $cabBorda = New-Object Windows.Controls.Border; $cabBorda.Background = Cor '#00FFFFFF'; $cabBorda.Child = $cab
    if ($temDif) { $cabBorda.Cursor = 'Hand' }
    [void]$pilha.Children.Add($cabBorda)

    # File list
    if ($temDif) {
        $lista = New-Object Windows.Controls.StackPanel
        $todos = @($faltam | ForEach-Object { @{ F = $_; Falta = $true } }) + @($novos | ForEach-Object { @{ F = $_; Falta = $false } })
        foreach ($x in ($todos | Select-Object -First $limiteLinhas)) { [void]$lista.Children.Add((Linha-Arquivo $x.F $x.Falta)) }
        if ($todos.Count -gt $limiteLinhas) {
            $mais = New-Object Windows.Controls.Border; $mais.Padding = '14,8'; $mais.BorderBrush = Cor '#EEF1F5'; $mais.BorderThickness = '0,1,0,0'
            $mais.Child = Texto ((L '... e mais {0} arquivos. A lista completa está no relatório.' '... and {0} more files. The full list is in the report.') -f ($todos.Count - $limiteLinhas)) 12 '#5B6B7F'
            [void]$lista.Children.Add($mais)
        }
        [void]$pilha.Children.Add($lista)
        $cabBorda.Tag = @{ Lista = $lista; Seta = $seta }
        $cabBorda.Add_MouseLeftButtonUp({
            param($s, $e)
            $l = $s.Tag.Lista; $a = $s.Tag.Seta
            if ($l.Visibility -eq 'Visible') { $l.Visibility = 'Collapsed'; $a.Text = [char]0xE76C } else { $l.Visibility = 'Visible'; $a.Text = [char]0xE70D }
        })
    }
    $caixa.Child = $pilha
    return $caixa
}

function Desenhar-Resultado {
    $d = $script:resultado
    $cartoes = Ctrl 'Cartoes'
    foreach ($c in @($cartoes.Children)) { $cartoes.Children.Remove($c) }
    $semDif = @($d.Itens | Where-Object { -not (Cont $_.Faltam) -and -not (Cont $_.Novos) }).Count
    Cartao 0 0xE711 '#C0392B' '#FDECEA' (L 'FALTAM NESTE COMPUTADOR' 'MISSING ON THIS COMPUTER') ('{0:N0}' -f $d.TotalFaltam) ((L 'arquivos · {0}' 'files · {0}') -f (Tamanho $d.TotalBytes))
    Cartao 2 0xE895 '#C77700' '#FFF4E0' (L 'MAIS NOVOS NO BACKUP' 'NEWER IN THE BACKUP') ('{0:N0}' -f $d.TotalNovos) (L 'arquivos com versão mais nova' 'files with a newer version')
    Cartao 4 0xE73E '#2E7D5B' '#E6F2EC' (L 'PASTAS SEM DIFERENÇA' 'FOLDERS WITH NO DIFFERENCE') ('{0} / {1}' -f $semDif, @($d.Itens).Count) (L 'pastas iguais ao backup' 'folders identical to the backup')

    $filtro = (Ctrl 'TxtFiltro').Text.Trim()
    $lista = Ctrl 'ListaSecoes'
    $lista.Children.Clear()
    # Folders with differences first
    $ordenados = @($d.Itens | Sort-Object @{ Expression = { -((Cont $_.Faltam) * 1000000 + (Cont $_.Novos)) } })
    foreach ($item in $ordenados) { $s = Secao $item $filtro; if ($s) { [void]$lista.Children.Add($s) } }
    if (-not $lista.Children.Count) { [void]$lista.Children.Add((Texto (L 'Nenhum arquivo com esse nome.' 'No file with that name.') 12.5 '#8A97A8')) }

    (Ctrl 'PainelMensagem').Visibility = 'Collapsed'
    (Ctrl 'PainelResultado').Visibility = 'Visible'
    # Scrolls the list back to the top after it finishes rendering
    [void]$janela.Dispatcher.BeginInvoke([Action]{ (Ctrl 'Rolagem').ScrollToTop() }, [Windows.Threading.DispatcherPriority]::ContextIdle)
}

# ---------- Compare (runs compare.ps1 hidden and reads the result) ----------
function Comparar {
    $sel = (Ctrl 'CmbBackup').SelectedItem
    $usuario = (Ctrl 'CmbUsuario').SelectedItem
    if (-not $sel -or -not $usuario) { return }
    $script:json = Join-Path $env:TEMP ('hermit_comparacao_' + [guid]::NewGuid().ToString('N') + '.json')
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot 'compare.ps1')`" -Backup `"$($sel.Tag)`" -Usuario `"$usuario`" -SaidaJson `"$script:json`" -Idioma $script:idioma"
    if ((Ctrl 'ChkConfig').IsChecked) { $arg += ' -IncluirConfiguracoes' }
    $script:processo = Start-Process powershell.exe -ArgumentList $arg -WindowStyle Hidden -PassThru
    foreach ($n in 'BtnComparar', 'CmbBackup', 'CmbUsuario', 'ChkConfig', 'BtnRelatorio', 'BtnCopiar') { (Ctrl $n).IsEnabled = $false }
    Mensagem 0xE895 '#1F6FB2' (L 'Comparando...' 'Comparing...') (L 'Lendo os arquivos do backup e deste computador. Em backups grandes isso pode levar alguns minutos.' 'Reading the files of the backup and of this computer. Large backups may take a few minutes.') $true
    Status (L 'Comparando...' 'Comparing...')
    $script:inicio = Get-Date
    $script:espera.Start()
}

$script:espera = New-Object Windows.Threading.DispatcherTimer
$script:espera.Interval = [TimeSpan]::FromMilliseconds(500)
$script:espera.Add_Tick({
    if (-not $script:processo.HasExited) {
        (Ctrl 'TxtMensagem2').Text = (L 'Lendo os arquivos... {0:mm\:ss}' 'Reading the files... {0:mm\:ss}') -f ((Get-Date) - $script:inicio)
        return
    }
    $script:espera.Stop()
    foreach ($n in 'BtnComparar', 'CmbBackup', 'CmbUsuario', 'ChkConfig') { (Ctrl $n).IsEnabled = $true }
    if (-not (Test-Path -LiteralPath $script:json)) {
        Mensagem 0xE783 '#C0392B' (L 'A comparação falhou' 'The comparison failed') ((L 'Veja o registro em {0}' 'See the log at {0}') -f (Join-Path $PSScriptRoot 'last-run-compare.txt'))
        Status (L 'Erro na comparação.' 'Comparison error.') '#C0392B'
        return
    }
    $script:resultado = Get-Content -LiteralPath $script:json -Raw -Encoding UTF8 | ConvertFrom-Json
    [IO.File]::Delete($script:json)
    Desenhar-Resultado
    (Ctrl 'BtnRelatorio').IsEnabled = $true
    (Ctrl 'BtnCopiar').IsEnabled = ($script:resultado.TotalFaltam -gt 0)
    $tempo = '{0:mm\:ss}' -f ((Get-Date) - $script:inicio)
    if ($script:resultado.TotalFaltam -eq 0 -and $script:resultado.TotalNovos -eq 0) { Status ((L 'Tudo certo: nada falta neste computador ({0}).' 'All good: nothing is missing on this computer ({0}).') -f $tempo) '#2E7D5B' }
    else { Status ((L 'Comparação concluída em {0}.' 'Comparison finished in {0}.') -f $tempo) }
})

# ---------- Events ----------
(Ctrl 'CmbBackup').Add_SelectionChanged({ Carregar-Usuarios })
(Ctrl 'CmbUsuario').Add_SelectionChanged({ (Ctrl 'BtnComparar').IsEnabled = [bool]((Ctrl 'CmbBackup').SelectedItem -and (Ctrl 'CmbUsuario').SelectedIndex -ge 0) })
(Ctrl 'BtnComparar').Add_Click({ Comparar })
(Ctrl 'TxtFiltro').Add_TextChanged({
    (Ctrl 'TxtFiltroDica').Visibility = $(if ((Ctrl 'TxtFiltro').Text) { 'Collapsed' } else { 'Visible' })
    if ($script:resultado) { Desenhar-Resultado }
})
(Ctrl 'BtnRelatorio').Add_Click({ if ($script:resultado -and (Test-Path -LiteralPath $script:resultado.Relatorio)) { Start-Process notepad.exe "`"$($script:resultado.Relatorio)`"" } })
(Ctrl 'BtnPastaBackup').Add_Click({ $sel = (Ctrl 'CmbBackup').SelectedItem; if ($sel) { Start-Process explorer.exe "`"$($sel.Tag)`"" } })
(Ctrl 'BtnCopiar').Add_Click({
    # Opens compare.ps1 in normal mode: it compares again and asks before copying
    $sel = (Ctrl 'CmbBackup').SelectedItem; $usuario = (Ctrl 'CmbUsuario').SelectedItem
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'compare.ps1')`" -Backup `"$($sel.Tag)`" -Usuario `"$usuario`" -Idioma $script:idioma"
    if ((Ctrl 'ChkConfig').IsChecked) { $arg += ' -IncluirConfiguracoes' }
    Start-Process powershell.exe -ArgumentList $arg
    Status (L 'A cópia foi aberta em outra janela: confirme lá.' 'The copy was opened in another window: confirm it there.') '#2E7D5B'
})
(Ctrl 'BtnFechar').Add_Click({ $janela.Close() })
(Ctrl 'BtnMinimizar').Add_Click({ $janela.WindowState = 'Minimized' })
(Ctrl 'BarraTitulo').Add_MouseLeftButtonDown({ $janela.DragMove() })

# Refreshes the backup list when a disk is connected or removed
$timerDiscos = New-Object Windows.Threading.DispatcherTimer
$timerDiscos.Interval = [TimeSpan]::FromSeconds(3)
$timerDiscos.Add_Tick({
    if ($script:espera.IsEnabled) { return }
    $agora = (Get-CimInstance Win32_LogicalDisk | ForEach-Object DeviceID) -join ','
    if ($agora -ne $script:assinatura) { $script:resultado = $null; Carregar-Backups; Status (L 'Lista de backups atualizada.' 'Backup list refreshed.') }
})

Carregar-Backups
Status (L 'Pronto.' 'Ready.')
$timerDiscos.Start()
[void]$janela.ShowDialog()
$timerDiscos.Stop()
