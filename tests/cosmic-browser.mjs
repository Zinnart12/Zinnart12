import assert from 'node:assert/strict';
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { mkdir, readFile } from 'node:fs/promises';

const base = process.env.COSMIC_TEST_BASE_URL || 'http://127.0.0.1:5175';
const server = process.env.COSMIC_TEST_BASE_URL ? null : spawn(process.execPath,
  ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '5175', '--strictPort'],
  { stdio: ['ignore', 'pipe', 'pipe'] });
let serverOutput = '', browser, count = 0;
server?.stdout.on('data', data => { serverOutput += data; });
server?.stderr.on('data', data => { serverOutput += data; });
const passed = label => console.log(`PASS ${++count}: ${label}`);
const norm = vector => Math.hypot(...vector);
const subtract = (a, b) => a.map((value, index) => value - b[index]);
const body = (state, id) => {
  const found = state.bodies.find(candidate => candidate.id === id);
  assert.ok(found, `Body ${id} exists`);
  return found;
};

try {
  for (let attempt = 0; attempt < 60; attempt++) {
    try { if ((await fetch(base)).ok) break; } catch { /* Vite booting */ }
    if (attempt === 59) throw new Error(`Dev server did not start. ${serverOutput}`);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  await mkdir('test-results', { recursive: true });
  browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 }, acceptDownloads: true });
  page.setDefaultTimeout(90000);
  const errors = [], workers = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('response', response => { if (response.status() >= 400) errors.push(`HTTP ${response.status()} ${response.url()}`); });
  page.on('worker', worker => workers.push(worker.url()));
  const ready = () => page.waitForFunction(() => window.__cosmic && !document.getElementById('cosmic-loading'));
  const snapshot = () => page.evaluate(() => window.__cosmic.snapshot());
  const status = () => page.evaluate(() => window.__cosmic.status());
  const camera = () => page.evaluate(() => window.__cosmic.camera());
  const sample = () => page.evaluate(() => window.__cosmic.sample());
  const settle = async () => {
    await page.evaluate(() => window.__cosmic.settle());
    await page.waitForFunction(() => !window.__cosmic.status().busy);
  };
  const frames = async (amount = 5) => page.evaluate(async amount => {
    for (let index = 0; index < amount; index++) await new Promise(requestAnimationFrame);
  }, amount);
  const pause = async () => {
    if ((await status()).running) await page.locator('#pause').click();
    await settle();
  };
  const preset = async id => {
    await page.locator(`[data-preset="${id}"]`).click();
    await settle();
  };
  const advance = seconds => page.evaluate(seconds => window.__cosmic.advance(seconds), seconds);
  const input = async (id, value, event = 'change') => {
    await page.locator(`#${id}`).evaluate((element, { value, event }) => {
      element.value = String(value);
      element.dispatchEvent(new Event(event, { bubbles: true }));
    }, { value, event });
    await settle();
  };
  const checkbox = async (id, checked) => {
    await page.locator(`#${id}`).setChecked(checked);
    await frames(2);
  };
  const focus = async id => {
    await page.locator(`[data-body="${id}"]`).click();
    await page.locator('#focus-body').click();
    await page.waitForFunction(id => {
      const c = window.__cosmic.camera(), s = window.__cosmic.snapshot();
      const b = s.bodies.find(body => body.id === id);
      return c.focusedId === id && Math.hypot(...c.positionMetres.map((value, i) => value - b.position[i])) < 8e10;
    }, id);
    // The focus transition converges in elapsed real time, including software GPU frames.
    await frames(45);
  };

  await page.goto(`${base}/?test`);
  await ready();
  await pause();
  const initial = await snapshot(), overview = await sample();
  assert.equal(initial.name, 'Solar System');
  assert.equal(initial.bodies.length, 10);
  assert.equal((await status()).worker, true);
  assert.ok(workers.length > 0 && page.workers().length > 0, 'physics runs in a real browser worker');
  assert.ok(overview.nonBlack > 100, 'actual rendered sky and star pixels exist');
  assert.equal(overview.glError, 0);
  assert.ok((await status()).renderer.drawCalls > 10);
  assert.equal(await page.locator('[data-body]').count(), 10);
  passed('Solar System starts with 10 physical bodies, a real Worker and compiled WebGL2 scene');

  const frozen = await snapshot();
  await frames(6);
  assert.deepEqual(await snapshot(), frozen, 'pause freezes the complete physics state');
  await page.locator('#time-speed').selectOption('1');
  const slowStart = (await snapshot()).time;
  await page.locator('#pause').click(); await frames(8); await pause();
  const slow = (await snapshot()).time - slowStart;
  assert.ok(slow > 0, 'resume performs actual integration');
  await page.locator('#time-speed').selectOption('3600');
  const fastStart = (await snapshot()).time;
  await page.locator('#pause').click(); await frames(8); await pause();
  const fast = (await snapshot()).time - fastStart;
  assert.ok(fast > slow * 100, `time speed changes integrated time: ${slow} -> ${fast}`);
  assert.notDeepEqual(body(await snapshot(), 'earth').position, body(frozen, 'earth').position);
  const beforeStep = await snapshot();
  await page.locator('#step').click(); await settle();
  const stepped = await snapshot();
  assert.ok(stepped.time > beforeStep.time && stepped.steps > beforeStep.steps);
  assert.notDeepEqual(body(stepped, 'earth').position, body(beforeStep, 'earth').position);
  await page.locator('#rewind').click(); await settle();
  const rewound = await snapshot();
  assert.ok(rewound.time < stepped.time);
  assert.notDeepEqual(body(rewound, 'earth').position, body(stepped, 'earth').position);
  assert.equal((await status()).running, false);
  await page.locator('#step').click(); await settle();
  const firstStep = await snapshot();
  await page.locator('#step').click(); await settle();
  const secondStep = await snapshot();
  assert.ok(secondStep.time > firstStep.time && firstStep.time > rewound.time);
  await page.locator('#rewind').click(); await settle();
  assert.equal((await snapshot()).time, firstStep.time);
  assert.deepEqual((await snapshot()).bodies, firstStep.bodies);
  await page.locator('#rewind').click(); await settle();
  assert.equal((await snapshot()).time, rewound.time, 'successive rewinds must advance through physical history despite recalculated diagnostics');
  assert.deepEqual((await snapshot()).bodies, rewound.bodies);
  passed('Pause, resume, speed, step and consecutive rewinds change or restore real positions without diagnostic-only history stalls');

  await preset('earthmoon');
  assert.equal((await snapshot()).bodies.length, 2);
  await frames(30);
  assert.ok(await page.evaluate(() => window.__cosmic.snapshot().bodies.every(b => window.__cosmic.screenPosition(b.id)?.visible)),
    'Earth–Moon preset automatically fits both genuine body centers');
  const lunarInitial = await snapshot();
  const lunarJSON = await page.evaluate(() => window.__cosmic.exportJSON());
  await advance(1000);
  const normal = await snapshot();
  const normalAcceleration = norm(subtract(body(normal, 'moon').velocity, body(lunarInitial, 'moon').velocity));
  await page.evaluate(text => window.__cosmic.importJSON(text), lunarJSON);
  await page.locator('[data-body="earth"]').click();
  const changedMass = body(lunarInitial, 'earth').mass * 4;
  await input('mass-slider', Math.log10(changedMass), 'input');
  const heavier = await snapshot();
  // Native range controls quantize to the declared step; the force comparison uses the actual mass.
  assert.ok(Math.abs(body(heavier, 'earth').mass / changedMass - 1) < 0.01);
  assert.ok(Number((await page.locator('#body-gravity').textContent())) > 35);
  await advance(1000);
  const increasedAcceleration = norm(subtract(body(await snapshot(), 'moon').velocity, body(lunarInitial, 'moon').velocity));
  assert.ok(increasedAcceleration > normalAcceleration * 3 && increasedAcceleration < normalAcceleration * 5,
    `mass slider changes gravitational trajectory: Δv ${normalAcceleration} -> ${increasedAcceleration}`);
  passed('Earth–Moon preset integrates its orbit; changing Earth mass changes the Moon’s gravitational acceleration');

  await preset('solar');
  for (let i = 0; i < 10; i++) await advance(86400);
  assert.ok((await snapshot()).time >= 864000 - 1e-6);
  await frames(15);
  await page.screenshot({ path: 'test-results/cosmic-overview.png' });
  await focus('earth');
  const earthImage = await sample();
  assert.ok(earthImage.nonBlack > 1000, 'focused Earth fills actual GPU pixels');
  assert.equal(earthImage.glError, 0);
  assert.equal((await camera()).focusedId, 'earth');
  await page.screenshot({ path: 'test-results/cosmic-earth.png' });
  passed('Overview and focused Earth render actual orbital history, lit procedural surface and atmosphere');

  const beforeOrbit = await camera();
  await page.mouse.move(580, 390); await page.mouse.down();
  await page.mouse.move(710, 430, { steps: 8 }); await page.mouse.up();
  await frames(12);
  const afterOrbit = await camera();
  assert.notDeepEqual(afterOrbit.positionMetres, beforeOrbit.positionMetres);
  const distance = norm(subtract(afterOrbit.positionMetres, afterOrbit.targetMetres));
  await page.mouse.wheel(0, -250); await frames(12);
  const zoomed = await camera();
  assert.ok(norm(subtract(zoomed.positionMetres, zoomed.targetMetres)) < distance);
  await page.locator('#camera-mode').click();
  assert.equal((await camera()).mode, 'fly');
  await page.locator('canvas').focus(); await page.mouse.move(600, 400);
  const beforeFly = await camera();
  await page.keyboard.down('w'); await frames(8); await page.keyboard.up('w');
  assert.notDeepEqual((await camera()).positionMetres, beforeFly.positionMetres);
  const physicalBeforeCameraFit = await snapshot();
  await page.locator('#overview').click(); await frames(3);
  assert.equal((await camera()).mode, 'fly', 'system fit preserves the current camera mode');
  assert.ok(await page.evaluate(() => window.__cosmic.snapshot().bodies.every(b => window.__cosmic.screenPosition(b.id)?.visible)),
    'overview fits all ten real Solar System centers, including outer planets');
  assert.deepEqual(await snapshot(), physicalBeforeCameraFit, 'system framing does not change inertial physics');
  await page.screenshot({ path: 'test-results/cosmic-overview.png' });
  await focus('earth');
  const flyFocused = await camera();
  const physicalEarth = body(physicalBeforeCameraFit, 'earth');
  assert.equal(flyFocused.mode, 'fly', 'focus preserves Fly mode');
  assert.ok(norm(subtract(flyFocused.positionMetres, physicalEarth.position)) < 8e10, 'Fly focus really brings the camera near Earth');
  assert.ok((await sample()).nonBlack > 1000, 'Fly focus exposes actual Earth surface pixels');
  assert.deepEqual(await snapshot(), physicalBeforeCameraFit, 'Fly focus changes no physical body state');
  await page.locator('#camera-mode').click();
  await checkbox('follow', false); assert.equal((await camera()).follow, false);
  await checkbox('follow', true);
  assert.equal((await camera()).mode, 'orbit');
  passed('Orbit, zoom, flight, all-body overview and Fly focus move the real camera while preserving inertial body state');

  await focus('earth');
  const beforeLayers = await sample();
  const trailDrawCalls = (await status()).renderer.drawCalls;
  await checkbox('show-trails', false);
  const noTrails = await sample();
  assert.notEqual(noTrails.signature, beforeLayers.signature, 'recorded physical trails affect actual pixels');
  assert.ok((await status()).renderer.drawCalls < trailDrawCalls, 'turning trails off removes genuine line geometry draw calls');
  await checkbox('show-trails', true);
  await checkbox('show-labels', false);
  assert.equal(await page.locator('[data-testid="body-labels"]').evaluate(element => {
    return [...element.children].filter(label => getComputedStyle(label).display !== 'none').length;
  }), 0);
  await checkbox('show-labels', true);
  const noVectors = (await status()).renderer.drawCalls;
  await checkbox('show-vectors', true); await sample();
  assert.ok((await status()).renderer.drawCalls > noVectors, 'actual vector geometry draws');
  await checkbox('show-vectors', false);
  const physicalBeforeScale = await snapshot();
  await checkbox('true-scale', true); await frames(30);
  assert.equal((await camera()).trueScale, true);
  assert.deepEqual(await snapshot(), physicalBeforeScale, 'true-scale changes display, not physical SI values');
  await checkbox('true-scale', false); await frames(30);
  await page.locator('#quality').selectOption('performance'); await sample();
  const lowTriangles = (await status()).renderer.triangles;
  await page.locator('#quality').selectOption('ultra'); await sample();
  assert.ok((await status()).renderer.triangles > lowTriangles, 'quality changes real mesh geometry');
  await page.locator('#quality').selectOption('balanced');
  passed('Trail, label, vector, true-scale and quality controls affect rendering while preserving physics');

  await page.locator('[data-body="earth"]').click();
  const beforeEdit = body(await snapshot(), 'earth');
  await page.locator('#edit-radius').fill(String(beforeEdit.radius / 1000 * 1.1));
  await page.locator('#edit-radius').press('Tab'); await settle();
  assert.ok(Math.abs(body(await snapshot(), 'earth').radius / beforeEdit.radius - 1.1) < 1e-10);
  const unsafeName = '<img src=x onerror="window.cosmicInjected=true">';
  await page.locator('#edit-name').fill(unsafeName); await page.locator('#edit-name').press('Tab'); await settle();
  assert.equal(body(await snapshot(), 'earth').name, unsafeName);
  assert.equal(await page.locator('#selected-name').textContent(), unsafeName);
  assert.equal(await page.locator('#selected-name img, .body-row-name img').count(), 0);
  assert.equal(await page.evaluate(() => window.cosmicInjected), undefined);
  await page.locator('#body-search').fill('img');
  assert.equal(await page.locator('[data-body]').count(), 1);
  await page.locator('#body-search').fill('');
  assert.equal(await page.locator('[data-body]').count(), 10);
  passed('Radius and name editors update worker-owned state; names render as safe text and body search filters the library');

  await page.locator('#save').click(); await settle();
  const saved = await snapshot();
  await page.locator('#edit-mass').fill('1e25'); await page.locator('#edit-mass').press('Tab'); await settle();
  assert.equal(body(await snapshot(), 'earth').mass, 1e25);
  await page.locator('#load').click(); await settle();
  assert.deepEqual((await snapshot()).bodies, saved.bodies);
  assert.equal((await snapshot()).time, saved.time);
  await page.reload(); await ready(); await pause();
  await page.locator('#load').click(); await settle();
  assert.deepEqual((await snapshot()).bodies, saved.bodies);
  assert.equal((await snapshot()).time, saved.time);
  passed('IndexedDB saves the complete simulation and restores it after edits and a full page reload');

  const downloadPromise = page.waitForEvent('download');
  await page.locator('#export-json').click();
  const download = await downloadPromise;
  assert.equal(download.suggestedFilename(), 'cosmic-sandbox.json');
  const exported = JSON.parse(await readFile(await download.path(), 'utf8'));
  assert.deepEqual(exported.bodies, (await snapshot()).bodies);
  assert.equal(exported.schemaVersion, 1);
  const imported = structuredClone(exported); imported.name = 'Imported browser test';
  await page.locator('#import-file').setInputFiles({ name: 'simulation.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(imported)) });
  await page.waitForFunction(() => window.__cosmic.snapshot().name === 'Imported browser test');
  await settle();
  assert.deepEqual((await snapshot()).bodies, imported.bodies);
  const validState = await snapshot();
  for (const [invalid, expected] of [
    ['{"bodies":', 'JSON không hợp lệ'],
    [JSON.stringify({ ...imported, bodies: imported.bodies.map((b, i) => i ? b : { ...b, mass: -1 }) }), 'Mass'],
    [JSON.stringify({ ...imported, bodies: [imported.bodies[0], imported.bodies[0]] }), 'unique'],
  ]) {
    await page.locator('#import-file').setInputFiles({ name: 'invalid.json', mimeType: 'application/json', buffer: Buffer.from(invalid) });
    await page.waitForFunction(text => document.getElementById('cosmic-toast').textContent.includes(text), expected);
    await settle();
    assert.deepEqual(await snapshot(), validState, 'invalid JSON must not partially mutate the universe');
  }
  passed('JSON download contains complete state; valid imports restore it and malformed, negative-mass or duplicate-ID data cannot corrupt it');

  await preset('binary');
  const binary = await snapshot();
  assert.equal(binary.bodies.length, 2);
  assert.ok(binary.bodies.every(b => b.kind === 'star'));
  await advance(86400);
  const advancedBinary = await snapshot();
  assert.notDeepEqual(body(advancedBinary, 'star-a').position, body(binary, 'star-a').position);
  assert.notDeepEqual(body(advancedBinary, 'star-b').position, body(binary, 'star-b').position);
  assert.ok(Math.abs(advancedBinary.diagnostics.energyDrift) < 1e-3);
  passed('Binary Stars preset moves both stars under their shared gravitational field and monitors energy error');

  await preset('impact');
  const impact = await snapshot();
  assert.equal(impact.bodies.length, 2);
  const mass = impact.bodies.reduce((sum, b) => sum + b.mass, 0);
  const volume = impact.bodies.reduce((sum, b) => sum + b.radius ** 3, 0);
  await advance(16000);
  const collision = await snapshot();
  assert.equal(collision.bodies.length, 1, 'actual worker detects the impact');
  assert.ok(collision.events.length > 0 && collision.events[0].energy > 0);
  assert.ok(Math.abs(collision.bodies[0].mass / mass - 1) < 1e-12);
  assert.ok(Math.abs(collision.bodies[0].radius ** 3 / volume - 1) < 1e-12);
  assert.ok(collision.bodies[0].temperature > impact.bodies[0].temperature);
  assert.equal(await page.locator('[data-body]').count(), 1);
  assert.ok((await status()).renderer.activeBursts > 0, 'new collision creates GPU particle geometry');
  assert.equal((await sample()).glError, 0);
  await page.evaluate(text => window.__cosmic.importJSON(text), JSON.stringify(collision));
  assert.equal((await status()).renderer.activeBursts, 0, 'loading historical collision events must not replay the explosion');
  passed('Giant Impact conserves mass and volume, heats the merger and emits GPU debris; loading its historic log does not replay the explosion');

  await preset('empty');
  assert.equal((await snapshot()).bodies.length, 0);
  assert.equal(await page.locator('#inspector-fields').isHidden(), true);
  assert.equal((await sample()).glError, 0);
  for (const [index, template] of ['sun', 'earth', 'mars', 'jupiter', 'moon', 'asteroid'].entries()) {
    await page.locator('#add-body').click();
    assert.equal(await page.locator('#add-dialog').evaluate(dialog => dialog.open), true);
    await page.locator(`[data-template="${template}"]`).click(); await settle();
    assert.equal((await snapshot()).bodies.length, index + 1);
    assert.equal(await page.locator('#add-dialog').evaluate(dialog => dialog.open), false);
  }
  const built = await snapshot();
  assert.deepEqual(new Set(built.bodies.map(b => b.kind)), new Set(['star', 'planet', 'moon', 'asteroid']));
  await advance(1000);
  const builtAdvanced = await snapshot();
  assert.notDeepEqual(builtAdvanced.bodies.map(b => b.position), built.bodies.map(b => b.position));
  assert.ok(builtAdvanced.bodies.every(b => [...b.position, ...b.velocity].every(Number.isFinite)));
  await page.locator('#delete-body').click(); await settle();
  assert.equal((await snapshot()).bodies.length, 5);
  await page.locator('#reset').click(); await settle();
  assert.equal((await snapshot()).bodies.length, 0, 'reset restores the selected preset’s initial conditions');
  passed('Empty Space and all six add templates create genuine physical bodies; delete and reset work');

  await preset('solar'); await focus('earth');
  await page.locator('#fullscreen').click();
  await page.waitForFunction(() => Boolean(document.fullscreenElement));
  await page.evaluate(() => document.exitFullscreen());
  await page.setViewportSize({ width: 390, height: 844 }); await frames(10);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), 390);
  await page.locator('#toggle-panels').click();
  assert.equal(await page.locator('.cosmic-inspector').isVisible(), true);
  assert.ok(await page.locator('.cosmic-inspector').evaluate(element => element.getBoundingClientRect().right <= innerWidth + 1));
  await page.screenshot({ path: 'test-results/cosmic-mobile.png' });
  await page.locator('#toggle-panels').click();
  assert.equal(await page.locator('.cosmic-inspector').isVisible(), false);
  assert.deepEqual(errors, [], 'no JavaScript, shader, HTTP or framebuffer errors');
  passed('Fullscreen and mobile resize work; the mobile inspector stays within the screen and opens or closes');

  // Release the first software GPU workload before rendering the standalone bundle.
  await page.close();
  const standalone = await browser.newPage({ viewport: { width: 900, height: 700 } });
  standalone.setDefaultTimeout(90000);
  const standaloneErrors = [], requests = [], standaloneWorkers = [];
  standalone.on('pageerror', error => standaloneErrors.push(error.message));
  standalone.on('console', message => { if (message.type() === 'error') standaloneErrors.push(message.text()); });
  standalone.on('request', request => { if (/^https?:/.test(request.url())) requests.push(request.url()); });
  standalone.on('worker', worker => standaloneWorkers.push(worker.url()));
  // Cloud Chromium blocks file://. Run the exact embedded HTML offline in an
  // about:blank document, proving neither modules, worker code nor textures need a server.
  await standalone.goto('about:blank?test');
  await standalone.context().setOffline(true);
  await standalone.setContent(await readFile('dist/index.html', 'utf8'), { waitUntil: 'domcontentloaded' });
  await standalone.waitForFunction(() => window.__cosmic && !document.getElementById('cosmic-loading'));
  await standalone.evaluate(async () => {
    if (window.__cosmic.status().running) document.getElementById('pause').click();
    await window.__cosmic.settle();
  });
  const standaloneInitial = await standalone.evaluate(() => window.__cosmic.snapshot());
  await standalone.evaluate(() => window.__cosmic.advance(10000));
  const standaloneAdvanced = await standalone.evaluate(() => window.__cosmic.snapshot());
  assert.ok(standaloneAdvanced.time > standaloneInitial.time);
  assert.notDeepEqual(body(standaloneAdvanced, 'earth').position, body(standaloneInitial, 'earth').position);
  assert.ok(standaloneWorkers.some(url => url.startsWith('blob:')), 'the bundled physics Worker is a Blob');
  const offlineImage = await standalone.evaluate(() => window.__cosmic.sample());
  assert.ok(offlineImage.nonBlack > 100);
  assert.equal(offlineImage.glError, 0);
  assert.deepEqual(requests, [], 'single HTML makes zero network requests');
  assert.deepEqual(standaloneErrors, [], 'standalone shader and worker compilation succeeds');
  passed('Exact standalone HTML renders and integrates gravity offline using its bundled Blob Worker with zero network requests');
  console.log(`\n${count} Cosmic Sandbox browser checks passed. GPU: Chromium SwiftShader (not an RTX benchmark).`);
} finally {
  await browser?.close();
  server?.kill('SIGTERM');
}
