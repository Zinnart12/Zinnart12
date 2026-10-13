import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir, readFile } from 'node:fs/promises';
import { shadowAngularRadius } from '../src/physics.js';

const base = process.env.TEST_BASE_URL || 'http://127.0.0.1:5174';
const server = process.env.TEST_BASE_URL ? null : spawn(process.execPath,
  ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '5174', '--strictPort'],
  { stdio: ['ignore', 'pipe', 'pipe'] });
let serverOutput = '';
server?.stdout.on('data', data => { serverOutput += data; });
server?.stderr.on('data', data => { serverOutput += data; });
let browser;
let count = 0;
const passed = label => { count++; console.log(`PASS ${count}: ${label}`); };

try {
  for (let attempt = 0; attempt < 60; attempt++) {
    try { if ((await fetch(base)).ok) break; } catch { /* server booting */ }
    if (attempt === 59) throw new Error(`Dev server did not start. ${serverOutput}`);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  await mkdir('test-results', { recursive: true });
  browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 }, acceptDownloads: true });
  // Software WebGL can take several seconds per frame; allow real interaction
  // stability waits and use a smaller viewport for the full-resolution presets.
  page.setDefaultTimeout(90000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('response', response => { if (response.status() >= 400) errors.push(`HTTP ${response.status()} ${response.url()}`); });
  await page.goto(`${base}/?test`);
  await page.waitForFunction(() => window.__observatory && !document.getElementById('loading'), null, { timeout: 90000 });
  const snapshot = () => page.evaluate(() => window.__observatory.snapshot());
  const sample = () => page.evaluate(() => window.__observatory.sample());
  const set = async (key, value) => {
    await page.locator(`#${key}`).evaluate((input, val) => {
      input.value = val;
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }, value);
  };
  const toggle = async (key, value) => {
    await page.locator(`#${key}`).evaluate((input, val) => {
      input.checked = val;
      input.dispatchEvent(new Event('change', { bubbles: true }));
    }, value);
  };
  const frames = async (count = 4) => page.evaluate(async count => {
    const before = window.__observatory.snapshot().time;
    for (let i = 0; i < count; i++) await new Promise(requestAnimationFrame);
    return window.__observatory.snapshot().time - before;
  }, count);

  assert.equal((await snapshot()).running, true);
  assert.equal((await snapshot()).shaderFailure, null);
  await toggle('autoQuality', false);
  await set('resolution', 0.4);
  await page.locator('#pause').click();
  const baseline = await sample();
  assert.equal(baseline.glError, 0);
  assert.ok(baseline.bright > 1000, 'the disk actually emits light');
  assert.ok(baseline.white < baseline.bright * 0.03, 'default exposure preserves plasma detail instead of clipping it to white');
  assert.equal((await snapshot()).hdr, true);
  passed('WebGL2 shaders compile, HDR works and default plasma has under 3% white-clipped bright pixels');

  const pausedTime = (await snapshot()).time;
  await frames();
  assert.equal((await snapshot()).time, pausedTime);
  assert.equal((await sample()).signature, baseline.signature);
  await page.locator('#pause').click();
  assert.ok(await frames() > 0);
  assert.notEqual((await sample()).signature, baseline.signature, 'animated plasma actually changes pixels, not just the clock');
  await set('speed', 0.05);
  const slow = await frames(5);
  await set('speed', 4);
  const fast = await frames(5);
  assert.ok(fast > slow * 10, `speed changes real simulation time: ${slow} → ${fast}`);
  await page.locator('#pause').click();
  await set('speed', 1);
  passed('Pause freezes emission and time; Resume and simulation speed advance animation');

  for (const boundary of [4, 8]) {
    await page.evaluate(t => window.__observatory.setTime(t), boundary - 0.001);
    const before = await page.evaluate(() => window.__observatory.sample({ profile: true }));
    await page.evaluate(t => window.__observatory.setTime(t), boundary + 0.001);
    const after = await page.evaluate(() => window.__observatory.sample({ profile: true }));
    const error = before.centerRow.reduce((sum, value, i) => sum + Math.abs(value - after.centerRow[i]), 0) / before.width;
    assert.ok(error < 0.75, `Noise parcel reset is continuous: ${error} average pixel levels`);
  }
  await page.evaluate(() => window.__observatory.setTime(600));
  const oldGas = await sample();
  await page.evaluate(() => window.__observatory.setTime(601));
  assert.notEqual((await sample()).signature, oldGas.signature, 'a long-running simulation retains evolving plasma');
  await page.evaluate(() => window.__observatory.setTime(0));
  passed('Staggered turbulent parcels reset without visible jumps and keep animating after ten simulation minutes');

  for (const [key, low, high] of [['density',0.1,3],['brightness',0.1,3],['exposure',0.3,2]]) {
    await set(key, low); const a = await sample();
    await set(key, high); const b = await sample();
    assert.ok(b.energy > a.energy, `${key} changes rendered light (${a.energy} → ${b.energy})`);
    await set(key, key === 'density' ? 1.2 : key === 'brightness' ? 1.15 : 1.05);
  }
  passed('Density, brightness and exposure monotonically affect rendered energy');

  for (const [key, low, high] of [['temperature',2500,22000],['spin',0,0.98],['tilt',-35,45],['lensing',0,1]]) {
    await set(key, low); const a = await sample();
    await set(key, high); const b = await sample();
    assert.notEqual(a.signature, b.signature, `${key} must change actual rendered pixels`);
    assert.equal(b.glError, 0);
    await set(key, key === 'temperature' ? 8200 : key === 'lensing' ? 1 : 0);
  }
  passed('Temperature, spin, disk tilt and lensing change the rendered image');

  const radiusBefore = Number((await page.locator('#radius').inputValue()));
  const beforeMass = await sample();
  await set('mass', 8.6);
  assert.ok(Math.abs(Number(await page.locator('#radius').inputValue()) / radiusBefore - 2) < 0.002);
  assert.notEqual((await sample()).signature, beforeMass.signature);
  await set('radius', radiusBefore);
  assert.ok(Math.abs((await snapshot()).state.mass - 4.3) < 0.01);
  await set('mass', 4.3);
  passed('Mass changes apparent size; horizon radius and mass stay linked by 2GM/c²');

  await set('quality', 1); await sample();
  assert.equal((await snapshot()).steps, 96);
  await set('quality', 4); await sample();
  assert.equal((await snapshot()).steps, 320);
  const lowWidth = (await snapshot()).width;
  await set('resolution', 0.6);
  assert.ok((await snapshot()).width > lowWidth);
  await set('quality', 2); await set('resolution', 0.4);
  passed('Lensing quality changes integration budget; resolution resizes GPU targets');

  for (const key of ['disk','stars','nebula','ring','bloom']) await toggle(key, false);
  const dark = await sample();
  assert.ok(dark.center.every(value => value <= 2), 'captured horizon is truly black');
  await toggle('ring', true);
  assert.equal((await sample()).signature, dark.signature, 'photon ring cannot emit a fake outline when the disk is off');
  for (const key of ['disk','stars','nebula']) {
    await toggle(key, true); const layer = await sample();
    assert.notEqual(layer.signature, dark.signature, `${key} actually adds its layer`);
    await toggle(key, false);
  }
  await toggle('disk', true); await toggle('ring', false);
  await set('quality', 4); await set('resolution', 0.6);
  const directImages = await sample();
  await toggle('ring', true);
  const allImages = await sample();
  assert.notEqual(allImages.signature, directImages.signature, 'real higher-order disk paths contribute to the photon image');
  await set('quality', 2); await set('resolution', 0.4);
  for (const key of ['stars','nebula']) await toggle(key, true);
  const noBloom = await sample();
  await toggle('bloom', true);
  assert.ok((await sample()).energy > noBloom.energy);
  passed('Scene layers and bloom work; photon images need emitting gas and contain no independent luminous outline');

  for (const key of ['disk','stars','nebula','bloom']) await toggle(key, false);
  await set('resolution', 0.75);
  const shadowWidths = [];
  for (const [mass, quality] of [[4.3, 1], [4.3, 4], [2, 4]]) {
    await set('mass', mass);
    await set('quality', quality);
    const result = await page.evaluate(() => window.__observatory.sample({ profile: true }));
    const center = Math.floor(result.width / 2);
    let left = center, right = center;
    while (left > 0 && result.centerRow[left] <= 2) left--;
    while (right < result.width - 1 && result.centerRow[right] <= 2) right++;
    const radius = (right - left - 1) / 2;
    const observer = Math.hypot(...(await snapshot()).camera) / ((await snapshot()).state.mass / 4.3);
    const expected = Math.tan(shadowAngularRadius(observer)) * result.height / (2 * Math.tan(23 * Math.PI / 180));
    assert.ok(Math.abs(radius - expected) < 3, `GPU shadow radius ${radius}px vs finite-observer analytic ${expected}px`);
    shadowWidths.push(radius);
  }
  assert.ok(Math.abs(shadowWidths[0] - shadowWidths[1]) <= 2, 'capture edge converges across quality levels');
  await set('mass', 4.3);
  await set('quality', 2); await set('resolution', 0.4);
  for (const key of ['disk','stars','nebula','bloom']) await toggle(key, true);
  passed('Rendered GPU capture edge agrees with the analytic finite-observer Schwarzschild shadow');

  await page.locator('#tidal-analysis').evaluate(el => { el.open = true; });
  assert.ok(Number.parseFloat(await page.locator('#tidal-radius').textContent()) > 7);
  await set('bodyDistance', 1);
  assert.ok((await page.locator('#tidal-outcome').textContent()).startsWith('Vượt'));
  await page.locator('[data-body="probe"]').click();
  assert.ok((await page.locator('#tidal-outcome').textContent()).startsWith('Chưa vượt'));
  assert.ok(Number.parseFloat(await page.locator('#tidal-radius').textContent()) < 1);
  await page.locator('[data-body="earth"]').click(); await set('bodyDistance', 10);
  await page.locator('#tidal-analysis').evaluate(el => { el.open = false; });
  passed('Tidal controls distinguish an Earth-sized body from a material-supported probe without automatic destruction');

  const cameraBefore = (await snapshot()).camera;
  await page.mouse.move(400, 370);
  await page.mouse.down(); await page.mouse.move(545, 425, { steps: 8 }); await page.mouse.up();
  await frames(8);
  assert.notDeepEqual((await snapshot()).camera, cameraBefore);
  const distanceBefore = Math.hypot(...(await snapshot()).camera);
  await page.mouse.wheel(0, -200); await frames(8);
  assert.ok(Math.hypot(...(await snapshot()).camera) < distanceBefore);
  await page.locator('#reset-camera').click(); await page.locator('#viewport').click({position:{x:30,y:330}});
  await page.keyboard.press('c');
  assert.equal((await snapshot()).cameraMode, 'fly');
  const flyBefore = (await snapshot()).camera;
  await page.keyboard.down('w'); await page.keyboard.down('Shift'); await frames(8);
  await page.keyboard.up('Shift'); await page.keyboard.up('w');
  assert.notDeepEqual((await snapshot()).camera, flyBefore);
  await page.keyboard.press('r');
  assert.equal((await snapshot()).cameraMode, 'orbit');
  passed('Pointer orbit, scroll zoom, C, R and boosted WASD flight move the real camera');

  await page.locator('[data-view="top"]').click();
  await page.waitForFunction(() => window.__observatory.snapshot().camera[1] > 33, null, { timeout: 60000 });
  const top = await sample();
  assert.ok(top.center.every(value => value < 3));
  await page.screenshot({ path: 'test-results/top-view.png' });
  await page.locator('[data-view="bottom"]').click();
  await page.waitForFunction(() => window.__observatory.snapshot().camera[1] < -33, null, { timeout: 60000 });
  assert.notEqual((await sample()).signature, top.signature);
  await page.locator('[data-view="edge"]').click(); await frames(20);
  await page.screenshot({ path: 'test-results/edge-view.png' });
  passed('Top, bottom and edge presets reveal different 3D disk projections');

  await page.setViewportSize({ width: 800, height: 600 });
  await page.locator('[data-mode="cinematic"]').click();
  await toggle('autoQuality', false); await set('resolution', 0.4);
  assert.equal((await snapshot()).state.autoOrbit, true);
  await page.locator('#pause').click();
  const orbitBefore = (await snapshot()).camera;
  await frames(12);
  assert.notDeepEqual((await snapshot()).camera, orbitBefore);
  await page.locator('[data-mode="performance"]').click();
  assert.equal((await snapshot()).state.quality, 1);
  assert.equal((await snapshot()).state.bloom, false);
  await page.locator('[data-mode="scientific"]').click();
  assert.equal((await snapshot()).state.spin, 0);
  assert.equal((await snapshot()).state.lensing, 1);
  assert.equal((await snapshot()).state.autoOrbit, false);
  await set('resolution', 0.4);
  passed('Cinematic enables explicit orbit; Performance lowers load; Scientific resets the physical ray model');

  const downloadPromise = page.waitForEvent('download');
  await page.locator('#screenshot').click();
  const download = await downloadPromise;
  await download.saveAs('test-results/screenshot.png');
  const png = await readFile('test-results/screenshot.png');
  assert.equal(png.subarray(1,4).toString(), 'PNG');
  assert.ok(png.length > 5000);
  await page.locator('#fullscreen').click();
  await page.waitForFunction(() => !!document.fullscreenElement);
  await page.evaluate(() => document.exitFullscreen());
  await page.locator('#reset-simulation').click();
  assert.equal((await snapshot()).state.mass, 4.3);
  assert.equal((await snapshot()).cameraMode, 'orbit');
  await toggle('autoQuality', false); await set('resolution', 0.4);
  await page.locator('#help').click(); assert.equal(await page.locator('#help-dialog').evaluate(d => d.open), true);
  await page.locator('#help-close').click();
  passed('Screenshot downloads a real PNG; fullscreen, reset and keyboard-help dialog work');

  await page.setViewportSize({ width: 390, height: 844 });
  await frames();
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), 390);
  await page.locator('#panel-toggle').click();
  await page.waitForFunction(() => document.querySelector('.panel').getBoundingClientRect().right <= innerWidth + 1);
  assert.ok(await page.locator('.panel').evaluate(el => el.getBoundingClientRect().right <= innerWidth + 1));
  await page.screenshot({ path: 'test-results/mobile.png' });
  await page.locator('#panel-toggle').click();
  passed('Mobile resize fits the screen; control drawer opens and closes');

  // Context loss is a real browser event. Reuse the renderer after its GPU resources restore.
  await page.evaluate(() => {
    const ext = document.querySelector('canvas').getContext('webgl2').getExtension('WEBGL_lose_context');
    ext.loseContext(); setTimeout(() => ext.restoreContext(), 300);
  });
  await page.waitForFunction(() => !window.__observatory.snapshot().running, null, { timeout: 10000 });
  await page.waitForFunction(() => window.__observatory.snapshot().running, null, { timeout: 30000 });
  assert.ok((await sample()).bright > 500);
  passed('WebGL context loss pauses safely and restoration rebuilds a working renderer');

  await page.setViewportSize({ width: 1280, height: 800 });
  await page.locator('[data-mode="scientific"]').click();
  await toggle('autoQuality', true);
  const initialScale = (await snapshot()).state.resolution;
  await page.waitForFunction(scale => window.__observatory.snapshot().state.resolution < scale, initialScale, { timeout: 45000 });
  assert.ok((await snapshot()).fps < 28);
  await toggle('autoQuality', false);
  passed('Adaptive quality really reduces resolution under slow software-GPU presentation');

  assert.deepEqual(errors, [], 'no JavaScript, shader, network or framebuffer errors');
  // Release the first GPU workload before compiling/rendering the offline page.
  await page.close();
  const offline = await browser.newPage({ viewport: { width: 1100, height: 760 } });
  const offlineErrors = [], network = [];
  offline.on('pageerror', e => offlineErrors.push(e.message));
  offline.on('console', m => { if (m.type() === 'error') offlineErrors.push(m.text()); });
  offline.on('request', r => { if (/^https?:/.test(r.url())) network.push(r.url()); });
  // Managed cloud Chromium blocks file://. Execute the exact HTML with networking
  // disabled in an about:blank document; no server or external asset can rescue it.
  await offline.goto('about:blank?test');
  await offline.context().setOffline(true);
  await offline.setContent(await readFile('dist/index.html', 'utf8'), { waitUntil: 'domcontentloaded', timeout: 90000 });
  await offline.waitForFunction(() => window.__observatory && !document.getElementById('loading'), null, { timeout: 90000 });
  await offline.evaluate(() => {
    document.getElementById('autoQuality').click();
    const input = document.getElementById('resolution'); input.value = 0.4; input.dispatchEvent(new Event('input'));
  });
  assert.ok((await offline.evaluate(() => window.__observatory.sample())).bright > 1000);
  assert.deepEqual(network, [], 'single HTML makes no network requests');
  assert.deepEqual(offlineErrors, []);
  await offline.screenshot({ path: 'test-results/offline.png' });
  passed('Exact standalone HTML renders with the browser offline and zero network requests');
  console.log(`\n${count} browser checks passed. GPU: Chromium SwiftShader (not an RTX benchmark).`);
} finally {
  await browser?.close();
  server?.kill('SIGTERM');
}
