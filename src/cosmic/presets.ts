import type { CelestialBody, SimulationState, Vec3 } from './types.ts';
import { AU, DAY, G, MEARTH, MSUN, REARTH } from './physics/constants.ts';
import { makeState, newBody } from './physics/engine.ts';

type Template = { id: string; name: string; description: string; create: () => CelestialBody };
export const BODY_TEMPLATES: Template[] = [
  { id: 'sun', name: 'Sun-like star', description: 'A 5,772 K main-sequence star.', create: () => newBody({ name: 'New star', kind: 'star', surface: 'lava',
    mass: MSUN, radius: 695_700_000, temperature: 5772, rotationPeriod: 25.38 * DAY, axialTilt: 7.25,
    atmosphere: 0, albedo: 0, composition: 'Hydrogen 73%; helium 25%; heavier elements 2%', color: '#fff2c5', seed: 104 }) },
  { id: 'earth', name: 'Earth-like planet', description: 'A rocky world with oceans and atmosphere.', create: () => newBody({ name: 'New Earth', surface: 'earth',
    mass: MEARTH, radius: REARTH, temperature: 288, rotationPeriod: 86164, axialTilt: 23.44,
    albedo: 0.306, atmosphere: 1, composition: 'Iron core; silicate mantle; water ocean; nitrogen–oxygen atmosphere', color: '#80b7e6', seed: 317 }) },
  { id: 'mars', name: 'Rocky planet', description: 'A dry, thin-atmosphere terrestrial planet.', create: () => newBody({ name: 'New Mars', surface: 'rocky',
    mass: 6.4171e23, radius: 3_389_500, temperature: 210, rotationPeriod: 88642.7, axialTilt: 25.19,
    albedo: 0.25, atmosphere: 0.006, composition: 'Silicate rock; iron oxides; carbon-dioxide atmosphere', color: '#c98769', seed: 423 }) },
  { id: 'jupiter', name: 'Gas giant', description: 'A hydrogen–helium giant with cloud bands.', create: () => newBody({ name: 'New Jupiter', surface: 'gas',
    mass: 1.89813e27, radius: 69_911_000, temperature: 165, rotationPeriod: 35730, axialTilt: 3.13,
    albedo: 0.343, atmosphere: 8, composition: 'Hydrogen and helium; ammonia cloud layers', color: '#d9b28b', seed: 551 }) },
  { id: 'moon', name: 'Moon', description: 'A cratered, airless natural satellite.', create: () => newBody({ name: 'New Moon', kind: 'moon', surface: 'rocky',
    mass: 7.342e22, radius: 1_737_400, temperature: 220, rotationPeriod: 27.321661 * DAY, axialTilt: 6.68,
    albedo: 0.12, atmosphere: 0, composition: 'Basalt and silicate regolith; small iron core', color: '#b8b6b1', seed: 212 }) },
  { id: 'asteroid', name: 'Asteroid', description: 'A small irregular rocky body.', create: () => newBody({ name: 'New asteroid', kind: 'asteroid', surface: 'rocky',
    mass: 2e15, radius: 5000, temperature: 180, rotationPeriod: 5.3 * 3600, axialTilt: 41,
    albedo: 0.09, atmosphere: 0, composition: 'Carbonaceous rock and metal', color: '#8b8279', seed: 909 }) },
];

function template(id: string, overrides: Partial<CelestialBody>): CelestialBody {
  const base = BODY_TEMPLATES.find((t) => t.id === id)!.create();
  return newBody({ ...base, ...overrides });
}

/** Kepler elements are approximate epoch-independent demonstrations, not an ephemeris. */
function orbit(distance: number, eccentricity: number, phase: number, inclination: number, totalMass: number): { position: Vec3; velocity: Vec3 } {
  const p = distance * (1 - eccentricity * eccentricity);
  const r = p / (1 + eccentricity * Math.cos(phase));
  const speed = Math.sqrt(G * totalMass / p);
  return {
    position: [r * Math.cos(phase), r * Math.sin(phase) * Math.sin(inclination), r * Math.sin(phase) * Math.cos(inclination)],
    velocity: [-speed * Math.sin(phase), speed * (eccentricity + Math.cos(phase)) * Math.sin(inclination), speed * (eccentricity + Math.cos(phase)) * Math.cos(inclination)],
  };
}

function barycentric(bodies: CelestialBody[]): CelestialBody[] {
  const mass = bodies.reduce((total, body) => total + body.mass, 0);
  const position: Vec3 = [0, 0, 0], velocity: Vec3 = [0, 0, 0];
  for (const body of bodies) for (let k = 0; k < 3; k++) {
    position[k] += body.position[k] * body.mass / mass;
    velocity[k] += body.velocity[k] * body.mass / mass;
  }
  for (const body of bodies) for (let k = 0; k < 3; k++) {
    body.position[k] -= position[k]; body.velocity[k] -= velocity[k];
  }
  return bodies;
}

export function createSolarSystem(): SimulationState {
  const sun = template('sun', { id: 'sun', name: 'Sun', position: [0, 0, 0], velocity: [0, 0, 0] });
  const parameters = [
    ['mercury', 'Mercury', 3.3011e23, 2_439_700, 0.3871, 0.2056, 7.00, 0.4, 440, 58.646 * DAY, 0.034, '#b5aaa0', 'rocky'],
    ['venus', 'Venus', 4.8675e24, 6_051_800, 0.7233, 0.0068, 3.39, 2.2, 737, -243.025 * DAY, 2.64, '#d7bc80', 'rocky'],
    ['earth', 'Earth', MEARTH, REARTH, 1.0, 0.0167, 0, 0, 288, 86164, 23.44, '#80b7e6', 'earth'],
    ['mars', 'Mars', 6.4171e23, 3_389_500, 1.5237, 0.0934, 1.85, 3.0, 210, 88642.7, 25.19, '#c98769', 'rocky'],
    ['jupiter', 'Jupiter', 1.89813e27, 69_911_000, 5.2028, 0.0489, 1.30, 0.9, 165, 35730, 3.13, '#d9b28b', 'gas'],
    ['saturn', 'Saturn', 5.6834e26, 58_232_000, 9.5388, 0.0565, 2.49, 2.7, 134, 38362, 26.73, '#e3cb9f', 'gas'],
    ['uranus', 'Uranus', 8.681e25, 25_362_000, 19.1914, 0.0463, 0.77, 4.1, 76, 62064, 97.77, '#a4dce3', 'ice'],
    ['neptune', 'Neptune', 1.02413e26, 24_622_000, 30.0611, 0.0095, 1.77, 5.2, 72, 57996, 28.32, '#5987e2', 'ice'],
  ] as const;
  const planets = parameters.map(([id, name, mass, radius, semimajor, eccentricity, inclination, phase, temperature, rotationPeriod, axialTilt, color, surface]) => {
    const baseId = id === 'earth' ? 'earth' : id === 'mars' ? 'mars' : surface === 'gas' || surface === 'ice' ? 'jupiter' : 'mars';
    return template(baseId, { id, name, mass, radius, temperature, rotationPeriod, axialTilt, color, surface,
      atmosphere: id === 'venus' ? 92 : id === 'mercury' ? 0 : surface === 'ice' ? 6 : atmosphereForTemplate(baseId),
      composition: id === 'venus' ? 'Silicate rock; dense carbon-dioxide atmosphere' : id === 'mercury' ? 'Large iron core; silicate crust; no substantial atmosphere' : surface === 'ice' ? 'Hydrogen–helium envelope; water, methane and ammonia interior' : BODY_TEMPLATES.find((t) => t.id === baseId)!.create().composition,
      seed: 1000 + id.length * 97 + Math.round(semimajor * 13),
      ...orbit(semimajor * AU, eccentricity, phase, inclination * Math.PI / 180, MSUN + mass) });
  });
  const earth = planets.find((planet) => planet.id === 'earth')!;
  const moon = template('moon', { id: 'moon', name: 'Moon' });
  const lunar = orbit(384_400_000, 0.0549, 1.1, 5.145 * Math.PI / 180, earth.mass + moon.mass);
  const earthCenter = [...earth.position], earthVelocity = [...earth.velocity];
  const lunarFraction = moon.mass / (earth.mass + moon.mass);
  for (let k = 0; k < 3; k++) {
    earth.position[k] = earthCenter[k] - lunar.position[k] * lunarFraction;
    earth.velocity[k] = earthVelocity[k] - lunar.velocity[k] * lunarFraction;
    moon.position[k] = earth.position[k] + lunar.position[k];
    moon.velocity[k] = earth.velocity[k] + lunar.velocity[k];
  }
  return makeState('Solar System', barycentric([sun, ...planets, moon]));
}

function atmosphereForTemplate(templateId: string): number {
  return templateId === 'earth' ? 1 : templateId === 'jupiter' ? 8 : 0.006;
}

function createEarthMoon(): SimulationState {
  const earth = template('earth', { id: 'earth', name: 'Earth' });
  const moon = template('moon', { id: 'moon', name: 'Moon',
    ...orbit(384_400_000, 0.0549, 0, 5.145 * Math.PI / 180, earth.mass + 7.342e22) });
  return makeState('Earth & Moon', barycentric([earth, moon]));
}

function createBinary(): SimulationState {
  const a = template('sun', { id: 'star-a', name: 'Star A', mass: MSUN * 0.8, radius: 580_000_000, temperature: 5200, color: '#ffdcaa' });
  const b = template('sun', { id: 'star-b', name: 'Star B', mass: MSUN * 0.6, radius: 440_000_000, temperature: 4400, color: '#ffc18b',
    ...orbit(0.2 * AU, 0.15, 0, 0, a.mass + MSUN * 0.6) });
  return makeState('Binary Stars', barycentric([a, b]));
}

function createImpact(): SimulationState {
  const earth = template('earth', { id: 'earth', name: 'Earth' });
  const projectile = template('mars', { id: 'theia', name: 'Theia', mass: MEARTH * 0.1,
    position: [80_000_000, 0, 1_000_000], velocity: [-6500, 0, -300], temperature: 450 });
  return makeState('Giant Impact', barycentric([earth, projectile]));
}

export const PRESETS: { id: string; name: string; description: string; create: () => SimulationState }[] = [
  { id: 'solar', name: 'Solar System', description: 'Sun, eight planets and Moon. Approximate Kepler initial orbits; fully interacting thereafter.', create: createSolarSystem },
  { id: 'earthmoon', name: 'Earth & Moon', description: 'Resolve an eccentric lunar orbit and the Earth–Moon barycenter.', create: createEarthMoon },
  { id: 'binary', name: 'Binary Stars', description: 'Two stars orbit their shared center of mass.', create: createBinary },
  { id: 'impact', name: 'Giant Impact', description: 'A Mars-scale body approaches Earth. Contacts merge mass, volume and momentum.', create: createImpact },
  { id: 'empty', name: 'Empty Space', description: 'Build your own gravitational system, up to 128 bodies.', create: () => makeState('Custom Universe', []) },
];
