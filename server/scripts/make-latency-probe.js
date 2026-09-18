/**
 * Write a 600x800 PNG of pseudo-handwriting, for latency probes only.
 *
 *   node scripts/make-latency-probe.js /tmp/probe.png
 *
 * This exists because image token count — and therefore how long the model spends looking —
 * depends on pixel AREA, not on what is written. So a synthetic slip measures latency honestly
 * while a real one is needed for accuracy. Deliberately no dependencies: EC2 has neither sharp
 * nor ImageMagick, and this is not worth installing either for.
 */
const zlib = require('zlib');
const fs = require('fs');

const W = 600;
const H = 800;

// One byte per pixel, greyscale, white paper.
const px = Buffer.alloc(W * H, 0xff);
const dot = (x, y, v) => {
  x = Math.round(x);
  y = Math.round(y);
  if (x >= 0 && x < W && y >= 0 && y < H) px[y * W + x] = v;
};
const stroke = (x0, y0, x1, y1, v) => {
  const steps = Math.ceil(Math.hypot(x1 - x0, y1 - y0));
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    // 2px nib, so the strokes survive JPEG-ish thinking the way pen on paper does.
    dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, v);
    dot(x0 + (x1 - x0) * t + 1, y0 + (y1 - y0) * t, v);
  }
};

// A frame, ruled lines, and a wobbling scrawl on each line — roughly the ink density of a nota.
let seed = 7;
const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
stroke(30, 30, W - 30, 30, 0x20);
stroke(30, H - 30, W - 30, H - 30, 0x20);
stroke(30, 30, 30, H - 30, 0x20);
stroke(W - 30, 30, W - 30, H - 30, 0x20);
for (let row = 0; row < 18; row++) {
  const y = 90 + row * 38;
  stroke(60, y + 16, W - 60, y + 16, 0xc0);
  let x = 70;
  while (x < W - 120) {
    const w = 6 + rnd() * 14;
    stroke(x, y + 14 - rnd() * 18, x + w, y + 14 - rnd() * 18, 0x30);
    x += w + 3 + rnd() * 5;
  }
}

// PNG: each scanline prefixed with filter byte 0, then deflate, then the three required chunks.
const raw = Buffer.alloc((W + 1) * H);
for (let y = 0; y < H; y++) {
  raw[y * (W + 1)] = 0;
  px.copy(raw, y * (W + 1) + 1, y * W, (y + 1) * W);
}
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body) >>> 0);
  return Buffer.concat([len, body, crc]);
};
let table = null;
function crc32(buf) {
  if (!table) {
    table = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c;
    }
  }
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = table[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return c ^ -1;
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(W, 0);
ihdr.writeUInt32BE(H, 4);
ihdr[8] = 8; // bit depth
ihdr[9] = 0; // greyscale
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw)),
  chunk('IEND', Buffer.alloc(0)),
]);

const out = process.argv[2] || '/tmp/probe.png';
fs.writeFileSync(out, png);
console.log(`${out} ${W}x${H} ${(png.length / 1024).toFixed(0)}kB`);
