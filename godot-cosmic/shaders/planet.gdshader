shader_type spatial;
render_mode ambient_light_disabled;
#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/lighting.gdshaderinc"
uniform vec4 base_color:source_color=vec4(.2,.5,.8,1);
uniform int surface_kind=0;
uniform float seed=1.;
uniform float sim_time=0.;
uniform float temperature=288.;
uniform int detail_quality=1;
uniform bool great_red_spot=false;
uniform bool mars_surface=false;
varying vec3 sphere_pos;
varying vec3 world_normal;
void vertex(){sphere_pos=VERTEX;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 p=normalize(sphere_pos),q=p*4.1+seed;
 float terrain=fbm(q+warp(q*.8)*1.3),detail=noise3(p*(detail_quality==0?24.:detail_quality==1?55.:110.)+seed);
 vec3 color=base_color.rgb,thermal=vec3(0.);float water=0.,land=0.;
 if(surface_kind==0||surface_kind==5){
  land=surface_kind==5?0.:smoothstep(.48,.54,terrain);water=1.-land;
  vec3 ocean=mix(vec3(.008,.045,.16),vec3(.025,.32,.52),smoothstep(.36,.49,terrain));
  vec3 ground=mix(vec3(.075,.28,.055),vec3(.42,.31,.14),smoothstep(.59,.72,terrain));
  color=mix(ocean,ground*(.85+.35*detail),land);
  float ice=smoothstep(.79,.94,abs(p.y)+(terrain-.5)*.13)*clamp((300.-temperature)/30.,0.,1.);
  color=mix(color,vec3(.85,.92,.96),ice);
  float illumination=0.;for(int i=0;i<4;i++){if(i>=stellar_count)break;illumination+=max(dot(normalize(world_normal),stellar_directions[i]),0.)*stellar_flux[i].a;}
  float city=pow(noise3(p*210.+seed),22.)*land*(1.-smoothstep(.01,.1,illumination));thermal+=vec3(1,.46,.1)*city*.5;
 }else if(surface_kind==2){
  float angle=sim_time*(.012+.032*p.y*p.y);
  vec3 adv=vec3(p.x*cos(angle)-p.z*sin(angle),p.y,p.x*sin(angle)+p.z*cos(angle));
  float bands=noise3(vec3(p.y*32.+fbm(adv*8.+seed)*2.7,adv.x*2.1,adv.z*2.1)+seed);
  color=mix(base_color.rgb*.4,base_color.rgb*(.8+terrain*.55),smoothstep(.25,.75,bands));
  if(great_red_spot){float spot=length(vec2(atan(adv.z,adv.x)-.6,(adv.y+.2)*2.5));color=mix(color,vec3(.64,.19,.09),1.-smoothstep(.18,.28,spot));}
 }else{color*=.6+terrain*.68+detail*.18;if(mars_surface){float craters=1.-smoothstep(.1,.18,noise3(p*28.+seed));color*=1.-.28*craters;color+=vec3(.15,.05,.025)*pow(terrain,4.);}}
 float roughness=mix(.84,.12,water),metallic=water*.02;
 ALBEDO=color;ROUGHNESS=roughness;METALLIC=metallic;
 NORMAL_MAP=vec3(.5+(detail-.5)*.09,.5+(terrain-.5)*.09,1.);NORMAL_MAP_DEPTH=.18*(1.-water);
 vec3 n=normalize(world_normal),v=normalize(INV_VIEW_MATRIX[3].xyz-(INV_VIEW_MATRIX*vec4(VERTEX,1)).xyz);
 if(detail_quality>0)n=normalize(n+vec3(dFdx(detail),dFdy(detail),0.)*.07*(1.-water));
 if(surface_kind==4||temperature>1300.){float lava=smoothstep(.5,.68,fbm(p*13.+seed));thermal+=vec3(1,.19,.025)*lava*clamp(pow(temperature/1600.,4.),0.,6.);}
 EMISSION=stellar_radiance(n,v,color,roughness,metallic)+thermal;
}
void light(){} // Explicit multi-star irradiance replaces artistic point attenuation.
