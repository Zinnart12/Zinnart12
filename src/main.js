import * as THREE from 'three';
import { CameraRig } from './camera.js';
import { createUI } from './ui.js';
import { DEFAULTS, REFERENCE_MASS, QUALITY_STEPS, diskInnerRadius, massFromRadius } from './physics.js';
import vertexShader from './shaders/fullscreen.vert.glsl?raw';
import fragmentShader from './shaders/blackhole.frag.glsl?raw';
import bloomShader from './shaders/bloom.frag.glsl?raw';
import compositeShader from './shaders/composite.frag.glsl?raw';
import './style.css';

const state = { ...DEFAULTS };
let renderer, rig, pipeline, resizeObserver;
let running = false, frameId, lastTime = 0, simulationTime = 0;
let sampleTime = 0, sampleFrames = 0, fps = 60, readoutAt = 0, lastQualityChange = 0;
let shaderFailure = null, firstFrame = true;

const ui = createUI(state, {
  parameter(key, value) {
    if (key === 'radius') state.mass = massFromRadius(value * 1e6);
    else state[key] = value;
    if (key === 'resolution' || key === 'quality') {
      lastQualityChange = performance.now();
      if (key === 'resolution') resize();
    }
    if (key === 'mass' || key === 'radius') rig?.update(0.1, false, state.mass / REFERENCE_MASS);
  },
  toggle(key, checked) { state[key] = checked; },
  mode: setMode,
  view(view) {
    state.autoOrbit = false;
    rig?.preset(view);
    ui.camera('orbit');
    ui.sync();
  },
  pause() { state.paused = !state.paused; },
  reset() {
    Object.assign(state, DEFAULTS);
    simulationTime = 0;
    lastQualityChange = performance.now();
    rig?.setMode('orbit');
    rig?.reset();
    ui.camera('orbit');
    resize();
    ui.toast('Simulation reset · góc nhìn và thông số đã được đặt lại');
  },
  resetCamera() {
    state.autoOrbit = false;
    rig?.setMode('orbit');
    rig?.reset();
    ui.camera('orbit');
  },
  camera: toggleCamera,
  screenshot: saveScreenshot,
  async fullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch { ui.toast('Trình duyệt không cho phép toàn màn hình trong cửa sổ này.'); }
  },
});

function setMode(mode) {
  state.mode = mode;
  if (mode === 'scientific') {
    state.spin = 0; state.lensing = 1; state.autoOrbit = false;
    state.exposure = 1.05; state.bloom = true;
    state.quality = 2; state.resolution = 0.85;
  } else if (mode === 'cinematic') {
    state.temperature = 8000; state.brightness = 1.7; state.exposure = 1.25;
    state.bloom = true; state.autoOrbit = !matchMedia('(prefers-reduced-motion: reduce)').matches;
    state.quality = 3; state.resolution = 1;
    rig?.setMode('orbit'); ui.camera('orbit');
    ui.toast(state.autoOrbit ? 'Cinematic · camera bay vòng đã bật. Tắt tại Scene layers.' : 'Cinematic · tự xoay đã tắt theo tùy chọn giảm chuyển động.');
  } else {
    state.bloom = false; state.autoOrbit = false;
    state.quality = 1; state.resolution = 0.55; state.nebula = false;
  }
  lastQualityChange = performance.now();
  resize();
}

function toggleCamera() {
  if (!rig) return;
  state.autoOrbit = false;
  rig.setMode(rig.mode === 'orbit' ? 'fly' : 'orbit');
  ui.camera(rig.mode);
  ui.toast(rig.mode === 'fly' ? 'Fly camera · WASD để bay, Q/E nâng hạ, giữ chuột trái để nhìn' : 'Orbit camera · kéo để xoay, cuộn để zoom');
}

function createPipeline(hdr) {
  const geometry = new THREE.PlaneGeometry(2, 2);
  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const targetOptions = {
    type: hdr ? THREE.HalfFloatType : THREE.UnsignedByteType,
    format: THREE.RGBAFormat, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
    depthBuffer: false, stencilBuffer: false,
  };
  const target = new THREE.WebGLRenderTarget(1, 1, targetOptions);
  const bloomA = new THREE.WebGLRenderTarget(1, 1, targetOptions);
  const bloomB = new THREE.WebGLRenderTarget(1, 1, targetOptions);
  const uniforms = {
    uCamera: { value: new THREE.Vector3() }, uForward: { value: new THREE.Vector3() },
    uRight: { value: new THREE.Vector3() }, uUp: { value: new THREE.Vector3() },
    uAspect: { value: 1 }, uTanFov: { value: Math.tan(THREE.MathUtils.degToRad(46 / 2)) },
    uRadius: { value: 1 }, uTime: { value: 0 }, uSpin: { value: 0 }, uTilt: { value: 0 },
    uInner: { value: 3 }, uTemperature: { value: 10500 }, uDensity: { value: 1.2 },
    uBrightness: { value: 1.5 }, uLensing: { value: 1 }, uSteps: { value: 144 },
    uDisk: { value: true }, uStars: { value: true }, uNebula: { value: true }, uRing: { value: true },
  };
  const material = new THREE.RawShaderMaterial({ vertexShader, fragmentShader, uniforms, glslVersion: THREE.GLSL3, depthTest: false, depthWrite: false });
  const bloom = new THREE.RawShaderMaterial({
    vertexShader, fragmentShader: bloomShader, glslVersion: THREE.GLSL3, depthTest: false, depthWrite: false,
    uniforms: { uTexture: { value: target.texture }, uTexel: { value: new THREE.Vector2() }, uDirection: { value: new THREE.Vector2() }, uThreshold: { value: false } },
  });
  const composite = new THREE.RawShaderMaterial({
    vertexShader, fragmentShader: compositeShader, glslVersion: THREE.GLSL3, depthTest: false, depthWrite: false,
    uniforms: { uScene: { value: target.texture }, uBloom: { value: bloomA.texture }, uTexel: { value: new THREE.Vector2() }, uBloomStrength: { value: 0.2 }, uExposure: { value: 1 } },
  });
  const quad = new THREE.Mesh(geometry, material);
  quad.frustumCulled = false;
  scene.add(quad);
  return { scene, camera, quad, material, uniforms, bloom, composite, target, bloomA, bloomB, hdr, width: 1, height: 1 };
}

function resize() {
  if (!renderer || !pipeline || !rig) return;
  const viewport = document.getElementById('viewport');
  const width = Math.max(1, viewport.clientWidth), height = Math.max(1, viewport.clientHeight);
  renderer.setSize(width, height, false);
  rig.camera.aspect = width / height;
  rig.camera.updateProjectionMatrix();
  // Bound both texture dimensions and total GPU memory even on very large displays.
  const maxDimension = Math.min(renderer.capabilities.maxTextureSize, 4096);
  const requestedScale = state.resolution * Math.min(devicePixelRatio || 1, 1.5);
  const scale = Math.min(requestedScale, maxDimension / width, maxDimension / height, Math.sqrt(4_200_000 / (width * height)));
  pipeline.width = Math.max(1, Math.floor(width * scale));
  pipeline.height = Math.max(1, Math.floor(height * scale));
  pipeline.target.setSize(pipeline.width, pipeline.height);
  const bw = Math.max(1, Math.floor(pipeline.width / 4)), bh = Math.max(1, Math.floor(pipeline.height / 4));
  pipeline.bloomA.setSize(bw, bh); pipeline.bloomB.setSize(bw, bh);
  pipeline.uniforms.uAspect.value = width / height;
  pipeline.composite.uniforms.uTexel.value.set(1 / pipeline.width, 1 / pipeline.height);
}

function render() {
  const p = pipeline, u = p.uniforms;
  u.uCamera.value.copy(rig.camera.position);
  u.uRight.value.setFromMatrixColumn(rig.camera.matrixWorld, 0);
  u.uUp.value.setFromMatrixColumn(rig.camera.matrixWorld, 1);
  u.uForward.value.setFromMatrixColumn(rig.camera.matrixWorld, 2).negate();
  u.uTime.value = simulationTime;
  u.uRadius.value = state.mass / REFERENCE_MASS;
  u.uInner.value = diskInnerRadius(state.spin);
  u.uSpin.value = state.spin; u.uTilt.value = THREE.MathUtils.degToRad(state.tilt);
  u.uTemperature.value = state.temperature; u.uDensity.value = state.density;
  u.uBrightness.value = state.brightness; u.uLensing.value = state.lensing;
  u.uSteps.value = QUALITY_STEPS[state.quality - 1];
  u.uDisk.value = state.disk; u.uStars.value = state.stars;
  u.uNebula.value = state.nebula; u.uRing.value = state.ring;
  p.quad.material = p.material;
  renderer.setRenderTarget(p.target);
  renderer.render(p.scene, p.camera);
  if (shaderFailure) throw new Error(shaderFailure);
  if (state.bloom) {
    p.quad.material = p.bloom;
    const b = p.bloom.uniforms;
    b.uTexture.value = p.target.texture;
    b.uTexel.value.set(1 / p.width, 1 / p.height);
    b.uDirection.value.set(0, 0); b.uThreshold.value = true;
    renderer.setRenderTarget(p.bloomA); renderer.render(p.scene, p.camera);
    b.uThreshold.value = false;
    b.uTexture.value = p.bloomA.texture;
    b.uTexel.value.set(1 / p.bloomA.width, 1 / p.bloomA.height);
    b.uDirection.value.set(1, 0);
    renderer.setRenderTarget(p.bloomB); renderer.render(p.scene, p.camera);
    b.uTexture.value = p.bloomB.texture; b.uDirection.value.set(0, 1);
    renderer.setRenderTarget(p.bloomA); renderer.render(p.scene, p.camera);
  }
  p.quad.material = p.composite;
  p.composite.uniforms.uBloomStrength.value = state.bloom ? (state.mode === 'cinematic' ? 0.55 : 0.23) : 0;
  p.composite.uniforms.uExposure.value = state.exposure;
  renderer.setRenderTarget(null); renderer.render(p.scene, p.camera);
  if (shaderFailure) throw new Error(shaderFailure);
}

function animate(now) {
  if (!running) return;
  const elapsed = Math.max(0, (now - lastTime) / 1000);
  const dt = Math.min(elapsed, 0.1);
  lastTime = now;
  if (!document.hidden) {
    const initializing = firstFrame;
    if (!state.paused) simulationTime += dt * state.speed;
    rig.update(dt, state.autoOrbit && !state.paused, state.mass / REFERENCE_MASS);
    try { render(); } catch (error) { fail(error); return; }
    if (firstFrame) { firstFrame = false; ui.ready(); lastQualityChange = now; }
    // Measure actual presentation intervals; exclude tab suspension and initial compilation.
    if (!initializing && elapsed > 0) { sampleTime += elapsed; sampleFrames++; }
    if (sampleTime >= 1) { fps = sampleFrames / sampleTime; sampleTime = sampleFrames = 0; }
    if (now - readoutAt > 500) {
      ui.readout(fps, simulationTime, rig.camera.position.length() / (state.mass / REFERENCE_MASS), pipeline.width, pipeline.height, pipeline.hdr);
      readoutAt = now;
    }
    if (state.autoQuality && now - lastQualityChange > 7000 && fps < 28) {
      if (state.resolution > 0.4) state.resolution = Math.max(0.35, Math.round((state.resolution - 0.1) * 100) / 100);
      else if (state.quality > 1) state.quality--;
      else if (state.bloom) state.bloom = false;
      else { lastQualityChange = now; frameId = requestAnimationFrame(animate); return; }
      resize(); ui.sync();
      ui.toast(`Adaptive quality · ${Math.round(state.resolution * 100)}% resolution / ${QUALITY_STEPS[state.quality - 1]} ray steps`);
      lastQualityChange = now;
    }
  }
  frameId = requestAnimationFrame(animate);
}

function fail(error) {
  running = false;
  cancelAnimationFrame(frameId);
  console.error(error);
  ui.error(`${error.message || error} Kiểm tra hỗ trợ WebGL2 và bật hardware acceleration trong trình duyệt.`);
}

async function saveScreenshot() {
  if (!renderer || !running) { ui.toast('Ảnh chưa sẵn sàng vì renderer không hoạt động.'); return; }
  const button = document.getElementById('screenshot');
  button.disabled = true;
  try {
    render();
    const blob = await new Promise(resolve => renderer.domElement.toBlob(resolve, 'image/png'));
    if (!blob) throw new Error('Không thể tạo ảnh PNG.');
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url; link.download = `event-horizon-${new Date().toISOString().replaceAll(':', '-')}.png`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
    ui.toast('Đã lưu ảnh PNG của khung nhìn hiện tại.');
  } catch (error) { ui.toast(error.message); }
  finally { button.disabled = false; }
}

try {
  const canvas = document.createElement('canvas');
  canvas.setAttribute('aria-label', 'Black hole rendered by curved light rays');
  const context = canvas.getContext('webgl2', { alpha: false, antialias: false, powerPreference: 'high-performance' });
  if (!context) throw new Error('Trình duyệt hoặc GPU hiện tại không cung cấp WebGL2.');
  renderer = new THREE.WebGLRenderer({ canvas, context, antialias: false, alpha: false });
  renderer.setPixelRatio(1);
  renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
  renderer.debug.checkShaderErrors = true;
  renderer.debug.onShaderError = (gl, program, vertex, fragment) => {
    shaderFailure = `Shader compilation failed: ${gl.getShaderInfoLog(vertex)} ${gl.getShaderInfoLog(fragment)} ${gl.getProgramInfoLog(program)}`;
  };
  document.getElementById('viewport').appendChild(canvas);
  rig = new CameraRig(document.getElementById('viewport'));
  const hdr = !!context.getExtension('EXT_color_buffer_float');
  pipeline = createPipeline(hdr);
  if (!hdr) ui.toast('GPU không hỗ trợ HDR float; đang dùng chế độ tương thích LDR.');
  resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(document.getElementById('viewport'));
  window.addEventListener('resize', resize);
  document.addEventListener('fullscreenchange', resize);
  document.addEventListener('visibilitychange', () => {
    lastTime = performance.now(); sampleTime = sampleFrames = 0;
  });
  canvas.addEventListener('webglcontextlost', event => {
    event.preventDefault(); running = false; cancelAnimationFrame(frameId);
    ui.toast('WebGL context bị mất. Đang chờ GPU khôi phục…');
  });
  canvas.addEventListener('webglcontextrestored', () => {
    shaderFailure = null; lastTime = performance.now();
    resize(); running = true; frameId = requestAnimationFrame(animate);
    ui.toast('GPU đã khôi phục. Mô phỏng tiếp tục.');
  });
  window.addEventListener('keydown', event => {
    if (/INPUT|TEXTAREA|SELECT|BUTTON/.test(event.target.tagName) || event.ctrlKey || event.metaKey || event.repeat || document.getElementById('help-dialog').open) return;
    if (event.code === 'KeyC') toggleCamera();
    if (event.code === 'KeyR') { state.autoOrbit = false; rig.setMode('orbit'); rig.reset(); ui.camera('orbit'); }
    if (event.code === 'Space') { event.preventDefault(); state.paused = !state.paused; }
    ui.sync();
  });
  resize();
  running = true; lastTime = performance.now();
  frameId = requestAnimationFrame(animate);

  // Opt-in instrumentation for functional browser tests; no production global state.
  if (new URLSearchParams(location.search).has('test')) {
    window.__observatory = {
      snapshot: () => ({ state: { ...state }, camera: rig.camera.position.toArray(), quaternion: rig.camera.quaternion.toArray(), cameraMode: rig.mode, time: simulationTime, running, hdr: pipeline.hdr, width: pipeline.width, height: pipeline.height, steps: pipeline.uniforms.uSteps.value, shaderFailure, fps }),
      sample() {
        render();
        const gl = renderer.getContext();
        const width = gl.drawingBufferWidth, height = gl.drawingBufferHeight;
        const pixels = new Uint8Array(width * height * 4);
        gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
        let energy = 0, bright = 0, signature = 0;
        for (let i = 0; i < pixels.length; i += 4) {
          const l = pixels[i] + pixels[i + 1] + pixels[i + 2];
          energy += l; if (l > 200) bright++;
          signature = (signature + l * ((i / 4) % 251 + 1)) % 2147483647;
        }
        const center = ((Math.floor(height / 2) * width) + Math.floor(width / 2)) * 4;
        return { energy, bright, signature, center: Array.from(pixels.slice(center, center + 3)), width, height, glError: gl.getError() };
      },
    };
  }
} catch (error) { fail(error); }

window.addEventListener('pagehide', () => {
  running = false; cancelAnimationFrame(frameId); resizeObserver?.disconnect();
  if (pipeline) {
    for (const key of ['target','bloomA','bloomB','material','bloom','composite']) pipeline[key].dispose();
    pipeline.quad.geometry.dispose();
  }
  renderer?.dispose();
});
