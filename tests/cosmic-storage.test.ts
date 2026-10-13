import assert from 'node:assert/strict';
import test from 'node:test';
import { SaveLoadManager } from '../src/cosmic/SaveLoadManager.ts';
import { TimeController } from '../src/cosmic/TimeController.ts';
import type { SimulationState } from '../src/cosmic/types.ts';

function fixture(): SimulationState {
  return {
    schemaVersion: 1,
    name: 'Trái Đất thử nghiệm',
    time: 1234,
    steps: 5,
    bodies: [{
      id: 'earth', name: 'Trái Đất', kind: 'planet', surface: 'earth',
      mass: 5.9722e24, radius: 6371000, position: [1.495978707e11, 0, 0],
      velocity: [0, 0, 29780], temperature: 288, rotationPeriod: 86164,
      axialTilt: 0.4091, albedo: 0.3, atmosphere: 1, composition: 'silicate',
      color: '#66aaff', seed: 12,
    }],
    events: [{ id: 1, time: 1000, position: [1, 2, 3], names: ['A', 'B'], energy: 42, survivorId: 'earth' }],
    diagnostics: {
      energy: -1, kinetic: 2, potential: -3, momentum: [4, 5, 6], energyDrift: 0.01,
      minStep: 10, lastSubsteps: 2, simulatedSeconds: 20, requestedSeconds: 30, limited: true,
    },
  };
}

test('JSON export/import preserves simulation time, body and collision properties', () => {
  const manager = new SaveLoadManager();
  const original = fixture();
  const restored = manager.importJSON(manager.exportJSON(original));
  assert.deepEqual(restored, original);
  restored.bodies[0].position[0] = 0;
  assert.notEqual(original.bodies[0].position[0], 0);
});

test('JSON import rejects malformed, oversized and invalid schema data', () => {
  const manager = new SaveLoadManager();
  assert.throws(() => manager.importJSON('{'), /JSON/);
  assert.throws(() => manager.importJSON(' '.repeat(2 * 1024 * 1024 + 1)), /2 MB/);
  assert.throws(() => manager.importJSON('{}'));
  const invalid = fixture();
  invalid.bodies[0].mass = -1;
  assert.throws(() => manager.importJSON(JSON.stringify(invalid)));
});

test('unsupported IndexedDB reports failure instead of claiming a successful save', async () => {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis, 'indexedDB');
  Object.defineProperty(globalThis, 'indexedDB', { value: undefined, configurable: true });
  try {
    const manager = new SaveLoadManager();
    await assert.rejects(manager.save(fixture()), /IndexedDB/);
    await assert.rejects(manager.load(), /IndexedDB/);
  } finally {
    if (descriptor) Object.defineProperty(globalThis, 'indexedDB', descriptor);
    else Reflect.deleteProperty(globalThis, 'indexedDB');
  }
});

test('time requests use real elapsed time and cap background tab jumps', () => {
  const time = new TimeController();
  assert.equal(time.requestSeconds(1 / 60) * 60, 86400);
  assert.equal(time.requestSeconds(10), 432000);
  assert.equal(time.requestSeconds(Number.NaN), 0);
  time.running = false;
  assert.equal(time.requestSeconds(0.1), 0);
  time.running = true;
  time.speed = 3600;
  assert.equal(time.requestSeconds(0.1), 360);
});

test('accumulation preserves equal requested time at 1, 30, 60 and 120 FPS with a busy worker', () => {
  for (const fps of [1, 30, 60, 120]) {
    const time = new TimeController();
    let busyUntil = 0;
    let requested = 0;
    for (let frame = 1; frame <= fps; frame += 1) {
      const now = frame / fps;
      time.accumulate(1 / fps);
      // A worker completion takes 20 ms, crossing one or more render frames.
      if (now + 1e-12 >= busyUntil) {
        requested += time.takeSeconds();
        busyUntil = now + 0.020;
      }
    }
    requested += time.takeSeconds();
    assert.ok(Math.abs(requested - 86400) < 1e-7, `${fps} FPS requested ${requested} seconds`);
    assert.equal(time.takeSeconds(), 0);
  }
});

test('pending requests cap catch-up and are discarded on pause, reset and explicit cancellation', () => {
  const time = new TimeController();
  time.accumulate(10);
  assert.equal(time.takeSeconds(), 432000);
  time.accumulate(3);
  time.accumulate(3);
  time.accumulate(3);
  assert.equal(time.takeSeconds(), 432000);

  time.accumulate(0.1);
  time.running = false;
  assert.equal(time.takeSeconds(), 0);
  time.accumulate(0.1);
  time.running = true;
  assert.equal(time.takeSeconds(), 0);

  time.accumulate(0.1);
  time.clear(fixture());
  assert.equal(time.takeSeconds(), 0);
  time.accumulate(0.1);
  time.discardPending();
  assert.equal(time.takeSeconds(), 0);
});

test('rewind restores independent previous snapshots and skips duplicate current checkpoints', () => {
  const time = new TimeController();
  const state = fixture();
  time.clear(state);
  state.time = 2000;
  state.bodies[0].position[0] = 2000;
  time.checkpoint(state);
  time.checkpoint(state);
  state.time = 3000;
  state.bodies[0].position[0] = 3000;
  time.checkpoint(state);
  const previous = time.rewind();
  assert.equal(previous?.time, 2000);
  assert.equal(previous?.bodies[0].position[0], 2000);
  previous!.bodies[0].position[0] = 5000;
  const oldest = time.rewind();
  assert.equal(oldest?.time, 1234);
  assert.equal(oldest?.bodies[0].position[0], 1.495978707e11);
  assert.equal(time.rewind(), null);
});

test('rewind history retains at most 90 snapshots and clear resets it', () => {
  const time = new TimeController();
  const state = fixture();
  for (let index = 0; index < 100; index += 1) {
    state.time = index;
    time.checkpoint(state);
  }
  let restored: SimulationState | null;
  let count = 0;
  let earliest = 0;
  while ((restored = time.rewind())) {
    count += 1;
    earliest = restored.time;
  }
  assert.equal(count, 89);
  assert.equal(earliest, 10);
  time.clear();
  assert.equal(time.rewind(), null);
});

test('recomputed diagnostics after restoration do not trap repeated rewind on one physical state', () => {
  const time = new TimeController();
  const state = fixture();
  time.clear(state);
  state.time = 2000;
  state.steps = 6;
  state.bodies[0].position[0] = 2000;
  time.checkpoint(state);
  state.time = 3000;
  state.steps = 7;
  state.bodies[0].position[0] = 3000;
  time.checkpoint(state);

  const restored = time.rewind()!;
  assert.equal(restored.time, 2000);
  assert.equal(restored.diagnostics.energy, -1);
  // SimulationEngine.load recomputes these values without changing the bodies.
  restored.diagnostics.energy = 900;
  restored.diagnostics.momentum[0] = 100;
  restored.diagnostics.lastSubsteps = 0;
  time.checkpoint(restored);

  const earlier = time.rewind()!;
  assert.equal(earlier.time, 1234);
  assert.equal(earlier.steps, 5);
  assert.equal(earlier.bodies[0].position[0], 1.495978707e11);
  assert.equal(earlier.diagnostics.energy, -1);
  assert.deepEqual(earlier.diagnostics.momentum, [4, 5, 6]);
  assert.equal(time.rewind(), null);
});
