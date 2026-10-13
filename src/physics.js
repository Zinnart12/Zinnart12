export const G = 6.67430e-11;
export const C = 299792458;
export const SOLAR_MASS = 1.98847e30;
export const REFERENCE_MASS = 4.3; // millions of solar masses
export const RS_PER_MILLION_KM = 2 * G * SOLAR_MASS * 1e6 / (C * C) / 1000;
export const PHOTON_SPHERE_RS = 1.5;
export const CRITICAL_IMPACT_RS = Math.sqrt(27) / 2;

export function schwarzschildRadius(millionSolarMasses) {
  return millionSolarMasses * RS_PER_MILLION_KM;
}

export function massFromRadius(radiusKm) {
  return radiusKm / RS_PER_MILLION_KM;
}

export function shadowAngularRadius(observerRadiusRs) {
  if (!(observerRadiusRs > 1)) throw new RangeError('Observer must be outside the horizon.');
  const sine = CRITICAL_IMPACT_RS * Math.sqrt(1 - 1 / observerRadiusRs) / observerRadiusRs;
  const angle = Math.asin(Math.min(1, sine));
  return observerRadiusRs >= PHOTON_SPHERE_RS ? angle : Math.PI - angle;
}

// Local-static-observer frequency ratio, including the observer's finite potential.
export function frequencyShift(emitterRadiusRs, beta, towardObserverCosine, observerRadiusRs = Infinity) {
  if (!(emitterRadiusRs > 1 && observerRadiusRs > 1 && beta >= 0 && beta < 1 && Math.abs(towardObserverCosine) <= 1)) {
    throw new RangeError('Invalid exterior emission or observer parameters.');
  }
  const doppler = Math.sqrt(1 - beta * beta) / (1 - beta * towardObserverCosine);
  return doppler * Math.sqrt((1 - 1 / emitterRadiusRs) / (1 - 1 / observerRadiusRs));
}

export function orbitalAngularVelocity(radiusRs, spin = 0) {
  if (!(radiusRs > 0)) throw new RangeError('Positive orbital radius required.');
  return Math.sqrt(0.5 / radiusRs ** 3) * (1 + 0.3 * spin);
}

// Uniform sphere, linear radial tidal field, quasi-static tensile support.
// This estimates the onset of disruption, not the timing of fragmentation.
// Schwarzschild's freely falling radial tidal eigenvalue is 2GM/r^3; internal
// self-gravity and material response are Newtonian uniform-body approximations.
export function tidalAssessment({ blackHoleMass, bodyRadius, bodyDensity, materialStrength = 0, distanceRs = 1 }) {
  if (![blackHoleMass, bodyRadius, bodyDensity, distanceRs].every(x => Number.isFinite(x) && x > 0)
      || !Number.isFinite(materialStrength) || materialStrength < 0) {
    throw new RangeError('Mass, radius, density and distance must be positive; strength cannot be negative.');
  }
  const blackHoleMassKg = blackHoleMass * 1e6 * SOLAR_MASS;
  const horizonRadius = schwarzschildRadius(blackHoleMass) * 1000;
  const distance = distanceRs * horizonRadius;
  const bodyMass = 4 * Math.PI / 3 * bodyDensity * bodyRadius ** 3;
  const selfGravity = G * bodyMass / bodyRadius ** 2;
  const tidalGradient = 2 * G * blackHoleMassKg / distance ** 3;
  const tidalAcceleration = tidalGradient * bodyRadius; // center to near surface
  const tidalStress = bodyDensity * tidalGradient * bodyRadius ** 2 / 4;
  const selfGravityStress = bodyDensity * selfGravity * bodyRadius / 4;
  const supportStress = selfGravityStress + materialStrength;
  const disruptionRadius = Math.cbrt(G * blackHoleMassKg * bodyDensity * bodyRadius ** 2 / (2 * supportStress));
  return {
    bodyMass, horizonRadius, tidalAcceleration, differentialAcceleration: 2 * tidalAcceleration,
    selfGravity, tidalStress, selfGravityStress, supportStress,
    stressRatio: tidalStress / supportStress,
    disruptionRadius, disruptionRadiusRs: disruptionRadius / horizonRadius,
    disruptsOutsideHorizon: disruptionRadius > horizonRadius,
    overThreshold: tidalStress > supportStress,
    insideHorizon: distanceRs <= 1,
    linearModelValid: bodyRadius / distance < 0.01,
  };
}

// Prograde Kerr ISCO used ONLY as an approximate emissivity inner boundary.
// Photon trajectories and the horizon remain Schwarzschild, not Kerr.
export function diskInnerRadius(spin) {
  const a = Math.max(0, Math.min(0.98, spin));
  const z1 = 1 + Math.cbrt(1 - a * a) * (Math.cbrt(1 + a) + Math.cbrt(1 - a));
  const z2 = Math.sqrt(3 * a * a + z1 * z1);
  return (3 + z2 - Math.sqrt((3 - z1) * (3 + z1 + 2 * z2))) / 2;
}

export const DEFAULTS = Object.freeze({
  mass: 4.3, spin: 0, tilt: 0, temperature: 8200, density: 1.2,
  brightness: 1.15, speed: 1, lensing: 1, quality: 2, resolution: 0.85,
  exposure: 1.05, disk: true, stars: true, nebula: true, ring: true,
  bloom: true, autoQuality: true, paused: false, mode: 'scientific',
  autoOrbit: false,
  bodyRadiusKm: 6371, bodyDensity: 5514, bodyStrengthMPa: 50, bodyDistance: 10,
});

export const QUALITY_STEPS = [96, 144, 216, 320];
export const QUALITY_NAMES = ['Low', 'Balanced', 'High', 'Ultra'];

// Reference integrator for regression tests of the equation used by the GPU.
// Null geodesics in Schwarzschild's orbital plane: x'' = -3 Rs L² x / (2 r⁵).
export function traceReference(origin, direction, { lensing = 1, step = 0.01, limit = 100000 } = {}) {
  let p = [...origin];
  const r0 = Math.hypot(...origin);
  const directionLength = Math.hypot(...direction);
  const radialDot = origin.reduce((s, x, j) => s + x / r0 * direction[j] / directionLength, 0);
  const f = Math.sqrt(Math.max(0.02, 1 - lensing / r0));
  let v = direction.map((x, j) => {
    const radial = origin[j] / r0 * radialDot;
    return radial + (x / directionLength - radial) / f;
  });
  const cross = [p[1] * v[2] - p[2] * v[1], p[2] * v[0] - p[0] * v[2], p[0] * v[1] - p[1] * v[0]];
  const l2 = cross.reduce((s, x) => s + x * x, 0);
  const acceleration = x => {
    const r = Math.hypot(...x);
    const k = -1.5 * lensing * l2 / r ** 5;
    return x.map(t => t * k);
  };
  let closestRadius = r0, angularTravel = 0;
  for (let i = 0; i < limit; i++) {
    closestRadius = Math.min(closestRadius, Math.hypot(...p));
    if (Math.hypot(...p) <= 1) return { captured: true, direction: v, position: p, closestRadius, angularTravel };
    if (Math.hypot(...p) > 50 && p.reduce((s, x, j) => s + x * v[j], 0) > 0) {
      const speed = Math.hypot(...v);
      return { captured: false, direction: v.map(x => x / speed), position: p, closestRadius, angularTravel };
    }
    const a = acceleration(p);
    const next = p.map((x, j) => x + v[j] * step + 0.5 * a[j] * step * step);
    const a2 = acceleration(next);
    const midpoint = p.map((x, j) => (x + next[j]) / 2);
    angularTravel += Math.sqrt(l2) * step / midpoint.reduce((s, x) => s + x * x, 0);
    v = v.map((x, j) => x + 0.5 * (a[j] + a2[j]) * step);
    p = next;
  }
  throw new Error('Reference ray did not finish within the integration budget.');
}
