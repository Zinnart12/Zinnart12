export const G = 6.67430e-11;
export const C = 299792458;
export const SOLAR_MASS = 1.98847e30;
export const REFERENCE_MASS = 4.3; // millions of solar masses
export const RS_PER_MILLION_KM = 2 * G * SOLAR_MASS * 1e6 / (C * C) / 1000;

export function schwarzschildRadius(millionSolarMasses) {
  return millionSolarMasses * RS_PER_MILLION_KM;
}

export function massFromRadius(radiusKm) {
  return radiusKm / RS_PER_MILLION_KM;
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
});

export const QUALITY_STEPS = [96, 144, 216, 320];
export const QUALITY_NAMES = ['Low', 'Balanced', 'High', 'Ultra'];

// Reference integrator for regression tests of the equation used by the GPU.
// Null geodesics in Schwarzschild's orbital plane: x'' = -3 Rs L² x / (2 r⁵).
export function traceReference(origin, direction, { lensing = 1, step = 0.01, limit = 40000 } = {}) {
  let p = [...origin];
  let v = [...direction];
  const cross = [p[1] * v[2] - p[2] * v[1], p[2] * v[0] - p[0] * v[2], p[0] * v[1] - p[1] * v[0]];
  const l2 = cross.reduce((s, x) => s + x * x, 0);
  const acceleration = x => {
    const r = Math.hypot(...x);
    const k = -1.5 * lensing * l2 / r ** 5;
    return x.map(t => t * k);
  };
  for (let i = 0; i < limit; i++) {
    if (Math.hypot(...p) <= 1) return { captured: true, direction: v, position: p };
    if (Math.hypot(...p) > 50 && p.reduce((s, x, j) => s + x * v[j], 0) > 0) {
      const speed = Math.hypot(...v);
      return { captured: false, direction: v.map(x => x / speed), position: p };
    }
    const a = acceleration(p);
    const next = p.map((x, j) => x + v[j] * step + 0.5 * a[j] * step * step);
    const a2 = acceleration(next);
    v = v.map((x, j) => x + 0.5 * (a[j] + a2[j]) * step);
    p = next;
  }
  throw new Error('Reference ray did not finish within the integration budget.');
}
