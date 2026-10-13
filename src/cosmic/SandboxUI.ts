import type { BodyPatch, CelestialBody, SimulationState } from './types.ts';
import { PRESETS, BODY_TEMPLATES } from './presets.ts';
import { AU, G } from './physics/constants.ts';
import { TIME_SPEEDS } from './TimeController.ts';

export interface UICallbacks {
  select(id: string): void;
  focus(id: string): void;
  preset(id: string): void;
  pause(): void;
  step(): void;
  rewind(): void;
  speed(value: number): void;
  add(template: string): void;
  remove(): void;
  edit(patch: BodyPatch): void;
  reset(): void;
  save(): void;
  load(): void;
  export(): void;
  import(text: string): void;
  options(options: Record<string, unknown>): void;
}
const escapeHTML = (text: string) => text.replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]!));
export const scientific = (n: number, digits = 3) => Number.isFinite(n) ? n.toExponential(digits - 1) : '—';
const vectorMagnitude = (v: number[]) => Math.hypot(...v);
const icons: Record<string, string> = {
  play: '<path d="m9 5 11 7-11 7Z"/>', pause: '<path d="M9 5v14M15 5v14"/>',
  add: '<path d="M12 4v16M4 12h16"/>', move: '<path d="M3 12h18M7 8l-4 4 4 4M17 8l4 4-4 4"/>',
  velocity: '<path d="M5 19 19 5M9 5h10v10"/>', reset: '<path d="M4 11a8 8 0 1 1 2 7M4 4v7h7"/>',
  save: '<path d="M5 4h12l3 3v13H4V4Z"/><path d="M8 4v6h8V4M8 20v-6h8v6"/>',
  load: '<path d="M12 17V4m-5 5 5-5 5 5M4 16v4h16v-4"/>',
  export: '<path d="M12 4v13m-5-5 5 5 5-5M4 16v4h16v-4"/>',
  crosshair: '<circle cx="12" cy="12" r="7"/><path d="M12 2v7m0 6v7M2 12h7m6 0h7"/>',
  overview: '<ellipse cx="12" cy="12" rx="10" ry="5" transform="rotate(-25 12 12)"/><circle cx="12" cy="12" r="2"/>',
  panels: '<path d="M4 5h16M4 12h16M4 19h16"/><path d="M8 5v14"/>',
  fullscreen: '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/>',
  rewind: '<path d="M9 5 4 9l5 4M4 9h9a6 6 0 1 1 0 12"/>',
  step: '<path d="m5 5 10 7-10 7ZM19 5v14"/>',
  remove: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 10v7M14 10v7"/>',
};
const icon = (name: string) => `<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name]}</svg>`;
export class SandboxUI {
  readonly host: HTMLElement;
  private root: HTMLElement;
  private selectedId: string | null = null;
  private lastIds = '';
  private lastUpdate = 0;
  private toastTimer = 0;
  private state?: SimulationState;
  constructor(parent: HTMLElement, private callbacks: UICallbacks) {
    parent.innerHTML = `
      <main class="cosmic-shell">
        <div id="universe-view" aria-label="Vũ trụ 3D"></div>
        <header class="cosmic-topbar">
          <a class="cosmic-brand" href="./"><span class="brand-orbit">◉</span><span>COSMIC<span class="brand-subtitle">SANDBOX / UNIVERSE SIMULATOR</span></span></a>
          <div class="scene-heading"><span class="live-indicator"></span><span id="scene-title">Solar System</span><span class="scene-badge">N-BODY</span></div>
          <div class="top-actions"><a href="./blackhole.html" title="Mở phòng quan sát hố đen">Hố đen ↗</a><button id="toggle-panels" title="Ẩn / hiện bảng điều khiển">☷</button><button id="fullscreen" title="Toàn màn hình">⛶</button></div>
        </header>
        <aside class="cosmic-library glass" aria-label="Thư viện mô phỏng">
          <div class="panel-label">PHÒNG THÍ NGHIỆM <span>01</span></div>
          <h1>Khám phá vũ trụ.</h1><p class="subtle">Tạo thay đổi. Quan sát quỹ đạo.</p>
          <div class="section-caption">KỊCH BẢN</div>
          <div class="preset-list">${PRESETS.map((p, i) => `<button class="preset-card ${i === 0 ? 'active' : ''}" data-preset="${escapeHTML(p.id)}" title="${escapeHTML(p.description || '')}"><span class="preset-art preset-art-${i}"><i></i><b></b></span><span>${escapeHTML(p.name)}<small>${escapeHTML(({ solar: '10 thiên thể · Hệ Mặt Trời', earthmoon: 'Quỹ đạo vệ tinh · 2 thiên thể', binary: 'Tâm khối lượng chung', impact: 'Va chạm hợp nhất', empty: 'Tạo hệ của riêng bạn' } as Record<string, string>)[p.id] || 'Mô phỏng hấp dẫn')}</small></span><em>↗</em></button>`).join('')}</div>
          <div class="section-caption bodies-caption">THIÊN THỂ <span id="body-count">0</span></div>
          <input id="body-search" class="body-search" type="search" placeholder="Tìm thiên thể…" aria-label="Tìm thiên thể" />
          <div id="body-list" class="body-list" role="list" aria-label="Danh sách thiên thể"></div>
          <div class="library-footer"><span class="status-dot"></span>Vị trí được tính từ hấp dẫn</div>
        </aside>
        <div class="viewport-actions"><button id="overview" title="Toàn cảnh hệ">◎ Toàn cảnh</button><button id="camera-mode" aria-pressed="false">⌖ Orbit</button><label><input id="follow" type="checkbox" checked /> Theo dõi</label></div>
        <div class="view-caption"><span id="view-subject">SOLAR SYSTEM</span><small>Kéo để xoay · Cuộn để zoom · Nhấp để chọn</small></div>
        <aside class="cosmic-inspector glass" aria-label="Thông số thiên thể">
          <div class="panel-label">ĐỐI TƯỢNG ĐÃ CHỌN <span id="body-kind">PLANET</span></div>
          <div class="inspector-heading"><span id="body-preview" class="body-preview"></span><div><h2 id="selected-name">Earth</h2><span id="selected-description" class="subtle">Hành tinh</span></div><button id="focus-body" title="Đưa camera đến thiên thể">⌖</button></div>
          <div class="inspector-tabs"><span class="active">Thông số</span><span>Vật lý SI</span></div>
          <div id="inspector-fields">
            <label class="property-field">Tên<input id="edit-name" maxlength="64" /></label>
            <label class="property-field">Khối lượng <span>kg</span><input id="edit-mass" type="number" min="1" max="1e35" step="any" /></label>
            <input id="mass-slider" type="range" min="10" max="32" step="0.002" aria-label="Điều chỉnh khối lượng" />
            <label class="property-field">Bán kính <span>km</span><input id="edit-radius" type="number" min="0.001" max="1e10" step="any" /></label>
            <input id="radius-slider" type="range" min="-1" max="7" step="0.002" aria-label="Điều chỉnh bán kính" />
            <div class="derived-grid"><div>Mật độ<b id="body-density">—</b><small>kg/m³</small></div><div>Trọng lực<b id="body-gravity">—</b><small>m/s²</small></div></div>
            <label class="property-field">Nhiệt độ <span>K</span><input id="edit-temperature" type="number" min="0" max="1e9" step="any" /></label>
            <div class="derived-grid"><div>Tốc độ<b id="body-speed">—</b><small>km/s</small></div><div>Khoảng cách tâm<b id="body-distance">—</b><small>AU</small></div></div>
            <details><summary>Vị trí & vận tốc <span>↗</span></summary><p class="subtle">Tọa độ tuyệt đối · hệ quán tính</p><div class="vector-heading"><span></span><span>x</span><span>y</span><span>z</span></div><div class="vector-inputs"><label>AU</label>${[0, 1, 2].map(i => `<input id="position-${i}" type="number" step="any" aria-label="Vị trí ${['x', 'y', 'z'][i]} AU" />`).join('')}</div><div class="vector-inputs"><label>km/s</label>${[0, 1, 2].map(i => `<input id="velocity-${i}" type="number" step="any" aria-label="Vận tốc ${['x', 'y', 'z'][i]} km/s" />`).join('')}</div><button id="stop-body" class="wide-button">Đặt vận tốc bằng 0</button></details>
            <details><summary>Quay & thành phần <span>↗</span></summary><label class="property-field">Chu kỳ quay <span>giờ</span><input id="edit-rotation" type="number" step="any" /></label><label class="property-field">Nghiêng trục <span>°</span><input id="edit-tilt" type="number" min="0" max="180" step="any" /></label><p id="body-composition" class="subtle"></p></details>
          </div>
          <button id="delete-body" class="delete-button">⌫ Xóa thiên thể</button>
        </aside>
        <aside class="diagnostics glass" aria-label="Kiểm tra vật lý"><div class="diag-heading"><span class="status-dot"></span><b>PHYSICS MONITOR</b><span id="fps">— FPS</span></div><div><span>ΔE / |E₀|</span><strong id="energy-drift">—</strong></div><div><span>Bước tích phân</span><strong id="physics-step">—</strong></div><div><span>Động lượng tổng</span><strong id="momentum">—</strong></div><p id="physics-status">Velocity Verlet · Web Worker</p></aside>
        <div class="layer-controls glass"><label><input id="show-trails" type="checkbox" checked /> Vệt quỹ đạo</label><label><input id="show-labels" type="checkbox" checked /> Tên</label><label><input id="show-vectors" type="checkbox" /> Vector</label><label title="Khi tắt, chỉ kích thước hiển thị thiên thể được phóng đại để dễ quan sát"><input id="true-scale" type="checkbox" /> Kích thước thật</label><select id="quality" aria-label="Chất lượng đồ họa"><option value="performance">Performance</option><option value="balanced" selected>Balanced</option><option value="ultra">Ultra</option></select></div>
        <footer class="cosmic-toolbar glass"><div class="time-controls"><button id="pause" class="play-button" title="Tạm dừng / tiếp tục (Space)">Ⅱ</button><button id="rewind" title="Khôi phục snapshot trước">↶</button><button id="step" title="Tiến một bước mô phỏng">▸|</button><div class="time-readout"><b id="elapsed-time">0 ngày</b><small>THỜI GIAN MÔ PHỎNG</small></div><select id="time-speed" aria-label="Tốc độ thời gian">${TIME_SPEEDS.map(s => `<option value="${s.value}" ${s.value === 86400 ? 'selected' : ''}>${s.label}</option>`).join('')}</select></div><div class="tool-divider"></div><div class="sandbox-tools"><button id="add-body"><b>＋</b><span>Thêm</span></button><button id="edit-position"><b>↔</b><span>Di chuyển</span></button><button id="edit-velocity"><b>↗</b><span>Vận tốc</span></button><button id="reset"><b>⟳</b><span>Reset</span></button><button id="save"><b>▣</b><span>Lưu</span></button><button id="load"><b>⇧</b><span>Tải</span></button><button id="export-json"><b>⇩</b><span>JSON</span></button><button id="import-json"><b>⇧</b><span>Nhập</span></button></div></footer>
        <dialog id="add-dialog"><div class="dialog-heading"><div><div class="panel-label">THƯ VIỆN THIÊN THỂ</div><h2>Thêm vào vũ trụ</h2></div><button id="close-add" aria-label="Đóng">×</button></div><p class="subtle">Thiên thể mới bắt đầu trên quỹ đạo tròn quanh vật thể nặng nhất, rồi chuyển động theo hấp dẫn N-body.</p><div class="template-grid">${BODY_TEMPLATES.map((t, i) => `<button data-template="${escapeHTML(t.id)}"><span class="template-sphere template-${i}"></span><b>${escapeHTML(t.name)}</b></button>`).join('')}</div></dialog>
        <input id="import-file" type="file" accept=".json,application/json" hidden />
        <div id="cosmic-toast" role="status" hidden></div><div id="cosmic-loading"><span class="loading-orbit"></span><h2>Khởi tạo vũ trụ</h2><p>Thiết lập thiên thể và physics worker…</p></div>
      </main>`;
    this.root = parent;
    this.host = this.el('universe-view');
    for (const [id, name] of [['add-body', 'add'], ['edit-position', 'move'], ['edit-velocity', 'velocity'], ['reset', 'reset'], ['save', 'save'], ['load', 'load'], ['export-json', 'export'], ['import-json', 'load']]) this.el(id).querySelector('b')!.innerHTML = icon(name);
    for (const [id, name] of [['pause', 'pause'], ['rewind', 'rewind'], ['step', 'step'], ['toggle-panels', 'panels'], ['fullscreen', 'fullscreen'], ['focus-body', 'crosshair']]) this.el(id).innerHTML = icon(name);
    this.el('overview').innerHTML = `${icon('overview')} Toàn cảnh`;
    this.el('camera-mode').innerHTML = `${icon('crosshair')} Orbit`;
    this.el('delete-body').innerHTML = `${icon('remove')} Xóa thiên thể`;
    this.root.querySelectorAll('.preset-card em').forEach(el => { el.innerHTML = icon('velocity'); });
    this.bind();
  }
  private el(id: string): HTMLElement { return this.root.querySelector(`#${id}`)!; }
  private input(id: string): HTMLInputElement { return this.el(id) as HTMLInputElement; }
  private bind() {
    const c = this.callbacks;
    this.root.querySelectorAll<HTMLButtonElement>('[data-preset]').forEach(btn => btn.onclick = () => { c.preset(btn.dataset.preset!); });
    this.root.querySelectorAll<HTMLButtonElement>('[data-template]').forEach(btn => btn.onclick = () => { (this.el('add-dialog') as HTMLDialogElement).close(); c.add(btn.dataset.template!); });
    this.el('pause').onclick = c.pause;
    this.el('step').onclick = c.step;
    this.el('rewind').onclick = c.rewind;
    this.el('reset').onclick = c.reset;
    this.el('save').onclick = c.save;
    this.el('load').onclick = c.load;
    this.el('export-json').onclick = c.export;
    this.el('delete-body').onclick = c.remove;
    this.el('focus-body').onclick = () => { if (this.selectedId) c.focus(this.selectedId); };
    this.el('overview').onclick = () => c.options({ overview: true });
    this.el('toggle-panels').onclick = () => this.root.classList.toggle('panels-hidden');
    this.el('fullscreen').onclick = () => { if (document.fullscreenElement) void document.exitFullscreen(); else void document.documentElement.requestFullscreen().catch(() => this.toast('Trình duyệt chưa cho phép toàn màn hình.')); };
    this.el('add-body').onclick = () => (this.el('add-dialog') as HTMLDialogElement).showModal();
    this.el('close-add').onclick = () => (this.el('add-dialog') as HTMLDialogElement).close();
    this.el('time-speed').onchange = () => c.speed(Number((this.el('time-speed') as HTMLSelectElement).value));
    this.el('body-search').oninput = () => this.updateList();
    this.el('camera-mode').onclick = () => { const fly = this.el('camera-mode').getAttribute('aria-pressed') !== 'true'; this.el('camera-mode').setAttribute('aria-pressed', String(fly)); this.el('camera-mode').innerHTML = `${icon('crosshair')} ${fly ? 'Fly · WASD/QE' : 'Orbit'}`; c.options({ cameraMode: fly ? 'fly' : 'orbit' }); };
    for (const [id, option] of [['show-trails', 'trails'], ['show-labels', 'labels'], ['show-vectors', 'vectors'], ['true-scale', 'trueScale'], ['follow', 'follow']]) {
      this.input(id).onchange = () => c.options({ [option]: this.input(id).checked });
    }
    this.el('quality').onchange = () => c.options({ quality: (this.el('quality') as HTMLSelectElement).value });
    this.el('import-json').onclick = () => this.input('import-file').click();
    this.input('import-file').onchange = async () => {
      const file = this.input('import-file').files?.[0];
      if (file) { if (file.size > 2_000_000) this.toast('Tệp JSON quá lớn (tối đa 2 MB).'); else c.import(await file.text()); }
      this.input('import-file').value = '';
    };
    for (const [id, property, factor] of [['edit-mass', 'mass', 1], ['edit-radius', 'radius', 1000], ['edit-temperature', 'temperature', 1], ['edit-rotation', 'rotationPeriod', 3600], ['edit-tilt', 'axialTilt', 1]] as const) {
      this.input(id).onchange = () => { const input = this.input(id); if (!input.checkValidity() || !Number.isFinite(Number(input.value))) { this.toast('Hãy nhập giá trị hữu hạn trong khoảng cho phép.'); return; } c.edit({ [property]: Number(input.value) * factor }); };
    }
    this.input('edit-name').onchange = () => c.edit({ name: this.input('edit-name').value.trim() });
    this.input('mass-slider').oninput = () => c.edit({ mass: 10 ** Number(this.input('mass-slider').value) });
    this.input('radius-slider').oninput = () => c.edit({ radius: 1000 * 10 ** Number(this.input('radius-slider').value) });
    for (const property of ['position', 'velocity'] as const) {
      for (let i = 0; i < 3; i++) this.input(`${property}-${i}`).onchange = () => {
        const value = [0, 1, 2].map(j => Number(this.input(`${property}-${j}`).value));
        if (!value.every(Number.isFinite)) return this.toast('Tọa độ phải là số hữu hạn.');
        c.edit({ [property]: value.map(v => v * (property === 'position' ? AU : 1000)) });
      };
    }
    this.el('stop-body').onclick = () => c.edit({ velocity: [0, 0, 0] });
    for (const [btn, field] of [['edit-position', 'position-0'], ['edit-velocity', 'velocity-0']]) this.el(btn).onclick = () => {
      const input = this.input(field); (input.closest('details') as HTMLDetailsElement).open = true; input.focus(); input.select();
    };
    document.addEventListener('keydown', event => {
      if (event.code === 'Space' && !(event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement || event.target instanceof HTMLTextAreaElement) && !(this.el('add-dialog') as HTMLDialogElement).open) { event.preventDefault(); c.pause(); }
    });
  }
  private updateList() {
    if (!this.state) return;
    const q = this.input('body-search').value.toLowerCase();
    const list = this.el('body-list');
    list.replaceChildren();
    for (const b of this.state.bodies.filter(b => b.name.toLowerCase().includes(q))) {
      const btn = document.createElement('button');
      btn.className = `body-row ${b.id === this.selectedId ? 'selected' : ''}`;
      btn.dataset.body = b.id;
      btn.innerHTML = `<span class="body-dot"></span><span class="body-row-name"></span><small>${b.kind === 'star' ? 'STAR' : b.kind === 'moon' ? 'MOON' : b.kind === 'asteroid' ? 'ROCK' : 'PLANET'}</small>`;
      btn.querySelector<HTMLElement>('.body-dot')!.style.backgroundColor = b.color;
      btn.querySelector<HTMLElement>('.body-row-name')!.textContent = b.name;
      btn.onclick = () => this.callbacks.select(b.id);
      btn.ondblclick = () => this.callbacks.focus(b.id);
      list.append(btn);
    }
  }
  update(state: SimulationState, selectedId: string | null, running: boolean, force = false) {
    this.state = state;
    const changed = this.selectedId !== selectedId;
    this.selectedId = selectedId;
    const ids = state.bodies.map(b => `${b.id}:${b.name}`).join('|');
    if (changed || ids !== this.lastIds || force) { this.lastIds = ids; this.updateList(); }
    this.el('scene-title').textContent = state.name;
    this.el('body-count').textContent = String(state.bodies.length);
    this.el('pause').innerHTML = icon(running ? 'pause' : 'play');
    this.el('pause').setAttribute('aria-label', running ? 'Tạm dừng' : 'Tiếp tục');
    const days = state.time / 86400;
    this.el('elapsed-time').textContent = days >= 365.25 ? `${(days / 365.25).toFixed(2)} năm` : days >= 1 ? `${days.toFixed(2)} ngày` : `${(state.time / 3600).toFixed(2)} giờ`;
    this.el('energy-drift').textContent = scientific(state.diagnostics.energyDrift, 2);
    this.el('physics-step').textContent = state.diagnostics.minStep > 0 ? `${state.diagnostics.minStep.toFixed(1)} s` : 'Chưa tích phân';
    this.el('momentum').textContent = `${scientific(vectorMagnitude(state.diagnostics.momentum), 2)} kg·m/s`;
    this.el('physics-status').textContent = state.diagnostics.limited ? 'Giới hạn tốc độ để giữ ổn định vật lý' : 'Velocity Verlet · Web Worker';
    this.el('physics-status').classList.toggle('limited', state.diagnostics.limited);
    const b = state.bodies.find(b => b.id === selectedId);
    this.el('inspector-fields').hidden = !b;
    this.el('delete-body').hidden = !b;
    this.el('focus-body').hidden = !b;
    this.el('selected-name').textContent = b?.name || 'Chọn thiên thể';
    if (!b) return;
    if (!changed && !force && performance.now() - this.lastUpdate < 200) return;
    this.lastUpdate = performance.now();
    this.el('body-kind').textContent = b.kind.toUpperCase();
    this.el('view-subject').textContent = state.name.toUpperCase();
    this.el('selected-description').textContent = `${b.kind === 'star' ? 'Ngôi sao' : b.kind === 'moon' ? 'Vệ tinh' : b.kind === 'asteroid' ? 'Tiểu hành tinh' : 'Hành tinh'} · ${b.surface}`;
    this.el('body-preview').style.background = `radial-gradient(circle at 30% 28%, #ffffff80, ${b.color} 38%, #040911 90%)`;
    this.el('body-preview').style.boxShadow = b.kind === 'star' ? `0 0 25px ${b.color}55` : 'none';
    const set = (id: string, value: string) => { const input = this.input(id); if (input !== document.activeElement) input.value = value; };
    set('edit-name', b.name);
    set('edit-mass', scientific(b.mass, 6)); set('mass-slider', String(Math.log10(b.mass)));
    set('edit-radius', String(Number((b.radius / 1000).toPrecision(6)))); set('radius-slider', String(Math.log10(b.radius / 1000)));
    set('edit-temperature', String(Number(b.temperature.toPrecision(5))));
    set('edit-rotation', String(Number((b.rotationPeriod / 3600).toPrecision(5)))); set('edit-tilt', String(b.axialTilt));
    this.el('body-density').textContent = (b.mass / ((4 / 3) * Math.PI * b.radius ** 3)).toLocaleString('en-US', { maximumFractionDigits: 1 });
    this.el('body-gravity').textContent = (G * b.mass / b.radius ** 2).toFixed(2);
    this.el('body-speed').textContent = (vectorMagnitude(b.velocity) / 1000).toFixed(2);
    this.el('body-distance').textContent = (vectorMagnitude(b.position) / AU).toFixed(4);
    this.el('body-composition').textContent = b.composition;
    for (let i = 0; i < 3; i++) { set(`position-${i}`, String(Number((b.position[i] / AU).toPrecision(7)))); set(`velocity-${i}`, String(Number((b.velocity[i] / 1000).toPrecision(7)))); }
  }
  setPreset(id: string) { this.root.querySelectorAll<HTMLElement>('[data-preset]').forEach(btn => btn.classList.toggle('active', btn.dataset.preset === id)); }
  setSpeed(value: number) { (this.el('time-speed') as HTMLSelectElement).value = String(value); }
  setFPS(value: number) { this.el('fps').textContent = `${Math.round(value)} FPS`; }
  ready() { this.el('cosmic-loading').remove(); }
  toast(message: string, persistent = false) {
    const toast = this.el('cosmic-toast'); toast.textContent = message; toast.hidden = false;
    window.clearTimeout(this.toastTimer);
    if (!persistent) this.toastTimer = window.setTimeout(() => { toast.hidden = true; }, 6000);
  }
}
