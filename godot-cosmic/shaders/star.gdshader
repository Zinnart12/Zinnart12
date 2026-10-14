shader_type spatial;
render_mode ambient_light_disabled;
#include "res://shaders/noise.gdshaderinc"
uniform vec4 temperature_color:source_color=vec4(1,.93,.77,1);
uniform float temperature=5772.;
uniform float sim_time=0.;
uniform float seed=1.;
uniform int detail_quality=1;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
 vec3 p=normalize(local_position);
 float coarse=fbm(p*13.+seed+vec3(sim_time*.002,0,0));
 float cell=noise3(p*(detail_quality==0?35.:detail_quality==1?67.:103.)+seed+warp(p*9.)*.6+vec3(sim_time*.03,0,0));
 float spots=smoothstep(.65,.77,coarse);
 float emission=(.32+1.3*pow(cell,2.2))*(1.-spots*.7);
 float limb=.45+.55*pow(abs(dot(normalize(NORMAL),normalize(VIEW))),.4);
 ALBEDO=vec3(0);ROUGHNESS=1.;EMISSION=temperature_color.rgb*emission*limb*.7*clamp(pow(temperature/5772.,.35),.4,2.5);
}
void light(){}
