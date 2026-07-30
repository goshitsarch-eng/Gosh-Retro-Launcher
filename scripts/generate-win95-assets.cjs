#!/usr/bin/env node
/*
 * Original clean-room Windows 95 RTM-style pixel drawings.
 *
 * Large and small sources below are separately authored designs. No Microsoft
 * binary, icon, screenshot, or extracted resource is read by this generator.
 * Reference material is used only for metaphor, perspective, visual bounds,
 * lighting direction, and palette-density observations documented in
 * assets/win95/PROVENANCE.md.
 */
const fs = require('node:fs')
const path = require('node:path')
const zlib = require('node:zlib')

const OUT = path.join(__dirname, '../src/renderer/src/assets/win95')
const P = {
  k: '#000000', w: '#ffffff', f: '#c0c0c0', s: '#808080',
  n: '#000080', b: '#0000ff', t: '#008080', a: '#00ffff',
  r: '#ff0000', m: '#800000', y: '#ffff00', o: '#808000',
  l: '#00ff00', g: '#008000', x: '#ff00ff', p: '#800080',
  clear: '#00000000'
}

function rgba(hex) {
  if (hex.length === 9) return [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16), parseInt(hex.slice(7, 9), 16)]
  return [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16), 255]
}

class Canvas {
  constructor(size) { this.size = size; this.data = Buffer.alloc(size * size * 4) }
  pixel(x, y, color) {
    x = Math.round(x); y = Math.round(y)
    if (x < 0 || y < 0 || x >= this.size || y >= this.size) return
    const [r, g, b, a] = rgba(color); const i = (y * this.size + x) * 4
    this.data[i] = r; this.data[i + 1] = g; this.data[i + 2] = b; this.data[i + 3] = a
  }
  rect(x, y, w, h, color) {
    for (let yy = Math.round(y); yy < Math.round(y + h); yy++) for (let xx = Math.round(x); xx < Math.round(x + w); xx++) this.pixel(xx, yy, color)
  }
  line(x0, y0, x1, y1, color, width = 1) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1)
    let dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1, dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1, err = dx + dy
    while (true) {
      for (let oy = 0; oy < width; oy++) for (let ox = 0; ox < width; ox++) this.pixel(x0 + ox, y0 + oy, color)
      if (x0 === x1 && y0 === y1) break
      const e2 = 2 * err
      if (e2 >= dy) { err += dy; x0 += sx }
      if (e2 <= dx) { err += dx; y0 += sy }
    }
  }
  polygon(points, color) {
    const minY = Math.max(0, Math.min(...points.map(([, y]) => y))), maxY = Math.min(this.size - 1, Math.max(...points.map(([, y]) => y)))
    for (let y = minY; y <= maxY; y++) {
      const nodes = []
      for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
        const [xi, yi] = points[i], [xj, yj] = points[j]
        if ((yi < y && yj >= y) || (yj < y && yi >= y)) nodes.push(Math.round(xi + (y - yi) / (yj - yi) * (xj - xi)))
      }
      nodes.sort((a, b) => a - b)
      for (let i = 0; i + 1 < nodes.length; i += 2) for (let x = nodes[i]; x <= nodes[i + 1]; x++) this.pixel(x, y, color)
    }
  }
  circle(cx, cy, radius, color) {
    for (let y = -radius; y <= radius; y++) for (let x = -radius; x <= radius; x++) if (x * x + y * y <= radius * radius) this.pixel(cx + x, cy + y, color)
  }
  dither(x, y, w, h, first, second) {
    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.pixel(xx, yy, (xx + yy) % 2 ? first : second)
  }
}

function largeWindow(c, x = 2, y = 3, w = 28, h = 26) {
  c.rect(x, y, w, h, P.k); c.rect(x + 1, y + 1, w - 2, h - 2, P.f)
  c.line(x + 1, y + 1, x + w - 2, y + 1, P.w); c.rect(x + 2, y + 3, w - 4, 5, P.n)
  c.rect(x + 4, y + 10, w - 8, h - 14, P.w); c.line(x + 4, y + 10, x + w - 5, y + 10, P.s)
  c.rect(x + w - 6, y + 4, 3, 3, P.f); c.pixel(x + w - 5, y + 5, P.k)
}
function largePage(c, x = 6, y = 1, w = 21, h = 29) {
  c.polygon([[x, y], [x + w - 6, y], [x + w, y + 6], [x + w, y + h], [x, y + h]], P.k)
  c.polygon([[x + 1, y + 1], [x + w - 7, y + 1], [x + w - 1, y + 7], [x + w - 1, y + h - 1], [x + 1, y + h - 1]], P.w)
  c.polygon([[x + w - 6, y + 1], [x + w - 1, y + 6], [x + w - 6, y + 6]], P.f)
  c.line(x + w - 6, y + 1, x + w - 6, y + 6, P.s)
}
function largeFolder(c, open = false) {
  c.polygon([[1, 8], [3, 5], [15, 5], [18, 9], [30, 9], [31, 28], [2, 28]], P.k)
  c.polygon([[2, 9], [4, 6], [14, 6], [17, 10], [29, 10], [30, 27], [3, 27]], P.y)
  c.line(3, 10, 29, 10, P.w); c.line(3, 11, 3, 25, P.w); c.dither(6, 13, 20, 12, P.y, P.o)
  if (open) {
    c.polygon([[1, 13], [31, 13], [26, 30], [0, 30]], P.k)
    c.polygon([[2, 14], [30, 14], [25, 29], [1, 29]], P.y)
    c.line(2, 14, 30, 14, P.w); c.dither(4, 18, 22, 9, P.y, P.o)
  }
}
function largeMonitor(c, x, y, w, h) {
  c.polygon([[x, y], [x + w, y + 1], [x + w - 1, y + h], [x + 1, y + h]], P.k)
  c.polygon([[x + 1, y + 1], [x + w - 1, y + 2], [x + w - 2, y + h - 2], [x + 2, y + h - 2]], P.f)
  c.polygon([[x + 3, y + 3], [x + w - 3, y + 4], [x + w - 4, y + h - 4], [x + 4, y + h - 4]], P.n)
  c.dither(x + 5, y + 5, Math.max(2, w - 10), Math.max(2, h - 9), P.b, P.t)
}

function drawLarge(id) {
  const c = new Canvas(32)
  switch (id) {
    case 'my-computer':
      /* Compact CRT and separate perspective keyboard, the RTM desktop metaphor. */
      c.polygon([[8, 2], [26, 2], [28, 4], [27, 20], [9, 20], [7, 18]], P.k)
      c.polygon([[9, 3], [25, 3], [26, 5], [25, 18], [10, 18], [9, 17]], P.f)
      c.line(10, 4, 24, 4, P.w); c.line(9, 4, 9, 16, P.w)
      c.rect(11, 6, 12, 9, P.k); c.rect(12, 7, 10, 7, P.t); c.line(13, 8, 20, 8, P.a)
      c.rect(15, 19, 6, 4, P.k); c.rect(16, 19, 4, 3, P.f)
      c.polygon([[7, 23], [23, 23], [29, 28], [4, 30], [2, 28]], P.k)
      c.polygon([[8, 24], [22, 24], [26, 27], [5, 28]], P.f); c.line(8, 25, 23, 25, P.w); c.line(7, 27, 25, 26, P.s); break
    case 'network-neighborhood':
      /* Two offset desktop systems joined by the yellow LAN lead used by RTM. */
      largeMonitor(c, 2, 2, 13, 10); c.rect(5, 12, 6, 2, P.k); c.polygon([[1, 14], [13, 14], [16, 17], [3, 18]], P.k); c.polygon([[3, 15], [12, 15], [14, 16], [4, 17]], P.f)
      c.line(13, 16, 22, 24, P.k, 2); c.line(13, 15, 23, 23, P.y)
      largeMonitor(c, 14, 13, 16, 12); c.rect(19, 25, 7, 3, P.k); c.polygon([[12, 28], [29, 27], [32, 30], [15, 32]], P.k); c.polygon([[15, 28], [28, 28], [29, 29], [16, 30]], P.f); break
    case 'recycle-empty': case 'recycle-full':
      /* An angled open waste-paper basket rather than the later upright can. */
      c.polygon([[7, 5], [23, 1], [29, 6], [26, 26], [12, 31], [7, 27], [5, 9]], P.k)
      c.polygon([[8, 7], [22, 3], [27, 7], [24, 25], [13, 29], [9, 26]], P.w)
      c.polygon([[10, 9], [22, 6], [25, 9], [22, 24], [14, 27], [11, 24]], P.f)
      c.line(11, 10, 14, 25, P.w); c.line(17, 8, 18, 25, P.s); c.line(23, 7, 21, 23, P.w)
      c.polygon([[5, 5], [22, 1], [29, 5], [27, 8], [8, 11], [4, 8]], P.k); c.polygon([[7, 6], [22, 3], [27, 5], [25, 7], [8, 9], [6, 8]], P.w)
      c.polygon([[13, 13], [17, 10], [19, 14], [17, 14], [19, 18], [15, 18], [13, 15]], P.g)
      c.polygon([[20, 17], [23, 20], [20, 24], [19, 22], [15, 24], [14, 20], [18, 19]], P.g)
      if (id === 'recycle-full') { c.polygon([[9, 4], [14, 2], [18, 11], [12, 13]], P.n); c.polygon([[19, 2], [25, 1], [25, 10], [20, 11]], P.y) }
      break
    case 'folder': largeFolder(c); break
    case 'folder-open': largeFolder(c, true); break
    case 'programs':
      largeFolder(c); largeWindow(c, 13, 11, 17, 16); c.rect(17, 20, 4, 3, P.n); c.rect(23, 20, 4, 3, P.r); break
    case 'documents':
      largePage(c); c.line(10, 10, 23, 10, P.n); c.line(10, 13, 24, 13, P.n); c.line(10, 16, 22, 16, P.n); c.line(10, 20, 24, 20, P.s); c.line(10, 23, 19, 23, P.s); break
    case 'settings': case 'control-panel':
      largeWindow(c); c.rect(6, 13, 20, 2, P.s); c.rect(9, 10, 3, 10, P.n); c.rect(19, 10, 3, 10, P.r); c.circle(10, 23, 2, P.g); c.circle(21, 23, 2, P.y); c.pixel(10, 23, P.w); break
    case 'find':
      largePage(c, 1, 1, 19, 26); c.line(5, 9, 15, 9, P.n); c.line(5, 12, 16, 12, P.n)
      c.circle(20, 19, 9, P.k); c.circle(20, 19, 7, P.w); c.circle(20, 19, 5, P.a); c.dither(17, 16, 6, 6, P.a, P.b); c.line(25, 25, 31, 31, P.k, 3); c.line(25, 25, 30, 30, P.f); break
    case 'help':
      c.polygon([[3, 4], [15, 2], [17, 5], [29, 3], [29, 28], [17, 30], [15, 27], [3, 29]], P.k)
      c.polygon([[4, 5], [14, 4], [16, 6], [16, 27], [14, 25], [4, 27]], P.n); c.polygon([[17, 6], [28, 4], [28, 27], [17, 29]], P.w)
      c.rect(8, 8, 5, 3, P.w); c.rect(12, 10, 3, 5, P.w); c.rect(10, 14, 3, 5, P.w); c.rect(10, 22, 3, 3, P.w); c.line(20, 10, 26, 9, P.s); c.line(20, 14, 26, 13, P.s); break
    case 'run':
      largeWindow(c); c.rect(6, 12, 20, 4, P.w); c.line(6, 12, 25, 12, P.s); c.rect(6, 19, 8, 5, P.f); c.rect(17, 19, 9, 5, P.f); c.line(8, 21, 12, 21, P.k); c.line(19, 21, 24, 21, P.k); break
    case 'shutdown':
      largeMonitor(c, 0, 5, 20, 16); c.rect(7, 21, 6, 3, P.k); c.rect(3, 24, 16, 3, P.k)
      c.rect(20, 7, 11, 22, P.k); c.rect(21, 8, 9, 20, P.f); c.line(21, 8, 29, 8, P.w); c.rect(23, 12, 5, 2, P.s); c.circle(26, 23, 2, P.g); c.line(5, 30, 11, 25, P.r, 2); c.line(11, 30, 5, 25, P.r, 2); break
    case 'windows-logo':
      c.polygon([[1, 7], [14, 3], [30, 6], [25, 26], [12, 23], [2, 27]], P.k)
      c.polygon([[3, 8], [14, 5], [14, 13], [4, 15]], P.r); c.polygon([[16, 5], [28, 7], [26, 15], [16, 13]], P.g)
      c.polygon([[4, 17], [14, 15], [14, 22], [4, 24]], P.b); c.polygon([[16, 15], [26, 17], [24, 24], [16, 22]], P.y)
      c.line(2, 28, 24, 27, P.s); break
    case 'application':
      largeWindow(c); c.rect(6, 12, 8, 6, P.n); c.rect(17, 12, 9, 6, P.r); c.rect(6, 20, 8, 5, P.g); c.rect(17, 20, 9, 5, P.y); c.line(7, 13, 12, 13, P.w); c.line(18, 13, 24, 13, P.w); break
    case 'url':
      c.circle(16, 16, 15, P.k); c.circle(16, 16, 13, P.b); c.circle(16, 16, 11, P.a); c.line(3, 16, 29, 16, P.w); c.line(16, 3, 16, 29, P.w); c.polygon([[12, 4], [8, 10], [7, 16], [9, 23], [13, 28]], P.b); c.polygon([[20, 4], [24, 10], [25, 16], [23, 23], [19, 28]], P.b); break
    case 'drive':
      c.polygon([[2, 8], [27, 6], [31, 12], [31, 27], [4, 30], [1, 25]], P.k); c.polygon([[3, 9], [26, 8], [29, 12], [29, 25], [5, 28], [3, 24]], P.f); c.line(4, 10, 26, 9, P.w); c.rect(7, 13, 17, 6, P.w); c.rect(9, 15, 13, 2, P.s); c.circle(25, 23, 2, P.g); break
    case 'printers':
      c.rect(7, 0, 19, 12, P.k); c.rect(8, 1, 17, 12, P.w); c.line(10, 4, 23, 4, P.n); c.line(10, 7, 22, 7, P.n)
      c.polygon([[2, 10], [29, 10], [32, 15], [30, 25], [3, 25], [0, 19]], P.k); c.polygon([[3, 11], [28, 11], [30, 15], [29, 23], [4, 23], [2, 19]], P.f); c.line(3, 12, 28, 12, P.w); c.pixel(26, 16, P.g)
      c.rect(7, 19, 20, 13, P.k); c.rect(8, 20, 18, 11, P.w); c.line(10, 23, 24, 23, P.n); c.line(10, 26, 23, 26, P.n); break
    case 'taskbar':
      largeWindow(c, 1, 2, 30, 27); c.rect(3, 24, 26, 4, P.f); c.line(3, 24, 28, 24, P.w); c.rect(4, 25, 7, 2, P.k); c.rect(12, 25, 9, 2, P.n); c.rect(22, 25, 6, 2, P.s); break
    case 'warning':
      c.polygon([[16, 0], [32, 30], [0, 30]], P.k); c.polygon([[16, 3], [29, 28], [3, 28]], P.y); c.rect(14, 9, 5, 12, P.k); c.rect(15, 23, 4, 4, P.k); c.line(11, 27, 21, 27, P.o); break
    case 'information':
      c.circle(16, 16, 15, P.k); c.circle(16, 16, 13, P.b); c.dither(5, 7, 22, 19, P.b, P.n); c.rect(14, 12, 5, 13, P.w); c.rect(11, 23, 10, 4, P.w); c.rect(14, 5, 5, 5, P.w); break
    case 'question':
      c.circle(16, 16, 15, P.k); c.circle(16, 16, 13, P.n); c.dither(5, 7, 22, 19, P.n, P.b); c.rect(10, 6, 10, 4, P.w); c.rect(19, 8, 5, 7, P.w); c.rect(15, 13, 7, 4, P.w); c.rect(13, 16, 5, 6, P.w); c.rect(13, 25, 5, 4, P.w); break
    case 'critical':
      c.circle(16, 16, 15, P.k); c.circle(16, 16, 13, P.r); c.dither(5, 7, 22, 19, P.r, P.m); c.rect(14, 6, 5, 15, P.w); c.rect(14, 24, 5, 5, P.w); break
    case 'new-shortcut':
      largePage(c, 3, 1, 20, 26); c.line(7, 10, 18, 10, P.n); c.line(7, 14, 19, 14, P.n); c.line(7, 18, 16, 18, P.n); c.line(18, 25, 30, 13, P.k, 3); c.polygon([[28, 11], [31, 12], [30, 15]], P.y); break
    case 'properties':
      largePage(c, 5, 1, 21, 29); c.rect(9, 8, 13, 3, P.n); c.rect(9, 14, 4, 4, P.y); c.line(15, 16, 22, 16, P.s); c.rect(9, 21, 4, 4, P.g); c.line(15, 23, 22, 23, P.s); break
    default: largeWindow(c)
  }
  return c.data
}

function smallWindow(c) {
  c.rect(1, 2, 14, 13, P.k); c.rect(2, 3, 12, 11, P.f); c.rect(3, 4, 10, 3, P.n); c.rect(3, 8, 10, 5, P.w); c.pixel(11, 5, P.w)
}
function smallFolder(c, open = false) {
  c.polygon([[0, 5], [2, 3], [7, 3], [9, 5], [15, 5], [15, 14], [1, 14]], P.k); c.polygon([[1, 6], [3, 4], [7, 4], [9, 6], [14, 6], [14, 13], [2, 13]], P.y); c.line(2, 6, 14, 6, P.w)
  if (open) { c.polygon([[0, 7], [16, 7], [13, 15], [0, 15]], P.k); c.polygon([[1, 8], [15, 8], [12, 14], [1, 14]], P.y); c.line(1, 8, 15, 8, P.w) }
}
function smallPage(c) { c.polygon([[3, 0], [10, 0], [14, 4], [14, 15], [3, 15]], P.k); c.polygon([[4, 1], [10, 1], [13, 4], [13, 14], [4, 14]], P.w); c.polygon([[10, 1], [13, 4], [10, 4]], P.f) }
function smallMonitor(c, x, y) { c.rect(x, y, 7, 6, P.k); c.rect(x + 1, y + 1, 5, 4, P.f); c.rect(x + 2, y + 2, 3, 2, P.n); c.rect(x + 2, y + 6, 3, 1, P.k) }

function drawSmall(id) {
  const c = new Canvas(16)
  switch (id) {
    case 'my-computer':
      c.polygon([[4, 1], [13, 1], [14, 2], [14, 9], [5, 9], [4, 8]], P.k); c.rect(5, 2, 8, 6, P.f); c.rect(6, 3, 6, 4, P.t); c.line(7, 4, 10, 4, P.a)
      c.rect(7, 9, 4, 2, P.k); c.polygon([[3, 11], [12, 11], [16, 14], [2, 16], [0, 14]], P.k); c.polygon([[4, 12], [11, 12], [14, 14], [2, 15]], P.f); break
    case 'network-neighborhood':
      smallMonitor(c, 0, 1); c.polygon([[0, 8], [7, 8], [9, 10], [1, 11]], P.k); c.line(7, 9, 11, 12, P.y); smallMonitor(c, 8, 8); c.polygon([[7, 15], [15, 14], [16, 16], [9, 16]], P.k); break
    case 'recycle-empty': case 'recycle-full':
      c.polygon([[3, 3], [11, 1], [15, 4], [13, 14], [6, 16], [3, 14], [2, 5]], P.k); c.polygon([[4, 4], [11, 2], [14, 4], [12, 13], [7, 15], [4, 13]], P.w); c.line(6, 5, 7, 13, P.s); c.line(10, 4, 10, 13, P.s); c.polygon([[6, 7], [9, 5], [10, 8], [8, 8], [10, 11], [7, 12]], P.g); if (id === 'recycle-full') { c.polygon([[5, 2], [8, 1], [10, 6], [6, 7]], P.n) } break
    case 'folder': smallFolder(c); break
    case 'folder-open': smallFolder(c, true); break
    case 'programs': smallFolder(c); c.rect(7, 7, 8, 7, P.k); c.rect(8, 8, 6, 5, P.w); c.rect(9, 9, 4, 2, P.n); break
    case 'documents': smallPage(c); c.line(6, 6, 11, 6, P.n); c.line(6, 8, 11, 8, P.n); c.line(6, 10, 10, 10, P.s); break
    case 'settings': case 'control-panel': smallWindow(c); c.rect(4, 9, 2, 3, P.n); c.rect(7, 8, 2, 4, P.r); c.rect(10, 10, 2, 2, P.g); break
    case 'find': smallPage(c); c.circle(10, 10, 4, P.k); c.circle(10, 10, 2, P.a); c.line(13, 13, 15, 15, P.k, 2); break
    case 'help': c.polygon([[1, 2], [7, 1], [8, 3], [15, 2], [15, 14], [8, 15], [7, 13], [1, 14]], P.k); c.polygon([[2, 3], [6, 2], [7, 4], [7, 13], [2, 13]], P.n); c.polygon([[8, 4], [14, 3], [14, 13], [8, 14]], P.w); c.rect(4, 4, 2, 2, P.w); c.rect(5, 6, 2, 3, P.w); c.pixel(5, 11, P.w); break
    case 'run': smallWindow(c); c.rect(4, 9, 8, 2, P.w); c.rect(4, 12, 3, 2, P.s); c.rect(9, 12, 3, 2, P.s); break
    case 'shutdown': smallMonitor(c, 0, 3); c.rect(8, 3, 8, 12, P.k); c.rect(9, 4, 6, 10, P.f); c.pixel(12, 11, P.g); c.line(1, 15, 5, 11, P.r); c.line(5, 15, 1, 11, P.r); break
    case 'windows-logo': c.polygon([[0, 4], [7, 1], [15, 3], [13, 13], [7, 11], [1, 14]], P.k); c.polygon([[2, 4], [7, 2], [7, 6], [2, 7]], P.r); c.polygon([[8, 2], [14, 4], [13, 7], [8, 6]], P.g); c.polygon([[2, 8], [7, 7], [7, 11], [2, 12]], P.b); c.polygon([[8, 7], [13, 8], [12, 12], [8, 11]], P.y); break
    case 'application': smallWindow(c); c.rect(4, 9, 3, 2, P.n); c.rect(9, 9, 3, 2, P.r); c.rect(4, 12, 3, 1, P.g); c.rect(9, 12, 3, 1, P.y); break
    case 'url': c.circle(8, 8, 8, P.k); c.circle(8, 8, 6, P.a); c.line(2, 8, 14, 8, P.w); c.line(8, 2, 8, 14, P.w); c.line(4, 4, 12, 4, P.b); c.line(4, 12, 12, 12, P.b); break
    case 'drive': c.polygon([[1, 4], [13, 3], [16, 6], [15, 14], [3, 15], [0, 12]], P.k); c.polygon([[2, 5], [12, 4], [14, 6], [14, 13], [3, 14], [2, 12]], P.f); c.rect(4, 7, 7, 3, P.w); c.pixel(12, 11, P.g); break
    case 'printers': c.rect(4, 0, 9, 6, P.k); c.rect(5, 1, 7, 5, P.w); c.rect(1, 5, 14, 8, P.k); c.rect(2, 6, 12, 6, P.f); c.pixel(12, 8, P.g); c.rect(4, 10, 9, 6, P.k); c.rect(5, 11, 7, 4, P.w); break
    case 'taskbar': smallWindow(c); c.rect(2, 12, 12, 2, P.f); c.rect(3, 13, 3, 1, P.k); c.rect(7, 13, 4, 1, P.n); break
    case 'warning': c.polygon([[8, 0], [16, 15], [0, 15]], P.k); c.polygon([[8, 2], [14, 14], [2, 14]], P.y); c.rect(7, 5, 2, 6, P.k); c.rect(7, 12, 2, 2, P.k); break
    case 'information': c.circle(8, 8, 8, P.k); c.circle(8, 8, 6, P.b); c.rect(7, 6, 3, 7, P.w); c.rect(5, 11, 6, 2, P.w); c.rect(7, 3, 3, 2, P.w); break
    case 'question': c.circle(8, 8, 8, P.k); c.circle(8, 8, 6, P.n); c.rect(5, 3, 6, 2, P.w); c.rect(10, 4, 3, 4, P.w); c.rect(7, 7, 4, 2, P.w); c.rect(6, 9, 2, 2, P.w); c.rect(6, 12, 2, 2, P.w); break
    case 'critical': c.circle(8, 8, 8, P.k); c.circle(8, 8, 6, P.r); c.rect(7, 3, 3, 7, P.w); c.rect(7, 12, 3, 2, P.w); break
    case 'new-shortcut': smallPage(c); c.line(6, 6, 11, 6, P.n); c.line(6, 9, 11, 9, P.n); c.line(9, 14, 15, 8, P.k, 2); c.pixel(15, 7, P.y); break
    case 'properties': smallPage(c); c.rect(6, 5, 5, 2, P.n); c.rect(6, 9, 2, 2, P.y); c.line(9, 10, 12, 10, P.s); break
    default: smallWindow(c)
  }
  return c.data
}

function crc32(buf) {
  let c = 0xffffffff
  for (const byte of buf) { c ^= byte; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1)) }
  return (c ^ 0xffffffff) >>> 0
}
function chunk(type, data) {
  const t = Buffer.from(type), out = Buffer.alloc(12 + data.length)
  out.writeUInt32BE(data.length, 0); t.copy(out, 4); data.copy(out, 8); out.writeUInt32BE(crc32(Buffer.concat([t, data])), 8 + data.length); return out
}
function png(size, rgbaData) {
  const raw = Buffer.alloc((size * 4 + 1) * size)
  for (let y = 0; y < size; y++) { raw[y * (size * 4 + 1)] = 0; rgbaData.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4) }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4); ihdr[8] = 8; ihdr[9] = 6
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))])
}
function upscale(data, from, to) {
  const out = Buffer.alloc(to * to * 4), factor = to / from
  for (let y = 0; y < to; y++) for (let x = 0; x < to; x++) { const si = (Math.floor(y / factor) * from + Math.floor(x / factor)) * 4, di = (y * to + x) * 4; data.copy(out, di, si, si + 4) }
  return out
}

const ids = [
  'my-computer', 'network-neighborhood', 'recycle-empty', 'recycle-full',
  'folder', 'folder-open', 'programs', 'documents', 'settings', 'control-panel',
  'find', 'help', 'run', 'shutdown', 'windows-logo', 'application', 'url',
  'drive', 'printers', 'taskbar', 'warning', 'information', 'question',
  'critical', 'new-shortcut', 'properties'
]
for (const family of [{ name: 'large', base: 32, draw: drawLarge }, { name: 'small', base: 16, draw: drawSmall }]) {
  const dir = path.join(OUT, family.name); fs.mkdirSync(dir, { recursive: true })
  for (const id of ids) {
    const source = family.draw(id)
    for (let scale = 1; scale <= 4; scale++) {
      const size = family.base * scale
      fs.writeFileSync(path.join(dir, `${id}-${size}.png`), png(size, scale === 1 ? source : upscale(source, family.base, size)))
    }
  }
}
console.log(`Generated ${ids.length * 8} independently-authored Win95 icon variants in ${OUT}`)
