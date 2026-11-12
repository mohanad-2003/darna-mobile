# Darna 3D launcher icon

The mobile launcher uses a photographic 3D miniature limestone house with navy joinery, warm interior lighting, an olive tree and a terracotta pot. The background is the approved deep blue `#234457`.

- Generated transparent source: `design/source/darna_launcher_house.png`.
- Final 1024px icon: `assets/branding/darna_app_icon.png` and `design/source/darna_app_icon.png`.
- The in-app `DarnaLogo` uses `assets/branding/darna_house_mark.png`, a transparent 256px export of the same house, beside the Arabic Darna wordmark. This appears on onboarding, login and about screens.
- Android: full-color legacy and adaptive icons in the `mipmap-*` folders, with a separate simple vector monochrome layer for themed icons.
- iOS: opaque PNGs in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- PWA: `web/icons/Darna-{192,512}.png`, with dedicated `Darna-maskable-{192,512}.png` files.

Regenerate with `powershell -NoProfile -ExecutionPolicy Bypass -File tool/export_brand_icons.ps1`.

The source was generated with the built-in image generation tool; platform sizes and backgrounds are exported from that source without changing the house artwork.

Generation prompt:

> Use case: stylized-concept. Asset type: Darna mobile app launcher icon foreground artwork. Reference image: use the supplied Darna architecture illustration only for its premium tactile 3D miniature style, ivory Palestinian limestone, navy blue joinery, olive foliage and warm lighting. Create ONE compact, beautiful miniature two-storey Palestinian limestone home, front three-quarter view, with a large arched deep-blue entrance, one warm-lit arched window above, and a modest olive tree in a terracotta planter tucked tightly beside the entrance. This should look like a polished three-dimensional architectural product photograph, not a flat line icon or vector symbol. Simplify to bold, recognizable architectural masses with refined materials and realistic depth. Brand palette: warm ivory #FAF7F2 stone, deep blue #234457 door, terracotta #BD7962 pot, natural muted olive leaves. Soft directional studio illumination, warm interior glow, controlled shadows, crisp clean edges. The home fills roughly 80 percent of the square frame, all objects centered and fully visible with generous transparent margins for app icon masking. Background is genuinely transparent alpha, no square base, no backplate, no thick circular pedestal. NO location pin, NO magnifying glass, NO text or lettering, NO logos, NO people, NO border, NO white outline, NO watermark. Built for a mobile app icon that reads clearly at 48 pixels. Square composition.

