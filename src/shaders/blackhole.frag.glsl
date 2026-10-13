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

vec3 diskRadiance(vec3 p, vec3 rayVelocity, vec3 normal, out float density) {
  // Disk-local coordinates; inclination changes the volume, not its screen projection.
  vec3 q = vec3(p.x, dot(p, normal), -p.y * sin(uTilt) + p.z * cos(uTilt));
  float r = length(q.xz);
  density = 0.0;
  if (r < uInner || r > 13.5) return vec3(0.0);
  float orbitalPhase = atan(q.z, q.x) - uTime * (1.0 + uSpin * 0.8) * sqrt(0.5 / (r * r * r)) * 2.0;
  vec3 flow = vec3(cos(orbitalPhase), sin(orbitalPhase), r * 0.33);
  float turbulence = fbm(flow * vec3(3.7, 3.7, 2.0));
  float filaments = sin(r * 39.0 + orbitalPhase * 3.0 + turbulence * 10.0 + sin(orbitalPhase * 7.0 + r * 2.1) * 0.7);
  float fine = sin(r * 72.0 + turbulence * 19.0 + orbitalPhase * 2.0);
  float structure = 0.48 + 0.32 * filaments + 0.13 * fine + 0.6 * turbulence;
  float edge = smoothstep(uInner, uInner + 0.22, r) * (1.0 - smoothstep(10.5, 13.5, r));
  float vertical = exp(-q.y * q.y / 0.007);
  density = max(0.02, structure) * edge * vertical * uDensity * 5.0;
  vec3 tangent = normalize(cross(normal, p));
  float beta = min(0.62, sqrt(0.5 / max(r - 1.0, 0.2))) * (1.0 + uSpin * 0.1);
  float gamma = inversesqrt(1.0 - beta * beta);
  float doppler = 1.0 / (gamma * (1.0 - beta * dot(tangent, -normalize(rayVelocity))));
  float gravitationalRedshift = sqrt(max(0.02, 1.0 - 1.0 / r));
  float shift = clamp(doppler * gravitationalRedshift, 0.25, 2.5);
  float temperature = uTemperature * pow(3.0 / r, 0.67) * shift;
  float radialEnergy = pow(3.0 / r, 2.2);
  return blackbody(temperature) * radialEnergy * pow(shift, 3.0) * uBrightness * 3.0 * pow(max(0.1, structure), 1.5);
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

  if (length(origin) <= 1.001) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }
  float b = dot(p, velocity);
  float sphereD = b * b - dot(p, p) + FIELD_RADIUS * FIELD_RADIUS;
  if (sphereD < 0.0 || (b > 0.0 && length(p) > FIELD_RADIUS)) {
    fragColor = vec4(background(uCamera, initialDir), 1.0); return;
  }
  if (length(p) > FIELD_RADIUS) p += velocity * max(0.0, -b - sqrt(sphereD));

  // Convert the observer's locally measured direction to an affine null-ray velocity.
  // E=1, v_radial=cos(psi), v_tangent=sin(psi)/sqrt(1-Rs/r).
  vec3 radial = normalize(p);
  vec3 vr = radial * dot(velocity, radial);
  velocity = vr + (velocity - vr) / sqrt(max(0.02, 1.0 - uLensing / length(p)));
  vec3 angularMomentum = cross(p, velocity);
  float l2 = dot(angularMomentum, angularMomentum);
  float impact = sqrt(l2);
  vec3 normal = vec3(0.0, cos(uTilt), sin(uTilt));

  // Bounded velocity-Verlet integration in units Rs=1. Finite quality budget.
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
    vec3 acceleration = gravity(p, l2);
    vec3 next = p + velocity * h + acceleration * (0.5 * h * h);
    vec3 nextVelocity = velocity + (acceleration + gravity(next, l2)) * (0.5 * h);

    if (uDisk && transmission > 0.005) {
      // Clip each curved segment to the disk slab, then integrate its optical depth.
      // This avoids missing a thin disk even at low ray-step counts.
      float y0 = dot(p, normal), y1 = dot(next, normal);
      float dy = y1 - y0;
      float ta = 0.0, tb = 1.0;
      if (abs(dy) < 0.00001) { if (abs(y0) > 0.19) tb = 0.0; }
      else {
        float a = (-0.19 - y0) / dy, b1 = (0.19 - y0) / dy;
        ta = max(0.0, min(a, b1)); tb = min(1.0, max(a, b1));
      }
      if (tb > ta) {
        vec3 samplePosition = mix(p, next, (ta + tb) * 0.5);
        float materialDensity;
        vec3 emission = diskRadiance(samplePosition, velocity, normal, materialDensity);
        float depth = materialDensity * length(next - p) * (tb - ta);
        float opacity = 1.0 - exp(-depth);
        color += transmission * emission * opacity;
        transmission *= 1.0 - opacity;
      }
    }
    p = next;
    velocity = nextVelocity;
  }
  // Unresolved near-critical rays are absorbed, rather than leaking an unlensed sky.
  if (!escaped && length(p) < FIELD_RADIUS) captured = true;
  if (!captured) color += transmission * background(p * uRadius, normalize(velocity));

  if (uRing && uLensing > 0.01) {
    // Subpixel approximation of unresolved higher-order photon images at b=3sqrt(3)/2 Rs.
    // Resolved multiple disk crossings above produce the actual secondary images.
    float critical = 2.598076 * sqrt(uLensing);
    float width = max(0.012, fwidth(impact) * 0.6);
    float ring = exp(-pow((impact - critical) / width, 2.0));
    float azimuth = atan(screen.y, screen.x);
    color += ring * blackbody(uTemperature * 0.85) * (0.18 + 0.1 * sin(azimuth + uTime * 0.07)) * uBrightness;
  }
  fragColor = vec4(min(color, vec3(40.0)), 1.0);
}
