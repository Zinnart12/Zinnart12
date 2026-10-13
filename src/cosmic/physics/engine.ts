import type { BodyPatch, CelestialBody, CollisionEvent, Diagnostics, SimulationState, Vec3 } from '../types.ts';
import { MAX_BODIES, MEARTH, REARTH } from './constants.ts';
import { GravitySolver } from './gravity.ts';

const solver = new GravitySolver();
const KINDS = new Set(['star', 'planet', 'moon', 'asteroid']);
const SURFACES = new Set(['earth', 'rocky', 'gas', 'ice', 'lava', 'ocean']);
let bodySequence = 0;

function object(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${label} must be an object.`);
  const prototype = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) throw new Error(`${label} must contain plain data.`);
  for (const key of ['__proto__', 'constructor', 'prototype']) {
    if (Object.hasOwn(value, key)) throw new Error(`${label} contains an unsafe key.`);
  }
  return value as Record<string, unknown>;
}
function number(value: unknown, label: string, min: number, max: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) {
    throw new Error(`${label} must be finite and between ${min} and ${max}.`);
  }
  return value;
}
function string(value: unknown, label: string, max = 120): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw new Error(`${label} is invalid.`);
  return value;
}
function vector(value: unknown, label: string, limit: number): Vec3 {
  if (!Array.isArray(value) || value.length !== 3) throw new Error(`${label} must have three coordinates.`);
  return value.map((v) => number(v, label, -limit, limit)) as Vec3;
}
function validateBody(input: unknown): CelestialBody {
  const b = object(input, 'Body');
  const kind = string(b.kind, 'Kind'), surface = string(b.surface, 'Surface');
  if (!KINDS.has(kind) || !SURFACES.has(surface)) throw new Error('Unknown body kind or surface.');
  const color = string(b.color, 'Color', 7);
  if (!/^#[0-9a-fA-F]{6}$/.test(color)) throw new Error('Color must be a six-digit hex color.');
  return {
    id: string(b.id, 'ID', 100), name: string(b.name, 'Name', 100),
    kind: kind as CelestialBody['kind'], surface: surface as CelestialBody['surface'],
    mass: number(b.mass, 'Mass (kg)', 1e-6, 1e35), radius: number(b.radius, 'Radius (m)', 1e-3, 1e18),
    position: vector(b.position, 'Position (m)', 1e22), velocity: vector(b.velocity, 'Velocity (m/s)', 1e9),
    temperature: number(b.temperature, 'Temperature (K)', 0, 1e9),
    rotationPeriod: number(b.rotationPeriod, 'Rotation period (s)', -1e15, 1e15),
    axialTilt: number(b.axialTilt, 'Axial tilt (degrees)', -360, 360),
    albedo: number(b.albedo, 'Albedo', 0, 1), atmosphere: number(b.atmosphere, 'Atmosphere', 0, 1000),
    composition: string(b.composition, 'Composition', 400), color,
    seed: number(b.seed, 'Seed', 0, 0xffffffff),
  };
}

export function newBody(overrides: Partial<CelestialBody> = {}): CelestialBody {
  object(overrides, 'Body properties');
  return validateBody({
    id: `body-${Date.now().toString(36)}-${++bodySequence}`, name: 'New planet', kind: 'planet', surface: 'rocky',
    mass: MEARTH, radius: REARTH, position: [0, 0, 0], velocity: [0, 0, 0], temperature: 288,
    rotationPeriod: 86400, axialTilt: 23.44, albedo: 0.3, atmosphere: 1,
    composition: 'Silicate rock and iron', color: '#8ebde8', seed: bodySequence, ...overrides,
  });
}

/** Validate plain saved data and return detached copies. Diagnostics never control integration. */
export function validateState(input: unknown): SimulationState {
  const s = object(input, 'Simulation');
  if (s.schemaVersion !== 1) throw new Error('Unsupported simulation format; expected schemaVersion 1.');
  if (!Array.isArray(s.bodies) || s.bodies.length > MAX_BODIES) throw new Error(`A simulation supports at most ${MAX_BODIES} bodies.`);
  const bodies = s.bodies.map(validateBody);
  if (new Set(bodies.map((b) => b.id)).size !== bodies.length) throw new Error('Body IDs must be unique.');
  const events: CollisionEvent[] = [];
  if (s.events !== undefined && !Array.isArray(s.events)) throw new Error('Collision events must be an array.');
  if (Array.isArray(s.events)) {
    if (s.events.length > 64) throw new Error('Too many saved collision events.');
    for (const inputEvent of s.events) {
      const e = object(inputEvent, 'Collision event');
      if (!Array.isArray(e.names) || e.names.length !== 2) throw new Error('Collision event needs two names.');
      events.push({ id: number(e.id, 'Event ID', 0, Number.MAX_SAFE_INTEGER),
        time: number(e.time, 'Event time', 0, 1e15), position: vector(e.position, 'Event position', 1e22),
        names: [string(e.names[0], 'Event name', 100), string(e.names[1], 'Event name', 100)],
        energy: number(e.energy, 'Impact energy', 0, 1e100), survivorId: string(e.survivorId, 'Survivor ID', 100) });
    }
  }
  const steps = number(s.steps, 'Steps', 0, Number.MAX_SAFE_INTEGER);
  if (!Number.isInteger(steps)) throw new Error('Steps must be an integer.');
  let diagnostics: Diagnostics = solver.diagnostics(bodies);
  if (s.diagnostics !== undefined) {
    const d = object(s.diagnostics, 'Diagnostics');
    if (typeof d.limited !== 'boolean') throw new Error('Diagnostic limited flag must be boolean.');
    diagnostics = {
      energy: number(d.energy, 'Energy', -1e100, 1e100), kinetic: number(d.kinetic, 'Kinetic energy', 0, 1e100),
      potential: number(d.potential, 'Potential energy', -1e100, 0), momentum: vector(d.momentum, 'Momentum', 1e100),
      energyDrift: number(d.energyDrift, 'Energy drift', -1e100, 1e100), minStep: number(d.minStep, 'Minimum step', 0, 1e15),
      lastSubsteps: number(d.lastSubsteps, 'Last substeps', 0, Number.MAX_SAFE_INTEGER),
      simulatedSeconds: number(d.simulatedSeconds, 'Simulated seconds', 0, 1e15),
      requestedSeconds: number(d.requestedSeconds, 'Requested seconds', 0, 1e15), limited: d.limited,
    };
  }
  return { schemaVersion: 1, name: string(s.name, 'Simulation name'),
    time: number(s.time, 'Simulation time (s)', 0, 1e15), steps, bodies, events,
    diagnostics };
}

export function makeState(name: string, bodies: CelestialBody[]): SimulationState {
  return validateState({ schemaVersion: 1, name, time: 0, steps: 0, bodies, events: [] });
}

function copyState(s: SimulationState): SimulationState {
  return { ...s, bodies: s.bodies.map((b) => ({ ...b, position: [...b.position], velocity: [...b.velocity] })),
    events: s.events.map((e) => ({ ...e, names: [...e.names], position: [...e.position] })),
    diagnostics: { ...s.diagnostics, momentum: [...s.diagnostics.momentum] } };
}

/** Perfectly inelastic contact model: conserved mass, volume and linear momentum. */
function mergeContacts(state: SimulationState, previous?: Map<string, Vec3>): boolean {
  let merged = false;
  let searching = true;
  while (searching) {
    searching = false;
    pair: for (let i = 0; i < state.bodies.length; i++) for (let j = i + 1; j < state.bodies.length; j++) {
      const a = state.bodies[i], b = state.bodies[j];
      const contact = a.radius + b.radius;
      const d = b.position.map((p, k) => p - a.position[k]);
      let collision = Math.hypot(...d) <= contact;
      const pa = previous?.get(a.id), pb = previous?.get(b.id);
      if (!collision && pa && pb) {
        // Swept sphere contact catches a fast or grazing passage between step endpoints.
        const start = pb.map((p, k) => p - pa[k]);
        const delta = d.map((p, k) => p - start[k]);
        const denominator = delta.reduce((sum, p) => sum + p * p, 0);
        const fraction = denominator > 0 ? Math.min(1, Math.max(0, -start.reduce((sum, p, k) => sum + p * delta[k], 0) / denominator)) : 0;
        collision = Math.hypot(...start.map((p, k) => p + delta[k] * fraction)) <= contact;
      }
      if (!collision) continue;
      const mass = a.mass + b.mass;
      const primary = a.mass >= b.mass ? a : b;
      const relative2 = a.velocity.reduce((sum, v, k) => sum + (v - b.velocity[k]) ** 2, 0);
      const energy = 0.5 * a.mass * b.mass / mass * relative2;
      const position = a.position.map((p, k) => (p * a.mass + b.position[k] * b.mass) / mass) as Vec3;
      const velocity = a.velocity.map((v, k) => (v * a.mass + b.velocity[k] * b.mass) / mass) as Vec3;
      const body: CelestialBody = { ...primary, mass, radius: Math.cbrt(a.radius ** 3 + b.radius ** 3),
        position, velocity, temperature: Math.min(1e9, (a.temperature * a.mass + b.temperature * b.mass) / mass + energy / (1000 * mass)) };
      state.events.push({ id: (state.events.at(-1)?.id ?? 0) + 1, time: state.time,
        position: [...position], names: [a.name, b.name], energy, survivorId: body.id });
      state.events = state.events.slice(-64);
      state.bodies[i] = body;
      state.bodies.splice(j, 1);
      previous?.delete(a.id); previous?.delete(b.id);
      merged = searching = true;
      break pair;
    }
  }
  return merged;
}

export class SimulationEngine {
  private state: SimulationState;
  private baseline: number;
  private gravity = new GravitySolver();

  constructor(state: SimulationState) {
    this.state = validateState(state);
    this.state.diagnostics = this.gravity.diagnostics(this.state.bodies);
    this.baseline = this.state.diagnostics.energy;
  }

  load(state: SimulationState): SimulationState {
    const checked = validateState(state);
    checked.diagnostics = this.gravity.diagnostics(checked.bodies);
    this.state = checked;
    this.baseline = checked.diagnostics.energy;
    return this.snapshot();
  }

  snapshot(): SimulationState { return copyState(this.state); }

  edit(id: string, patch: BodyPatch): SimulationState {
    object(patch, 'Body patch');
    if (Object.hasOwn(patch, 'id')) throw new Error('A body ID cannot be edited.');
    const next = this.snapshot();
    const index = next.bodies.findIndex((body) => body.id === id);
    if (index < 0) throw new Error('Body not found.');
    next.bodies[index] = validateBody({ ...next.bodies[index], ...patch });
    return this.load(next);
  }

  add(body: CelestialBody): SimulationState {
    const next = this.snapshot();
    next.bodies.push(validateBody(body));
    return this.load(next);
  }

  remove(id: string): SimulationState {
    const next = this.snapshot();
    next.bodies = next.bodies.filter((body) => body.id !== id);
    return this.load(next);
  }

  /** The returned clock advances only by completed steps; a budget never skips physics. */
  advance(seconds: number, maxSteps = 512): SimulationState {
    number(seconds, 'Requested seconds', 0, 1e15);
    number(maxSteps, 'Substep budget', 1, 4096);
    if (!Number.isInteger(maxSteps)) throw new Error('Substep budget must be an integer.');
    const next = this.snapshot();
    let baseline = this.baseline;
    if (mergeContacts(next)) baseline = this.gravity.diagnostics(next.bodies).energy;
    let completed = 0, substeps = 0, minStep = Infinity;
    while (completed < seconds && substeps < maxSteps) {
      const remaining = seconds - completed;
      const step = Math.min(remaining, this.gravity.stableStep(next.bodies), 1e15 - next.time);
      if (next.steps >= Number.MAX_SAFE_INTEGER) break;
      if (!(step > 0) || !Number.isFinite(step) || next.time + step === next.time) break;
      const previous = new Map(next.bodies.map((body) => [body.id, [...body.position] as Vec3]));
      this.gravity.step(next.bodies, step);
      for (const body of next.bodies) {
        if (![...body.position, ...body.velocity].every(Number.isFinite)) throw new Error('Numerical overflow; choose smaller masses or speeds.');
      }
      completed += step; next.time += step; next.steps++; substeps++;
      minStep = Math.min(minStep, step);
      if (mergeContacts(next, previous)) baseline = this.gravity.diagnostics(next.bodies).energy;
    }
    const diagnostics = this.gravity.diagnostics(next.bodies, baseline);
    if (![diagnostics.energy, ...diagnostics.momentum, next.time].every(Number.isFinite)) throw new Error('Simulation exceeded numeric limits.');
    next.diagnostics = { ...diagnostics, minStep: Number.isFinite(minStep) ? minStep : 0,
      lastSubsteps: substeps, simulatedSeconds: completed, requestedSeconds: seconds,
      limited: completed < seconds - Math.max(1e-9, seconds * 1e-12) };
    // Commit transactionally only if all generated values remain exportable and finite.
    this.state = validateState(next);
    this.baseline = baseline;
    return this.snapshot();
  }
}
