import test from 'node:test';
import assert from 'node:assert/strict';
import { AU, DAY, G, MEARTH, MSUN, YEAR } from '../src/cosmic/physics/constants.ts';
import { GravitySolver } from '../src/cosmic/physics/gravity.ts';
import { makeState, newBody, SimulationEngine, validateState } from '../src/cosmic/physics/engine.ts';
import { PRESETS, createSolarSystem } from '../src/cosmic/presets.ts';
import type { SimulationState } from '../src/cosmic/types.ts';

function run(engine: SimulationEngine, duration: number): SimulationState {
  const end = engine.snapshot().time + duration;
  let state = engine.snapshot();
  let batches = 0;
  while (state.time < end - 1e-5) {
    state = engine.advance(end - state.time, 2048);
    assert.ok(state.diagnostics.simulatedSeconds > 0, 'simulation must make forward progress');
    assert.ok(++batches < 500, 'integration must converge within its test budget');
  }
  return state;
}

function twoBody(eccentricity = 0, velocityFactor = 1): SimulationEngine {
  const separation = AU * (1 - eccentricity);
  const speed = Math.sqrt(G * (MSUN + MEARTH) / AU * (1 + eccentricity) / (1 - eccentricity)) * velocityFactor;
  const fraction = MEARTH / (MSUN + MEARTH);
  return new SimulationEngine(makeState('Two bodies', [
    newBody({ id: 'sun', name: 'Sun', kind: 'star', mass: MSUN, radius: 695700000,
      position: [-separation * fraction, 0, 0], velocity: [0, 0, -speed * fraction] }),
    newBody({ id: 'earth', name: 'Earth', position: [separation * (1 - fraction), 0, 0], velocity: [0, 0, speed * (1 - fraction)] }),
  ]));
}

function relative(state: SimulationState): number[] {
  return state.bodies[1].position.map((v, k) => v - state.bodies[0].position[k]);
}

test('Earth completes a year with a bounded orbit and conserved energy', () => {
  const state = run(twoBody(), YEAR);
  const delta = relative(state);
  assert.ok(Math.abs(Math.hypot(...delta) / AU - 1) < 1e-6);
  assert.ok(Math.hypot(delta[0] - AU, delta[1], delta[2]) / AU < 3e-4);
  assert.ok(Math.abs(state.diagnostics.energyDrift) < 1e-8);
});

test('Moon returns after its Kepler period without falling into Earth', () => {
  const engine = new SimulationEngine(PRESETS.find((p) => p.id === 'earthmoon')!.create());
  const initial = engine.snapshot();
  const start = relative(initial);
  const semimajor = 384400000;
  const period = 2 * Math.PI * Math.sqrt(semimajor ** 3 / (G * initial.bodies.reduce((m, b) => m + b.mass, 0)));
  const state = run(engine, period);
  assert.equal(state.bodies.length, 2);
  const delta = relative(state);
  assert.ok(Math.hypot(...delta.map((v, k) => v - start[k])) / semimajor < 0.001);
  assert.ok(Math.abs(state.diagnostics.energyDrift) < 1e-6);
});

test('Changing the Sun mass changes force and the orbit immediately', () => {
  const solver = new GravitySolver();
  const base = twoBody().snapshot();
  const initial = solver.accelerations(base.bodies)[3];
  base.bodies[0].mass *= 2;
  const changed = solver.accelerations(base.bodies)[3];
  assert.ok(Math.abs(changed / initial - 2) < 1e-14);
  const normal = run(twoBody(), 30 * DAY);
  const heavier = run(new SimulationEngine(base), 30 * DAY);
  assert.ok(Math.hypot(...relative(normal).map((v, k) => v - relative(heavier)[k])) > AU * 0.1);
});

test('A ten-year eccentric orbit has bounded energy error without artificial decay', () => {
  const engine = twoBody(0.6);
  const initialEnergy = engine.snapshot().diagnostics.energy;
  let peak = 0;
  for (let i = 0; i < 40; i++) {
    const state = run(engine, YEAR / 4);
    peak = Math.max(peak, Math.abs((state.diagnostics.energy - initialEnergy) / initialEnergy));
    assert.equal(state.bodies.length, 2);
  }
  const final = engine.snapshot();
  assert.ok(peak < 8e-5, `bounded relative energy error ${peak}`);
  assert.ok(Math.abs(Math.hypot(...relative(final)) / AU - 0.4) < 0.003);
});

test('A body above escape velocity leaves rather than being forced into an orbit', () => {
  const state = run(twoBody(0, Math.SQRT2 * 1.25), YEAR);
  assert.ok(state.diagnostics.energy > 0);
  assert.ok(Math.hypot(...relative(state)) > 7 * AU);
  assert.ok(Math.abs(state.diagnostics.energyDrift) < 2e-6);
});

test('High-speed collision merges volume and mass and conserves linear momentum', () => {
  const left = newBody({ id: 'left', name: 'Left', mass: 2e10, radius: 1000, position: [-10000, 0, 0], velocity: [10000, 200, 0] });
  const right = newBody({ id: 'right', name: 'Right', mass: 3e10, radius: 1000, position: [10000, 0, 0], velocity: [-10000, 200, 0] });
  const engine = new SimulationEngine(makeState('Impact', [left, right]));
  const initialMomentum = engine.snapshot().diagnostics.momentum;
  const state = engine.advance(5);
  assert.equal(state.bodies.length, 1);
  assert.equal(state.events.length, 1);
  assert.equal(state.bodies[0].mass, 5e10);
  assert.ok(Math.abs(state.bodies[0].radius - Math.cbrt(2e9)) < 1e-9);
  for (let k = 0; k < 3; k++) assert.ok(Math.abs(state.diagnostics.momentum[k] - initialMomentum[k]) < Math.max(1, Math.abs(initialMomentum[k]) * 1e-12));
  assert.ok(state.events[0].energy > 0);
  assert.ok(Math.abs(state.diagnostics.energyDrift) < 1e-12, 'collision resets the conservative energy reference');
});

test('Adaptive close-orbit steps are finite and a work budget never skips simulated time', () => {
  const sun = newBody({ id: 'sun', mass: MSUN, radius: 695700000 });
  const separation = 2e9;
  const planet = newBody({ id: 'planet', mass: MEARTH, position: [separation, 0, 0], velocity: [0, 0, Math.sqrt(G * MSUN / separation)] });
  const engine = new SimulationEngine(makeState('Close orbit', [sun, planet]));
  const state = engine.advance(YEAR, 16);
  assert.equal(state.diagnostics.lastSubsteps, 16);
  assert.equal(state.diagnostics.limited, true);
  assert.equal(state.time, state.diagnostics.simulatedSeconds);
  assert.ok(state.time < YEAR);
  assert.ok(state.diagnostics.minStep > 0 && state.diagnostics.minStep < 100);
  assert.ok(state.bodies.flatMap((b) => [...b.position, ...b.velocity]).every(Number.isFinite));
});

test('Solar preset has ten realistic SI bodies and a nearly resting barycenter', () => {
  const state = createSolarSystem();
  assert.equal(state.bodies.length, 10);
  assert.equal(state.bodies.find((b) => b.id === 'earth')!.mass, MEARTH);
  assert.ok(Math.abs(state.bodies.find((b) => b.id === 'moon')!.radius - 1737400) < 1);
  const scale = state.bodies.reduce((total, b) => total + b.mass * Math.hypot(...b.velocity), 0);
  assert.ok(Math.hypot(...state.diagnostics.momentum) / scale < 1e-14);
  const engine = new SimulationEngine(state);
  const advanced = engine.advance(30 * DAY, 512);
  assert.equal(advanced.bodies.length, 10);
  assert.ok(advanced.time > 0);
  assert.ok(Math.abs(advanced.diagnostics.energyDrift) < 1e-5);
});

test('Validation rejects poisoned, nonfinite, duplicate and excessive JSON inputs', () => {
  const state = createSolarSystem();
  const bad = JSON.parse(JSON.stringify(state));
  bad.bodies[0].mass = '1e30';
  assert.throws(() => validateState(bad), /finite/);
  bad.bodies[0].mass = NaN;
  assert.throws(() => validateState(bad), /finite/);
  const duplicate = JSON.parse(JSON.stringify(state));
  duplicate.bodies[1].id = duplicate.bodies[0].id;
  assert.throws(() => validateState(duplicate), /unique/);
  assert.throws(() => validateState(JSON.parse('{"schemaVersion":1,"__proto__":{}}')), /unsafe/);
  assert.throws(() => validateState({ ...state, bodies: Array.from({ length: 129 }, () => state.bodies[0]) }), /128/);
  assert.throws(() => validateState({ ...state, schemaVersion: 2 }), /Unsupported/);
});

test('Snapshots, imported state and failed mutations are isolated from engine state', () => {
  const input = createSolarSystem();
  const engine = new SimulationEngine(input);
  input.bodies[0].mass = 1;
  const snap = engine.snapshot();
  snap.bodies[0].position[0] = 1e20;
  assert.equal(engine.snapshot().bodies[0].mass, MSUN);
  assert.notEqual(engine.snapshot().bodies[0].position[0], 1e20);
  assert.throws(() => engine.edit('earth', { mass: -1 }), /finite/);
  assert.equal(engine.snapshot().bodies.find((b) => b.id === 'earth')!.mass, MEARTH);
  const beforeEdit = engine.snapshot().diagnostics;
  const edited = engine.edit('sun', { mass: MSUN * 2 });
  assert.ok(edited.diagnostics.potential < beforeEdit.potential * 1.9, 'paused mass edits immediately recompute potential');
  assert.notEqual(edited.diagnostics.energy, beforeEdit.energy);
  assert.equal(edited.diagnostics.energyDrift, 0);
  const state = engine.advance(DAY);
  assert.deepEqual(validateState(JSON.parse(JSON.stringify(state))), state);
});
