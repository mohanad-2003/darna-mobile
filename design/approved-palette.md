# Darna approved palette

The app and dashboard use deep blue `#234457`, warm ivory `#FAF7F2`, and restrained terracotta `#BD7962`. Light cards are white. Dark surfaces are `#111923` / `#1B2735`, with `#A6C7DC` for legible blue text and actions.

Brand colors live in `lib/app/theme.dart`. Vector illustrations and their dark-mode mappings use the same blue-grey palette. Native launcher icons and Android splash backgrounds are regenerated from the shared symbol.

## Image assets

All raster artwork below was recolored with the built-in image generation tool. Original object layouts were retained. Onboarding originals are `design/source/{discover,connect,publish}.png`; transparent state originals are `design/source/illustrations/*.png`.

Runtime files are `assets/onboarding/{discover,connect,publish}.jpg` (900px) and `assets/illustrations/{welcome_phone,listing_under_review,no_connection,listing_unavailable,add_listing_photos}.png` (480px, alpha preserved).

To export after changing source images: `powershell -NoProfile -ExecutionPolicy Bypass -File tool/export_clay_illustrations.ps1`. Vector/icon export commands are documented in `design/logo-vector-prompts.md`.

## Image edit prompts

### Onboarding: discover

> Use case: precise-object-edit. Edit target: supplied Darna onboarding discover illustration. Update only the brand palette, preserving every object, composition, proportions, shadows, realistic handcrafted 3D style, square aspect ratio and blank background. Replace all teal brand-colored objects, teal doors, frames, camera trim, location pin, magnifying glass, chat bubbles or plus button with deep blue #234457. Replace pale mint accent surfaces with pale blue-grey #E8EEF1. Keep limestone buildings warm ivory, keep olive trees naturally green, and use restrained terracotta #BD7962 for existing small decorative accents only. The entire flat background must be uniform warm ivory #FAF7F2 with no edge, border or vignette, so it blends into the app screen. No text, no logos, no new objects, no watermark. Keep original composition.

### Onboarding: connect

> Use case: precise-object-edit. Edit target: supplied Darna onboarding connect illustration. Update only the brand palette, preserving every object, composition, proportions, shadows, realistic handcrafted 3D style, square aspect ratio and blank background. Replace all teal brand-colored objects, teal doors, frames, camera trim, location pin, magnifying glass, chat bubbles or plus button with deep blue #234457. Replace pale mint accent surfaces with pale blue-grey #E8EEF1. Keep limestone buildings warm ivory, keep olive trees naturally green, and use restrained terracotta #BD7962 for existing small decorative accents only. The entire flat background must be uniform warm ivory #FAF7F2 with no edge, border or vignette, so it blends into the app screen. No text, no logos, no new objects, no watermark. Keep original composition.

### Onboarding: publish

> Use case: precise-object-edit. Edit target: supplied Darna onboarding publish illustration. Update only the brand palette, preserving every object, composition, proportions, shadows, realistic handcrafted 3D style, square aspect ratio and blank background. Replace all teal brand-colored objects, teal doors, frames, camera trim, location pin, magnifying glass, chat bubbles or plus button with deep blue #234457. Replace pale mint accent surfaces with pale blue-grey #E8EEF1. Keep limestone buildings warm ivory, keep olive trees naturally green, and use restrained terracotta #BD7962 for existing small decorative accents only. The entire flat background must be uniform warm ivory #FAF7F2 with no edge, border or vignette, so it blends into the app screen. No text, no logos, no new objects, no watermark. Keep original composition.

### State: welcome_phone

> Use case: precise-object-edit. Edit target: supplied transparent Darna welcome_phone state illustration. Palette update ONLY, preserve objects, exact composition, spacing, subject size within the square canvas, limestone texture, shadows and handcrafted 3D aesthetic. Replace branded teal elements including doors, windows, devices, camera, badges, frames and decorative base with deep blue #234457. Replace pale mint accents with blue-grey #E8EEF1. Keep ivory limestone #FAF7F2 and natural olive-green leaves, with restrained terracotta #BD7962 for existing pots. Keep every symbol and object intact. The canvas must have a genuinely transparent alpha background, including the empty margins. No opaque background, no checkerboard pixels, no text, no new objects, no watermark.

### State: listing_under_review

> Use case: precise-object-edit. Edit target: supplied transparent Darna listing_under_review state illustration. Palette update ONLY, preserve objects, exact composition, spacing, subject size within the square canvas, limestone texture, shadows and handcrafted 3D aesthetic. Replace branded teal elements including doors, windows, devices, camera, badges, frames and decorative base with deep blue #234457. Replace pale mint accents with blue-grey #E8EEF1. Keep ivory limestone #FAF7F2 and natural olive-green leaves, with restrained terracotta #BD7962 for existing pots. Keep every symbol and object intact. The canvas must have a genuinely transparent alpha background, including the empty margins. No opaque background, no checkerboard pixels, no text, no new objects, no watermark.

### State: no_connection

> Use case: precise-object-edit. Edit target: supplied transparent Darna no_connection state illustration. Palette update ONLY, preserve objects, exact composition, spacing, subject size within the square canvas, limestone texture, shadows and handcrafted 3D aesthetic. Replace branded teal elements including doors, windows, devices, camera, badges, frames and decorative base with deep blue #234457. Replace pale mint accents with blue-grey #E8EEF1. Keep ivory limestone #FAF7F2 and natural olive-green leaves, with restrained terracotta #BD7962 for existing pots. Keep every symbol and object intact. The canvas must have a genuinely transparent alpha background, including the empty margins. No opaque background, no checkerboard pixels, no text, no new objects, no watermark.

### State: listing_unavailable

> Use case: precise-object-edit. Edit target: supplied transparent Darna listing_unavailable state illustration. Palette update ONLY, preserve objects, exact composition, spacing, subject size within the square canvas, limestone texture, shadows and handcrafted 3D aesthetic. Replace branded teal elements including doors, windows, devices, camera, badges, frames and decorative base with deep blue #234457. Replace pale mint accents with blue-grey #E8EEF1. Keep ivory limestone #FAF7F2 and natural olive-green leaves, with restrained terracotta #BD7962 for existing pots. Keep every symbol and object intact. The canvas must have a genuinely transparent alpha background, including the empty margins. No opaque background, no checkerboard pixels, no text, no new objects, no watermark.

### State: add_listing_photos

> Use case: precise-object-edit. Edit target: supplied transparent Darna add_listing_photos state illustration. Palette update ONLY, preserve objects, exact composition, spacing, subject size within the square canvas, limestone texture, shadows and handcrafted 3D aesthetic. Replace branded teal elements including doors, windows, devices, camera, badges, frames and decorative base with deep blue #234457. Replace pale mint accents with blue-grey #E8EEF1. Keep ivory limestone #FAF7F2 and natural olive-green leaves, with restrained terracotta #BD7962 for existing pots. Keep every symbol and object intact. The canvas must have a genuinely transparent alpha background, including the empty margins. No opaque background, no checkerboard pixels, no text, no new objects, no watermark.

