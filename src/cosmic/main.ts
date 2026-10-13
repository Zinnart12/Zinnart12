import './style.css';
import type { BodyPatch, SimulationState, Vec3 } from './types.ts';
import { createSolarSystem, PRESETS, BODY_TEMPLATES } from './presets.ts';
import { AU, G } from './physics/constants.ts';
import { WorkerClient } from './WorkerClient.ts';
import { SaveLoadManager } from './SaveLoadManager.ts';
import { TimeController } from './TimeController.ts';
import { SandboxUI } from './SandboxUI.ts';
import { UniverseRenderer } from './rendering/UniverseRenderer.ts';

declare global {
  interface Window {
    __COSMIC_WORKER_SOURCE__?: string;
    __cosmic?: {
      snapshot(): SimulationState;
      status(): { running: boolean; speed: number; busy: boolean; worker: boolean; renderer: ReturnType<UniverseRenderer['getInfo']> };
      settle(): Promise<void>;
      advance(seconds: number): Promise<void>;
      importJSON(text: string): Promise<void>;
      exportJSON(): string;
      camera(): ReturnType<UniverseRenderer['getCameraState']>;
      screenPosition(id: string): ReturnType<UniverseRenderer['getBodyScreenPosition']>;
      sample(): { nonBlack: number; signature: number; glError: number };
    };
  }
}

const time = new TimeController();
const storage = new SaveLoadManager();
let state = createSolarSystem();
let initialState = structuredClone(state);
let selectedId: string | null = 'earth';
let renderer: UniverseRenderer;
let client: WorkerClient;
let queue = Promise.resolve();
let pendingCommands = 0;
let advancePending = false;
let ready = false;
let lastCheckpoint = 0;
let lastEvent = 0;
let lastFrame = performance.now();

function fail(error: unknown) {
  time.running = false;
  time.discardPending();
  ui.toast(error instanceof Error ? error.message : String(error), true);
  ui.update(state, selectedId, false, true);
}
function accept(next: SimulationState, force = false) {
  state = next;
  if (!state.bodies.some(body => body.id === selectedId)) selectedId = state.bodies[0]?.id ?? null;
  renderer.update(state, selectedId);
  ui.update(state, selectedId, time.running, force);
  const event = state.events.at(-1);
  if (event && event.id > lastEvent) {
    lastEvent = event.id;
    ui.toast(`${event.names.join(' + ')}: hợp nhất khi tiếp xúc · E va chạm ${event.energy.toExponential(2)} J`);
  }
  if (performance.now() - lastCheckpoint > 1000) { time.checkpoint(state); lastCheckpoint = performance.now(); }
}
function run(operation: () => Promise<void>): Promise<void> {
  pendingCommands++;
  const next = queue.then(operation).catch(fail).finally(() => { pendingCommands--; });
  queue = next;
  return next;
}
function select(id: string) {
  if (!state.bodies.some(body => body.id === id)) return;
  selectedId = id;
  renderer.update(state, selectedId);
  ui.update(state, selectedId, time.running, true);
}
function checkpoint() { time.checkpoint(state); lastCheckpoint = performance.now(); }
async function loadState(next: SimulationState, resetInitial = true) {
  time.discardPending();
  lastEvent = next.events.at(-1)?.id || 0;
  selectedId = next.bodies.find(b => b.id === 'earth')?.id ?? next.bodies[0]?.id ?? null;
  const loaded = await client.request({ type: 'load', state: next });
  if (resetInitial) initialState = structuredClone(loaded);
  time.clear(loaded);
  renderer.resetHistory();
  accept(loaded, true);
  renderer.resetCamera();
  time.discardPending();
}
function pause() {
  time.running = !time.running;
  time.discardPending();
  ui.update(state, selectedId, time.running, true);
  if (!time.running) void run(async () => { checkpoint(); });
}
function edit(patch: BodyPatch) {
  const id = selectedId;
  if (!id) return;
  void run(async () => {
    checkpoint();
    accept(await client.request({ type: 'edit', id, patch }), true);
    checkpoint();
  });
}

const ui = new SandboxUI(document.querySelector<HTMLElement>('#app')!, {
  select,
  focus: id => { select(id); renderer.focus(id); },
  preset: id => {
    const preset = PRESETS.find(p => p.id === id);
    if (preset) void run(async () => { await loadState(preset.create()); ui.setPreset(id); });
  },
  pause,
  step: () => {
    time.running = false;
    time.discardPending();
    void run(async () => { checkpoint(); accept(await client.request({ type: 'advance', seconds: Math.min(time.speed, 86400), maxSteps: 512 }), true); checkpoint(); });
  },
  rewind: () => {
    time.running = false;
    time.discardPending();
    void run(async () => {
      checkpoint();
      const previous = time.rewind();
      if (!previous) { ui.toast('Chưa có snapshot trước. Hãy tiến mô phỏng rồi tua lại.'); ui.update(state, selectedId, false, true); return; }
      lastEvent = previous.events.at(-1)?.id || 0;
      accept(await client.request({ type: 'load', state: previous }), true);
      lastCheckpoint = performance.now();
    });
  },
  speed: value => { if (Number.isFinite(value) && value > 0) { time.speed = value; time.discardPending(); } },
  add: templateId => void run(async () => {
    const template = BODY_TEMPLATES.find(t => t.id === templateId);
    if (!template) return;
    const body = template.create();
    const parent = state.bodies.reduce<(typeof body) | null>((heaviest, b) => !heaviest || b.mass > heaviest.mass ? b : heaviest, null);
    if (parent) {
      // A Kepler starting velocity is an initial condition; all later positions are N-body solutions.
      const existing = state.bodies.filter(b => b.id !== parent.id).map(b => Math.hypot(...b.position.map((p, i) => p - parent.position[i])));
      const distance = Math.max(parent.radius * 8 + body.radius * 4, parent.kind === 'star' ? (0.5 + state.bodies.length * 0.23) * AU : parent.radius * 35);
      let orbitRadius = distance;
      while (existing.some(r => Math.abs(r - orbitRadius) < Math.max(body.radius * 5, orbitRadius * 0.02))) orbitRadius *= 1.13;
      const phase = state.bodies.length * 2.399963;
      const speed = Math.sqrt(G * (parent.mass + body.mass) / orbitRadius);
      body.position = [parent.position[0] + orbitRadius * Math.cos(phase), parent.position[1], parent.position[2] + orbitRadius * Math.sin(phase)];
      body.velocity = [parent.velocity[0] - speed * Math.sin(phase), parent.velocity[1], parent.velocity[2] + speed * Math.cos(phase)];
    }
    checkpoint();
    const added = await client.request({ type: 'add', body });
    selectedId = body.id;
    accept(added, true); checkpoint();
    renderer.focus(body.id);
    ui.toast(`Đã thêm ${body.name}. Khối lượng mới tác động đến toàn hệ.`);
  }),
  remove: () => { const id = selectedId; if (id) void run(async () => { checkpoint(); accept(await client.request({ type: 'remove', id }), true); checkpoint(); }); },
  edit,
  reset: () => void run(async () => { await loadState(structuredClone(initialState), false); ui.toast('Đã khôi phục điều kiện ban đầu.'); }),
  save: () => void run(async () => { await storage.save(state); ui.toast('Đã lưu mô phỏng trong trình duyệt. Xuất JSON để mang sang máy khác.'); }),
  load: () => void run(async () => { const saved = await storage.load(); if (saved) { time.running = false; await loadState(saved); ui.setPreset(''); ui.toast('Đã tải trạng thái đã lưu.'); } else ui.toast('Chưa có bản lưu trong trình duyệt này.'); }),
  export: () => void run(async () => {
    const url = URL.createObjectURL(new Blob([storage.exportJSON(state)], { type: 'application/json' }));
    const link = document.createElement('a'); link.href = url; link.download = 'cosmic-sandbox.json'; link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    ui.toast('Đã xuất trạng thái mô phỏng sang JSON.');
  }),
  import: text => void run(async () => { const imported = storage.importJSON(text); time.running = false; await loadState(imported); ui.setPreset(''); ui.toast('Đã nhập mô phỏng từ JSON.'); }),
  options: options => {
    if (options.overview) renderer.fitSystem();
    else renderer.setOptions(options);
    if ('trueScale' in options) ui.toast(options.trueScale ? 'Kích thước thiên thể đúng tỉ lệ. Focus để nhìn các hành tinh nhỏ.' : 'Phóng đại kích thước hiển thị. Khoảng cách và vật lý giữ đơn vị thật.');
  },
});

async function start() {
  renderer = new UniverseRenderer(ui.host, select);
  let blobURL: string | null = null;
  const worker = window.__COSMIC_WORKER_SOURCE__
    ? (() => { blobURL = URL.createObjectURL(new Blob([window.__COSMIC_WORKER_SOURCE__!], { type: 'text/javascript' })); return new Worker(blobURL); })()
    : new Worker(new URL('./physics/worker.ts', import.meta.url), { type: 'module' });
  client = new WorkerClient(worker);
  accept(await client.request({ type: 'load', state }), true);
  if (blobURL) URL.revokeObjectURL(blobURL);
  time.clear(state);
  initialState = structuredClone(state);
  renderer.resetCamera();
  ui.ready(); ready = true;
  const test = new URLSearchParams(location.search).has('test');
  if (test) window.__cosmic = {
    snapshot: () => structuredClone(state),
    status: () => ({ running: time.running, speed: time.speed, busy: advancePending || pendingCommands > 0, worker: !!client, renderer: renderer.getInfo() }),
    settle: async () => { await queue; },
    advance: seconds => { time.running = false; time.discardPending(); return run(async () => { checkpoint(); accept(await client.request({ type: 'advance', seconds, maxSteps: 4096 }), true); checkpoint(); }); },
    importJSON: text => run(async () => { const imported = storage.importJSON(text); time.running = false; await loadState(imported); }),
    exportJSON: () => storage.exportJSON(state),
    camera: () => renderer.getCameraState(),
    screenPosition: id => renderer.getBodyScreenPosition(id),
    sample: () => {
      const canvas = ui.host.querySelector('canvas')!;
      renderer.render(0);
      const gl = canvas.getContext('webgl2')!;
      const width = Math.min(canvas.width, 128), height = Math.min(canvas.height, 128);
      const pixels = new Uint8Array(width * height * 4);
      gl.readPixels(Math.floor((canvas.width - width) / 2), Math.floor((canvas.height - height) / 2), width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
      let nonBlack = 0, signature = 0;
      for (let i = 0; i < pixels.length; i += 4) { if (pixels[i] + pixels[i + 1] + pixels[i + 2] > 24) nonBlack++; signature = (signature + pixels[i] * ((i % 151) + 1) + pixels[i + 1] * 3 + pixels[i + 2] * 7) >>> 0; }
      return { nonBlack, signature, glError: gl.getError() };
    },
  };
  lastFrame = performance.now();
  requestAnimationFrame(frame);
}

function frame(now: number) {
  if (!ready) return;
  const delta = Math.max(0, (now - lastFrame) / 1000);
  lastFrame = now;
  if (!document.hidden && time.running) {
    // Accumulate elapsed foreground time even while the worker is occupied.
    // Render FPS therefore does not determine the requested physical timeline.
    time.accumulate(delta);
    if (!advancePending && pendingCommands === 0) {
      const seconds = time.takeSeconds();
      if (seconds > 0) {
        advancePending = true;
        void run(async () => {
          const next = await client.request({ type: 'advance', seconds, maxSteps: 512 });
          if (next.diagnostics.limited) time.discardPending();
          accept(next);
        }).finally(() => { advancePending = false; });
      }
    }
  }
  renderer.render(delta);
  ui.setFPS(renderer.getInfo().fps);
  requestAnimationFrame(frame);
}
document.addEventListener('visibilitychange', () => { lastFrame = performance.now(); time.discardPending(); });
window.addEventListener('pageshow', () => { lastFrame = performance.now(); });
window.addEventListener('pagehide', event => { if (!event.persisted) { client?.dispose(); renderer?.dispose(); ready = false; } });
void start().catch(error => { ui.ready(); fail(error); });
