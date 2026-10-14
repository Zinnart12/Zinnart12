shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.2, 0.5, 0.8, 1.0);
uniform int surface_kind = 0;
uniform float seed = 1.0;
uniform float sim_time = 0.0;
uniform float temperature = 288.0;
uniform vec3 sunlight_direction = vec3(1.0,0.0,0.0);
varying vec3 sphere_pos;
varying vec3 world_normal;
float hash(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.yzx + 33.33); return fract((p.x + p.y) * p.z); }
float noise3(vec3 p) {
 vec3 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) { float a=0.52,n=0.0; for(int i=0;i<5;i++){ n+=a*noise3(p); p=p*2.03+vec3(7.1,3.6,9.3); a*=0.48;} return n; }
void vertex(){ sphere_pos=VERTEX; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
 vec3 p=normalize(sphere_pos), q=p*4.1+seed;
 float terrain=fbm(q+vec3(fbm(q*0.8),fbm(q+5.1),fbm(q+9.3))*1.3);
 float detail=noise3(p*55.0+seed);
 vec3 color=base_color.rgb;
 float water=0.0;
 if(surface_kind==0 || surface_kind==5){
  float land=surface_kind==5?0.0:smoothstep(0.48,0.54,terrain);
  water=1.0-land;
  vec3 ocean=mix(vec3(0.008,0.025,0.09),vec3(0.02,0.22,0.40),smoothstep(0.36,0.49,terrain));
  vec3 ground=mix(vec3(0.055,0.19,0.04),vec3(0.34,0.25,0.11),smoothstep(0.59,0.72,terrain));
  color=mix(ocean,ground*(0.8+0.35*detail),land);
  color=mix(color,vec3(0.84,0.91,0.94),smoothstep(0.8,0.94,abs(p.y)+(terrain-0.5)*0.13));
  float night=1.0-smoothstep(-0.2,0.12,dot(normalize(world_normal),sunlight_direction));
  float city=pow(noise3(p*210.0+seed),22.0)*land*night;
  EMISSION=vec3(1.0,0.46,0.10)*city*0.65;
 }else if(surface_kind==2){
  float warp=fbm(p*8.0+seed);
  float bands=noise3(vec3(p.y*32.0+warp*2.7,p.x*2.1,p.z*2.1)+seed);
  color=mix(base_color.rgb*0.30,base_color.rgb*(0.75+terrain*0.55),smoothstep(0.25,0.75,bands));
 }else if(surface_kind==3){ color*=0.62+terrain*0.55; }
 else{ color*=0.55+terrain*0.68+detail*0.18; }
 ALBEDO=color;
 ROUGHNESS=mix(0.83,0.13,water);
 METALLIC=0.04*water;
 NORMAL_MAP=vec3(0.5+(detail-0.5)*0.09,0.5+(terrain-0.5)*0.09,1.0);
 NORMAL_MAP_DEPTH=0.18*(1.0-water);
 if(surface_kind==4 || temperature>1300.0){
  float lava=smoothstep(0.5,0.68,fbm(p*13.0+seed));
  EMISSION+=vec3(1.0,0.19,0.025)*lava*clamp(pow(temperature/1600.0,4.0),0.0,6.0);
 }
}
