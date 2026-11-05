# Darna brand assets

The identity pairs an outlined Arabic Tajawal Bold wordmark with a geometric roof
and architectural entrance. The symbol sits on the right of the Arabic wordmark.

- Teal: `#0F766E`; ivory: `#FAF6F1`.
- All SVG artwork consists of filled paths, with transparent negative space.
- `darna_logo_tight.svg` and `darna_logo_tight_dark.svg` are the in-app lockups.
- `darna_symbol.svg` and `darna_symbol_dark.svg` are standalone symbol masters.
- `darna_logo_vector_proof.png` previews the identity on four backgrounds.

Regenerate from Windows PowerShell, from the mobile directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/export_vector_logos.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/export_brand_icons.ps1
```

The first script outlines the bundled Arabic font and exports SVGs and the proof.
The second renders Android launcher/adaptive/splash assets, iOS app icons and web
icons directly from the symbol SVG. Android adaptive icons keep the complete mark
inside the central safe area; iOS app icons are opaque.

`tool/export_assets.cjs` also reads the symbol SVG when rebuilding raster splash
assets. The in-app loading screen uses the dark symbol SVG directly.

The older raster logo in `design/source/darna_logo.png` is an archived reference;
it is not used by the application or either logo export script.
