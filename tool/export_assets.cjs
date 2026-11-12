// Rebuilds the shipped brand assets from the full-size originals in design/source.
//   cd mobile && npm i --no-save sharp && node tool/export_assets.cjs
// Produces: light JPEG onboarding art, PNG illustrations and logo, the ivory house mark (splash), and the
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
    await sharp(src(`${name}.png`)).resize(900).jpeg({ quality: 88 }).toFile(out(`assets/onboarding/${name}.jpg`));
  }
}

// The vector masters keep generous clear space. For use inside the app, write copies whose
// viewBox hugs the artwork (plus a small margin), so a given height shows a bigger logo.
// Screen illustrations (login, states): 480 px keeps each transparent PNG below 200 KB.
// The originals are painted on a flat cream square. On screen they should sit directly on the
// page, so the cream that touches the border is made transparent (see cutCreamBackground).
async function illustrations() {
  const dir = src('illustrations');
  if (!fs.existsSync(dir)) return;
  for (const f of fs.readdirSync(dir).filter((n) => n.endsWith('.png'))) {
    const file = path.join(dir, f);
    const meta = await sharp(file).metadata();
    const cut = meta.hasAlpha ? sharp(file) : await cutCreamBackground(file);
    await cut.resize(480).png().toFile(out('assets/illustrations/' + f));
  }
}

// Flood-fills the near-cream pixels connected to the picture's border (so cream inside the
// artwork is kept) and turns them transparent in proportion to their distance from the cream.
// Edge colours are un-mixed from the cream, which avoids a light fringe on a dark screen.
async function cutCreamBackground(file, { reach = 28, solid = 6 } = {}) {
  const { data, info } = await sharp(file).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const bg = [0, 0, 0];
  const corners = [[2, 2], [w - 3, 2], [2, h - 3], [w - 3, h - 3]];
  for (const [x, y] of corners) for (let c = 0; c < 3; c++) bg[c] += data[(y * w + x) * 3 + c] / corners.length;
  const dist = (i) => Math.hypot(data[i] - bg[0], data[i + 1] - bg[1], data[i + 2] - bg[2]);

  const reached = new Uint8Array(w * h);
  const stack = [];
  const push = (x, y) => {
    const p = y * w + x;
    if (!reached[p] && dist(p * 3) <= reach) { reached[p] = 1; stack.push(p); }
  };
  for (let x = 0; x < w; x++) { push(x, 0); push(x, h - 1); }
  for (let y = 0; y < h; y++) { push(0, y); push(w - 1, y); }
  while (stack.length) {
    const p = stack.pop();
    const x = p % w, y = (p / w) | 0;
    if (x > 0) push(x - 1, y);
    if (x < w - 1) push(x + 1, y);
    if (y > 0) push(x, y - 1);
    if (y < h - 1) push(x, y + 1);
  }

  const rgba = Buffer.alloc(w * h * 4);
  for (let p = 0; p < w * h; p++) {
    const i = p * 3, o = p * 4;
    let a = 1;
    if (reached[p]) a = Math.min(1, Math.max(0, (dist(i) - solid) / (reach - solid)));
    for (let c = 0; c < 3; c++) {
      const v = a > 0 ? (data[i + c] - bg[c] * (1 - a)) / a : data[i + c];
      rgba[o + c] = Math.max(0, Math.min(255, Math.round(v)));
    }
    rgba[o + 3] = Math.round(a * 255);
  }
  // The generated pictures have a faint line along their outer edge; it must not show.
  const margin = 6;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (x < margin || y < margin || x >= w - margin || y >= h - margin) rgba[(y * w + x) * 4 + 3] = 0;
    }
  }
  return sharp(rgba, { raw: { width: w, height: h, channels: 4 } });
}


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

// Use the vector symbol so future exports keep every platform on the same identity.
async function houseOnly() {
  const buf = await sharp(out('assets/branding/darna_symbol_dark.svg'))
    .resize(1024).png().trim({ threshold: 1 }).toBuffer();
  return { buf };
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
    // Android 13 themed icons use the simple vector mark. The full-color launcher
    // foreground is exported separately by export_brand_icons.ps1 from the 3D artwork.
    await (await mark(house, Math.round(108 * scale), 52 * scale)).toFile(res(`mipmap-${bucket}/ic_darna_monochrome.png`));
    // Pre-Android 12 launch screen: 128 dp square with an 88 dp house.
    await (await mark(house, Math.round(128 * scale), 88 * scale)).toFile(res(`mipmap-${bucket}/ic_darna_splash.png`));
  }
}

(async () => {
  // `node tool/export_assets.cjs illustrations` rebuilds only the screen illustrations.
  if (process.argv[2] === 'illustrations') {
    await illustrations();
    console.log('illustrations exported');
    return;
  }
  await onboarding();
  await illustrations();
  await logo();
  await androidAndMark();
  console.log('assets exported');
})();
