shader_type spatial;
render_mode unshaded;
uniform vec4 temperature_color : source_color = vec4(1.0,0.93,0.77,1.0);
uniform float temperature=5772.0;
uniform float sim_time=0.0;
uniform float seed=1.0;
varying vec3 local_position;
float h(vec3 p){p=fract(p*0.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float n(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){local_position=VERTEX;}
void fragment(){
 vec3 p=normalize(local_position);
 float coarse=n(p*13.0+seed);
 float cell=n(p*67.0+seed+vec3(sim_time*0.00002,0,0));
 float spots=smoothstep(0.72,0.87,coarse);
 float emission=(0.48+1.7*pow(cell,2.2))*(1.0-spots*0.7);
 ALBEDO=vec3(0.0);
 EMISSION=temperature_color.rgb*emission*clamp(pow(temperature/5772.0,4.0),0.02,8.0);
}
