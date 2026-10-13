import test from 'node:test';
import assert from 'node:assert/strict';
import { schwarzschildRadius, massFromRadius, diskInnerRadius, traceReference } from '../src/physics.js';

test('Schwarzschild radius agrees with 2.953 km per solar mass and scales with mass', () => {
  const solarRadius = schwarzschildRadius(1e-6);
  assert.ok(Math.abs(solarRadius - 2.95334) < 0.001);
  assert.equal(schwarzschildRadius(8.6), 2 * schwarzschildRadius(4.3));
  assert.ok(Math.abs(massFromRadius(schwarzschildRadius(4.3)) - 4.3) < 1e-12);
});

test('emissivity ISCO is 3 Rs for zero spin and decreases for prograde spin', () => {
  assert.equal(diskInnerRadius(0), 3);
  assert.ok(diskInnerRadius(0.5) < 3);
  assert.ok(diskInnerRadius(0.98) > 0.8);
  assert.ok(diskInnerRadius(0.98) < diskInnerRadius(0.5));
});

test('a radial null ray is captured by the horizon', () => {
  assert.equal(traceReference([0, 0, 40], [0, 0, -1]).captured, true);
});

test('null rays on opposite sides of the critical impact parameter have different outcomes', () => {
  assert.equal(traceReference([2.4, 0, 40], [0, 0, -1]).captured, true);
  assert.equal(traceReference([3.1, 0, 40], [0, 0, -1]).captured, false);
});

test('weak-field deflection bends toward the mass and approaches 2 Rs / b', () => {
  const ray = traceReference([20, 0, 100], [0, 0, -1]);
  assert.equal(ray.captured, false);
  assert.ok(ray.direction[0] < 0);
  const angle = Math.atan2(-ray.direction[0], -ray.direction[2]);
  assert.ok(angle > 0.09 && angle < 0.12, `Observed ${angle} radians`);
});

test('disabling lensing leaves a straight ray and preserves its sky direction', () => {
  const ray = traceReference([4, 0, 40], [0, 0, -1], { lensing: 0 });
  assert.equal(ray.captured, false);
  assert.deepEqual(ray.direction, [0, 0, -1]);
});
