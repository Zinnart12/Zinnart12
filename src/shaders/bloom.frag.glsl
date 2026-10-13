precision highp float;
in vec2 vUv;
out vec4 fragColor;
uniform sampler2D uTexture;
uniform vec2 uTexel;
uniform vec2 uDirection;
uniform bool uThreshold;
void main() {
  vec3 c = texture(uTexture, vUv).rgb * 0.227027;
  c += texture(uTexture, vUv + uDirection * uTexel * 1.384615).rgb * 0.316216;
  c += texture(uTexture, vUv - uDirection * uTexel * 1.384615).rgb * 0.316216;
  c += texture(uTexture, vUv + uDirection * uTexel * 3.230769).rgb * 0.070270;
  c += texture(uTexture, vUv - uDirection * uTexel * 3.230769).rgb * 0.070270;
  if (uThreshold) c *= smoothstep(0.65, 1.8, max(c.r, max(c.g, c.b)));
  fragColor = vec4(c, 1.0);
}
