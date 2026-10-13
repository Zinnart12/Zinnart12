/** All persisted positions/radii are metres, velocities m/s, masses kg and time seconds. */
export type Vec3 = [number, number, number];
export type BodyKind = 'star' | 'planet' | 'moon' | 'asteroid';
export type SurfaceKind = 'earth' | 'rocky' | 'gas' | 'ice' | 'lava' | 'ocean';
export interface CelestialBody {
  id: string;
  name: string;
  kind: BodyKind;
  surface: SurfaceKind;
  mass: number;
  radius: number;
  position: Vec3;
  velocity: Vec3;
  temperature: number;
  rotationPeriod: number;
  axialTilt: number;
  albedo: number;
  atmosphere: number;
  composition: string;
  color: string;
  seed: number;
}
export interface CollisionEvent {
  id: number;
  time: number;
  position: Vec3;
  names: [string, string];
  energy: number;
  survivorId: string;
}
export interface Diagnostics {
  energy: number;
  kinetic: number;
  potential: number;
  momentum: Vec3;
  energyDrift: number;
  minStep: number;
  lastSubsteps: number;
  simulatedSeconds: number;
  requestedSeconds: number;
  limited: boolean;
}
export interface SimulationState {
  schemaVersion: 1;
  name: string;
  time: number;
  steps: number;
  bodies: CelestialBody[];
  events: CollisionEvent[];
  diagnostics: Diagnostics;
}
export type BodyPatch = Partial<Omit<CelestialBody, 'id'>>;
export type WorkerRequest = (
  | { type: 'load'; state: SimulationState }
  | { type: 'advance'; seconds: number; maxSteps?: number }
  | { type: 'edit'; id: string; patch: BodyPatch }
  | { type: 'add'; body: CelestialBody }
  | { type: 'remove'; id: string }
  | { type: 'snapshot' }
) & { requestId: number };
export interface WorkerResponse {
  requestId: number;
  state?: SimulationState;
  error?: string;
}
