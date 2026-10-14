shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled;
uniform float sim_time=0.;
void fragment(){float edge=pow(max(0.,1.-abs(UV.x-.5)*2.),2.);ALBEDO=vec3(.12,.5,1.4);ALPHA=edge*(1.-UV.y)*.18;}
