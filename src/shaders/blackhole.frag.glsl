precision highp float;
precision highp int;
in vec2 vUv;
out vec4 fragColor;
uniform vec3 uCamera;
uniform vec3 uForward;
uniform vec3 uRight;
uniform vec3 uUp;
uniform float uAspect;
uniform float uTanFov;
uniform float uRadius;
uniform float uTime;
uniform float uSpin;
uniform float uTilt;
uniform float uInner;
uniform float uTemperature;
uniform float uDensity;
uniform float uBrightness;
uniform float uLensing;
uniform float uPixelAngle;
uniform int uSteps;
uniform bool uDisk;
uniform bool uStars;
uniform bool uNebula;
uniform bool uRing;

const float PI = 3.14159265359;
const float FIELD_RADIUS = 40.0;

float hash13(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}
vec2 hash23(vec3 p) {
  return vec2(hash13(p), hash13(p + vec3(19.7, 3.1, 47.2)));
}
float noise3(vec3 p) {
  vec3 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(hash13(i), hash13(i + vec3(1,0,0)), f.x),
                 mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
                 mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
  float n = 0.0, a = 0.5;
  for (int i = 0; i < 4; i++) { n += a * noise3(p); p = p * 2.03 + 17.7; a *= 0.5; }
  return n;
}

vec3 blackbody(float kelvin) {
  // Approximate blackbody chromaticity, with Doppler/gravitational temperature shift.
  float t = clamp(kelvin, 1200.0, 40000.0) / 100.0;
  vec3 c;
  c.r = t <= 66.0 ? 1.0 : 1.292936 * pow(t - 60.0, -0.133205);
  c.g = t <= 66.0 ? 0.390082 * log(t) - 0.631841 : 1.129891 * pow(t - 60.0, -0.075515);
  c.b = t >= 66.0 ? 1.0 : (t <= 19.0 ? 0.0 : 0.543207 * log(t - 10.0) - 1.196254);
  return pow(clamp(c, 0.0, 1.0), vec3(2.2));
}

vec3 sphereDirection(vec3 origin, vec3 direction, float radius) {
  float b = dot(origin, direction);
  float discriminant = b * b + radius * radius - dot(origin, origin);
  if (discriminant < 0.0) return direction;
  float t = -b + sqrt(discriminant);
  if (t <= 0.0) return direction;
  return normalize(origin + direction * t);
}

vec3 starLayer(vec3 dir, float cells, float seed) {
  // Procedural cubemap: star positions remain fixed in world space, not screen space.
  vec3 ad = abs(dir);
  vec2 uv;
  float face;
  if (ad.x >= ad.y && ad.x >= ad.z) { uv = dir.yz / ad.x; face = dir.x > 0.0 ? 0.0 : 1.0; }
  else if (ad.y >= ad.z) { uv = dir.xz / ad.y; face = dir.y > 0.0 ? 2.0 : 3.0; }
  else { uv = dir.xy / ad.z; face = dir.z > 0.0 ? 4.0 : 5.0; }
  vec2 grid = (uv * 0.5 + 0.5) * cells;
  vec2 id = floor(grid);
  vec3 cell = vec3(id, face * 19.0 + seed);
  float probability = hash13(cell + 12.3);
  vec2 center = 0.12 + hash23(cell) * 0.76;
  float distanceToStar = length(fract(grid) - center);
  float aa = max(length(fwidth(grid)), 0.025);
  float variance = 0.002 + aa * aa * 0.065;
  float core = exp(-distanceToStar * distanceToStar / variance) * min(1.0, 0.006 / variance);
  float halo = exp(-distanceToStar * 24.0) * 0.035;
  float intensity = step(0.991, probability) * (core + halo) * mix(0.10, 2.0, pow(hash13(cell + 6.9), 5.0));
  vec3 color = mix(vec3(0.52, 0.68, 1.0), vec3(1.0, 0.78, 0.53), hash13(cell + 31.0));
  return color * intensity;
}

vec3 background(vec3 origin, vec3 direction) {
  vec3 color = vec3(0.0012, 0.0020, 0.0036);
  if (uStars) {
    // Three finite celestial shells give camera translation real stellar parallax.
    color += starLayer(sphereDirection(origin, direction, 180.0), 180.0, 2.0);
    color += starLayer(sphereDirection(origin, direction, 470.0), 360.0, 8.0) * 0.65;
    color += starLayer(sphereDirection(origin, direction, 1400.0), 670.0, 23.0) * 0.5;
  }
  if (uNebula) {
    vec3 d = sphereDirection(origin, direction, 2200.0);
    float band = exp(-pow(dot(d, normalize(vec3(0.7, 0.18, 0.6))) * 3.6, 2.0));
    float clouds = fbm(d * 6.0 + 10.0);
    float dust = fbm(d * 15.0 + 63.0);
    color += mix(vec3(0.013, 0.025, 0.043), vec3(0.07, 0.038, 0.035), clouds)
      * band * smoothstep(0.28, 0.7, clouds) * (0.3 + dust);
  }
  return color;
}

vec3 gravity(vec3 p, float l2) {
  float r2 = max(dot(p, p), 0.1);
  return -1.5 * uLensing * l2 * p / (r2 * r2 * sqrt(r2));
}

float plasmaField(vec3 p, float footprint, out float turbulence) {
  float sum = 0.0, weight = 0.0, amplitude = 0.5;
  turbulence = 0.0;
  // Filter each octave in world space. Derivatives inside divergent ray loops
  // are undefined, so the ray cone and differential-shear Jacobian set the LOD.
  int octaves = uSteps <= 96 ? 3 : (uSteps >= 216 ? 5 : 4);
  for (int i = 0; i < 5; i++) {
    if (i >= octaves) break;
    float filterWeight = 1.0 - smoothstep(0.25, 0.9, footprint);
    float value = 0.5;
    if (filterWeight > 0.001) value = mix(0.5, noise3(p), filterWeight);
    sum += value * amplitude;
    turbulence += abs(2.0 * value - 1.0) * amplitude;
    weight += amplitude;
    p = p * 2.07 + vec3(17.3, 31.7, 9.1);
    footprint *= 2.07; amplitude *= 0.5;
  }
  turbulence /= weight;
  return sum / weight;
}

vec4 plasmaParcel(vec3 q, float r, float omega, float age, float epoch, float footprint) {
  float phase = atan(q.z, q.x) + age * omega * 4.0;
  vec3 advected = vec3(r * cos(phase), q.y * 3.0, r * sin(phase));
  vec3 drift = (uTime + 4.0) * vec3(0.017, 0.025, -0.013);
  vec3 seed = epoch * vec3(11.7, 23.3, 7.1);
  vec3 warpInput = advected * 0.37 + drift + seed;
  vec3 warp = vec3(noise3(warpInput + vec3(5,17,3)),
                   noise3(warpInput + vec3(31,2,19)),
                   noise3(warpInput + vec3(7,43,11))) - 0.5;
  vec3 warped = advected * vec3(1.0, 0.8, 1.0) + warp * 2.3;
  // Smooth, nonperiodic density, ridged turbulence and correlated hot/cold patches.
  float shearFootprint = footprint * (1.0 + 6.0 * age * omega);
  float turbulence;
  float cloud = plasmaField(warped * 1.15 + drift + seed, shearFootprint * 1.6, turbulence);
  return vec4(cloud, turbulence, warp.xy);
}

vec3 diskRadiance(vec3 p, vec3 rayVelocity, vec3 normal, float footprint,
                  float observerPotential, out float extinction) {
  // Disk-local coordinates; inclination changes the volume, not its screen projection.
  vec3 q = vec3(p.x, dot(p, normal), -p.y * sin(uTilt) + p.z * cos(uTilt));
  float r = length(q.xz);
  float sphericalRadius = length(p);
  extinction = 0.0;
  // No contribution from inside the Schwarzschild horizon, even when the
  // experimental spin emissivity boundary would fall inside it.
  if (sphericalRadius <= 1.001 || r < uInner || r > 13.5) return vec3(0.0);
  float nominalHeight = 0.035 + 0.016 * r;
  if (abs(q.y) > nominalHeight * 4.2) return vec3(0.0);

  // Two overlapping parcel lifetimes prevent unbounded shear from eventually
  // filtering every noise octave to its mean. A parcel is reset ONLY at zero
  // weight. Fresh epoch seeds prevent repetition and smooth weights prevent pops.
  float omega = sqrt(0.5 / (r * r * r)) * (1.0 + uSpin * 0.3);
  float flowTime = uTime + 4.0;
  float ageA = mod(flowTime, 8.0), ageB = mod(flowTime + 4.0, 8.0);
  float weightA = smoothstep(0.0, 1.0, 1.0 - abs(ageA * 0.25 - 1.0));
  vec4 a = vec4(0.5, 0.0, 0.0, 0.0), b = a;
  if (weightA > 0.000001) a = plasmaParcel(q, r, omega, ageA, floor(flowTime / 8.0), footprint);
  if (weightA < 0.999999) b = plasmaParcel(q, r, omega, ageB, floor((flowTime + 4.0) / 8.0), footprint);
  vec4 field = mix(b, a, weightA);
  float varianceWeight = sqrt(weightA * weightA + (1.0 - weightA) * (1.0 - weightA));
  float cloud = 0.5 + (field.x - 0.5) / varianceWeight;
  float turbulence = field.y;
  float clumps = pow(smoothstep(0.24, 0.76, cloud), 1.7);
  float structure = 0.055 + clumps * (0.7 + 2.5 * turbulence);
  float height = nominalHeight * (1.0 + field.w * 0.65);
  float vertical = exp(-0.5 * pow(q.y / height, 2.0));
  float edge = smoothstep(uInner, uInner + 0.3, r) * (1.0 - smoothstep(10.5, 13.5, r));
  float materialDensity = structure * edge * vertical * uDensity * 2.2;

  // Convert affine spatial velocity into the emitter's local static tetrad.
  float potential = max(0.02, 1.0 - 1.0 / sphericalRadius);
  vec3 radial = normalize(p);
  vec3 radialVelocity = radial * dot(rayVelocity, radial);
  vec3 localLightDirection = normalize(radialVelocity + sqrt(potential) * (rayVelocity - radialVelocity));
  vec3 tangent = normalize(cross(normal, p));
  // Schwarzschild circular speed measured by a local static observer. Spin only
  // perturbs the emitter; stable Schwarzschild circular orbits start at 3 Rs.
  float beta = min(0.67, sqrt(0.5 / max(r - 1.0, 0.2)) * (1.0 + uSpin * 0.1));
  float gamma = inversesqrt(1.0 - beta * beta);
  float doppler = 1.0 / (gamma * (1.0 - beta * dot(tangent, -localLightDirection)));
  float shift = doppler * sqrt(potential / observerPotential);
  // A zero-torque thin-disk temperature envelope, normalized at its maximum
  // (r / r_inner = 49/36), with temperature-dependent bolometric emission.
  float x = r / uInner;
  float thermalProfile = max(0.0, (1.0 - inversesqrt(x)) / (x * x * x)) / 0.05665278;
  float temperature = uTemperature * pow(thermalProfile, 0.25) * (1.0 + field.z * 0.3);
  float intrinsicFlux = pow(temperature / 8200.0, 4.0);
  // Comoving path length = static proper length / Doppler factor. The source
  // function is grey LTE; g^4 is the bolometric (not specific-frequency) boost.
  extinction = materialDensity / doppler;
  return blackbody(temperature * shift) * intrinsicFlux * pow(shift, 4.0) * uBrightness * 0.85;
}

void main() {
  vec2 screen = vUv * 2.0 - 1.0;
  vec3 initialDir = normalize(uForward + screen.x * uAspect * uTanFov * uRight + screen.y * uTanFov * uUp);
  vec3 origin = uCamera / uRadius;
  vec3 p = origin;
  vec3 velocity = initialDir;
  vec3 color = vec3(0.0);
  float transmission = 1.0;
  bool captured = false;
  bool escaped = false;
  float angularTravel = 0.0;

  float observerRadius = length(origin);
  if (observerRadius <= 1.001) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }
  // Convert the observer's locally measured direction to an affine null-ray velocity.
  // Do this at the ACTUAL observer, before any truncated-field entrance step.
  // E=1, v_radial=cos(psi), v_tangent=sin(psi)/sqrt(1-Rs/r).
  vec3 radial = origin / observerRadius;
  vec3 vr = radial * dot(velocity, radial);
  velocity = vr + (velocity - vr) / sqrt(max(0.02, 1.0 - uLensing / observerRadius));
  vec3 angularMomentum = cross(origin, velocity);
  float l2 = dot(angularMomentum, angularMomentum);
  if (observerRadius > FIELD_RADIUS) {
    vec3 entranceDirection = normalize(velocity);
    float b = dot(origin, entranceDirection);
    float sphereD = b * b - dot(origin, origin) + FIELD_RADIUS * FIELD_RADIUS;
    if (sphereD < 0.0 || b > 0.0) { fragColor = vec4(background(uCamera, initialDir), 1.0); return; }
    p += entranceDirection * max(0.0, -b - sqrt(sphereD));
    float r2 = dot(p, p);
    float potential = max(0.02, 1.0 - uLensing / sqrt(r2));
    // The omitted weak-field segment must not change the observer's impact
    // parameter. Reconstruct incoming velocity with the original L and E=1.
    velocity = cross(angularMomentum, p) / r2
      - normalize(p) * sqrt(max(0.0, 1.0 - potential * l2 / r2));
  }
  float angularSpeed = sqrt(l2);
  float observerPotential = max(0.02, 1.0 - 1.0 / observerRadius);
  vec3 normal = vec3(0.0, cos(uTilt), sin(uTilt));

  // Bounded integration in units Rs=1. Finite quality budget.
  // Curvature is integrated in world space; both emission and escaped stars follow it.
  for (int i = 0; i < 384; i++) {
    if (i >= uSteps) break;
    float r = length(p);
    if (r < 1.001) { captured = true; break; }
    if (r > FIELD_RADIUS + 0.01 && dot(p, velocity) > 0.0) { escaped = true; break; }
    float h = clamp(r * 0.085, 0.035, 2.0) * (180.0 / float(uSteps));
    // Smaller steps for nearly critical rays resolve multiple disk images.
    h *= mix(0.65, 1.0, smoothstep(2.0, 5.0, r));
    h /= max(1.0, length(velocity));
    if (uDisk && r < 14.0 && r > uInner - 0.5 && abs(dot(p, normal)) < 1.2) {
      float height = 0.035 + 0.016 * r;
      h = min(h, height * 1.4 / max(0.15, abs(dot(velocity, normal))));
    }
    vec3 acceleration = gravity(p, l2);
    vec3 next, nextVelocity;
    if (r < 7.0) {
      // RK4 only in the strong field: much less energy drift at the unstable
      // photon orbit, without quadrupling the cost of distant background rays.
      vec3 v2 = velocity + acceleration * (0.5 * h);
      vec3 a2 = gravity(p + velocity * (0.5 * h), l2);
      vec3 v3 = velocity + a2 * (0.5 * h);
      vec3 a3 = gravity(p + v2 * (0.5 * h), l2);
      vec3 v4 = velocity + a3 * h;
      vec3 a4 = gravity(p + v3 * h, l2);
      next = p + h * (velocity + 2.0 * v2 + 2.0 * v3 + v4) / 6.0;
      nextVelocity = velocity + h * (acceleration + 2.0 * a2 + 2.0 * a3 + a4) / 6.0;
    } else {
      next = p + velocity * h + acceleration * (0.5 * h * h);
      nextVelocity = velocity + (acceleration + gravity(next, l2)) * (0.5 * h);
    }
    vec3 midpoint = (p + next) * 0.5;
    angularTravel += angularSpeed * h / max(1.0, dot(midpoint, midpoint));

    if (uDisk && transmission > 0.003 && (uRing || angularTravel < PI)) {
      // Clip each curved segment to the disk slab, then integrate its optical depth.
      // This avoids missing a thin disk even at low ray-step counts.
      float y0 = dot(p, normal), y1 = dot(next, normal);
      float dy = y1 - y0;
      float ta = 0.0, tb = 1.0;
      if (abs(dy) < 0.00001) { if (abs(y0) > 1.2) tb = 0.0; }
      else {
        float a = (-1.2 - y0) / dy, b1 = (1.2 - y0) / dy;
        ta = max(0.0, min(a, b1)); tb = min(1.0, max(a, b1));
      }
      if (tb > ta) {
        // Two-point Gaussian quadrature, rather than one midpoint of a thin slab.
        // Resolve the height profile and gas variation without a dense opaque sheet.
        for (int j = 0; j < 2; j++) {
          float fraction = j == 0 ? 0.2113248654 : 0.7886751346;
          float t = mix(ta, tb, fraction);
          vec3 samplePosition = mix(p, next, t);
          float extinction;
          float footprint = max(0.002, length(samplePosition - origin) * uPixelAngle);
          vec3 emission = diskRadiance(samplePosition, mix(velocity, nextVelocity, t), normal,
            footprint, observerPotential, extinction);
          float potential = max(0.02, 1.0 - 1.0 / length(samplePosition));
          float properLength = h * (tb - ta) * 0.5 / sqrt(potential);
          float opticalDepth = extinction * properLength;
          float opacity = 1.0 - exp(-opticalDepth);
          color += transmission * emission * opacity;
          transmission *= 1.0 - opacity;
        }
      }
    }
    p = next;
    velocity = nextVelocity;
  }
  // Unresolved near-critical rays are absorbed, rather than leaking an unlensed sky.
  if (!escaped && length(p) < FIELD_RADIUS) captured = true;
  if (!captured) color += transmission * background(p * uRadius, normalize(velocity));

  // No additive outline. Higher-order photon images can only come from actual
  // emitting gas encountered after a curved ray travels more than pi radians.
  // Only cap at the half-float safety limit; preserve HDR detail until exposure.
  fragColor = vec4(min(color, vec3(60000.0)), 1.0);
}
