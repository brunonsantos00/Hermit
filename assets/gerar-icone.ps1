<#
    Gera o ícone do projeto: assets\icone.ico (Windows) e assets\icone.png (Linux).
    Rode de novo só se quiser mudar o desenho.
#>

Add-Type -AssemblyName System.Drawing

function Desenhar([int]$tam) {
    $s = $tam / 256.0
    $bmp = New-Object Drawing.Bitmap $tam, $tam
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([Drawing.Color]::Transparent)

    # Fundo: quadrado arredondado azul
    $m = 8 * $s; $lado = $tam - 2 * $m; $r = 52 * $s
    $fundo = New-Object Drawing.Drawing2D.GraphicsPath
    $fundo.AddArc($m, $m, 2 * $r, 2 * $r, 180, 90)
    $fundo.AddArc($m + $lado - 2 * $r, $m, 2 * $r, 2 * $r, 270, 90)
    $fundo.AddArc($m + $lado - 2 * $r, $m + $lado - 2 * $r, 2 * $r, 2 * $r, 0, 90)
    $fundo.AddArc($m, $m + $lado - 2 * $r, 2 * $r, 2 * $r, 90, 90)
    $fundo.CloseFigure()
    $grad = New-Object Drawing.Drawing2D.LinearGradientBrush(
        (New-Object Drawing.PointF 0, 0), (New-Object Drawing.PointF $tam, $tam),
        [Drawing.ColorTranslator]::FromHtml('#2B7FC7'), [Drawing.ColorTranslator]::FromHtml('#0F2B46'))
    $g.FillPath($grad, $fundo)

    # Seta circular (sincronizar / transferir)
    $branco = [Drawing.Color]::White
    $esp = [math]::Max(18 * $s, 2)
    $caneta = New-Object Drawing.Pen $branco, $esp
    $caneta.StartCap = 'Round'; $caneta.EndCap = 'Flat'
    $c = 128 * $s; $raio = 74 * $s
    $inicio = -50; $volta = 285
    $g.DrawArc($caneta, $c - $raio, $c - $raio, 2 * $raio, 2 * $raio, $inicio, $volta)

    # Ponta da seta no fim do arco
    $ang = ($inicio + $volta) * [math]::PI / 180
    $px = $c + $raio * [math]::Cos($ang); $py = $c + $raio * [math]::Sin($ang)
    $tx = -[math]::Sin($ang); $ty = [math]::Cos($ang)      # direção do movimento
    $nx = [math]::Cos($ang); $ny = [math]::Sin($ang)       # para fora do círculo
    $L = 30 * $s; $W = 24 * $s
    $pontos = [Drawing.PointF[]]@(
        (New-Object Drawing.PointF ($px + $tx * $L), ($py + $ty * $L)),
        (New-Object Drawing.PointF ($px + $nx * $W), ($py + $ny * $W)),
        (New-Object Drawing.PointF ($px - $nx * $W), ($py - $ny * $W)))
    $g.FillPolygon((New-Object Drawing.SolidBrush $branco), $pontos)

    # Disco no centro
    $dw = 70 * $s; $dh = 44 * $s; $dx = $c - $dw / 2; $dy = $c - $dh / 2; $dr = 9 * $s
    $disco = New-Object Drawing.Drawing2D.GraphicsPath
    $disco.AddArc($dx, $dy, 2 * $dr, 2 * $dr, 180, 90)
    $disco.AddArc($dx + $dw - 2 * $dr, $dy, 2 * $dr, 2 * $dr, 270, 90)
    $disco.AddArc($dx + $dw - 2 * $dr, $dy + $dh - 2 * $dr, 2 * $dr, 2 * $dr, 0, 90)
    $disco.AddArc($dx, $dy + $dh - 2 * $dr, 2 * $dr, 2 * $dr, 90, 90)
    $disco.CloseFigure()
    $g.FillPath((New-Object Drawing.SolidBrush $branco), $disco)
    if ($tam -ge 32) {
        $azul = New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml('#1F6FB2'))
        $led = 9 * $s
        $g.FillEllipse($azul, $dx + $dw - 20 * $s, $c - $led / 2, $led, $led)
        $g.FillRectangle($azul, $dx + 12 * $s, $c - 3 * $s, 30 * $s, 6 * $s)
    }

    $g.Dispose()
    return $bmp
}

function Png([Drawing.Bitmap]$bmp) {
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    return , $ms.ToArray()
}

# Imagem no formato clássico do .ico (BMP de 32 bits com transparência), lido por qualquer programa
function Dib([Drawing.Bitmap]$bmp) {
    $t = $bmp.Width
    $ret = New-Object Drawing.Rectangle 0, 0, $t, $t
    $dados = $bmp.LockBits($ret, 'ReadOnly', [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $px = New-Object byte[] ($t * $t * 4)
    [Runtime.InteropServices.Marshal]::Copy($dados.Scan0, $px, 0, $px.Length)
    $bmp.UnlockBits($dados)
    $linhaMascara = [int][math]::Floor(($t + 31) / 32) * 4
    $ms = New-Object IO.MemoryStream
    $w = New-Object IO.BinaryWriter $ms
    $w.Write([uint32]40); $w.Write([int32]$t); $w.Write([int32]($t * 2))
    $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]0)
    $w.Write([uint32]($px.Length + $linhaMascara * $t))
    $w.Write([int32]0); $w.Write([int32]0); $w.Write([uint32]0); $w.Write([uint32]0)
    for ($y = $t - 1; $y -ge 0; $y--) { $w.Write($px, $y * $t * 4, $t * 4) }   # BMP guarda de baixo para cima
    $w.Write((New-Object byte[] ($linhaMascara * $t)))                           # máscara vazia (usa o canal alfa)
    $w.Flush()
    return , $ms.ToArray()
}

$pasta = $PSScriptRoot

# .ico com vários tamanhos (BMP nos pequenos, PNG no de 256)
$tamanhos = 16, 24, 32, 48, 64, 128, 256
$imagens = foreach ($t in $tamanhos) { if ($t -ge 256) { , (Png (Desenhar $t)) } else { , (Dib (Desenhar $t)) } }
$ms = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter $ms
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$tamanhos.Count)
$offset = 6 + 16 * $tamanhos.Count
for ($i = 0; $i -lt $tamanhos.Count; $i++) {
    $t = $tamanhos[$i]; $dados = $imagens[$i]
    $lado = if ($t -ge 256) { 0 } else { $t }
    $w.Write([byte]$lado); $w.Write([byte]$lado); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$dados.Length); $w.Write([uint32]$offset)
    $offset += $dados.Length
}
foreach ($dados in $imagens) { $w.Write([byte[]]$dados) }
$w.Flush()
[IO.File]::WriteAllBytes((Join-Path $pasta 'icone.ico'), $ms.ToArray())

# .png grande para o Linux
(Desenhar 512).Save((Join-Path $pasta 'icone.png'), [Drawing.Imaging.ImageFormat]::Png)

Write-Host 'Ícones gerados: icone.ico e icone.png'
