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
$scale = 180.0 / $bounds.Height
$wordWidth = $bounds.Width * $scale
$left = (1536 - ($wordWidth + 96 + 384)) / 2
$symbolX = $left + $wordWidth + 96
$translateX = $left - $bounds.X * $scale
$translateY = 294 - $bounds.Y * $scale
$wordMatrix = New-Object Windows.Media.Matrix($scale, 0, 0, $scale, $translateX, $translateY)
$wordGeometry.Transform = New-Object Windows.Media.MatrixTransform($wordMatrix)

# A closed roof/pin contour and an independent closed arch; evenodd removes
# the doorway without painting it a background colour. Doorway height = 120.
$symbolPath = 'M188 4 Q192 0 196 4 L272 70 V36 Q272 30 278 30 H310 Q316 30 316 36 V108 L380 164 Q388 172 378 172 H328 C341 238 316 280 280 316 L198 396 Q192 402 186 396 L104 316 C68 280 43 238 56 172 H6 Q-4 172 4 164 Z M144 280 V208 C144 181.49 165.49 160 192 160 C218.51 160 240 181.49 240 208 V280 Z'
$symbolGeometry = [Windows.Media.Geometry]::Parse($symbolPath).Clone()
$symbolGeometry.Transform = New-Object Windows.Media.TranslateTransform($symbolX, 184)
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

foreach ($variant in @(@{ Name = 'darna_logo_master.svg'; Color = '#0F766E' }, @{ Name = 'darna_logo_dark.svg'; Color = '#FAF6F1' })) {
    $wordElements = ($wordPaths | ForEach-Object { '  <path fill="' + $variant.Color + '" d="' + $_.Trim() + '"/>' }) -join "`n"
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="768" viewBox="0 0 1536 768">
$wordElements
  <path fill="$($variant.Color)" fill-rule="evenodd" d="$symbolData"/>
</svg>
"@
    [IO.File]::WriteAllText((Join-Path $destination $variant.Name), $svg, $utf8)
}

# Export a separate proof; its backgrounds never become part of the SVG files.
$wordGeometry = [Windows.Media.Geometry]::Parse($wordData)
$symbolGeometry = [Windows.Media.Geometry]::Parse('F0' + $symbolData)
$proof = New-Object Windows.Media.DrawingVisual
$dc = $proof.RenderOpen()
$backgrounds = @('#FAF8F3', '#0F1F1D', '#121212', '#0F766E')
for ($row = 0; $row -lt 4; $row++) {
    $dc.PushTransform((New-Object Windows.Media.TranslateTransform(0, ($row * 384))))
    $dc.DrawRectangle([Windows.Media.BrushConverter]::new().ConvertFromString($backgrounds[$row]), $null, (New-Object Windows.Rect(0, 0, 768, 384)))
    $dc.PushTransform((New-Object Windows.Media.ScaleTransform(0.5, 0.5)))
    $ink = if ($row -eq 0) { '#0F766E' } else { '#FAF6F1' }
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
Write-Output "Exported master and dark SVGs; wordmark height 180, symbol height 400, doorway height 120."
