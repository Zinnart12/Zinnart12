shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_front;
uniform vec4 tint:source_color=vec4(.15,.42,.85,1);
uniform float strength=.4;
uniform vec3 sunlight_direction=vec3(1,0,0);
varying vec3 world_normal;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),3.6);float cosine=dot(normalize(world_normal),sunlight_direction);float day=smoothstep(-.25,.3,cosine);vec3 sunset=mix(tint.rgb,vec3(1,.29,.07),exp(-cosine*cosine*90.)*.65);ALBEDO=sunset*(.06+day);ALPHA=rim*strength;}
