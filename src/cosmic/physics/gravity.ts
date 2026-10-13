import type { CelestialBody, Diagnostics, Vec3 } from '../types.ts';
import { G, MAX_STEP } from './constants.ts';

/** Direct, symmetric, double-precision N-body gravity. No artificial drag or orbit constraints. */
export class GravitySolver {
  accelerations(bodies: CelestialBody[]): Float64Array {
    const a = new Float64Array(bodies.length * 3);
    for (let i = 0; i < bodies.length; i++) for (let j = i + 1; j < bodies.length; j++) {
      const left = bodies[i], right = bodies[j];
      const dx = right.position[0] - left.position[0];
      const dy = right.position[1] - left.position[1];
      const dz = right.position[2] - left.position[2];
      const distance2 = dx * dx + dy * dy + dz * dz;
      // Overlaps are merged before integration. This floor only handles roundoff at contact.
      const contact = left.radius + right.radius;
      const radius2 = Math.max(distance2, contact * contact * 0.01);
      const factor = G / (radius2 * Math.sqrt(radius2));
      const delta = [dx, dy, dz];
      for (let k = 0; k < 3; k++) {
        a[i * 3 + k] += delta[k] * factor * right.mass;
        a[j * 3 + k] -= delta[k] * factor * left.mass;
      }
    }
    return a;
  }

  /** Velocity Verlet has bounded energy error for resolved, constant-step orbits. */
  step(bodies: CelestialBody[], seconds: number): void {
    const initial = this.accelerations(bodies);
    for (let i = 0; i < bodies.length; i++) for (let k = 0; k < 3; k++) {
      bodies[i].position[k] += bodies[i].velocity[k] * seconds + 0.5 * initial[i * 3 + k] * seconds * seconds;
    }
    const final = this.accelerations(bodies);
    for (let i = 0; i < bodies.length; i++) for (let k = 0; k < 3; k++) {
      bodies[i].velocity[k] += 0.5 * (initial[i * 3 + k] + final[i * 3 + k]) * seconds;
    }
  }

  stableStep(bodies: CelestialBody[]): number {
    let seconds = MAX_STEP;
    for (let i = 0; i < bodies.length; i++) for (let j = i + 1; j < bodies.length; j++) {
      const left = bodies[i], right = bodies[j];
      const d = left.position.map((p, k) => right.position[k] - p);
      const v = left.velocity.map((p, k) => right.velocity[k] - p);
      const distance = Math.hypot(...d);
      const speed = Math.hypot(...v);
      seconds = Math.min(seconds, 0.01 * Math.sqrt(distance ** 3 / (G * (left.mass + right.mass))));
      if (speed > 0) seconds = Math.min(seconds, 0.15 * distance / speed);
    }
    return seconds;
  }

  diagnostics(bodies: CelestialBody[], baseline?: number): Diagnostics {
    let kinetic = 0, potential = 0;
    const momentum: Vec3 = [0, 0, 0];
    for (let i = 0; i < bodies.length; i++) {
      const body = bodies[i];
      kinetic += 0.5 * body.mass * body.velocity.reduce((sum, v) => sum + v * v, 0);
      for (let k = 0; k < 3; k++) momentum[k] += body.mass * body.velocity[k];
      for (let j = i + 1; j < bodies.length; j++) {
        const other = bodies[j];
        const distance = Math.hypot(...body.position.map((p, k) => other.position[k] - p));
        potential -= G * body.mass * other.mass / Math.max(distance, (body.radius + other.radius) * 0.1);
      }
    }
    const energy = kinetic + potential;
    return { energy, kinetic, potential, momentum,
      energyDrift: baseline !== undefined && baseline !== 0 ? (energy - baseline) / Math.abs(baseline) : 0,
      minStep: 0, lastSubsteps: 0, simulatedSeconds: 0, requestedSeconds: 0, limited: false };
  }
}
