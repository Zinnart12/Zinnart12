shader_type spatial;
render_mode blend_mix,depth_draw_never,ambient_light_disabled;
#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/lighting.gdshaderinc"
uniform float sim_time=0.;
varying vec3 local_pos;
varying vec3 world_normal;
void vertex(){local_pos=VERTEX;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){vec3 p=normalize(local_pos)*7.+vec3(sim_time*.002,0,0);float f=fbm(p+warp(p*.5)*.7);ALBEDO=vec3(.92,.96,1);ALPHA=smoothstep(.55,.70,f)*.85;ROUGHNESS=1.;EMISSION=stellar_radiance(normalize(world_normal),normalize(INV_VIEW_MATRIX[3].xyz-(INV_VIEW_MATRIX*vec4(VERTEX,1)).xyz),ALBEDO,1.,0.);}
void light(){}
