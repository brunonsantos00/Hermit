<#
    PAINEL - Backup e Migração
    --------------------------
    Janela com botões para fazer e restaurar o backup sem precisar mexer no terminal.
    Abra com "0-ABRIR-PAINEL.bat".
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Backup e Migração" Width="780" SizeToContent="Height" WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="CanMinimize"
        FontFamily="Segoe UI" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
    <Style x:Key="BotaoGrande" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="16" Padding="22,20">
              <Border.Effect><DropShadowEffect BlurRadius="18" ShadowDepth="3" Opacity="0.35" Color="#000000"/></Border.Effect>
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Opacity" Value="0.9"/>
                <Setter TargetName="b" Property="RenderTransform"><Setter.Value><TranslateTransform Y="-2"/></Setter.Value></Setter>
              </Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.75"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="BotaoSecundario" TargetType="Button">
      <Setter Property="Foreground" Value="#E2E8F0"/>
      <Setter Property="Background" Value="#1E293B"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,10,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="10" Padding="14,9"
                    BorderBrush="#2B3A55" BorderThickness="1">
              <ContentPresenter HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#2A3A55"/>
                <Setter TargetName="b" Property="BorderBrush" Value="#3B82F6"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="BotaoJanela" TargetType="Button">
      <Setter Property="Foreground" Value="#94A3B8"/>
      <Setter Property="Width" Value="46"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent" CornerRadius="8" Margin="2,6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1E293B"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#111B2E"/>
      <Setter Property="BorderBrush" Value="#1F2B44"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="14"/>
      <Setter Property="Padding" Value="18,14"/>
      <Setter Property="Margin" Value="0,14,0,0"/>
    </Style>
  </Window.Resources>

  <Border Margin="14" CornerRadius="18" Background="#0B1220" BorderBrush="#1F2B44" BorderThickness="1">
    <Border.Effect><DropShadowEffect BlurRadius="24" ShadowDepth="0" Opacity="0.6" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="46"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Barra de título -->
      <Grid x:Name="BarraTitulo" Background="Transparent">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
          <TextBlock Text="&#xE777;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="#3B82F6" VerticalAlignment="Center"/>
          <TextBlock Text="Backup e Migração" Foreground="#94A3B8" FontSize="12.5" Margin="10,0,0,0" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,8,0">
          <Button x:Name="BtnMinimizar" Style="{StaticResource BotaoJanela}" Content="&#xE921;"/>
          <Button x:Name="BtnFechar" Style="{StaticResource BotaoJanela}" Content="&#xE8BB;"/>
        </StackPanel>
      </Grid>

      <!-- Conteúdo -->
      <StackPanel Grid.Row="1" Margin="30,4,30,0">
        <TextBlock Text="O que você quer fazer?" Foreground="White" FontSize="28" FontWeight="SemiBold"/>
        <TextBlock x:Name="TxtPC" Foreground="#64748B" FontSize="13" Margin="0,4,0,0"/>

        <Grid Margin="0,20,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="16"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>

          <Button x:Name="BtnBackup" Style="{StaticResource BotaoGrande}">
            <Button.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#3B82F6" Offset="0"/>
                <GradientStop Color="#6366F1" Offset="1"/>
              </LinearGradientBrush>
            </Button.Background>
            <StackPanel>
              <TextBlock Text="&#xE74E;" FontFamily="Segoe MDL2 Assets" FontSize="30"/>
              <TextBlock Text="Fazer backup" FontSize="21" FontWeight="SemiBold" Margin="0,12,0,0"/>
              <TextBlock Text="Salva arquivos, configurações, Wi-Fi e a lista de programas no HD externo."
                         FontSize="12.5" Opacity="0.85" TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>
          </Button>

          <Button x:Name="BtnRestaurar" Grid.Column="2" Style="{StaticResource BotaoGrande}">
            <Button.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#10B981" Offset="0"/>
                <GradientStop Color="#0D9488" Offset="1"/>
              </LinearGradientBrush>
            </Button.Background>
            <StackPanel>
              <TextBlock Text="&#xE777;" FontFamily="Segoe MDL2 Assets" FontSize="30"/>
              <TextBlock Text="Restaurar backup" FontSize="21" FontWeight="SemiBold" Margin="0,12,0,0"/>
              <TextBlock Text="Passa tudo do backup para este computador e reinstala os programas."
                         FontSize="12.5" Opacity="0.85" TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>
          </Button>
        </Grid>

        <!-- Discos -->
        <Border Style="{StaticResource Card}" Margin="0,18,0,0">
          <StackPanel>
            <Grid>
              <TextBlock Text="DISCOS CONECTADOS" Foreground="#64748B" FontSize="11.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
              <Button x:Name="BtnAtualizar" HorizontalAlignment="Right" Style="{StaticResource BotaoSecundario}" Margin="0" Padding="0">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" VerticalAlignment="Center"/>
                  <TextBlock Text="Atualizar" FontSize="11.5" Margin="6,0,0,0"/>
                </StackPanel>
              </Button>
            </Grid>
            <ScrollViewer MaxHeight="190" VerticalScrollBarVisibility="Auto" Margin="0,8,0,0">
              <StackPanel x:Name="ListaDiscos"/>
            </ScrollViewer>
          </StackPanel>
        </Border>

        <!-- Último backup -->
        <Border Style="{StaticResource Card}">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border Width="40" Height="40" CornerRadius="10" Background="#1E293B" VerticalAlignment="Center">
              <TextBlock Text="&#xE81C;" FontFamily="Segoe MDL2 Assets" FontSize="17" Foreground="#A5B4FC"
                         HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
              <TextBlock Text="ÚLTIMO BACKUP" Foreground="#64748B" FontSize="11.5" FontWeight="SemiBold"/>
              <TextBlock x:Name="TxtUltimo" Foreground="#E2E8F0" FontSize="13.5" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
            </StackPanel>
          </Grid>
        </Border>
      </StackPanel>

      <!-- Rodapé -->
      <Border Grid.Row="2" BorderBrush="#1F2B44" BorderThickness="0,1,0,0" Margin="0,18,0,0" Padding="30,14,30,18">
        <Grid>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="BtnPasta" Style="{StaticResource BotaoSecundario}">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center"/>
                <TextBlock Text="Abrir backups" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
            <Button x:Name="BtnGuia" Style="{StaticResource BotaoSecundario}">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE897;" FontFamily="Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center"/>
                <TextBlock Text="Guia rápido" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
            <Button x:Name="BtnRegistro" Style="{StaticResource BotaoSecundario}">
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="&#xE9F9;" FontFamily="Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center"/>
                <TextBlock Text="Ver registro" Margin="8,0,0,0"/>
              </StackPanel>
            </Button>
          </StackPanel>
          <TextBlock x:Name="TxtStatus" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#64748B"
                     FontSize="12" MaxWidth="250" TextWrapping="Wrap" TextAlignment="Right"/>
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

$sistema = Get-CimInstance Win32_OperatingSystem
(Ctrl 'TxtPC').Text = "Computador: $env:COMPUTERNAME   •   $($sistema.Caption -replace 'Microsoft ', '')"

function Status([string]$texto, [string]$cor = '#64748B') {
    $s = Ctrl 'TxtStatus'; $s.Text = $texto; $s.Foreground = Cor $cor
}

# ---------- Dados ----------
function Get-Discos {
    @(Get-CimInstance Win32_LogicalDisk | Where-Object { ($_.DriveType -eq 2 -or $_.DriveType -eq 3) -and $_.Size } | Sort-Object DeviceID)
}
function Get-Backups {
    @(foreach ($d in Get-Discos) {
        foreach ($nomePasta in 'BACKUP_PC', 'BACKUP_NOTEBOOK') {
            $b = "$($d.DeviceID)\$nomePasta"
            if (Test-Path -LiteralPath $b) { Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue }
        }
    }) | Sort-Object LastWriteTime -Descending
}
function Tipo-Disco($d) {
    if ($d.DeviceID -eq $env:SystemDrive) { return 'Sistema' }
    try {
        $bus = (Get-Partition -DriveLetter $d.DeviceID.TrimEnd(':') -ErrorAction Stop | Get-Disk -ErrorAction Stop).BusType
        if ("$bus" -eq 'USB') { return 'USB' }
        return 'Interno'
    } catch {
        if ($d.DriveType -eq 2) { return 'Removível' }
        return 'Disco'
    }
}

# ---------- Linha de cada disco ----------
function Nova-LinhaDisco($d, [int]$qtdBackups) {
    $usado = $d.Size - $d.FreeSpace
    $pct = [math]::Round(100 * $usado / $d.Size)
    $corBarra = if ($pct -ge 90) { '#EF4444' } elseif ($pct -ge 75) { '#F59E0B' } else { '#3B82F6' }
    $tipo = Tipo-Disco $d

    $g = New-Object Windows.Controls.Grid
    $g.Margin = '0,8,0,4'
    foreach ($w in 'Auto', '*', 'Auto') {
        $c = New-Object Windows.Controls.ColumnDefinition
        $c.Width = (New-Object Windows.GridLengthConverter).ConvertFromString($w)
        $g.ColumnDefinitions.Add($c)
    }

    $icone = New-Object Windows.Controls.TextBlock
    $icone.Text = [char]0xEDA2; $icone.FontFamily = 'Segoe Fluent Icons, Segoe MDL2 Assets'; $icone.FontSize = 26
    $icone.Foreground = Cor $(if ($tipo -eq 'USB') { '#A5B4FC' } else { '#94A3B8' })
    $icone.VerticalAlignment = 'Center'; $icone.Margin = '0,0,14,0'
    [Windows.Controls.Grid]::SetColumn($icone, 0); [void]$g.Children.Add($icone)

    $info = New-Object Windows.Controls.StackPanel
    [Windows.Controls.Grid]::SetColumn($info, 1)
    $nome = New-Object Windows.Controls.TextBlock
    $rotulo = if ($d.VolumeName) { $d.VolumeName } elseif ($d.DeviceID -eq $env:SystemDrive) { 'Windows' } else { 'Sem nome' }
    $letra = New-Object Windows.Documents.Run("$($d.DeviceID)  ")
    $letra.FontWeight = 'SemiBold'
    $nome.Inlines.Add($letra)
    $nome.Inlines.Add((New-Object Windows.Documents.Run($rotulo)))
    $extra = New-Object Windows.Documents.Run("   $tipo • $($d.FileSystem)")
    $extra.Foreground = Cor '#64748B'; $extra.FontSize = 11.5
    $nome.Inlines.Add($extra)
    $nome.Foreground = Cor '#E2E8F0'; $nome.FontSize = 13.5
    [void]$info.Children.Add($nome)

    # Barra de uso
    $trilho = New-Object Windows.Controls.Border
    $trilho.Height = 6; $trilho.CornerRadius = 3; $trilho.Background = Cor '#1E293B'; $trilho.Margin = '0,7,0,5'
    $barraGrid = New-Object Windows.Controls.Grid
    foreach ($v in $pct, (100 - $pct)) {
        $c = New-Object Windows.Controls.ColumnDefinition
        $c.Width = New-Object Windows.GridLength([math]::Max($v, 0.01), 'Star')
        $barraGrid.ColumnDefinitions.Add($c)
    }
    $preenchido = New-Object Windows.Controls.Border
    $preenchido.CornerRadius = 3; $preenchido.Background = Cor $corBarra
    [void]$barraGrid.Children.Add($preenchido)
    $trilho.Child = $barraGrid
    [void]$info.Children.Add($trilho)

    $livre = New-Object Windows.Controls.TextBlock
    $livre.Text = ('{0:N1} GB livres de {1:N1} GB' -f ($d.FreeSpace / 1GB), ($d.Size / 1GB))
    $livre.Foreground = Cor '#64748B'; $livre.FontSize = 11.5
    [void]$info.Children.Add($livre)
    [void]$g.Children.Add($info)

    if ($qtdBackups -gt 0) {
        $selo = New-Object Windows.Controls.Border
        $selo.CornerRadius = 9; $selo.Padding = '10,3'; $selo.Margin = '14,0,0,0'
        $selo.Background = Cor '#14532D'; $selo.VerticalAlignment = 'Center'
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = if ($qtdBackups -eq 1) { '1 backup' } else { "$qtdBackups backups" }
        $t.Foreground = Cor '#86EFAC'; $t.FontSize = 11.5; $t.FontWeight = 'SemiBold'
        $selo.Child = $t
        [Windows.Controls.Grid]::SetColumn($selo, 2); [void]$g.Children.Add($selo)
    }
    return $g
}

function Atualizar {
    $lista = Ctrl 'ListaDiscos'
    $lista.Children.Clear()
    $script:backups = Get-Backups
    foreach ($d in Get-Discos) {
        $qtd = @($script:backups | Where-Object { $_.FullName.StartsWith($d.DeviceID) }).Count
        [void]$lista.Children.Add((Nova-LinhaDisco $d $qtd))
    }

    $u = Ctrl 'TxtUltimo'
    if ($script:backups.Count) {
        $b = $script:backups[0]
        $tam = ''
        $resumo = Join-Path $b.FullName 'RESUMO.txt'
        if (Test-Path -LiteralPath $resumo) {
            $linha = Get-Content -LiteralPath $resumo -Encoding UTF8 | Where-Object { $_ -like 'Tamanho:*' } | Select-Object -First 1
            if ($linha) { $tam = '  •  ' + $linha.Replace('Tamanho:', '').Trim() }
        } else { $tam = '  •  incompleto ou em andamento' }
        $u.Text = '{0}  •  {1:dd/MM/yyyy HH:mm}{2}' -f $b.FullName, $b.LastWriteTime, $tam
        $u.Foreground = Cor '#E2E8F0'
    } else {
        $u.Text = 'Nenhum backup encontrado nos discos conectados.'
        $u.Foreground = Cor '#64748B'
    }
    $script:assinatura = (Get-Discos | ForEach-Object DeviceID) -join ','
}

# ---------- Ações ----------
function Rodar([string]$arquivo, [string]$nome) {
    $caminho = Join-Path $PSScriptRoot $arquivo
    if (-not (Test-Path -LiteralPath $caminho)) { Status "Arquivo $arquivo não encontrado." '#F87171'; return }
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$caminho`""
        Status "$nome aberto em outra janela. Siga as instruções nela." '#86EFAC'
    } catch {
        Status 'É preciso clicar em "Sim" na permissão do Windows.' '#FBBF24'
    }
}

(Ctrl 'BtnBackup').Add_Click({ Rodar 'backup.ps1' 'Backup' })
(Ctrl 'BtnRestaurar').Add_Click({
    if (-not $script:backups.Count) {
        $r = [Windows.MessageBox]::Show("Nenhum backup foi encontrado nos discos conectados.`n`nConecte o HD com a pasta BACKUP_PC e clique em Atualizar.`n`nAbrir a restauração mesmo assim?",
                                        'Restaurar backup', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    Rodar 'restaurar.ps1' 'Restauração'
})
(Ctrl 'BtnPasta').Add_Click({
    if ($script:backups.Count) { Start-Process explorer.exe $script:backups[0].Parent.FullName }
    else { Status 'Nenhum backup encontrado ainda.' '#FBBF24' }
})
(Ctrl 'BtnGuia').Add_Click({
    $g = Join-Path $PSScriptRoot 'LEIA-ME.txt'
    if (Test-Path -LiteralPath $g) { Start-Process notepad.exe "`"$g`"" } else { Status 'LEIA-ME.txt não encontrado.' '#F87171' }
})
(Ctrl 'BtnRegistro').Add_Click({
    $reg = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'ultima-execucao-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($reg) { Start-Process notepad.exe "`"$($reg.FullName)`"" } else { Status 'Nenhum registro ainda: rode um backup primeiro.' }
})
(Ctrl 'BtnAtualizar').Add_Click({ Atualizar; Status 'Lista atualizada.' })
(Ctrl 'BtnFechar').Add_Click({ $janela.Close() })
(Ctrl 'BtnMinimizar').Add_Click({ $janela.WindowState = 'Minimized' })
(Ctrl 'BarraTitulo').Add_MouseLeftButtonDown({ $janela.DragMove() })

# Detecta sozinho quando um HD é conectado ou removido
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(3)
$timer.Add_Tick({
    $agora = (Get-Discos | ForEach-Object DeviceID) -join ','
    if ($agora -ne $script:assinatura) { Atualizar; Status 'Discos atualizados.' }
})

Atualizar
$timer.Start()
[void]$janela.ShowDialog()
$timer.Stop()
