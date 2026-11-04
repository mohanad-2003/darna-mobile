# Vector logo and dark-mode logo: prompts

Why: the current `darna_logo` is a raster image (soft edges when enlarged) and exists only in
teal, which disappears on a dark background. Both prompts below ask for a true vector
(SVG) so it stays sharp at any size.

Use them with a tool that outputs SVG (Recraft "vector", Illustrator "Text to Vector",
Figma plugins), or give the prompt plus `design/source/darna_logo.png` to a designer.
Always check the Arabic wordmark letter by letter: د ا ر ن ا (five letters, right to left).

Brand colours: deep teal `#0F766E`, warm ivory `#FAF6F1`, deep green-black `#173F3A`.

## 1. Master vector logo (light backgrounds)

```
Vector logo for "دارنا" (Darna), an Arabic real-estate mobile app. Output a clean SVG.
Horizontal lockup: the symbol on the right, the Arabic wordmark "دارنا" on the left.

Symbol: a simple geometric house roof that merges into a location pin, with an arched
open doorway cut out as negative space and a small chimney on the right side of the roof.
Flat solid colour, no gradients, no outlines, no shadows, no glow, no texture. Use only
the colour #0F766E.

Wordmark: the exact Arabic word "دارنا", in a bold, modern, geometric Arabic typeface with
rounded terminals and even stroke weight, matching the roundness of the symbol. Same colour
#0F766E. Letters in correct order right to left: د ا ر ن ا. The dot of the ن sits above
the letter. The wordmark height is about 45% of the symbol height, vertically centered on it.

Rules: fully transparent background, every shape a single closed solid path, no raster
effects, no text rendered as a font reference (convert to outlines), generous clear space
equal to the height of the doorway around the lockup, no slogan, no English, no mockup.
Provide an SVG with a viewBox, about 1536x768.
```

## 2. Dark-mode logo

```
Same logo as the master vector logo (same symbol, same Arabic wordmark "دارنا", same
proportions and spacing), recoloured for dark backgrounds. Output a clean SVG.

Colours: symbol and wordmark in warm ivory #FAF6F1. The doorway cut-out stays transparent.
Optional: a very subtle variant of the symbol in mint #DBEEE8 is NOT allowed; use one flat
colour only. No gradients, no outlines, no glow, no shadows.

It must read clearly on #0F1F1D (very dark green), on #121212 (near-black) and on
#0F766E (the brand teal). Fully transparent background, all shapes solid closed outlined
paths, same viewBox as the master logo so both files are interchangeable.
```

## 3. Symbol only (app icon and small sizes)

```
Only the symbol of the Darna logo (roof + location pin + arched doorway + chimney), no
wordmark. SVG, one flat colour, square viewBox 1024x1024, the symbol centered and filling
about 55% of the canvas, transparent background. Provide two files: #0F766E, and #FAF6F1.
```

## After you have the SVG files

Send them over or drop them into `design/source/` (`darna_logo.svg`,
`darna_logo_dark.svg`, `darna_symbol.svg`). They get wired in as follows:
- the in-app logo switches between the light and dark file with the theme,
- the app icon layers (`ic_darna_foreground`) are re-exported from the symbol file,
- `node tool/export_assets.cjs` regenerates the raster sizes.
