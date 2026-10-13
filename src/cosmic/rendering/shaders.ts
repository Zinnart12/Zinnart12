/** Procedural surfaces are illustrative. Positions and radii come from the SI simulation. */
export const surfaceVertex = /* glsl */ `
varying vec3 vLocal;
varying vec3 vNormal;
varying vec3 vWorld;
void main() {
  vLocal = position;
  vNormal = normalize(mat3(modelMatrix) * normal);
  vWorld = (modelMatrix * vec4(position, 1.0)).xyz;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

const noise = /* glsl */ `
float hash(vec3 p) {
  p = fract(p * vec3(.1031, .1030, .0973));
  p += dot(p, p.yxz + 33.33);
  return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
  vec3 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
                 mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
                 mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
  float n = .52 * noise3(p);
  p = mat3(.00,.80,.60, -.80,.36,-.48, -.60,-.48,.64) * p * 2.03;
  n += .26 * noise3(p);
  p = mat3(.36,.80,.48, -.80,.00,.60, .48,-.60,.64) * p * 2.01;
  n += .13 * noise3(p);
  n += .065 * noise3(p * 2.11);
  return n;
}
`;

export const planetFragment = /* glsl */ `
precision highp float;
varying vec3 vLocal;
varying vec3 vNormal;
varying vec3 vWorld;
uniform vec3 uColor;
uniform vec3 uLightDir;
uniform vec3 uLightColor;
uniform vec3 uEye;
uniform float uSeed;
uniform float uTime;
uniform float uSurface;
uniform float uAtmosphere;
uniform float uAlbedo;
${noise}
void main() {
  vec3 p = normalize(vLocal);
  vec3 N = normalize(vNormal);
  vec3 V = normalize(uEye - vWorld);
  float latitude = abs(p.y);
  vec3 q = p * 4.2 + uSeed;
  float continental = fbm(q + vec3(fbm(q * .7), fbm(q * .7 + 6.1), 0.0) * 1.3);
  float detail = noise3(p * 42.0 + uSeed);
  vec3 base = uColor;
  float water = 0.0, land = 0.0, clouds = 0.0;
  if (uSurface < .5) {
    land = smoothstep(.48, .535, continental);
    water = 1.0 - land;
    vec3 ocean = mix(vec3(.005,.047,.16), vec3(.014,.21,.38), smoothstep(.39,.49,continental));
    float dry = smoothstep(.57,.68,continental) * (1.0 - smoothstep(.15,.6,latitude));
    vec3 terrain = mix(vec3(.038,.19,.065), vec3(.30,.23,.105), dry);
    terrain *= .78 + detail * .44;
    terrain = mix(terrain, vec3(.48,.49,.45), smoothstep(.71,.77,continental));
    base = mix(ocean, terrain, land);
    float ice = smoothstep(.76 + (continental-.5)*.18, .92, latitude);
    base = mix(base, vec3(.79,.87,.9), ice);
    vec3 wind = vec3(p.x + uTime*.00013, p.y*.82, p.z - uTime*.00007);
    clouds = smoothstep(.58,.7,fbm(wind * 6.4 + 23.1 + uSeed)) * uAtmosphere;
    base = mix(base, vec3(.89,.93,.97), clouds * .86);
  } else if (uSurface < 1.5) {
    float pits = smoothstep(.68,.82,noise3(p*34.0+uSeed));
    base *= .55 + continental*.75 + detail*.18 - pits*.18;
    base += vec3(.045,.035,.025) * smoothstep(.38,.58,continental);
  } else if (uSurface < 2.5) {
    float warp = fbm(p*8.0 + uSeed + vec3(uTime*.00009,0,0));
    float jet = noise3(vec3(p.y*31.0 + warp*2.8, p.x*1.8, p.z*1.8) + uSeed);
    float band = smoothstep(.31,.72,jet);
    vec3 lightGas = mix(vec3(.81,.69,.47), uColor, .43);
    vec3 darkGas = mix(vec3(.27,.13,.055), uColor*.42, .5);
    base = mix(darkGas, lightGas, band);
    base *= .76 + .48 * fbm(vec3(p.x*20.0,p.y*65.0,p.z*20.0)+uSeed);
    float storm = exp(-pow((p.y + .2)*16.0,2.0)-pow((p.z-.94)*10.0,2.0)) * smoothstep(-.2,.3,p.x);
    base = mix(base, vec3(.53,.17,.065), storm*.66);
  } else if (uSurface < 3.5) {
    base = mix(uColor*.55, mix(uColor,vec3(.73,.87,.94),.55),continental);
    base += pow(detail,5.0) * .16;
    base *= .83 + .24*noise3(p*85.0+uSeed);
  } else if (uSurface < 4.5) {
    float cracks = pow(1.0-abs(noise3(p*28.0+uSeed)*2.0-1.0),18.0);
    base = uColor * (.18 + continental*.4) + vec3(1.6,.21,.007)*cracks;
  } else {
    water = 1.0;
    base = mix(vec3(.008,.05,.17),uColor*.5,continental);
    clouds = smoothstep(.56,.73,fbm(p*7.0+uSeed+uTime*.0001))*uAtmosphere;
    base = mix(base,vec3(.86,.92,.98),clouds*.8);
  }
  float day = max(dot(N,uLightDir),0.0);
  float diffuse = pow(day,.86);
  vec3 lit = base * (vec3(.019,.027,.045) + uLightColor * diffuse * (1.04 + uAlbedo*.25));
  float spec = pow(max(dot(reflect(-uLightDir,N),V),0.0),72.0);
  lit += water * (1.0-clouds) * spec * day * vec3(.55,.67,.74);
  float rim = pow(1.0-max(dot(N,V),0.0),3.7);
  lit += vec3(.06,.26,.56)*rim*pow(day,.32)*uAtmosphere*.56;
  if (uSurface < .5) {
    float cities = pow(smoothstep(.58,.77,noise3(p*118.0+uSeed)),5.0);
    lit += vec3(.65,.32,.06)*cities*land*(1.0-smoothstep(-.15,.16,dot(N,uLightDir)))*.23;
  }
  if (uSurface > 3.5 && uSurface < 4.5) lit += max(base-vec3(.15),vec3(0))*.5;
  gl_FragColor = vec4(max(lit,vec3(0)),1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

export const starFragment = /* glsl */ `
precision highp float;
varying vec3 vLocal;
varying vec3 vNormal;
varying vec3 vWorld;
uniform vec3 uColor;
uniform vec3 uEye;
uniform float uSeed;
uniform float uTime;
${noise}
void main() {
  vec3 p=normalize(vLocal);
  float n=fbm(p*23.0+uSeed+vec3(uTime*.000015,0,0));
  float fine=noise3(p*82.0+uSeed);
  float spots=smoothstep(.72,.86,fbm(p*8.0+uSeed+43.1));
  float facing=max(dot(normalize(vNormal),normalize(uEye-vWorld)),0.0);
  float limb=.57+.43*pow(facing,.45);
  // Keep median granules below the ACES shoulder; only hot cell cores feed bloom.
  // Uniform high emission would compress the entire photosphere into featureless white.
  float cells=smoothstep(.22,.75,n);
  float emission=.54+2.25*pow(cells,2.3)+fine*.13;
  vec3 color=uColor*emission*(1.0-spots*.8)*limb;
  gl_FragColor=vec4(color,1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

export const atmosphereFragment = /* glsl */ `
varying vec3 vNormal;
varying vec3 vWorld;
uniform vec3 uEye;
uniform vec3 uLightDir;
uniform vec3 uColor;
uniform float uStrength;
void main() {
  float rim=pow(1.0-abs(dot(normalize(vNormal),normalize(uEye-vWorld))),3.3);
  float day=max(dot(normalize(vNormal),uLightDir),0.0);
  float alpha=rim*(.055+.24*pow(day,.35))*uStrength;
  gl_FragColor=vec4(uColor,alpha);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

export const ringFragment = /* glsl */ `
varying vec3 vLocal;
varying vec3 vWorld;
uniform vec3 uColor;
uniform vec3 uLightDir;
uniform vec3 uCenter;
uniform float uRadius;
uniform float uSeed;
${noise}
void main() {
  float r=length(vLocal.xy);
  float grain=noise3(vec3(r*135.0,uSeed,0.0));
  float structure=noise3(vec3(r*21.0,3.0,uSeed));
  float gap=1.0-smoothstep(.025,.048,abs(r-1.96));
  float alpha=(.19+structure*.46+grain*.18)*(1.0-gap*.85);
  alpha*=smoothstep(1.28,1.42,r)*(1.0-smoothstep(2.45,2.6,r));
  vec3 q=vWorld-uCenter;
  float t=-dot(q,uLightDir);
  float shadow=(t>0.0 && length(q+uLightDir*t)<uRadius)? .17:1.0;
  vec3 color=uColor*(.65+grain*.45)*shadow;
  gl_FragColor=vec4(color,alpha);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

export const starfieldVertex = /* glsl */ `
attribute float aSize;
attribute float aPhase;
varying vec3 vColor;
varying float vPhase;
uniform float uPixelRatio;
void main() {
  vColor=color;
  vPhase=aPhase;
  gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);
  gl_PointSize=aSize*uPixelRatio;
}`;
export const starfieldFragment = /* glsl */ `
varying vec3 vColor;
varying float vPhase;
uniform float uWallTime;
void main() {
  float radius=length(gl_PointCoord-.5)*2.0;
  float a=exp(-radius*radius*4.2)*(1.0-smoothstep(.5,1.0,radius));
  float twinkle=.88+.12*sin(uWallTime*.4+vPhase);
  gl_FragColor=vec4(vColor*twinkle,a);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

export const particlesVertex = /* glsl */ `
attribute vec3 aVelocity;
attribute float aSize;
varying float vFade;
uniform float uAge;
uniform float uPixelRatio;
void main() {
  float age=max(0.0,uAge);
  vec3 p=position+aVelocity*age;
  vec4 mv=modelViewMatrix*vec4(p,1.0);
  gl_Position=projectionMatrix*mv;
  gl_PointSize=min(9.0,aSize*uPixelRatio*95.0/max(12.0,-mv.z));
  vFade=exp(-age*.45);
}`;
export const particlesFragment = /* glsl */ `
varying float vFade;
void main() {
  float a=1.0-smoothstep(.08,.5,length(gl_PointCoord-.5));
  gl_FragColor=vec4(vec3(2.1,.6,.08),a*vFade);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;
