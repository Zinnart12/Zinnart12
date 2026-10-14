shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front;
uniform vec4 tint : source_color = vec4(0.15,0.42,0.85,1.0);
uniform float strength=0.4;
uniform vec3 sunlight_direction=vec3(1.0,0.0,0.0);
varying vec3 world_normal;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.6);
 float day=0.2+0.8*max(dot(normalize(world_normal),sunlight_direction),0.0);
 ALBEDO=tint.rgb*day;
 ALPHA=rim*strength;
}
