shader_type spatial;
render_mode blend_mix, depth_draw_never;
uniform float sim_time=0.0;
varying vec3 local_pos;
float hash(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){local_pos=VERTEX;}
void fragment(){vec3 p=normalize(local_pos)*7.0+vec3(sim_time*0.000007,0,0);float f=noise3(p)*0.6+noise3(p*2.04+7.0)*0.3+noise3(p*4.17+13.0)*0.1;ALBEDO=vec3(0.92,0.96,1.0);ALPHA=smoothstep(0.57,0.73,f)*0.78;ROUGHNESS=1.0;}
