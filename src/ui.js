import { DEFAULTS, QUALITY_NAMES, RS_PER_MILLION_KM, schwarzschildRadius, tidalAssessment } from './physics.js';

const icons = {
  pause: '<path d="M8 5v14M16 5v14"/>',
  play: '<path d="m9 5 11 7-11 7z"/>',
  reset: '<path d="M3 10a9 9 0 1 1 2 8M3 4v6h6"/>',
  camera: '<rect x="3" y="6" width="18" height="14" rx="3"/><path d="m8 6 2-3h4l2 3"/><circle cx="12" cy="13" r="3"/>',
  fullscreen: '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/>',
  orbit: '<circle cx="12" cy="12" r="3"/><ellipse cx="12" cy="12" rx="10" ry="5" transform="rotate(-30 12 12)"/>',
  fly: '<path d="m3 10 18-7-7 18-3-8-8-3Zm8 3 10-10"/>',
  chevron: '<path d="m9 5 7 7-7 7"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 4 2l-1.5 1v2m0 3h.01"/>',
  settings: '<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="15" cy="17" r="3"/>',
};
export const icon = name => `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${icons[name] || ''}</svg>`;

const ranges = [
  ['mass', 'Black hole mass', 'Khối lượng', 0.5, 12, 0.1],
  ['spin', 'Spin', 'Quay xấp xỉ · không phải Kerr', 0, 0.98, 0.01],
  ['tilt', 'Disk inclination', 'Góc nghiêng đĩa', -80, 80, 1],
  ['temperature', 'Accretion temperature', 'Nhiệt độ đỉnh của profile đĩa zero-torque', 2000, 25000, 100],
  ['density', 'Disk density', 'Mật độ quang học', 0.1, 3, 0.05],
  ['brightness', 'Disk brightness', 'Cường độ phát xạ', 0.1, 4, 0.05],
  ['speed', 'Simulation speed', 'Thời gian chuyển động khí', 0.05, 5, 0.05],
];

function range(key, label, hint, min, max, step, value = DEFAULTS[key]) {
  return `<div class="range-control"><div class="range-label"><label for="${key}" title="${hint}">${label}</label><output id="${key}-value" for="${key}"></output></div><input id="${key}" data-param="${key}" type="range" min="${min}" max="${max}" step="${step}" value="${value}" aria-label="${label}" /></div>`;
}
function toggle(key, label, description = '') {
  return `<label class="toggle-row" for="${key}"><span>${label}${description ? `<small>${description}</small>` : ''}</span><input id="${key}" data-toggle="${key}" type="checkbox" ${DEFAULTS[key] ? 'checked' : ''}/><span class="switch" aria-hidden="true"></span></label>`;
}

export function createUI(state, actions) {
  document.querySelector('#app').innerHTML = `
    <main class="observatory">
      <div id="viewport" aria-label="Mô phỏng hố đen 3D — kéo để xoay, cuộn để zoom">
        <div id="loading"><span class="loading-ring"></span><strong>Tracing the light.</strong><small>Khởi tạo mô phỏng WebGL2…</small></div>
      </div>
      <header class="topbar">
        <a class="brand" href="#" aria-label="Event Horizon Observatory"><svg viewBox="0 0 40 40" fill="none" aria-hidden="true"><circle cx="20" cy="20" r="10" stroke="currentColor"/><ellipse cx="20" cy="20" rx="18" ry="5" transform="rotate(-25 20 20)" stroke="currentColor"/><circle cx="20" cy="20" r="4" fill="currentColor"/></svg><span>EVENT HORIZON<small>BLACK HOLE OBSERVATORY</small></span></a>
        <nav class="mode-tabs" aria-label="Simulation mode"><button data-mode="scientific" class="active" aria-pressed="true">Scientific</button><button data-mode="cinematic" aria-pressed="false">Cinematic</button><button data-mode="performance" aria-pressed="false">Performance</button></nav>
        <div class="topbar-right"><span class="live-dot"></span><span>LIVE SIMULATION</span><button id="help" class="icon-button" title="Hướng dẫn điều khiển" aria-label="Hướng dẫn điều khiển">${icon('help')}</button><button id="panel-toggle" class="icon-button mobile-only" title="Bảng điều khiển" aria-label="Bảng điều khiển">${icon('settings')}</button></div>
      </header>

      <div class="scene-heading"><div class="eyebrow"><span class="tiny-line"></span> DEEP SPACE / 001</div><h1>Sagittarius A<span>*</span></h1><p>The quiet center of everything.</p></div>
      <div class="scene-badge"><span class="live-dot"></span><span id="model-label">SCHWARZSCHILD NULL GEODESICS</span></div>
      <div class="view-presets" aria-label="Camera presets"><button data-view="edge" class="selected" title="Nhìn ngang đĩa">EDGE</button><button data-view="top" title="Nhìn từ trên">TOP</button><button data-view="bottom" title="Nhìn từ dưới">BELOW</button></div>

      <div class="scene-readout"><div><span>EVENT HORIZON</span><strong id="horizon-readout">12.70 <small>million km</small></strong></div><div><span>PHOTON SPHERE</span><strong>1.50 <small>Rₛ</small></strong></div><div><span>OBSERVER DISTANCE</span><strong id="distance-readout">34.0 <small>Rₛ</small></strong></div></div>
      <div class="scene-axis" title="World-space camera orientation"><svg viewBox="0 0 72 72"><path d="M30 42 61 51M30 42 30 10M30 42 10 56"/><text x="62" y="56">X</text><text x="26" y="8">Y</text><text x="4" y="66">Z</text><circle cx="30" cy="42" r="2"/></svg></div>

      <aside class="panel" aria-label="Simulation controls">
        <div class="panel-title"><span class="eyebrow">OBJECT PROPERTIES</span><span class="object-id">BH–001</span></div>
        <div class="object-card"><div class="object-symbol"><i></i></div><div><h2>Supermassive black hole</h2><p>Milky Way · Galactic center</p></div><span class="tag">ACTIVE</span></div>
        <div class="panel-scroll">
          <section><h3><span class="section-number">01</span> Physical parameters</h3>${ranges.map(args => range(...args)).join('')}
            <details class="advanced"><summary>Horizon radius & lensing ${icon('chevron')}</summary>
              ${range('radius', 'Schwarzschild radius', 'Liên kết với khối lượng theo Rₛ = 2GM/c²', 0.5 * RS_PER_MILLION_KM / 1e6, 12 * RS_PER_MILLION_KM / 1e6, 0.01, schwarzschildRadius(DEFAULTS.mass) / 1e6)}
              <p class="control-note">Bán kính và khối lượng được liên kết bởi Rₛ = 2GM/c².</p>
              ${range('lensing', 'Lensing strength', '1.0 là Schwarzschild; giá trị khác là thí nghiệm', 0, 1.5, 0.05)}
            </details>
            <details class="advanced" id="tidal-analysis"><summary>Tidal assessment ${icon('chevron')}</summary>
              <div class="body-presets" aria-label="Test body"><button data-body="earth">Earth</button><button data-body="rock">Asteroid</button><button data-body="probe">Probe</button></div>
              ${range('bodyRadiusKm', 'Body radius', 'Bán kính vật thể thử', 0.001, 12000, 0.001)}
              ${range('bodyDensity', 'Body density', 'Mật độ trung bình · cấu trúc cầu đồng nhất', 500, 20000, 1)}
              ${range('bodyStrengthMPa', 'Tensile strength', 'Sức bền kéo của vật chất', 0, 1000, 1)}
              ${range('bodyDistance', 'Body distance', 'Khoảng cách từ tâm hố đen', 0.5, 30, 0.1)}
              <div class="tidal-report" id="tidal-report" aria-live="polite"></div>
              <p class="control-note">Ước lượng thủy triều tuyến tính và ứng suất tĩnh của vật thể cầu đồng nhất. Không xác định thời điểm phân mảnh hay tạo hoạt ảnh vỡ.</p>
            </details>
          </section>
          <section><h3><span class="section-number">02</span> Render settings</h3>
            ${range('quality', 'Gravitational lensing quality', 'Số bước tích phân tia sáng', 1, 4, 1)}
            ${range('resolution', 'Render resolution', 'Tỉ lệ độ phân giải GPU so với viewport', 0.35, 1.5, 0.05)}
            ${range('exposure', 'Exposure', 'Filmic tone mapping · giảm về 0.01 cho khí rất nóng', 0.01, 2.5, 0.01)}
            ${toggle('autoQuality', 'Adaptive quality', 'Tự giảm tải khi FPS thấp')}
            ${toggle('bloom', 'Bloom', 'Ánh sáng HDR & soft glow')}
          </section>
          <section><h3><span class="section-number">03</span> Scene layers</h3>
            ${toggle('disk', 'Accretion disk')}${toggle('stars', 'Starfield')}${toggle('nebula', 'Distant nebula')}${toggle('ring', 'Photon ring', 'Ảnh khí từ tia đi vòng > 180°; không thêm viền sáng')}${toggle('autoOrbit', 'Cinematic orbit', 'Chỉ tự xoay khi bật công tắc này')}
          </section>
          <div class="physics-note"><span>THE PHYSICS BEHIND THE VIEW</span><p id="physics-description"></p><div>Rₛ = 2GM / c² <span>r<sub>ph</sub> = 1.5 Rₛ</span></div><p>Shadow: b<sub>crit</sub> = 2.598 Rₛ ở xa. Đây là bán kính biểu kiến, không phải chân trời hay photon sphere.</p></div>
          <button id="reset-simulation" class="secondary-button">${icon('reset')} Reset simulation</button>
        </div>
        <footer class="panel-footer"><span><i class="live-dot"></i><b id="fps">—</b> FPS</span><span id="render-info">WEBGL 2 · HDR</span></footer>
      </aside>

      <footer class="transport"><div class="time-controls"><button id="pause" class="pause-button" title="Pause / Resume (Space)" aria-label="Pause simulation" aria-pressed="false">${icon('pause')}</button><div class="simulation-time"><span>SIMULATION TIME</span><strong id="sim-time">00:00:00</strong></div><span class="speed-pill" id="speed-pill">1.00×</span></div>
        <div class="transport-tools"><button id="camera-mode" class="tool-button" title="Đổi Orbit / Fly (C)">${icon('orbit')}<span id="camera-mode-label">Orbit</span></button><span class="tool-divider"></span><button id="reset-camera" class="icon-button" title="Đặt lại góc nhìn (R)" aria-label="Reset camera">${icon('reset')}</button><button id="screenshot" class="icon-button" title="Tải ảnh PNG" aria-label="Screenshot">${icon('camera')}</button><button id="fullscreen" class="icon-button" title="Toàn màn hình" aria-label="Fullscreen">${icon('fullscreen')}</button></div>
      </footer>
      <div class="control-hint" id="control-hint"><span>DRAG</span> orbit <i>·</i> <span>SCROLL</span> zoom <i>·</i> <span>C</span> fly camera <i>·</i> <span>R</span> reset</div>
      <div id="toast" role="status" aria-live="polite"></div>
      <dialog id="help-dialog"><button id="help-close" class="dialog-close" aria-label="Đóng">×</button><div class="eyebrow">EXPLORE THE UNKNOWN</div><h2>Your window into spacetime.</h2><p>Mô phỏng tương tác, đơn vị shader chuẩn hóa theo Rₛ. Đây là mô hình trực quan có tích phân tia sáng, không phải bộ giải Kerr hay mô phỏng thủy động lực học GR đầy đủ.</p><dl><dt>Chuột trái + kéo</dt><dd>Xoay camera / nhìn quanh</dd><dt>Cuộn chuột</dt><dd>Zoom / đổi tốc độ bay</dd><dt>C</dt><dd>Đổi Orbit ↔ Fly</dd><dt>W A S D</dt><dd>Di chuyển (Fly) / chỉnh Orbit</dd><dt>Q / E · Shift</dt><dd>Hạ / nâng · bay nhanh</dd><dt>R · Space</dt><dd>Đặt lại camera · dừng / chạy</dd></dl><p>Scientific đặt spin = 0 và lensing = 1. Cinematic tăng bloom và tự bật bay vòng; bạn có thể tắt ở Scene layers. Khối lượng và Rₛ luôn liên kết; vị trí camera dùng đơn vị tham chiếu cố định để thấy kích thước thay đổi.</p><p class="dialog-footnote">Thời gian trên màn hình là thời gian chuyển động trực quan. FPS phụ thuộc GPU, trình duyệt và độ phân giải.</p></dialog>
      <div id="error-overlay" role="alert" hidden><h2>Unable to open the observatory</h2><p id="error-message"></p><button id="retry" class="secondary-button">Thử lại</button></div>
    </main>`;

  const get = id => document.getElementById(id);
  const format = (key, value) => {
    if (key === 'mass') return `${Number(value).toFixed(1)} <span>× 10⁶ M☉</span>`;
    if (key === 'temperature') return `${Math.round(value).toLocaleString('en-US')} <span>K</span>`;
    if (key === 'tilt') return `${value} <span>°</span>`;
    if (key === 'quality') return `${QUALITY_NAMES[value - 1]} <span>${[96,144,216,320][value - 1]}</span>`;
    if (key === 'resolution') return `${Math.round(value * 100)} <span>%</span>`;
    if (key === 'radius') return `${Number(value).toFixed(2)} <span>million km</span>`;
    if (key === 'bodyRadiusKm') return `${Number(value).toLocaleString('en-US', { maximumFractionDigits: 3 })} <span>km</span>`;
    if (key === 'bodyDensity') return `${Math.round(value).toLocaleString('en-US')} <span>kg/m³</span>`;
    if (key === 'bodyStrengthMPa') return `${value} <span>MPa</span>`;
    if (key === 'bodyDistance') return `${Number(value).toFixed(1)} <span>Rₛ</span>`;
    return `${Number(value).toFixed(2)}${key === 'speed' ? ' <span>×</span>' : ''}`;
  };
  function updateControl(key, value) {
    const input = get(key);
    input.value = value;
    get(`${key}-value`).innerHTML = format(key, value);
    input.style.setProperty('--fill', `${(value - input.min) / (input.max - input.min) * 100}%`);
  }
  function sync() {
    for (const input of document.querySelectorAll('[data-param]')) updateControl(input.dataset.param, input.dataset.param === 'radius' ? schwarzschildRadius(state.mass) / 1e6 : state[input.dataset.param]);
    for (const input of document.querySelectorAll('[data-toggle]')) input.checked = state[input.dataset.toggle];
    for (const button of document.querySelectorAll('[data-mode]')) {
      const active = state.mode === button.dataset.mode;
      button.classList.toggle('active', active);
      button.setAttribute('aria-pressed', active);
    }
    get('horizon-readout').innerHTML = `${(schwarzschildRadius(state.mass) / 1e6).toFixed(2)} <small>million km</small>`;
    get('speed-pill').textContent = `${state.speed.toFixed(2)}×`;
    get('pause').innerHTML = icon(state.paused ? 'play' : 'pause');
    get('pause').setAttribute('aria-label', state.paused ? 'Resume simulation' : 'Pause simulation');
    get('pause').setAttribute('aria-pressed', state.paused);
    const exact = state.spin === 0 && state.lensing === 1;
    get('model-label').textContent = exact ? 'SCHWARZSCHILD NULL GEODESICS' : 'SCHWARZSCHILD · EXPERIMENTAL EFFECTS';
    get('physics-description').textContent = state.spin > 0 ? 'Quay và biên trong đĩa lấy cảm hứng từ Kerr. Tia sáng và chân trời vẫn là Schwarzschild: không giải metric Kerr hay frame dragging.' : state.lensing !== 1 ? 'Lensing strength khác 1 là thí nghiệm thay đổi độ cong, không phải nghiệm Schwarzschild chính xác. Đặt về 1 để quan sát mô hình chuẩn.' : 'Tia sáng Schwarzschild được tích phân trong không gian 3D; ảnh photon hình thành từ khí trên quỹ đạo tia cong. Đĩa và truyền bức xạ là mô hình xấp xỉ.';
    const tide = tidalAssessment({ blackHoleMass: state.mass, bodyRadius: state.bodyRadiusKm * 1000,
      bodyDensity: state.bodyDensity, materialStrength: state.bodyStrengthMPa * 1e6, distanceRs: state.bodyDistance });
    const number = x => x >= 1e4 || x < 0.01 ? x.toExponential(2) : x.toFixed(2);
    const outcome = tide.overThreshold ? 'Vượt ngưỡng ứng suất tĩnh' : 'Chưa vượt ngưỡng ứng suất tĩnh';
    get('tidal-report').innerHTML = `<dl><dt>Body mass</dt><dd>${number(tide.bodyMass)} kg</dd><dt>Surface tide · Δa</dt><dd>${number(tide.tidalAcceleration)} m/s²</dd><dt>Self gravity</dt><dd>${number(tide.selfGravity)} m/s²</dd><dt>Tidal stress</dt><dd>${number(tide.tidalStress / 1e6)} MPa</dd><dt>Gravity + strength</dt><dd>${number(tide.supportStress / 1e6)} MPa</dd><dt>Disruption estimate</dt><dd id="tidal-radius">${tide.disruptionRadiusRs.toFixed(3)} Rₛ</dd></dl><p id="tidal-outcome">${outcome}. Ngưỡng ${tide.disruptsOutsideHorizon ? 'ở ngoài' : 'ở trong'} chân trời.${!tide.linearModelValid ? ' Kích thước quá lớn so với khoảng cách: mô hình tuyến tính mất độ tin cậy.' : ''}</p>`;
  }
  for (const input of document.querySelectorAll('[data-param]')) input.addEventListener('input', () => {
    actions.parameter(input.dataset.param, Number(input.value));
    sync();
  });
  for (const input of document.querySelectorAll('[data-toggle]')) input.addEventListener('change', () => {
    actions.toggle(input.dataset.toggle, input.checked);
    sync();
  });
  for (const button of document.querySelectorAll('[data-mode]')) button.addEventListener('click', () => { actions.mode(button.dataset.mode); sync(); });
  for (const button of document.querySelectorAll('[data-view]')) button.addEventListener('click', () => {
    actions.view(button.dataset.view);
    for (const b of document.querySelectorAll('[data-view]')) b.classList.toggle('selected', b === button);
  });
  for (const button of document.querySelectorAll('[data-body]')) button.addEventListener('click', () => {
    const presets = { earth: [6371, 5514, 50], rock: [0.5, 3000, 1], probe: [0.001, 4500, 600] };
    const [radius, density, strength] = presets[button.dataset.body];
    actions.parameter('bodyRadiusKm', radius); actions.parameter('bodyDensity', density);
    actions.parameter('bodyStrengthMPa', strength); sync();
  });
  for (const [id, action] of [['pause','pause'],['reset-simulation','reset'],['reset-camera','resetCamera'],['camera-mode','camera'],['screenshot','screenshot'],['fullscreen','fullscreen']]) get(id).addEventListener('click', () => { actions[action](); sync(); });
  get('help').addEventListener('click', () => get('help-dialog').showModal());
  get('help-close').addEventListener('click', () => get('help-dialog').close());
  get('help-dialog').addEventListener('click', event => { if (event.target === get('help-dialog')) get('help-dialog').close(); });
  get('panel-toggle').addEventListener('click', () => document.body.classList.toggle('panel-open'));
  get('retry').addEventListener('click', () => location.reload());
  get('brand')?.addEventListener('click', event => event.preventDefault());
  sync();

  let toastTimer;
  return {
    sync,
    camera(mode) {
      get('camera-mode-label').textContent = mode === 'fly' ? 'Fly' : 'Orbit';
      get('camera-mode').innerHTML = `${icon(mode === 'fly' ? 'fly' : 'orbit')}<span id="camera-mode-label">${mode === 'fly' ? 'Fly' : 'Orbit'}</span>`;
      get('control-hint').innerHTML = mode === 'fly' ? '<span>WASD</span> move <i>·</i> <span>Q / E</span> down / up <i>·</i> <span>SHIFT</span> boost <i>·</i> <span>DRAG</span> look' : '<span>DRAG</span> orbit <i>·</i> <span>SCROLL</span> zoom <i>·</i> <span>C</span> fly camera <i>·</i> <span>R</span> reset';
    },
    readout(fps, seconds, distance, width, height, hdr) {
      get('fps').textContent = Math.round(fps);
      const t = Math.floor(seconds);
      get('sim-time').textContent = [Math.floor(t / 3600), Math.floor(t / 60) % 60, t % 60].map(n => String(n).padStart(2, '0')).join(':');
      get('distance-readout').innerHTML = `${distance.toFixed(1)} <small>Rₛ</small>`;
      get('render-info').textContent = `${width} × ${height} · ${hdr ? 'HDR' : 'LDR'}`;
    },
    ready() { get('loading').remove(); },
    error(message) { get('error-overlay').hidden = false; get('error-message').textContent = message; },
    toast(message) {
      get('toast').textContent = message;
      get('toast').classList.add('visible');
      clearTimeout(toastTimer);
      toastTimer = setTimeout(() => get('toast').classList.remove('visible'), 4500);
    },
  };
}
