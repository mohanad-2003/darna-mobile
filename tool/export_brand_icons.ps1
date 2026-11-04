param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$brandIcon = [System.Drawing.Image]::FromFile((Join-Path $ProjectRoot 'assets/branding/darna_app_icon.png'))
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Export-Icon([string]$RelativePath, [int]$Size) {
    $destination = Join-Path $ProjectRoot $RelativePath
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb))
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($brandIcon, 0, 0, $Size, $Size)
        $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    $densities = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
    foreach ($density in $densities.Keys) {
        Export-Icon "android/app/src/main/res/mipmap-$density/ic_darna.png" $densities[$density]
    }
    $manifestPath = Join-Path $ProjectRoot 'android/app/src/main/AndroidManifest.xml'
    $manifest = [System.IO.File]::ReadAllText($manifestPath).Replace('@mipmap/ic_launcher', '@mipmap/ic_darna')
    [System.IO.File]::WriteAllText($manifestPath, $manifest, $utf8)

    $catalogPath = Join-Path $ProjectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    foreach ($entry in $catalog.images) {
        $entry.filename = $entry.filename -replace '^Icon-App-', 'Darna-'
        $pointSize = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
        $scale = [int]($entry.scale -replace 'x', '')
        Export-Icon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" ([int]($pointSize * $scale))
    }
    [System.IO.File]::WriteAllText($catalogPath, ($catalog | ConvertTo-Json -Depth 5), $utf8)

    Export-Icon 'web/icons/Darna-192.png' 192
    Export-Icon 'web/icons/Darna-512.png' 512
    Export-Icon 'web/darna-favicon.png' 32
} finally {
    $brandIcon.Dispose()
}
