param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore,WindowsBase
[xml]$symbol = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'assets/branding/darna_symbol_dark.svg'))
$geometry = [Windows.Media.Geometry]::Parse($symbol.svg.path.d)

# Render all platform icons from the same vector used by the app.
function Export-Icon([string]$RelativePath, [int]$Size, [double]$MarkWidth = 0.66, [string]$Background = '#234457', [string]$Ink = '#FAF7F2') {
    $visual = New-Object Windows.Media.DrawingVisual
    $dc = $visual.RenderOpen()
    if ($Background) {
        $dc.DrawRectangle([Windows.Media.BrushConverter]::new().ConvertFromString($Background), $null, (New-Object Windows.Rect(0, 0, $Size, $Size)))
    }
    $scale = $Size * $MarkWidth / 320
    $offsetX = ($Size - 320 * $scale) / 2
    $offsetY = $Size / 2 - 151.5 * $scale
    $matrix = New-Object Windows.Media.Matrix($scale, 0, 0, $scale, $offsetX, $offsetY)
    $dc.PushTransform((New-Object Windows.Media.MatrixTransform($matrix)))
    $dc.DrawGeometry([Windows.Media.BrushConverter]::new().ConvertFromString($Ink), $null, $geometry)
    $dc.Pop()
    $dc.Close()
    $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap($Size, $Size, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $ProjectRoot $RelativePath))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}

Export-Icon 'assets/branding/darna_app_icon.png' 1024
Export-Icon 'design/source/darna_app_icon.png' 1024
$densities = @{ 'mdpi' = 1; 'hdpi' = 1.5; 'xhdpi' = 2; 'xxhdpi' = 3; 'xxxhdpi' = 4 }
foreach ($density in $densities.Keys) {
    $factor = $densities[$density]
    Export-Icon "android/app/src/main/res/mipmap-$density/ic_darna.png" ([int](48 * $factor))
    Export-Icon "android/app/src/main/res/mipmap-$density/ic_darna_foreground.png" ([int](108 * $factor)) (64.0 / 108) ''
    Export-Icon "android/app/src/main/res/mipmap-$density/ic_darna_splash.png" ([int](128 * $factor)) 0.78 ''
}
$catalog = Get-Content -LiteralPath (Join-Path $ProjectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
foreach ($entry in $catalog.images) {
    $pointSize = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
    $factor = [int]($entry.scale -replace 'x', '')
    Export-Icon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" ([int]($pointSize * $factor))
}
# iOS requires opaque app icons, so flatten the rendered images before shipping.
Add-Type -AssemblyName System.Drawing
foreach ($entry in $catalog.images) {
    $path = Join-Path $ProjectRoot "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)"
    $source = [System.Drawing.Image]::FromFile($path)
    $flat = New-Object System.Drawing.Bitmap($source.Width, $source.Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb))
    $graphics = [System.Drawing.Graphics]::FromImage($flat)
    try { $graphics.DrawImageUnscaled($source, 0, 0) } finally { $graphics.Dispose(); $source.Dispose() }
    try { $flat.Save($path, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $flat.Dispose() }
}
Export-Icon 'web/icons/Darna-192.png' 192
Export-Icon 'web/icons/Darna-512.png' 512
Export-Icon 'web/darna-favicon.png' 32 0.82
Write-Output 'Exported Android, iOS and web icons from the vector symbol.'
