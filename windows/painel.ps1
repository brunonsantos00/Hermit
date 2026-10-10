<#
    PAINEL - Backup e Migração
    --------------------------
    Janela com botões para fazer e restaurar o backup sem precisar mexer no terminal.
    Abra com "0-ABRIR-PAINEL.bat".
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$versao = '2.0'

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Backup e Migração" Width="980" SizeToContent="Height" WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="CanMinimize"
        FontFamily="Segoe UI" TextOptions.TextFormattingMode="Display" UseLayoutRounding="True">
  <Window.Resources>
    <SolidColorBrush x:Key="Texto" Color="#1B2A3A"/>
    <SolidColorBrush x:Key="TextoSuave" Color="#5B6B7F"/>
    <SolidColorBrush x:Key="Borda" Color="#D5DCE5"/>

    <Style x:Key="Rotulo" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#5B6B7F"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <!-- Cartão de ação (backup / restaurar) -->
    <Style x:Key="CartaoAcao" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Tag" Value="#1F6FB2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="White" BorderBrush="#D5DCE5" BorderThickness="1" CornerRadius="4">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="4"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border Background="{TemplateBinding Tag}" CornerRadius="4,0,0,4"/>
                <ContentPresenter Grid.Column="1" Margin="20,18"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="BorderBrush" Value="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"/>
                <Setter TargetName="b" Property="Background" Value="#FAFCFE"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="b" Property="Background" Value="#F0F4F8"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Botão do rodapé -->
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
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Botão tipo link -->
    <Style x:Key="BotaoLink" TargetType="Button">
      <Setter Property="Foreground" Value="#1F6FB2"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent" Padding="6,2" CornerRadius="3">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#E8F1FA"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Botões da barra de título -->
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
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Cabeçalho -->
      <Border x:Name="BarraTitulo" Background="#0F2B46" CornerRadius="5,5,0,0" Padding="20,12,10,12">
        <Grid>
          <StackPanel Orientation="Horizontal">
            <Border Width="34" Height="34" Background="#1F6FB2" CornerRadius="3">
              <TextBlock Text="&#xE777;" FontFamily="Segoe MDL2 Assets" FontSize="16" Foreground="White"
                         HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Text="Backup e Migração" Foreground="White" FontSize="15" FontWeight="SemiBold"/>
              <TextBlock Text="Backup e migração de estações de trabalho" Foreground="#9FB3C8" FontSize="11.5"/>
            </StackPanel>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top">
            <Button x:Name="BtnMinimizar" Style="{StaticResource BotaoJanela}" Content="&#xE921;"/>
            <Button x:Name="BtnFechar" Style="{StaticResource BotaoJanela}" Content="&#xE8BB;"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Faixa de informações da estação -->
      <Border Grid.Row="1" Background="White" BorderBrush="#D5DCE5" BorderThickness="0,0,0,1" Padding="24,10">
        <StackPanel x:Name="FaixaInfo" Orientation="Horizontal"/>
      </Border>

      <!-- Corpo -->
      <StackPanel Grid.Row="2" Margin="24,20,24,20">
        <TextBlock Text="AÇÕES" Style="{StaticResource Rotulo}"/>
        <Grid Margin="0,8,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="16"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>

          <Button x:Name="BtnBackup" Style="{StaticResource CartaoAcao}" Tag="#1F6FB2">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Border Width="44" Height="44" Background="#E8F1FA" CornerRadius="3" VerticalAlignment="Center">
                <TextBlock Text="&#xE74E;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#1F6FB2"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <StackPanel Grid.Column="1" Margin="16,0,12,0" VerticalAlignment="Center">
                <TextBlock Text="Fazer backup" FontSize="15" FontWeight="SemiBold" Foreground="#1B2A3A"/>
                <TextBlock Text="Salva arquivos, configurações, redes Wi-Fi e a lista de programas desta estação."
                           FontSize="12" Foreground="#5B6B7F" TextWrapping="Wrap" Margin="0,3,0,0"/>
              </StackPanel>
              <TextBlock Grid.Column="2" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#8A97A8" VerticalAlignment="Center"/>
            </Grid>
          </Button>

          <Button x:Name="BtnRestaurar" Grid.Column="2" Style="{StaticResource CartaoAcao}" Tag="#2E7D5B">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Border Width="44" Height="44" Background="#E6F2EC" CornerRadius="3" VerticalAlignment="Center">
                <TextBlock Text="&#xE777;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#2E7D5B"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <StackPanel Grid.Column="1" Margin="16,0,12,0" VerticalAlignment="Center">
                <TextBlock Text="Restaurar backup" FontSize="15" FontWeight="SemiBold" Foreground="#1B2A3A"/>
                <TextBlock Text="Transfere o backup para esta estação e reinstala os programas automaticamente."
                           FontSize="12" Foreground="#5B6B7F" TextWrapping="Wrap" Margin="0,3,0,0"/>
              </StackPanel>
              <TextBlock Grid.Column="2" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#8A97A8" VerticalAlignment="Center"/>
            </Grid>
          </Button>
        </Grid>

        <!-- Dispositivos -->
        <Grid Margin="0,22,0,8">
          <TextBlock Text="DISPOSITIVOS DE ARMAZENAMENTO" Style="{StaticResource Rotulo}" VerticalAlignment="Center"/>
          <Button x:Name="BtnAtualizar" Style="{StaticResource BotaoLink}" HorizontalAlignment="Right">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" VerticalAlignment="Center"/>
              <TextBlock Text="Atualizar" Margin="6,0,0,0"/>
            </StackPanel>
          </Button>
        </Grid>
        <Border Background="White" BorderBrush="#D5DCE5" BorderThickness="1" CornerRadius="4">
          <StackPanel>
            <Border Background="#F7F9FB" BorderBrush="#D5DCE5" BorderThickness="0,0,0,1" CornerRadius="4,4,0,0" Padding="16,8">
              <Grid x:Name="Cabecalho"/>
            </Border>
            <ScrollViewer MaxHeight="300" VerticalScrollBarVisibility="Auto">
              <StackPanel x:Name="ListaDiscos"/>
            </ScrollViewer>
          </StackPanel>
        </Border>

        <!-- Último backup -->
        <TextBlock Text="ÚLTIMO BACKUP" Style="{StaticResource Rotulo}" Margin="0,22,0,8"/>
        <Border Background="White" BorderBrush="#D5DCE5" BorderThickness="1" CornerRadius="4" Padding="16,12">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <TextBlock Text="&#xE81C;" FontFamily="Segoe MDL2 Assets" FontSize="16" Foreground="#5B6B7F" VerticalAlignment="Center"/>
            <TextBlock x:Name="TxtUltimo" Grid.Column="1" Margin="12,0,0,0" FontSize="12.5" Foreground="#1B2A3A"
                       VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
          </Grid>
        </Border>
      </StackPanel>

      <!-- Rodapé -->
      <Border Grid.Row="3" Background="#E9EDF2" BorderBrush="#D5DCE5" BorderThickness="0,1,0,0" CornerRadius="0,0,5,5" Padding="24,10">
        <Grid>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="BtnPasta" Style="{StaticResource BotaoRodape}">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Foreground="#5B6B7F"/>
                <TextBlock Text="Abrir backups" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
            <Button x:Name="BtnGuia" Style="{StaticResource BotaoRodape}">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE897;" FontFamily="Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Foreground="#5B6B7F"/>
                <TextBlock Text="Guia rápido" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
            <Button x:Name="BtnRegistro" Style="{StaticResource BotaoRodape}">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE9F9;" FontFamily="Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Foreground="#5B6B7F"/>
                <TextBlock Text="Ver registro" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
            <TextBlock x:Name="TxtStatus" Foreground="#5B6B7F" FontSize="12" MaxWidth="330" TextTrimming="CharacterEllipsis"/>
            <TextBlock x:Name="TxtVersao" Foreground="#8A97A8" FontSize="11.5" Margin="16,0,0,0"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Window>
'@

try {
    $janela = [Windows.Markup.XamlReader]::Parse($xaml)
} catch {
    [Windows.MessageBox]::Show("Não foi possível abrir o painel:`n$($_.Exception.Message)", 'Backup e Migração', 'OK', 'Error') | Out-Null
    exit 1
}
function Ctrl([string]$nome) { $janela.FindName($nome) }
$conversor = New-Object Windows.Media.BrushConverter
function Cor([string]$hex) { $conversor.ConvertFromString($hex) }

function Status([string]$texto, [string]$cor = '#5B6B7F') {
    $s = Ctrl 'TxtStatus'; $s.Text = $texto; $s.Foreground = Cor $cor
}

# ---------- Elementos simples ----------
function Texto([string]$t, [double]$tam = 12.5, [string]$cor = '#1B2A3A', [string]$peso = 'Normal') {
    $b = New-Object Windows.Controls.TextBlock
    $b.Text = $t; $b.FontSize = $tam; $b.Foreground = Cor $cor; $b.FontWeight = $peso
    $b.VerticalAlignment = 'Center'; $b.TextTrimming = 'CharacterEllipsis'
    return $b
}
function Icone([int]$codigo, [double]$tam = 12, [string]$cor = '#5B6B7F') {
    $b = New-Object Windows.Controls.TextBlock
    $b.Text = [char]$codigo; $b.FontFamily = 'Segoe MDL2 Assets'; $b.FontSize = $tam; $b.Foreground = Cor $cor
    $b.VerticalAlignment = 'Center'
    return $b
}
function Horizontal { $p = New-Object Windows.Controls.StackPanel; $p.Orientation = 'Horizontal'; $p.VerticalAlignment = 'Center'; return $p }
function Colocar($grid, $elemento, [int]$coluna, [int]$linha = 0, [int]$span = 1) {
    [Windows.Controls.Grid]::SetColumn($elemento, $coluna)
    [Windows.Controls.Grid]::SetRow($elemento, $linha)
    if ($span -gt 1) { [Windows.Controls.Grid]::SetColumnSpan($elemento, $span) }
    [void]$grid.Children.Add($elemento)
}

# Colunas da tabela de dispositivos (cabeçalho e linhas usam as mesmas larguras)
$colunas = '70', '*', '100', '230', '190', '80'
function Nova-GradeTabela {
    $g = New-Object Windows.Controls.Grid
    $conv = New-Object Windows.GridLengthConverter
    foreach ($w in $colunas) {
        $c = New-Object Windows.Controls.ColumnDefinition
        $c.Width = $conv.ConvertFromString($w)
        $g.ColumnDefinitions.Add($c)
    }
    return $g
}

# Faixa de informações da estação
$sistema = Get-CimInstance Win32_OperatingSystem
$faixa = Ctrl 'FaixaInfo'
foreach ($par in @(@('Estação', $env:COMPUTERNAME), @('Sistema', ($sistema.Caption -replace '^Microsoft ', '')), @('Usuário', $env:USERNAME))) {
    $p = Horizontal; $p.Margin = '0,0,28,0'
    [void]$p.Children.Add((Texto "$($par[0]): " 12 '#5B6B7F'))
    [void]$p.Children.Add((Texto $par[1] 12 '#1B2A3A' 'SemiBold'))
    [void]$faixa.Children.Add($p)
}
(Ctrl 'TxtVersao').Text = "v$versao"

# Cabeçalho da tabela
$cab = Ctrl 'Cabecalho'
$cabGrade = Nova-GradeTabela
$i = 0
foreach ($t in 'UNIDADE', 'NOME', 'TIPO', 'SISTEMA OPERACIONAL', 'ESPAÇO', 'BACKUPS') {
    Colocar $cabGrade (Texto $t 10.5 '#5B6B7F' 'SemiBold') $i; $i++
}
$cab.Children.Add($cabGrade) | Out-Null

# ---------- Detecção de discos e sistemas ----------
function Detectar-SO([string]$letra) {
    if ($letra -eq $env:SystemDrive) { return @{ Nome = ($sistema.Caption -replace '^Microsoft ', ''); Familia = 'windows' } }
    $kernel = "$letra\Windows\System32\ntoskrnl.exe"
    if (Test-Path -LiteralPath $kernel) {
        $v = (Get-Item -LiteralPath $kernel).VersionInfo
        if ($v.FileMajorPart -ge 10) { if ($v.FileBuildPart -ge 22000) { $n = 'Windows 11' } else { $n = 'Windows 10' } }
        elseif ($v.FileMajorPart -eq 6 -and $v.FileMinorPart -eq 3) { $n = 'Windows 8.1' }
        elseif ($v.FileMajorPart -eq 6 -and $v.FileMinorPart -eq 2) { $n = 'Windows 8' }
        elseif ($v.FileMajorPart -eq 6 -and $v.FileMinorPart -eq 1) { $n = 'Windows 7' }
        else { $n = 'Windows' }
        return @{ Nome = "$n (build $($v.FileBuildPart))"; Familia = 'windows' }
    }
    $osRelease = "$letra\etc\os-release"
    if (Test-Path -LiteralPath $osRelease) {
        $linha = Get-Content -LiteralPath $osRelease -ErrorAction SilentlyContinue | Where-Object { $_ -like 'PRETTY_NAME=*' } | Select-Object -First 1
        $n = if ($linha) { ($linha -replace '^PRETTY_NAME=', '').Trim('"') } else { 'Linux' }
        return @{ Nome = $n; Familia = 'linux' }
    }
    if (Test-Path -LiteralPath "$letra\System\Library\CoreServices\SystemVersion.plist") { return @{ Nome = 'macOS'; Familia = 'mac' } }
    return $null
}

$tiposLinuxGpt = @{
    '{0fc63daf-8483-4772-8e79-3d69d8477de4}' = 'dados'
    '{e6d6d379-f507-44c2-a23c-238f2a3df928}' = 'LVM'
    '{4f68bce3-e8cd-4db1-96e7-fbcaf984b709}' = 'raiz'
    '{933ac7e1-2eb4-4f13-b844-0e14e2aef915}' = 'home'
    '{0657fd6d-a4ab-43c4-84e5-0933c84b4f4f}' = 'swap'
}
$tiposLinuxMbr = @{ 131 = 'dados'; 142 = 'LVM'; 130 = 'swap' }

function Get-Discos {
    @(Get-CimInstance Win32_LogicalDisk | Where-Object { ($_.DriveType -eq 2 -or $_.DriveType -eq 3) -and $_.Size } | Sort-Object DeviceID)
}

function Get-Dispositivos {
    $lista = New-Object System.Collections.ArrayList
    $particoes = @(Get-Partition -ErrorAction SilentlyContinue)
    $discosFisicos = @{}
    Get-Disk -ErrorAction SilentlyContinue | ForEach-Object { $discosFisicos[[int]$_.Number] = $_ }

    foreach ($d in Get-Discos) {
        $letra = $d.DeviceID
        $part = $particoes | Where-Object { $_.DriveLetter -and "$($_.DriveLetter):" -eq $letra } | Select-Object -First 1
        $tipo = if ($letra -eq $env:SystemDrive) { 'Sistema' } elseif ($d.DriveType -eq 2) { 'Removível' } else { 'Interno' }
        if ($part -and $discosFisicos.ContainsKey([int]$part.DiskNumber) -and "$($discosFisicos[[int]$part.DiskNumber].BusType)" -eq 'USB') { $tipo = 'USB' }
        [void]$lista.Add([pscustomobject]@{
            Letra = $letra; Nome = $(if ($d.VolumeName) { $d.VolumeName } elseif ($letra -eq $env:SystemDrive) { 'Windows' } else { 'Sem nome' })
            Tipo = $tipo; FS = $d.FileSystem; Total = [double]$d.Size; Livre = [double]$d.FreeSpace
            SO = (Detectar-SO $letra); Acessivel = $true
        })
    }

    # Partições de Linux não têm letra no Windows, mas dá para reconhecer pelo tipo da partição
    foreach ($p in $particoes) {
        $gpt = "$($p.GptType)".ToLower()
        $papel = $null
        if ($gpt -and $tiposLinuxGpt.ContainsKey($gpt)) { $papel = $tiposLinuxGpt[$gpt] }
        elseif ($p.MbrType -and $tiposLinuxMbr.ContainsKey([int]$p.MbrType)) { $papel = $tiposLinuxMbr[[int]$p.MbrType] }
        if (-not $papel -or $papel -eq 'swap') { continue }
        [void]$lista.Add([pscustomobject]@{
            Letra = '—'; Nome = "Disco $($p.DiskNumber), partição $($p.PartitionNumber)"
            Tipo = 'Linux'; FS = "Linux ($papel)"; Total = [double]$p.Size; Livre = -1
            SO = @{ Nome = 'Linux'; Familia = 'linux' }; Acessivel = $false
        })
    }
    return $lista
}

function Get-Backups {
    @(foreach ($d in Get-Discos) {
        foreach ($nomePasta in 'BACKUP_PC', 'BACKUP_NOTEBOOK') {
            $b = "$($d.DeviceID)\$nomePasta"
            if (Test-Path -LiteralPath $b) { Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue }
        }
    }) | Sort-Object LastWriteTime -Descending
}

# ---------- Linha da tabela ----------
function Nova-Linha($dev, [int]$qtdBackups, [bool]$ultima) {
    $borda = New-Object Windows.Controls.Border
    $borda.Padding = '16,10'
    if (-not $ultima) { $borda.BorderBrush = Cor '#EEF1F5'; $borda.BorderThickness = '0,0,0,1' }

    $g = Nova-GradeTabela
    foreach ($h in 'Auto', 'Auto') { $r = New-Object Windows.Controls.RowDefinition; $r.Height = 'Auto'; $g.RowDefinitions.Add($r) }

    # Unidade
    $u = Horizontal
    $corIcone = if ($dev.Tipo -eq 'USB') { '#1F6FB2' } elseif ($dev.Tipo -eq 'Linux') { '#B4690E' } else { '#5B6B7F' }
    [void]$u.Children.Add((Icone 0xEDA2 15 $corIcone))
    $tl = Texto "  $($dev.Letra)" 12.5 '#1B2A3A' 'SemiBold'
    [void]$u.Children.Add($tl)
    Colocar $g $u 0

    Colocar $g (Texto $dev.Nome) 1
    Colocar $g (Texto $(if ($dev.Tipo -eq 'Linux') { 'Partição' } else { "$($dev.Tipo) · $($dev.FS)" }) 12 '#5B6B7F') 2

    # Sistema operacional
    $so = Horizontal
    $ponto = New-Object Windows.Shapes.Ellipse
    $ponto.Width = 8; $ponto.Height = 8; $ponto.Margin = '0,0,8,0'
    if ($dev.SO) {
        $ponto.Fill = Cor $(switch ($dev.SO.Familia) { 'windows' { '#2E7D5B' } 'linux' { '#B4690E' } default { '#6B5BA8' } })
        [void]$so.Children.Add($ponto)
        [void]$so.Children.Add((Texto $dev.SO.Nome 12 '#1B2A3A'))
    } else {
        $ponto.Fill = Cor '#A3AEBB'
        [void]$so.Children.Add($ponto)
        [void]$so.Children.Add((Texto 'Nenhum sistema' 12 '#8A97A8'))
    }
    Colocar $g $so 3

    # Espaço
    if ($dev.Livre -ge 0) {
        $esp = New-Object Windows.Controls.StackPanel
        $esp.VerticalAlignment = 'Center'; $esp.Margin = '0,0,16,0'
        $pct = [math]::Round(100 * ($dev.Total - $dev.Livre) / $dev.Total)
        $trilho = New-Object Windows.Controls.Border
        $trilho.Height = 5; $trilho.Background = Cor '#E4E9EF'; $trilho.CornerRadius = 2
        $bg = New-Object Windows.Controls.Grid
        foreach ($v in $pct, (100 - $pct)) {
            $c = New-Object Windows.Controls.ColumnDefinition
            $c.Width = New-Object Windows.GridLength([math]::Max($v, 0.01), 'Star')
            $bg.ColumnDefinitions.Add($c)
        }
        $cheio = New-Object Windows.Controls.Border
        $cheio.CornerRadius = 2
        $cheio.Background = Cor $(if ($pct -ge 90) { '#C0392B' } elseif ($pct -ge 75) { '#C77700' } else { '#1F6FB2' })
        [void]$bg.Children.Add($cheio); $trilho.Child = $bg
        [void]$esp.Children.Add($trilho)
        $txt = Texto ('{0:N1} GB livres de {1:N1} GB' -f ($dev.Livre / 1GB), ($dev.Total / 1GB)) 11 '#5B6B7F'
        $txt.Margin = '0,4,0,0'
        [void]$esp.Children.Add($txt)
        Colocar $g $esp 4
    } else {
        Colocar $g (Texto ('{0:N1} GB' -f ($dev.Total / 1GB)) 12 '#5B6B7F') 4
    }

    # Backups
    if ($qtdBackups -gt 0) {
        $selo = New-Object Windows.Controls.Border
        $selo.Background = Cor '#E6F2EC'; $selo.BorderBrush = Cor '#B7D8C6'; $selo.BorderThickness = 1
        $selo.CornerRadius = 3; $selo.Padding = '8,2'; $selo.HorizontalAlignment = 'Left'; $selo.VerticalAlignment = 'Center'
        $selo.Child = Texto $qtdBackups 11.5 '#2E7D5B' 'SemiBold'
        Colocar $g $selo 5
    } else {
        Colocar $g (Texto '—' 12 '#A3AEBB') 5
    }

    # Mensagem embaixo da linha
    $aviso = $null
    if (-not $dev.Acessivel) {
        $aviso = @(0xE946, '#8A5A00', '#FFF8E6', '#F0D9A8',
                   'Partição de Linux: o Windows não consegue ler este dispositivo. Para fazer o backup dele, use o script linux/backup.sh no próprio Linux.')
    } elseif (-not $dev.SO) {
        $aviso = @(0xE946, '#4A5A6E', '#F3F5F8', '#DDE3EA',
                   'Neste dispositivo não há nenhum sistema operacional, então não é possível fazer backup de sistema a partir dele. Ele pode ser usado para guardar backups.')
    }
    if ($aviso) {
        $caixa = New-Object Windows.Controls.Border
        $caixa.Background = Cor $aviso[2]; $caixa.BorderBrush = Cor $aviso[3]; $caixa.BorderThickness = 1
        $caixa.CornerRadius = 3; $caixa.Padding = '10,6'; $caixa.Margin = '0,8,0,0'
        $linhaAviso = Horizontal
        [void]$linhaAviso.Children.Add((Icone $aviso[0] 12 $aviso[1]))
        $ta = Texto $aviso[4] 11.5 $aviso[1]
        $ta.Margin = '8,0,0,0'; $ta.TextWrapping = 'Wrap'; $ta.TextTrimming = 'None'; $ta.MaxWidth = 800
        [void]$linhaAviso.Children.Add($ta)
        $caixa.Child = $linhaAviso
        Colocar $g $caixa 0 1 6
    }

    $borda.Child = $g
    return $borda
}

function Atualizar {
    $lista = Ctrl 'ListaDiscos'
    $lista.Children.Clear()
    $script:backups = Get-Backups
    $devs = @(Get-Dispositivos)
    for ($i = 0; $i -lt $devs.Count; $i++) {
        $d = $devs[$i]
        $qtd = if ($d.Acessivel) { @($script:backups | Where-Object { $_.FullName.StartsWith($d.Letra) }).Count } else { 0 }
        [void]$lista.Children.Add((Nova-Linha $d $qtd ($i -eq $devs.Count - 1)))
    }

    $u = Ctrl 'TxtUltimo'
    if ($script:backups.Count) {
        $b = $script:backups[0]
        $extra = ''
        $resumo = Join-Path $b.FullName 'RESUMO.txt'
        if (Test-Path -LiteralPath $resumo) {
            $linha = Get-Content -LiteralPath $resumo -Encoding UTF8 | Where-Object { $_ -like 'Tamanho:*' } | Select-Object -First 1
            if ($linha) { $extra = '   ·   ' + $linha.Replace('Tamanho:', '').Trim() }
        } else { $extra = '   ·   incompleto ou em andamento' }
        $origem = Join-Path $b.FullName '00_Info\origem.txt'
        if ((Test-Path -LiteralPath $origem) -and ((Get-Content -LiteralPath $origem -TotalCount 1) -match 'linux')) { $extra += '   ·   feito no Linux' }
        $u.Text = '{0}   ·   {1:dd/MM/yyyy HH:mm}{2}' -f $b.FullName, $b.LastWriteTime, $extra
        $u.Foreground = Cor '#1B2A3A'
    } else {
        $u.Text = 'Nenhum backup encontrado nos dispositivos conectados.'
        $u.Foreground = Cor '#8A97A8'
    }
    $script:assinatura = (Get-Discos | ForEach-Object DeviceID) -join ','
}

# ---------- Ações ----------
function Rodar([string]$arquivo, [string]$nome) {
    $caminho = Join-Path $PSScriptRoot $arquivo
    if (-not (Test-Path -LiteralPath $caminho)) { Status "Arquivo $arquivo não encontrado." '#C0392B'; return }
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$caminho`""
        Status "$nome iniciado em outra janela. Siga as instruções nela." '#2E7D5B'
    } catch {
        Status 'Permissão de administrador negada.' '#C77700'
    }
}

(Ctrl 'BtnBackup').Add_Click({ Rodar 'backup.ps1' 'Backup' })
(Ctrl 'BtnRestaurar').Add_Click({
    if (-not $script:backups.Count) {
        $r = [Windows.MessageBox]::Show("Nenhum backup foi encontrado nos dispositivos conectados.`n`nConecte o disco com a pasta BACKUP_PC e clique em Atualizar.`n`nAbrir a restauração mesmo assim?",
                                        'Restaurar backup', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    Rodar 'restaurar.ps1' 'Restauração'
})
(Ctrl 'BtnPasta').Add_Click({
    if ($script:backups.Count) { Start-Process explorer.exe $script:backups[0].Parent.FullName }
    else { Status 'Nenhum backup encontrado ainda.' '#C77700' }
})
(Ctrl 'BtnGuia').Add_Click({
    $g = Join-Path $PSScriptRoot 'LEIA-ME.txt'
    if (Test-Path -LiteralPath $g) { Start-Process notepad.exe "`"$g`"" } else { Status 'LEIA-ME.txt não encontrado.' '#C0392B' }
})
(Ctrl 'BtnRegistro').Add_Click({
    $reg = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'ultima-execucao-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($reg) { Start-Process notepad.exe "`"$($reg.FullName)`"" } else { Status 'Nenhum registro ainda: rode um backup primeiro.' }
})
(Ctrl 'BtnAtualizar').Add_Click({ Atualizar; Status 'Lista atualizada.' })
(Ctrl 'BtnFechar').Add_Click({ $janela.Close() })
(Ctrl 'BtnMinimizar').Add_Click({ $janela.WindowState = 'Minimized' })
(Ctrl 'BarraTitulo').Add_MouseLeftButtonDown({ $janela.DragMove() })

# Detecta sozinho quando um disco é conectado ou removido
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(3)
$timer.Add_Tick({
    $agora = (Get-Discos | ForEach-Object DeviceID) -join ','
    if ($agora -ne $script:assinatura) { Atualizar; Status 'Dispositivos atualizados.' }
})

Atualizar
Status 'Pronto.'
$timer.Start()
[void]$janela.ShowDialog()
$timer.Stop()
