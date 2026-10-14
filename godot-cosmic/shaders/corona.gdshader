shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled;
#include "res://shaders/noise.gdshaderinc"
uniform vec4 tint:source_color=vec4(1,.7,.3,1);
uniform float sim_time=0.;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0.0),vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0.0),vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);}
void fragment(){vec2 p=(UV-.5)*6.;float r=length(p);float stream=fbm(vec3(p*4.,sim_time*.03));float halo=exp(-max(0.,r-1.)*4.)*smoothstep(.95,1.1,r)*(1.-smoothstep(2.,3.,r));ALBEDO=tint.rgb*2.;ALPHA=halo*(.1+stream*.16);}
