shader_type spatial;
render_mode ambient_light_disabled,cull_disabled;
#include "res://shaders/noise.gdshaderinc"
uniform vec4 tint:source_color=vec4(1,.3,.07,1);
uniform float sim_time=0.;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){ALBEDO=vec3(0);EMISSION=tint.rgb*(.5+fbm(p*14.+vec3(sim_time*.08,0,0))*2.);}
void light(){}
