import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import type { CelestialBody, SimulationState, Vec3 } from '../types';
import {
  surfaceVertex, planetFragment, starFragment, atmosphereFragment, ringFragment,
  starfieldVertex, starfieldFragment, particlesVertex, particlesFragment,
} from './shaders';

export const AU_METRES = 149_597_870_700;
export const SCENE_UNITS_PER_AU = 32;
const METRES_TO_SCENE = SCENE_UNITS_PER_AU / AU_METRES;
const EARTH_RADIUS = 6_371_000;
const SOLAR_RADIUS = 696_340_000;
const YEAR_SECONDS = 365.25 * 86_400;

export interface RendererOptions {
  trails?: boolean;
  labels?: boolean;
  vectors?: boolean;
  trueScale?: boolean;
  /** Multiplies the illustrative display radius; has no effect on SI gravity/collisions. */
  visibilityScale?: number;
  quality?: 'performance' | 'balanced' | 'ultra';
  cameraMode?: 'orbit' | 'fly';
  follow?: boolean;
}
interface Options extends Required<RendererOptions> {}
interface BodyVisual {
  body: CelestialBody;
  group: THREE.Group;
  mesh: THREE.Mesh<THREE.BufferGeometry, THREE.ShaderMaterial>;
  atmosphere?: THREE.Mesh<THREE.BufferGeometry, THREE.ShaderMaterial>;
  rings?: THREE.Mesh<THREE.BufferGeometry, THREE.ShaderMaterial>;
  label: HTMLDivElement;
  trail: THREE.Line<THREE.BufferGeometry, THREE.LineBasicMaterial>;
  history: Vec3[];
  velocity: THREE.ArrowHelper;
  force: THREE.ArrowHelper;
  radius: number;
}
interface Burst {
  cloud: THREE.Points<THREE.BufferGeometry, THREE.ShaderMaterial>;
  position: Vec3;
  started: number;
}

function seeded(seed: number): () => number {
  let x = seed >>> 0;
  return () => {
    x += 0x6d2b79f5;
    let y = x;
    y = Math.imul(y ^ (y >>> 15), y | 1);
    y ^= y + Math.imul(y ^ (y >>> 7), y | 61);
    return ((y ^ (y >>> 14)) >>> 0) / 4294967296;
  };
}

/** Approximate blackbody chromaticity. This only shades the visible stellar photosphere. */
function temperatureColor(kelvin: number): THREE.Color {
  const t = THREE.MathUtils.clamp(kelvin, 1000, 40_000) / 100;
  const red = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -.1332047592);
  const green = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -.0755148492);
  const blue = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
  return new THREE.Color(
    THREE.MathUtils.clamp(red / 255, 0, 1),
    THREE.MathUtils.clamp(green / 255, 0, 1),
    THREE.MathUtils.clamp(blue / 255, 0, 1),
  );
}
function surfaceId(body: CelestialBody): number {
  return ['earth', 'rocky', 'gas', 'ice', 'lava', 'ocean'].indexOf(body.surface);
}

/** WebGL2 scene renderer. Physics is owned by the worker; no orbit is manufactured here. */
export class UniverseRenderer {
  readonly canvas: HTMLCanvasElement;
  private readonly host: HTMLElement;
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.PerspectiveCamera(48, 1, .002, 80_000);
  private readonly renderer: THREE.WebGLRenderer;
  private readonly controls: OrbitControls;
  private readonly composer: EffectComposer;
  private readonly bloom: UnrealBloomPass;
  private readonly resizeObserver: ResizeObserver;
  private readonly labels: HTMLDivElement;
  private readonly visuals = new Map<string, BodyVisual>();
  private readonly raycaster = new THREE.Raycaster();
  private readonly pointer = new THREE.Vector2();
  private readonly starfield: THREE.Points<THREE.BufferGeometry, THREE.ShaderMaterial>;
  private readonly selectionHalo: THREE.LineLoop<THREE.BufferGeometry, THREE.LineBasicMaterial>;
  private readonly bursts: Burst[] = [];
  private readonly seenEvents = new Set<number>();
  private readonly origin = new THREE.Vector3();
  private readonly keys = new Set<string>();
  private readonly scratch = new THREE.Vector3();
  private readonly projected = new THREE.Vector3();
  private readonly forward = new THREE.Vector3();
  private readonly right = new THREE.Vector3();
  private readonly up = new THREE.Vector3(0, 1, 0);
  private readonly focusTarget = new THREE.Vector3();
  private readonly focusPosition = new THREE.Vector3();
  private readonly hdr: boolean;
  private options: Options = {
    trails: true, labels: true, vectors: false, trueScale: false, visibilityScale: 1,
    quality: 'balanced', cameraMode: 'orbit', follow: true,
  };
  private sphere: THREE.SphereGeometry;
  private readonly asteroid = new THREE.IcosahedronGeometry(1, 2);
  private readonly ringGeometry = new THREE.RingGeometry(1.28, 2.6, 128, 1);
  private state: SimulationState | null = null;
  private selectedId: string | null = null;
  private focusedId: string | null = null;
  private focusMoving = false;
  private bodySignature = '';
  private lastTime = -1;
  private lastSteps = -1;
  private lastStateName = '';
  private width = 1;
  private height = 1;
  private wallTime = 0;
  private fps = 0;
  private fpsElapsed = 0;
  private fpsFrames = 0;
  private adaptiveRatio = 1;
  private adaptiveElapsed = 0;
  private keyboardActive = false;
  private pointerStart: [number, number] | null = null;
  private disposed = false;
  private contextLost = false;
  private clearHistoryOnNextUpdate = false;
  private readonly onSelect: (id: string) => void;

  constructor(host: HTMLElement, onSelect: (id: string) => void) {
    this.host = host;
    this.onSelect = onSelect;
    this.canvas = document.createElement('canvas');
    this.canvas.dataset.testid = 'universe-canvas';
    this.canvas.setAttribute('aria-label', 'Interactive 3D universe. Drag to orbit, scroll to zoom, click a body to select.');
    this.canvas.tabIndex = 0;
    Object.assign(this.canvas.style, { display: 'block', width: '100%', height: '100%', touchAction: 'none', outline: 'none' });
    this.renderer = new THREE.WebGLRenderer({ canvas: this.canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
    this.renderer.setClearColor(0x03060c, 1);
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.07;
    this.renderer.info.autoReset = false;
    this.hdr = this.renderer.extensions.has('EXT_color_buffer_float');
    this.host.append(this.canvas);
    this.labels = document.createElement('div');
    this.labels.dataset.testid = 'body-labels';
    Object.assign(this.labels.style, { position: 'absolute', inset: '0', pointerEvents: 'none', overflow: 'hidden' });
    this.host.append(this.labels);
    this.scene.background = new THREE.Color(0x03060c);
    this.sphere = new THREE.SphereGeometry(1, 48, 32);
    this.controls = new OrbitControls(this.camera, this.canvas);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = .09;
    this.controls.enablePan = true;
    this.controls.screenSpacePanning = true;
    this.controls.minDistance = .006;
    this.controls.maxDistance = 20_000;
    this.controls.zoomSpeed = .8;
    this.controls.rotateSpeed = .68;
    this.controls.addEventListener('start', this.onControlsStart);
    this.camera.position.set(75, 78, 108);
    this.controls.target.set(0, 0, 0);
    this.camera.lookAt(0, 0, 0);
    const target = new THREE.WebGLRenderTarget(1, 1, { type: this.hdr ? THREE.HalfFloatType : THREE.UnsignedByteType });
    target.samples = 0;
    this.composer = new EffectComposer(this.renderer, target);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), .22, .35, 1.18);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
    this.starfield = this.makeStarfield();
    this.scene.add(this.starfield);
    const circle = Array.from({ length: 80 }, (_, i) => new THREE.Vector3(Math.cos(i / 80 * Math.PI * 2), Math.sin(i / 80 * Math.PI * 2), 0));
    this.selectionHalo = new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(circle), new THREE.LineBasicMaterial({ color: 0x5eecbc, transparent: true, opacity: .55, depthTest: true }));
    this.selectionHalo.visible = false;
    this.scene.add(this.selectionHalo);
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(host);
    this.canvas.addEventListener('pointerdown', this.onPointerDown);
    this.canvas.addEventListener('pointerup', this.onPointerUp);
    this.canvas.addEventListener('pointerenter', this.onPointerEnter);
    this.canvas.addEventListener('pointerleave', this.onPointerLeave);
    this.canvas.addEventListener('webglcontextlost', this.onContextLost);
    this.canvas.addEventListener('webglcontextrestored', this.onContextRestored);
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
    window.addEventListener('blur', this.onBlur);
    this.resize();
  }

  update(state: SimulationState, selectedId: string | null): void {
    if (this.disposed) return;
    const signature = state.bodies.map(body => `${body.id}:${body.seed}`).sort().join('|');
    const loadedDocument = this.clearHistoryOnNextUpdate || !this.state || state.time < this.lastTime || state.steps < this.lastSteps
      || state.name !== this.lastStateName;
    this.clearHistoryOnNextUpdate = false;
    const reset = signature !== this.bodySignature || loadedDocument || state.time - this.lastTime > YEAR_SECONDS;
    if (reset) {
      this.clearTrails();
      this.clearBursts();
      if (loadedDocument) {
        this.seenEvents.clear();
        // A loaded document contains a historic event log, not new explosions.
        for (const event of state.events) this.seenEvents.add(event.id);
      }
    }
    this.bodySignature = signature;
    this.state = state;
    this.selectedId = selectedId;
    const ids = new Set(state.bodies.map(body => body.id));
    for (const [id, visual] of this.visuals) {
      if (!ids.has(id)) { this.disposeVisual(visual); this.visuals.delete(id); }
    }
    if (this.focusedId && !ids.has(this.focusedId)) {
      this.focusedId = null;
      this.focusMoving = false;
    }
    const focused = this.focusedId ? state.bodies.find(body => body.id === this.focusedId) : undefined;
    if (focused && this.options.follow) this.recenter(focused.position, false);
    if (!this.visuals.size && !focused) {
      const anchor = state.bodies.find(body => body.kind === 'star') || state.bodies[0];
      if (anchor) this.recenter(anchor.position, false);
    }
    const timeMoved = state.time !== this.lastTime || reset;
    for (const body of state.bodies) {
      let visual = this.visuals.get(body.id);
      if (visual && (visual.body.kind !== body.kind || visual.body.surface !== body.surface)) {
        this.disposeVisual(visual);
        this.visuals.delete(body.id);
        visual = undefined;
      }
      if (!visual) { visual = this.makeBody(body); this.visuals.set(body.id, visual); }
      const manuallyMoved = state.time === this.lastTime && body.position.some((n, i) => n !== visual!.body.position[i]);
      if (manuallyMoved) visual.history = [];
      visual.body = body;
      visual.radius = this.displayRadius(body);
      this.toScene(body.position, visual.group.position);
      visual.mesh.scale.setScalar(visual.radius);
      const period = Math.abs(body.rotationPeriod) > 1 ? body.rotationPeriod : 86_400;
      // Physical spin is visual only. A body's center is never moved by this rotation.
      const spin = (state.time / period % 1) * Math.PI * 2;
      visual.group.rotation.set(THREE.MathUtils.degToRad(body.axialTilt), spin, 0, 'YXZ');
      const uniforms = visual.mesh.material.uniforms;
      uniforms.uTime.value = state.time / 3600;
      uniforms.uSeed.value = (body.seed % 10_000) * .0137;
      uniforms.uColor.value.copy(body.kind === 'star' ? temperatureColor(body.temperature) : new THREE.Color(body.color));
      uniforms.uAtmosphere.value = THREE.MathUtils.clamp(body.atmosphere, 0, 1);
      uniforms.uAlbedo.value = THREE.MathUtils.clamp(body.albedo, 0, 1);
      this.updateLight(visual);
      if (visual.atmosphere) {
        visual.atmosphere.scale.setScalar(visual.radius * 1.045);
        visual.atmosphere.visible = body.kind === 'star' || body.atmosphere > .001;
        visual.atmosphere.material.uniforms.uStrength.value = body.kind === 'star' ? 1.25 : Math.min(body.atmosphere, 1);
      }
      if (visual.rings) {
        visual.rings.scale.setScalar(visual.radius);
        visual.rings.material.uniforms.uCenter.value.copy(visual.group.position);
        visual.rings.material.uniforms.uRadius.value = visual.radius;
      }
      if (timeMoved || manuallyMoved) {
        const previous = visual.history[visual.history.length - 1];
        const movement = previous ? Math.hypot(...body.position.map((n, i) => n - previous[i])) : Infinity;
        if (!previous || movement > Math.max(body.radius * .001, 1)) {
          visual.history.push([...body.position]);
          const limit = this.options.quality === 'ultra' ? 520 : this.options.quality === 'performance' ? 180 : 320;
          if (visual.history.length > limit) visual.history.splice(0, visual.history.length - limit);
        }
      }
      this.updateTrail(visual);
      this.updateVectors(visual);
      visual.label.textContent = body.name;
      visual.label.style.color = body.id === selectedId ? '#a8f5db' : '#b0bccb';
      visual.label.style.opacity = body.id === selectedId ? '1' : '.77';
      visual.trail.material.opacity = body.id === selectedId ? .55 : .22;
    }
    for (const event of state.events) {
      if (!this.seenEvents.has(event.id)) {
        this.seenEvents.add(event.id);
        this.makeBurst(event.position, event.id);
      }
    }
    this.lastTime = state.time;
    this.lastSteps = state.steps;
    this.lastStateName = state.name;
  }

  render(deltaSeconds: number): void {
    if (this.disposed || this.contextLost) return;
    const delta = THREE.MathUtils.clamp(deltaSeconds, 0, .25);
    this.wallTime += delta;
    if (this.options.cameraMode === 'fly') this.updateFly(delta);
    if (this.focusMoving && this.options.cameraMode === 'orbit') {
      const blend = 1 - Math.exp(-Math.min(Math.max(deltaSeconds, 0), 1) * 6);
      this.camera.position.lerp(this.focusPosition, blend);
      this.controls.target.lerp(this.focusTarget, blend);
      if (this.camera.position.distanceTo(this.focusPosition) < .0001 && this.controls.target.distanceTo(this.focusTarget) < .0001) this.focusMoving = false;
    }
    this.controls.update();
    this.camera.updateMatrixWorld();
    this.starfield.position.copy(this.camera.position);
    this.starfield.material.uniforms.uWallTime.value = this.wallTime;
    this.updateLabels();
    const selected = this.selectedId ? this.visuals.get(this.selectedId) : undefined;
    this.selectionHalo.visible = Boolean(selected);
    if (selected) {
      this.selectionHalo.position.copy(selected.group.position);
      this.selectionHalo.quaternion.copy(this.camera.quaternion);
      this.selectionHalo.scale.setScalar(selected.radius * 1.22);
    }
    for (const visual of this.visuals.values()) {
      visual.mesh.material.uniforms.uEye.value.copy(this.camera.position);
      visual.atmosphere?.material.uniforms.uEye.value.copy(this.camera.position);
      const distance = this.camera.position.distanceTo(visual.group.position);
      visual.atmosphere && (visual.atmosphere.visible = (visual.body.kind === 'star' || visual.body.atmosphere > .001) && distance < visual.radius * 1000);
    }
    for (let i = this.bursts.length - 1; i >= 0; i--) {
      const burst = this.bursts[i];
      const age = this.wallTime - burst.started;
      if (age > 12) { this.scene.remove(burst.cloud); burst.cloud.geometry.dispose(); burst.cloud.material.dispose(); this.bursts.splice(i, 1); }
      else { this.toScene(burst.position, burst.cloud.position); burst.cloud.material.uniforms.uAge.value = age; }
    }
    this.renderer.info.reset();
    this.composer.render(delta);
    this.fpsFrames++;
    // Use real frame interval, including software-rendering time, for honest statistics.
    this.fpsElapsed += Math.max(deltaSeconds, .00001);
    if (this.fpsElapsed >= .7) {
      this.fps = this.fpsFrames / this.fpsElapsed;
      this.adaptiveElapsed += this.fpsElapsed;
      this.fpsElapsed = 0;
      this.fpsFrames = 0;
      if (this.options.quality === 'balanced' && this.adaptiveElapsed > 2) {
        const previous = this.adaptiveRatio;
        if (this.fps < 22) this.adaptiveRatio = Math.max(.55, this.adaptiveRatio * .8);
        else if (this.fps > 52) this.adaptiveRatio = Math.min(1, this.adaptiveRatio * 1.1);
        this.adaptiveElapsed = 0;
        if (previous !== this.adaptiveRatio) this.resize();
      }
    }
  }

  focus(id: string): void {
    const visual = this.visuals.get(id);
    if (!visual) return;
    this.focusedId = id;
    this.recenter(visual.body.position);
    // Recenter is purely a coordinate transform. It never changes a body or its state.
    for (const current of this.visuals.values()) { this.toScene(current.body.position, current.group.position); this.updateTrail(current); }
    this.focusTarget.set(0, 0, 0);
    const direction = this.camera.position.clone().sub(this.controls.target).normalize();
    if (!direction.lengthSq()) direction.set(.65, .38, 1).normalize();
    this.focusPosition.copy(direction).multiplyScalar(Math.max(visual.radius * 5.2, .012));
    this.focusMoving = true;
    this.updateCameraPlanes();
    if (this.options.cameraMode === 'fly') {
      this.camera.position.copy(this.focusPosition);
      this.controls.target.copy(this.focusTarget);
      this.camera.lookAt(this.focusTarget);
      this.focusMoving = false;
    }
  }

  /** Fit genuine body centers and the current visible geometry, never invented orbits. */
  fitSystem(): void {
    const direction = this.camera.position.clone().sub(this.controls.target).normalize();
    if (!direction.lengthSq()) direction.set(.65, .55, 1).normalize();
    const bounds = new THREE.Box3();
    let minimumRadius = Infinity;
    for (const visual of this.visuals.values()) {
      const center = new THREE.Vector3(...visual.body.position);
      const radius = visual.radius * (visual.rings ? 2.6 : 1.05) / METRES_TO_SCENE;
      bounds.expandByPoint(center.clone().addScalar(radius));
      bounds.expandByPoint(center.clone().addScalar(-radius));
      minimumRadius = Math.min(minimumRadius, visual.radius);
    }
    const center = bounds.isEmpty() ? new THREE.Vector3() : bounds.getCenter(new THREE.Vector3());
    let radius = 0;
    for (const visual of this.visuals.values()) {
      radius = Math.max(radius, new THREE.Vector3(...visual.body.position).distanceTo(center) * METRES_TO_SCENE
        + visual.radius * (visual.rings ? 2.6 : 1.05));
    }
    this.recenter(center.toArray() as Vec3);
    this.focusedId = null;
    this.focusTarget.set(0, 0, 0);
    // The floating-origin change also refreshes geometry immediately before a new snapshot.
    for (const visual of this.visuals.values()) {
      this.toScene(visual.body.position, visual.group.position);
      this.updateTrail(visual);
      this.updateVectors(visual);
      visual.rings?.material.uniforms.uCenter.value.copy(visual.group.position);
    }
    const verticalHalfFov = THREE.MathUtils.degToRad(this.camera.fov / 2);
    let safeWidth = this.width;
    const hostRect = this.host.getBoundingClientRect();
    const middle = hostRect.left + hostRect.width / 2;
    // Reserve the visible side panels when embedded in the sandbox; generic hosts use full size.
    for (const panel of this.host.parentElement?.querySelectorAll<HTMLElement>('.cosmic-library,.cosmic-inspector') || []) {
      if (getComputedStyle(panel).display === 'none') continue;
      const rect = panel.getBoundingClientRect();
      const halfWidth = rect.right < middle ? middle - rect.right : rect.left > middle ? rect.left - middle : this.width / 2;
      safeWidth = Math.min(safeWidth, Math.max(this.width * .25, halfWidth * 2));
    }
    const horizontalHalfFov = Math.atan(Math.tan(verticalHalfFov) * safeWidth / this.height);
    const distance = radius > 0 ? radius / Math.sin(Math.min(verticalHalfFov, horizontalHalfFov)) * 1.25 : 150;
    this.focusPosition.copy(direction).multiplyScalar(Math.max(distance, .012));
    this.focusMoving = true;
    this.camera.near = Number.isFinite(minimumRadius) ? Math.max(.000001, Math.min(.002, minimumRadius * .012)) : .002;
    this.camera.far = Math.max(80_000, distance + radius * 3);
    this.controls.minDistance = Number.isFinite(minimumRadius) ? Math.max(minimumRadius * 1.16, .000003) : .006;
    this.controls.maxDistance = Math.max(20_000, distance * 3);
    this.camera.updateProjectionMatrix();
    if (this.options.cameraMode === 'fly') {
      this.camera.position.copy(this.focusPosition);
      this.controls.target.copy(this.focusTarget);
      this.camera.lookAt(this.focusTarget);
      this.focusMoving = false;
    }
  }

  resetCamera(): void {
    if (this.state && this.state.name !== 'Solar System') {
      this.fitSystem();
      return;
    }
    const anchor = this.state?.bodies.find(body => body.kind === 'star') || this.state?.bodies[0];
    if (anchor) this.recenter(anchor.position);
    this.focusedId = null;
    this.focusTarget.set(0, 0, 0);
    this.focusPosition.set(75, 78, 108);
    this.focusMoving = true;
    this.controls.target.set(0, 0, 0);
    this.updateCameraPlanes();
  }

  setOptions(options: RendererOptions): void {
    const prior = this.options;
    this.options = { ...prior, ...options };
    this.options.visibilityScale = THREE.MathUtils.clamp(this.options.visibilityScale, .1, 5);
    if (this.options.quality !== prior.quality) {
      this.adaptiveRatio = 1;
      this.adaptiveElapsed = 0;
      const old = this.sphere;
      this.sphere = this.options.quality === 'performance' ? new THREE.SphereGeometry(1, 32, 20)
        : this.options.quality === 'ultra' ? new THREE.SphereGeometry(1, 64, 40) : new THREE.SphereGeometry(1, 48, 32);
      for (const visual of this.visuals.values()) {
        if (visual.mesh.geometry === old) visual.mesh.geometry = this.sphere;
        if (visual.atmosphere) visual.atmosphere.geometry = this.sphere;
      }
      old.dispose();
    }
    this.bloom.enabled = this.hdr && this.options.quality !== 'performance';
    this.controls.enabled = this.options.cameraMode === 'orbit';
    this.keys.clear();
    this.resize();
    if (this.state) this.update(this.state, this.selectedId);
    if (this.options.trueScale !== prior.trueScale || this.options.visibilityScale !== prior.visibilityScale) {
      if (this.focusedId) this.focus(this.focusedId);
      this.updateCameraPlanes();
    }
  }

  getInfo(): { fps: number; drawCalls: number; triangles: number; scale: number; hdr: boolean; quality: Options['quality']; resolutionScale: number; activeBursts: number } {
    return { fps: this.fps, drawCalls: this.renderer.info.render.calls, triangles: this.renderer.info.render.triangles,
      scale: SCENE_UNITS_PER_AU, hdr: this.hdr, quality: this.options.quality, resolutionScale: this.adaptiveRatio, activeBursts: this.bursts.length };
  }

  /** Absolute, inertial SI camera coordinates are reconstructed from the floating origin. */
  getCameraState(): { positionAU: Vec3; targetAU: Vec3; positionMetres: Vec3; targetMetres: Vec3; mode: 'orbit' | 'fly'; focusedId: string | null; follow: boolean; trueScale: boolean; visibilityScale: number } {
    const position = this.camera.position.clone().multiplyScalar(1 / METRES_TO_SCENE).add(this.origin);
    const target = this.controls.target.clone().multiplyScalar(1 / METRES_TO_SCENE).add(this.origin);
    return {
      positionAU: position.clone().multiplyScalar(1 / AU_METRES).toArray() as Vec3,
      targetAU: target.clone().multiplyScalar(1 / AU_METRES).toArray() as Vec3,
      positionMetres: position.toArray() as Vec3, targetMetres: target.toArray() as Vec3,
      mode: this.options.cameraMode, focusedId: this.focusedId, follow: this.options.follow,
      trueScale: this.options.trueScale, visibilityScale: this.options.visibilityScale,
    };
  }

  getDisplayedRadius(id: string): number { return this.visuals.get(id)?.radius ?? 0; }

  /** Call before loading/importing a document, even when its epoch and body IDs match. */
  resetHistory(): void {
    this.clearTrails();
    this.clearBursts();
    this.clearHistoryOnNextUpdate = true;
  }

  /** Test/inspector helper: projected body center, plus genuine recorded trail count. */
  getBodyScreenPosition(id: string): { x: number; y: number; visible: boolean; radiusPixels: number; trailPoints: number } | null {
    const visual = this.visuals.get(id);
    if (!visual) return null;
    this.camera.updateMatrixWorld();
    const p = visual.group.position.clone().project(this.camera);
    const distance = this.camera.position.distanceTo(visual.group.position);
    return { x: (p.x * .5 + .5) * this.width, y: (-p.y * .5 + .5) * this.height,
      visible: Math.abs(p.x) < 1 && Math.abs(p.y) < 1 && p.z > -1 && p.z < 1,
      radiusPixels: visual.radius / Math.max(distance, .00001) * this.height / (2 * Math.tan(THREE.MathUtils.degToRad(this.camera.fov / 2))),
      trailPoints: visual.history.length };
  }

  resize(): void {
    if (this.disposed) return;
    const rect = this.host.getBoundingClientRect();
    this.width = Math.max(1, Math.round(rect.width));
    this.height = Math.max(1, Math.round(rect.height));
    const limit = this.options.quality === 'performance' ? 1 : this.options.quality === 'ultra' ? 2 : 1.35;
    const ratio = Math.min(window.devicePixelRatio || 1, limit) * this.adaptiveRatio;
    this.renderer.setPixelRatio(ratio);
    this.renderer.setSize(this.width, this.height, false);
    this.composer.setPixelRatio(ratio);
    this.composer.setSize(this.width, this.height);
    this.camera.aspect = this.width / this.height;
    this.camera.updateProjectionMatrix();
    this.starfield?.material.uniforms.uPixelRatio && (this.starfield.material.uniforms.uPixelRatio.value = ratio);
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.resizeObserver.disconnect();
    this.controls.removeEventListener('start', this.onControlsStart);
    this.controls.dispose();
    this.canvas.removeEventListener('pointerdown', this.onPointerDown);
    this.canvas.removeEventListener('pointerup', this.onPointerUp);
    this.canvas.removeEventListener('pointerenter', this.onPointerEnter);
    this.canvas.removeEventListener('pointerleave', this.onPointerLeave);
    this.canvas.removeEventListener('webglcontextlost', this.onContextLost);
    this.canvas.removeEventListener('webglcontextrestored', this.onContextRestored);
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    window.removeEventListener('blur', this.onBlur);
    for (const visual of this.visuals.values()) this.disposeVisual(visual);
    this.visuals.clear();
    this.clearBursts();
    this.sphere.dispose(); this.asteroid.dispose(); this.ringGeometry.dispose();
    this.starfield.geometry.dispose(); this.starfield.material.dispose();
    this.selectionHalo.geometry.dispose(); this.selectionHalo.material.dispose();
    this.composer.passes.forEach(pass => pass.dispose());
    this.composer.dispose();
    this.renderer.dispose();
    this.canvas.remove(); this.labels.remove();
  }

  private displayRadius(body: CelestialBody): number {
    const actual = Math.max(body.radius, 1) * METRES_TO_SCENE;
    if (this.options.trueScale) return actual;
    // A screen visibility aid, deliberately separate from physical collision/force radii.
    const visible = this.illustrativeRadius(body);
    let factor = 1;
    for (const other of this.state?.bodies || []) {
      if (other.id === body.id) continue;
      const separation = Math.hypot(...body.position.map((n, i) => n - other.position[i])) * METRES_TO_SCENE;
      // Shared pair factor preserves the illustrative size ratio and avoids false contact.
      factor = Math.min(factor, .82 * separation / (visible + this.illustrativeRadius(other)));
    }
    return Math.max(actual, visible * Math.max(0, factor));
  }

  private illustrativeRadius(body: CelestialBody): number {
    const visible = body.kind === 'star' ? 2.45 * Math.pow(body.radius / SOLAR_RADIUS, .42)
      : body.kind === 'asteroid' ? Math.max(.105, .55 * Math.pow(body.radius / EARTH_RADIUS, .42))
        : .64 * Math.pow(body.radius / EARTH_RADIUS, .42);
    return visible * this.options.visibilityScale;
  }

  private toScene(position: Vec3, target: THREE.Vector3): THREE.Vector3 {
    return target.set(position[0] - this.origin.x, position[1] - this.origin.y, position[2] - this.origin.z).multiplyScalar(METRES_TO_SCENE);
  }

  private recenter(position: Vec3, preserveAbsoluteCamera = true): void {
    const next = new THREE.Vector3(...position);
    const shift = next.clone().sub(this.origin).multiplyScalar(METRES_TO_SCENE);
    this.origin.copy(next);
    if (!preserveAbsoluteCamera) return;
    this.camera.position.sub(shift);
    this.controls.target.sub(shift);
    this.focusTarget.sub(shift);
    this.focusPosition.sub(shift);
  }

  private updateCameraPlanes(): void {
    const radius = this.focusedId ? this.visuals.get(this.focusedId)?.radius ?? 1 : 1;
    this.camera.near = Math.max(.000_001, Math.min(.002, radius * .012));
    this.camera.far = 80_000;
    this.controls.minDistance = Math.max(radius * 1.16, .000_003);
    this.camera.updateProjectionMatrix();
  }

  private makeBody(body: CelestialBody): BodyVisual {
    const group = new THREE.Group();
    const material = new THREE.ShaderMaterial({
      vertexShader: surfaceVertex, fragmentShader: body.kind === 'star' ? starFragment : planetFragment,
      uniforms: {
        uColor: { value: new THREE.Color(body.color) }, uLightDir: { value: new THREE.Vector3(1, 0, 0) },
        uLightColor: { value: new THREE.Color(1, .95, .87) }, uEye: { value: this.camera.position.clone() },
        uSeed: { value: body.seed * .0137 }, uTime: { value: 0 }, uSurface: { value: surfaceId(body) },
        uAtmosphere: { value: body.atmosphere }, uAlbedo: { value: body.albedo },
      },
    });
    const mesh = new THREE.Mesh(body.kind === 'asteroid' ? this.asteroid : this.sphere, material);
    mesh.userData.bodyId = body.id;
    group.add(mesh);
    const haloColor = body.kind === 'star' ? temperatureColor(body.temperature) : new THREE.Color(body.surface === 'gas' ? body.color : '#4c97ed');
    const atmosphere = new THREE.Mesh(this.sphere, new THREE.ShaderMaterial({
      vertexShader: surfaceVertex, fragmentShader: atmosphereFragment,
      uniforms: { uEye: { value: this.camera.position.clone() }, uLightDir: { value: new THREE.Vector3(1, 0, 0) },
        uColor: { value: haloColor }, uStrength: { value: body.atmosphere } },
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    atmosphere.renderOrder = 1;
    group.add(atmosphere);
    const label = document.createElement('div');
    label.dataset.bodyId = body.id;
    label.dataset.testid = 'body-label';
    Object.assign(label.style, { position: 'absolute', font: '500 10px/1.3 system-ui, sans-serif', letterSpacing: '.06em',
      color: '#b0bccb', whiteSpace: 'nowrap', textShadow: '0 1px 5px #000', padding: '2px 5px',
      borderRadius: '3px', transformOrigin: '0 0', background: 'rgba(3,7,13,.45)' });
    this.labels.append(label);
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(520 * 3), 3));
    geometry.setDrawRange(0, 0);
    const trail = new THREE.Line(geometry, new THREE.LineBasicMaterial({ color: body.color, transparent: true, opacity: .24, depthWrite: false }));
    trail.frustumCulled = false;
    this.scene.add(trail);
    const velocity = new THREE.ArrowHelper(new THREE.Vector3(1, 0, 0), new THREE.Vector3(), 1, 0x69c9ff, .3, .13);
    const force = new THREE.ArrowHelper(new THREE.Vector3(1, 0, 0), new THREE.Vector3(), 1, 0xffbc6a, .3, .13);
    this.scene.add(group, velocity, force);
    const visual: BodyVisual = { body, group, mesh, atmosphere, label, trail, history: [], velocity, force, radius: this.displayRadius(body) };
    if (/saturn|sao thổ/i.test(body.name)) {
      const rings = new THREE.Mesh(this.ringGeometry, new THREE.ShaderMaterial({
        vertexShader: surfaceVertex, fragmentShader: ringFragment, transparent: true, side: THREE.DoubleSide, depthWrite: false,
        uniforms: { uColor: { value: new THREE.Color('#beac86') }, uLightDir: { value: new THREE.Vector3(1, 0, 0) },
          uCenter: { value: new THREE.Vector3() }, uRadius: { value: visual.radius }, uSeed: { value: body.seed*.0137 } },
      }));
      rings.rotation.x = Math.PI / 2;
      rings.renderOrder = 1;
      group.add(rings);
      visual.rings = rings;
    }
    return visual;
  }

  private updateLight(visual: BodyVisual): void {
    if (!this.state) return;
    const stars = this.state.bodies.filter(body => body.kind === 'star' && body.id !== visual.body.id);
    let nearest: CelestialBody | undefined, minimum = Infinity;
    for (const star of stars) {
      const distance = star.position.reduce((sum, n, i) => sum + (n - visual.body.position[i]) ** 2, 0);
      if (distance < minimum) { minimum = distance; nearest = star; }
    }
    const direction = new THREE.Vector3(1, .4, 0).normalize();
    if (nearest) direction.set(...nearest.position).sub(new THREE.Vector3(...visual.body.position)).normalize();
    visual.mesh.material.uniforms.uLightDir.value.copy(direction);
    // Keep distant planets readable. This is exposure-normalized illustrative illumination.
    visual.mesh.material.uniforms.uLightColor.value.copy(nearest ? temperatureColor(nearest.temperature) : new THREE.Color(.28, .32, .42));
    visual.atmosphere?.material.uniforms.uLightDir.value.copy(direction);
    visual.rings?.material.uniforms.uLightDir.value.copy(direction);
  }

  private updateTrail(visual: BodyVisual): void {
    const attribute = visual.trail.geometry.getAttribute('position') as THREE.BufferAttribute;
    for (let i = 0; i < visual.history.length; i++) {
      this.toScene(visual.history[i], this.scratch);
      attribute.setXYZ(i, this.scratch.x, this.scratch.y, this.scratch.z);
    }
    attribute.needsUpdate = true;
    visual.trail.geometry.setDrawRange(0, visual.history.length);
    visual.trail.visible = this.options.trails && visual.history.length > 1;
  }

  private updateVectors(visual: BodyVisual): void {
    const velocity = new THREE.Vector3(...visual.body.velocity);
    visual.velocity.visible = this.options.vectors && velocity.lengthSq() > 0;
    visual.velocity.position.copy(visual.group.position);
    if (visual.velocity.visible) {
      const speed = velocity.length();
      visual.velocity.setDirection(velocity.normalize());
      const length = Math.max(visual.radius * 1.5, Math.min(8, Math.log10(1 + speed) * .6));
      visual.velocity.setLength(length, length*.19, length*.08);
    }
    const acceleration = new THREE.Vector3();
    for (const body of this.state?.bodies || []) {
      if (body.id === visual.body.id) continue;
      const direction = new THREE.Vector3(...body.position).sub(new THREE.Vector3(...visual.body.position));
      const d2 = direction.lengthSq();
      if (d2 > 0) acceleration.addScaledVector(direction, 6.67430e-11 * body.mass / (d2 * Math.sqrt(d2)));
    }
    visual.force.visible = this.options.vectors && acceleration.lengthSq() > 0;
    visual.force.position.copy(visual.group.position);
    if (visual.force.visible) {
      const length = Math.max(visual.radius * 1.5, Math.min(8, Math.log10(1 + acceleration.length() * 100) * 2));
      visual.force.setDirection(acceleration.normalize());
      visual.force.setLength(length, length*.19, length*.08);
    }
  }

  private updateLabels(): void {
    const occupied: { x: number; y: number; width: number }[] = [];
    const ordered = [...this.visuals.values()].sort((a, b) => Number(b.body.id === this.selectedId) - Number(a.body.id === this.selectedId));
    for (const visual of ordered) {
      this.projected.copy(visual.group.position).project(this.camera);
      const show = this.options.labels && this.projected.z > -1 && this.projected.z < 1
        && Math.abs(this.projected.x) < 1.04 && Math.abs(this.projected.y) < 1.04;
      visual.label.style.display = show ? 'block' : 'none';
      if (show) {
        const distance = this.camera.position.distanceTo(visual.group.position);
        const radiusPixels = visual.radius / Math.max(distance, .0001) * this.height / (2 * Math.tan(THREE.MathUtils.degToRad(this.camera.fov / 2)));
        const x = (this.projected.x*.5+.5)*this.width + Math.min(radiusPixels+7, 95);
        const y = (-this.projected.y*.5+.5)*this.height - 7;
        const width = visual.body.name.length * 6 + 10;
        if (occupied.some(box => Math.abs(box.y-y)<17 && x<box.x+box.width && x+width>box.x)) {
          visual.label.style.display = 'none';
          continue;
        }
        occupied.push({x,y,width});
        visual.label.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`;
      }
    }
  }

  private makeStarfield(): THREE.Points<THREE.BufferGeometry, THREE.ShaderMaterial> {
    const random = seeded(2026114);
    const count = 4300;
    const positions = new Float32Array(count*3), colors = new Float32Array(count*3);
    const sizes = new Float32Array(count), phases = new Float32Array(count);
    for (let i=0; i<count; i++) {
      const z = random()*2-1, angle=random()*Math.PI*2, radial=Math.sqrt(1-z*z);
      const radius=5500+random()*1600;
      positions.set([radial*Math.cos(angle)*radius, z*radius, radial*Math.sin(angle)*radius], i*3);
      const bright=.12+Math.pow(random(),6)*.95;
      const tint=random();
      colors.set([bright*(tint>.7?1:.73), bright*.84, bright*(tint<.2?1.1:.78)], i*3);
      sizes[i]=random()<.022?3.2: .75+random()*1.15;
      phases[i]=random()*Math.PI*2;
    }
    const geometry=new THREE.BufferGeometry();
    geometry.setAttribute('position',new THREE.BufferAttribute(positions,3));
    geometry.setAttribute('color',new THREE.BufferAttribute(colors,3));
    geometry.setAttribute('aSize',new THREE.BufferAttribute(sizes,1));
    geometry.setAttribute('aPhase',new THREE.BufferAttribute(phases,1));
    const material=new THREE.ShaderMaterial({ vertexShader: starfieldVertex, fragmentShader: starfieldFragment,
      uniforms: { uWallTime: { value: 0 }, uPixelRatio: { value: 1 } },
      vertexColors: true, transparent: true, depthWrite: false, depthTest: true, blending: THREE.AdditiveBlending });
    const cloud=new THREE.Points(geometry,material);
    cloud.frustumCulled=false;
    return cloud;
  }

  private makeBurst(position: Vec3, id: number): void {
    if (this.bursts.length > 7) return;
    const random=seeded(id*12317+18), count=this.options.quality==='performance'?150:450;
    const geometry=new THREE.BufferGeometry();
    const velocities=new Float32Array(count*3), sizes=new Float32Array(count);
    for (let i=0;i<count;i++) {
      const z=random()*2-1, a=random()*Math.PI*2, r=Math.sqrt(1-z*z), speed=.3+random()*2.5;
      velocities.set([r*Math.cos(a)*speed,z*speed,r*Math.sin(a)*speed],i*3);
      sizes[i]=1.8+random()*4;
    }
    geometry.setAttribute('position',new THREE.BufferAttribute(new Float32Array(count*3),3));
    geometry.setAttribute('aVelocity',new THREE.BufferAttribute(velocities,3));
    geometry.setAttribute('aSize',new THREE.BufferAttribute(sizes,1));
    const material=new THREE.ShaderMaterial({ vertexShader: particlesVertex, fragmentShader: particlesFragment,
      uniforms: { uAge: { value: 0 }, uPixelRatio: { value: this.renderer.getPixelRatio() } },
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
    const cloud=new THREE.Points(geometry,material);
    cloud.frustumCulled=false;
    this.toScene(position,cloud.position);
    this.scene.add(cloud);
    this.bursts.push({cloud,position:[...position],started:this.wallTime});
  }

  private clearTrails(): void {
    for (const visual of this.visuals.values()) { visual.history=[]; visual.trail.geometry.setDrawRange(0,0); }
  }

  private clearBursts(): void {
    for (const burst of this.bursts) { this.scene.remove(burst.cloud); burst.cloud.geometry.dispose(); burst.cloud.material.dispose(); }
    this.bursts.length=0;
  }

  private disposeVisual(visual: BodyVisual): void {
    this.scene.remove(visual.group,visual.trail,visual.velocity,visual.force);
    visual.mesh.material.dispose(); visual.atmosphere?.material.dispose(); visual.rings?.material.dispose();
    visual.trail.geometry.dispose(); visual.trail.material.dispose();
    visual.velocity.dispose(); visual.force.dispose(); visual.label.remove();
  }

  private updateFly(delta: number): void {
    this.camera.getWorldDirection(this.forward);
    this.right.crossVectors(this.forward,this.up).normalize();
    const distance=this.focusedId ? this.camera.position.distanceTo(this.visuals.get(this.focusedId)?.group.position || new THREE.Vector3()) : this.camera.position.length();
    const speed=Math.max(.008,Math.min(250,distance*.55)) * (this.keys.has('ShiftLeft')||this.keys.has('ShiftRight')?3:1)*delta;
    const displacement=new THREE.Vector3();
    if(this.keys.has('KeyW')) displacement.add(this.forward);
    if(this.keys.has('KeyS')) displacement.sub(this.forward);
    if(this.keys.has('KeyD')) displacement.add(this.right);
    if(this.keys.has('KeyA')) displacement.sub(this.right);
    if(this.keys.has('KeyE')) displacement.add(this.up);
    if(this.keys.has('KeyQ')) displacement.sub(this.up);
    if(displacement.lengthSq()) { displacement.normalize().multiplyScalar(speed); this.camera.position.add(displacement); this.controls.target.add(displacement); }
  }

  private readonly onControlsStart = (): void => { this.focusMoving=false; };
  private readonly onPointerEnter = (): void => { this.keyboardActive=true; };
  private readonly onPointerLeave = (): void => { this.keyboardActive=false; };
  private readonly onPointerDown = (event: PointerEvent): void => {
    this.pointerStart=[event.clientX,event.clientY];
    this.canvas.focus({preventScroll:true});
    if(this.options.cameraMode==='fly') { this.focusMoving=false; this.canvas.setPointerCapture(event.pointerId); this.canvas.addEventListener('pointermove',this.onFlyPointerMove); }
  };
  private readonly onFlyPointerMove = (event: PointerEvent): void => {
    if(!event.buttons||this.options.cameraMode!=='fly') return;
    const euler=new THREE.Euler().setFromQuaternion(this.camera.quaternion,'YXZ');
    euler.y-=event.movementX*.003;
    euler.x=THREE.MathUtils.clamp(euler.x-event.movementY*.003,-Math.PI*.49,Math.PI*.49);
    this.camera.quaternion.setFromEuler(euler);
    this.camera.getWorldDirection(this.scratch);
    this.controls.target.copy(this.camera.position).addScaledVector(this.scratch,1);
  };
  private readonly onPointerUp = (event: PointerEvent): void => {
    this.canvas.removeEventListener('pointermove',this.onFlyPointerMove);
    if(!this.pointerStart) return;
    const moved=Math.hypot(event.clientX-this.pointerStart[0],event.clientY-this.pointerStart[1]);
    this.pointerStart=null;
    if(moved>5||event.button!==0) return;
    const rect=this.canvas.getBoundingClientRect();
    this.pointer.set((event.clientX-rect.left)/rect.width*2-1,-(event.clientY-rect.top)/rect.height*2+1);
    this.raycaster.setFromCamera(this.pointer,this.camera);
    const hits=this.raycaster.intersectObjects([...this.visuals.values()].map(visual=>visual.mesh));
    if(hits[0]) { this.onSelect(hits[0].object.userData.bodyId as string); return; }
    // Tiny true-size bodies remain selectable by a small screen-space hit allowance.
    let closest:string|null=null,best=9;
    for(const [id] of this.visuals) {
      const location=this.getBodyScreenPosition(id);
      if(location?.visible) { const d=Math.hypot(location.x-(event.clientX-rect.left),location.y-(event.clientY-rect.top)); if(d<best) {closest=id;best=d;} }
    }
    if(closest) this.onSelect(closest);
  };
  private readonly onKeyDown = (event: KeyboardEvent): void => {
    if(!this.keyboardActive && document.activeElement!==this.canvas) return;
    if(event.target instanceof HTMLElement && (event.target.matches('input,textarea,select')||event.target.isContentEditable)) return;
    if(this.options.cameraMode==='fly'&&['KeyW','KeyA','KeyS','KeyD','KeyQ','KeyE','ShiftLeft','ShiftRight'].includes(event.code)) { event.preventDefault(); this.keys.add(event.code); }
  };
  private readonly onKeyUp = (event: KeyboardEvent): void => { this.keys.delete(event.code); };
  private readonly onBlur = (): void => { this.keys.clear(); };
  private readonly onContextLost = (event: Event): void => { event.preventDefault(); this.contextLost=true; };
  private readonly onContextRestored = (): void => { this.contextLost=false; this.resize(); };
}
