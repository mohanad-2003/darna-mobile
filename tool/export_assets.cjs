// Rebuilds the shipped brand assets from the full-size originals in design/source.
//   cd mobile && npm i --no-save sharp && node tool/export_assets.cjs
// Produces: light WebP onboarding art and logo, the white house mark (splash), and the
// Android adaptive-icon foreground and splash images at every density.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const src = (f) => path.join(root, 'design/source', f);
const out = (f) => path.join(root, f);
const res = (f) => path.join(root, 'android/app/src/main/res', f);

const CREAM = [250, 248, 243];
// Android density buckets: scale relative to mdpi (1dp = 1px).
const DENSITIES = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

async function onboarding() {
  for (const name of ['discover', 'connect', 'publish']) {
    // Shown at about 360 dp tall, so 900 px covers 2.5x screens.
    await sharp(src(`${name}.png`)).resize(900).webp({ quality: 82, effort: 6 }).toFile(out(`assets/onboarding/${name}.webp`));
  }
}

// The vector masters keep generous clear space. For use inside the app, write copies whose
// viewBox hugs the artwork (plus a small margin), so a given height shows a bigger logo.
async function logo() {
  const master = fs.readFileSync(out('assets/branding/darna_logo_master.svg'), 'utf8');
  const { info } = await sharp(Buffer.from(master)).png().trim({ threshold: 1 }).toBuffer({ resolveWithObject: true });
  const full = await sharp(Buffer.from(master)).metadata();
  const pad = Math.round(Math.max(info.width, info.height) * 0.03);
  const left = Math.max(0, -info.trimOffsetLeft - pad);
  const top = Math.max(0, -info.trimOffsetTop - pad);
  const w = Math.min(full.width - left, info.width + 2 * pad);
  const h = Math.min(full.height - top, info.height + 2 * pad);
  for (const [from, to] of [['darna_logo_master.svg', 'darna_logo_tight.svg'], ['darna_logo_dark.svg', 'darna_logo_tight_dark.svg']]) {
    const svg = fs.readFileSync(out('assets/branding/' + from), 'utf8')
      .replace(/<svg[^>]*>/, '<svg xmlns="http://www.w3.org/2000/svg" width="' + w + '" height="' + h + '" viewBox="' + left + ' ' + top + ' ' + w + ' ' + h + '">');
    fs.writeFileSync(out('assets/branding/' + to), svg);
  }
  console.log('logo viewBox', left, top, w, h);
}

// The icon is a cream house on a teal square. Turning "how far a pixel is from teal" into
// transparency gives the house alone, with smooth edges.
async function houseOnly() {
  const { data, info } = await sharp(src('darna_app_icon.png')).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width, height } = info;
  const luma = (i) => 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];

  let tealLuma = 0;
  const corners = [[4, 4], [width - 5, 4], [4, height - 5], [width - 5, height - 5]];
  for (const [x, y] of corners) tealLuma += luma((y * width + x) * 3) / corners.length;
  const creamLuma = 0.2126 * CREAM[0] + 0.7152 * CREAM[1] + 0.0722 * CREAM[2];

  const rgba = Buffer.alloc(width * height * 4);
  let minX = width, minY = height, maxX = 0, maxY = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const a = Math.min(1, Math.max(0, (luma((y * width + x) * 3) - tealLuma) / (creamLuma - tealLuma)));
      const o = (y * width + x) * 4;
      rgba[o] = CREAM[0]; rgba[o + 1] = CREAM[1]; rgba[o + 2] = CREAM[2];
      rgba[o + 3] = Math.round(a * 255);
      if (a > 0.05) { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
    }
  }
  const box = { left: minX, top: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
  return sharp(rgba, { raw: { width, height, channels: 4 } }).extract(box).png().toBuffer().then((buf) => ({ buf, box }));
}

// Places the house, `houseHeight` tall, centered on a transparent square canvas.
async function mark(house, canvas, houseHeight) {
  const h = Math.round(houseHeight);
  const resized = await sharp(house.buf).resize({ height: h }).png().toBuffer();
  const meta = await sharp(resized).metadata();
  return sharp({ create: { width: canvas, height: canvas, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
    .composite([{ input: resized, left: Math.round((canvas - meta.width) / 2), top: Math.round((canvas - h) / 2) }])
    .png();
}

async function androidAndMark() {
  const house = await houseOnly();

  // In-app splash mark (white house, transparent).
  await (await mark(house, 512, 400)).webp({ quality: 95, alphaQuality: 100 }).toFile(out('assets/branding/darna_mark.webp'));

  for (const [bucket, scale] of Object.entries(DENSITIES)) {
    // Adaptive icon layers are 108 dp; only the central 66 dp is guaranteed visible, so
    // the house is 52 dp tall. The same layer doubles as the Android 13 themed (monochrome) icon.
    await (await mark(house, Math.round(108 * scale), 52 * scale)).toFile(res(`mipmap-${bucket}/ic_darna_foreground.png`));
    // Pre-Android 12 launch screen: 128 dp square with an 88 dp house.
    await (await mark(house, Math.round(128 * scale), 88 * scale)).toFile(res(`mipmap-${bucket}/ic_darna_splash.png`));
  }
}

(async () => {
  await onboarding();
  await logo();
  await androidAndMark();
  console.log('assets exported');
})();
