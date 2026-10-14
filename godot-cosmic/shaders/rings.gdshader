shader_type spatial;
render_mode cull_disabled,ambient_light_disabled,blend_mix;
#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/lighting.gdshaderinc"
varying vec3 local_pos;
varying vec3 world_normal;
void vertex(){local_pos=VERTEX;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){float r=length(local_pos.xz);float grain=noise3(vec3(r*95.,local_pos.x*18.,local_pos.z*18.));vec3 color=mix(vec3(.23,.18,.12),vec3(.75,.64,.42),grain);float gap=1.-smoothstep(1.89,1.93,r)*(1.-smoothstep(1.99,2.03,r));ALBEDO=color;ALPHA=gap*(.6+grain*.35);ROUGHNESS=.95;vec3 n=normalize(world_normal);if(!FRONT_FACING)n=-n;EMISSION=stellar_radiance(n,normalize(INV_VIEW_MATRIX[3].xyz-(INV_VIEW_MATRIX*vec4(VERTEX,1)).xyz),color,.95,0.);vec3 l=normalize(sunlight_direction);vec3 point=(MODEL_MATRIX*vec4(local_pos,0)).xyz/length(MODEL_MATRIX[0].xyz);float proj=dot(point,l);if(proj<0.&&length(point-proj*l)<1.)EMISSION*=.08;}
void light(){}
