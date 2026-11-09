param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore,WindowsBase
$culture = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object Text.UTF8Encoding($false)
$destination = Join-Path $ProjectRoot 'assets/branding'
$design = Join-Path $ProjectRoot 'design'

# Windows text shaping supplies the Arabic contextual forms before outlining.
# The final SVGs contain no text, font references, raster data or filters.
$fontUri = [uri]((Join-Path $ProjectRoot 'assets/fonts/').Replace('\', '/'))
$family = New-Object Windows.Media.FontFamily($fontUri, './#Tajawal')
$typeface = New-Object Windows.Media.Typeface($family, [Windows.FontStyles]::Normal, [Windows.FontWeights]::Bold, [Windows.FontStretches]::Normal)
$word = [string]([char]0x062F) + [char]0x0627 + [char]0x0631 + [char]0x0646 + [char]0x0627
$text = New-Object Windows.Media.FormattedText($word, [Globalization.CultureInfo]::GetCultureInfo('ar'), [Windows.FlowDirection]::RightToLeft, $typeface, 200, [Windows.Media.Brushes]::Black, 1)
$wordGeometry = $text.BuildGeometry((New-Object Windows.Point(0, 0))).GetOutlinedPathGeometry()
# Soften the geometric font's terminal corners before outlining again. This
# construction pen is baked into filled contours and never written as a stroke.
$roundingPen = New-Object Windows.Media.Pen([Windows.Media.Brushes]::Black, 6)
$roundingPen.LineJoin = [Windows.Media.PenLineJoin]::Round
$roundedEdges = $wordGeometry.GetWidenedPathGeometry($roundingPen)
$wordGeometry = [Windows.Media.Geometry]::Combine($wordGeometry, $roundedEdges, [Windows.Media.GeometryCombineMode]::Union, $null).GetOutlinedPathGeometry()
$bounds = $wordGeometry.Bounds
$scale = 210.0 / $bounds.Height
$wordWidth = $bounds.Width * $scale
$left = (1536 - ($wordWidth + 72 + 320)) / 2
$symbolX = $left + $wordWidth + 72
$translateX = $left - $bounds.X * $scale
$translateY = 279 - $bounds.Y * $scale
$wordMatrix = New-Object Windows.Media.Matrix($scale, 0, 0, $scale, $translateX, $translateY)
$wordGeometry.Transform = New-Object Windows.Media.MatrixTransform($wordMatrix)

# Two closed contours: a geometric roof and an open architectural arch.
# The space inside the entrance stays transparent on every background.
$symbolPath = 'M20 132 L148 24 Q160 14 172 24 L300 132 L276 160 L160 62 L44 160 Z M60 284 V210 C60 152 104 112 160 112 C216 112 260 152 260 210 V284 H220 V210 C220 174 196 152 160 152 C124 152 100 174 100 210 V284 Z'
$symbolGeometry = [Windows.Media.Geometry]::Parse($symbolPath).Clone()
$symbolGeometry.Transform = New-Object Windows.Media.TranslateTransform($symbolX, 232)
$symbolGeometry.FillRule = [Windows.Media.FillRule]::EvenOdd

# Bake transforms into points, retaining the original cubic and quadratic curves.
function Convert-PathToSvg([Windows.Media.Geometry]$Geometry) {
    $outlined = $Geometry.GetOutlinedPathGeometry()
    $paths = foreach ($figure in $outlined.Figures) {
        if (-not $figure.IsClosed) { throw 'Open contour in logo' }
    }
    $data = $outlined.ToString($culture) -replace '^F[01]', ''
    return $data
}
$wordData = Convert-PathToSvg $wordGeometry
$symbolData = Convert-PathToSvg $symbolGeometry
$wordPaths = @([regex]::Split($wordData, '(?=[Mm])') | Where-Object { $_.Trim() })

foreach ($variant in @(@{ Name = 'darna_logo_master.svg'; Color = '#234457' }, @{ Name = 'darna_logo_dark.svg'; Color = '#FAF7F2' })) {
    $wordElements = ($wordPaths | ForEach-Object { '  <path fill="' + $variant.Color + '" d="' + $_.Trim() + '"/>' }) -join "`n"
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="768" viewBox="0 0 1536 768">
$wordElements
  <path fill="$($variant.Color)" fill-rule="evenodd" d="$symbolData"/>
</svg>
"@
    [IO.File]::WriteAllText((Join-Path $destination $variant.Name), $svg, $utf8)
    $tightName = if ($variant.Name -eq 'darna_logo_master.svg') { 'darna_logo_tight.svg' } else { 'darna_logo_tight_dark.svg' }
    $tightX = [math]::Floor($left - 16)
    $tightWidth = [math]::Ceiling($wordWidth + 72 + 320 + 32)
    $tight = $svg.Replace('width="1536" height="768" viewBox="0 0 1536 768"', "width=`"$tightWidth`" height=`"304`" viewBox=`"$tightX 232 $tightWidth 304`"")
    [IO.File]::WriteAllText((Join-Path $destination $tightName), $tight, $utf8)
}

foreach ($variant in @(@{ Name = 'darna_symbol.svg'; Color = '#234457' }, @{ Name = 'darna_symbol_dark.svg'; Color = '#FAF7F2' })) {
    $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320"><path fill="' + $variant.Color + '" d="' + $symbolPath + '"/></svg>'
    [IO.File]::WriteAllText((Join-Path $destination $variant.Name), $svg, $utf8)
}

# Export a separate proof; its backgrounds never become part of the SVG files.
$wordGeometry = [Windows.Media.Geometry]::Parse($wordData)
$symbolGeometry = [Windows.Media.Geometry]::Parse('F0' + $symbolData)
$proof = New-Object Windows.Media.DrawingVisual
$dc = $proof.RenderOpen()
$backgrounds = @('#FAF7F2', '#111923', '#121212', '#234457')
for ($row = 0; $row -lt 4; $row++) {
    $dc.PushTransform((New-Object Windows.Media.TranslateTransform(0, ($row * 384))))
    $dc.DrawRectangle([Windows.Media.BrushConverter]::new().ConvertFromString($backgrounds[$row]), $null, (New-Object Windows.Rect(0, 0, 768, 384)))
    $dc.PushTransform((New-Object Windows.Media.ScaleTransform(0.5, 0.5)))
    $ink = if ($row -eq 0) { '#234457' } else { '#FAF7F2' }
    $brush = [Windows.Media.BrushConverter]::new().ConvertFromString($ink)
    $dc.DrawGeometry($brush, $null, $wordGeometry)
    $dc.DrawGeometry($brush, $null, $symbolGeometry)
    $dc.Pop()
    $dc.Pop()
}
$dc.Close()
$bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(768, 1536, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($proof)
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream = [IO.File]::Create((Join-Path $design 'darna_logo_vector_proof.png'))
try { $encoder.Save($stream) } finally { $stream.Dispose() }
Write-Output 'Exported outlined wordmark, light/dark lockups, symbol variants and proof.'
