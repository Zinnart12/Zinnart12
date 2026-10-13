precision highp float;
in vec2 vUv;
out vec4 fragColor;
uniform sampler2D uScene;
uniform sampler2D uBloom;
uniform vec2 uTexel;
uniform float uBloomStrength;
uniform float uExposure;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 aces(vec3 c) {
  return clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0);
}
void main() {
  // FXAA on the HDR scene: derivative-based edge detection without temporal ghosting.
  vec3 center = texture(uScene, vUv).rgb;
  vec3 nw = texture(uScene, vUv + vec2(-1, 1) * uTexel).rgb;
  vec3 ne = texture(uScene, vUv + vec2(1, 1) * uTexel).rgb;
  vec3 sw = texture(uScene, vUv + vec2(-1,-1) * uTexel).rgb;
  vec3 se = texture(uScene, vUv + vec2(1,-1) * uTexel).rgb;
  float lnw = luma(nw), lne = luma(ne), lsw = luma(sw), lse = luma(se), lm = luma(center);
  vec2 dir = vec2(-((lnw + lne) - (lsw + lse)), (lnw + lsw) - (lne + lse));
  float reduce = max((lnw + lne + lsw + lse) * 0.03125, 0.0078125);
  dir = clamp(dir / (min(abs(dir.x), abs(dir.y)) + reduce), vec2(-6.0), vec2(6.0)) * uTexel;
  vec3 a = 0.5 * (texture(uScene, vUv + dir * (-1.0/6.0)).rgb + texture(uScene, vUv + dir * (1.0/6.0)).rgb);
  vec3 b = a * 0.5 + 0.25 * (texture(uScene, vUv - dir * 0.5).rgb + texture(uScene, vUv + dir * 0.5).rgb);
  float lb = luma(b);
  float lo = min(lm, min(min(lnw, lne), min(lsw, lse)));
  float hi = max(lm, max(max(lnw, lne), max(lsw, lse)));
  vec3 color = lb < lo || lb > hi ? a : b;
  color += texture(uBloom, vUv).rgb * uBloomStrength;
  color = pow(aces(color * uExposure), vec3(1.0 / 2.2));
  // Gentle vignette; it never adds light to the captured black-hole center.
  vec2 q = vUv * 2.0 - 1.0;
  color *= 1.0 - 0.14 * smoothstep(0.25, 1.6, dot(q, q));
  fragColor = vec4(color, 1.0);
}
