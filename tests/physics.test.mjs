import test from 'node:test';
import assert from 'node:assert/strict';
import { schwarzschildRadius, massFromRadius, diskInnerRadius, traceReference,
  shadowAngularRadius, frequencyShift, orbitalAngularVelocity, tidalAssessment,
  CRITICAL_IMPACT_RS, PHOTON_SPHERE_RS } from '../src/physics.js';

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

function directionForImpact(b, observerRadius = 34) {
  const sine = b * Math.sqrt(1 - 1 / observerRadius) / observerRadius;
  return [sine, 0, -Math.sqrt(1 - sine * sine)];
}

test('finite observer shadow, photon sphere and horizon are distinct physical scales', () => {
  assert.equal(PHOTON_SPHERE_RS, 1.5);
  assert.ok(Math.abs(CRITICAL_IMPACT_RS - 2.598076211) < 1e-9);
  const r = 34;
  assert.ok(Math.abs(Math.sin(shadowAngularRadius(r)) * r / Math.sqrt(1 - 1 / r) - CRITICAL_IMPACT_RS) < 1e-12);
  assert.ok(shadowAngularRadius(1.1) > Math.PI / 2, 'inside the photon sphere the escape cone is smaller than a hemisphere');
});

test('finite-observer null rays straddle the analytic critical impact parameter', () => {
  const below = traceReference([0, 0, 34], directionForImpact(CRITICAL_IMPACT_RS * 0.999), { step: 0.003 });
  const above = traceReference([0, 0, 34], directionForImpact(CRITICAL_IMPACT_RS * 1.001), { step: 0.003 });
  assert.equal(below.captured, true);
  assert.equal(above.captured, false);
  assert.ok(above.closestRadius > 1.5 && above.closestRadius < 1.6);
  assert.ok(above.angularTravel > 2 * Math.PI, 'a near-critical escaped ray actually wraps around the hole');
});

// Independent Schwarzschild Binet quadrature, not the Cartesian tracer's ODE.
// u=1/r, (du/dphi)^2 = 1/b^2 - u^2 + u^3; t^2 substitution removes the turning singularity.
function exactDeflection(b) {
  let lo = 0, hi = 2 / 3;
  const polynomial = u => 1 / b ** 2 - u * u + u ** 3;
  for (let i = 0; i < 80; i++) {
    const mid = (lo + hi) / 2;
    if (polynomial(mid) > 0) lo = mid; else hi = mid;
  }
  const turn = (lo + hi) / 2;
  const f = t => t === 0 ? 2 * Math.sqrt(turn) / Math.sqrt(2 * turn - 3 * turn * turn)
    : 2 * turn * t / Math.sqrt(Math.max(1e-30, polynomial(turn * (1 - t * t))));
  const n = 4000;
  let integral = f(0) + f(1);
  for (let i = 1; i < n; i++) integral += (i % 2 ? 4 : 2) * f(i / n);
  return 2 * integral / (3 * n) - Math.PI;
}

test('null-ray bending agrees with an independent Schwarzschild orbit integral', () => {
  const b = 8, r = 200;
  const direction = directionForImpact(b, r);
  const ray = traceReference([0, 0, r], direction, { step: 0.005 });
  const incomingAngle = Math.atan2(direction[0] / Math.sqrt(1 - 1 / r), -direction[2]);
  const outgoingAngle = Math.atan2(ray.direction[0], -ray.direction[2]);
  assert.ok(Math.abs(incomingAngle - outgoingAngle - exactDeflection(b)) < 0.002);
});

test('redshift includes both potentials; approaching gas is brighter than receding gas', () => {
  assert.equal(frequencyShift(4, 0, 0, 4), 1);
  assert.ok(Math.abs(frequencyShift(4, 0, 0) - Math.sqrt(0.75)) < 1e-12);
  const approaching = frequencyShift(4, 0.4, 1, 34);
  const receding = frequencyShift(4, 0.4, -1, 34);
  assert.ok(approaching > 1 && receding < 1);
  assert.ok(approaching ** 4 > receding ** 4 * 20, 'bolometric beaming follows the frequency ratio to the fourth power');
});

test('orbital advection obeys Kepler shear instead of rigid-body rotation', () => {
  assert.ok(Math.abs(orbitalAngularVelocity(3) / orbitalAngularVelocity(12) - 8) < 1e-12);
});

const earth = { bodyRadius: 6.371e6, bodyDensity: 5514, materialStrength: 50e6 };

test('Earth-sized body at Sagittarius A* exceeds the tidal threshold outside the horizon', () => {
  const tide = tidalAssessment({ blackHoleMass: 4.3, ...earth });
  assert.ok(Math.abs(tide.tidalAcceleration - 3550.47) < 0.1);
  assert.ok(Math.abs(tide.selfGravity - 9.82) < 0.01);
  assert.ok(tide.disruptionRadiusRs > 7.1 && tide.disruptionRadiusRs < 7.2);
  assert.equal(tide.disruptsOutsideHorizon, true);
  assert.equal(tide.overThreshold, true);
  assert.equal(tidalAssessment({ blackHoleMass: 4.3, ...earth, distanceRs: 10 }).overThreshold, false);
});

test('a more massive hole may swallow a terrestrial body below the static tidal threshold', () => {
  const tide = tidalAssessment({ blackHoleMass: 100, ...earth });
  assert.equal(tide.disruptsOutsideHorizon, false);
  assert.equal(tide.overThreshold, false);
  assert.ok(tide.disruptionRadiusRs > 0.8 && tide.disruptionRadiusRs < 1);
});

test('material strength protects a small probe where its self-gravity alone cannot', () => {
  const small = { blackHoleMass: 4.3, bodyRadius: 1, bodyDensity: 4500, distanceRs: 1 };
  const rubble = tidalAssessment(small);
  const solid = tidalAssessment({ ...small, materialStrength: 600e6 });
  assert.equal(rubble.overThreshold, true);
  assert.equal(solid.overThreshold, false);
  assert.ok(solid.tidalStress < 1);
  assert.ok(solid.disruptionRadiusRs < 0.01);
});

test('tidal acceleration scales with R/r^3 and model invalidity is reported for large bodies', () => {
  const atOne = tidalAssessment({ blackHoleMass: 4.3, ...earth });
  const atTwo = tidalAssessment({ blackHoleMass: 4.3, ...earth, distanceRs: 2 });
  assert.ok(Math.abs(atOne.tidalAcceleration / atTwo.tidalAcceleration - 8) < 1e-12);
  assert.equal(tidalAssessment({ blackHoleMass: 0.00001, ...earth }).linearModelValid, false);
  assert.throws(() => tidalAssessment({ blackHoleMass: 4.3, ...earth, bodyDensity: -1 }), RangeError);
});
