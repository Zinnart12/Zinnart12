shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,fog_disabled;
#include "res://shaders/noise.gdshaderinc"
uniform sampler2D screen_texture:hint_screen_texture,filter_linear;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform vec3 center_position=vec3(0);
uniform float rs_scene=1.0;
uniform float sim_time=0.0;
uniform float disk_temperature=12000.0;
uniform bool disk_enabled=true;
uniform int ray_steps=192;
uniform float step_precision=0.08;
uniform bool debug_rays=false;

// Schwarzschild null-orbit spatial equation in Rs units:
// d²x/dλ² = -(3/2) h² x / r^5, h = |x × dx/dλ|.
// Midpoint integration bends rays, including repeated disk crossings.
// No geometry warp, fixed ring, Kerr metric, or exact scene-wide curved visibility.
vec3 acceleration(vec3 p,float h2){float r2=max(dot(p,p),0.4);return -1.5*h2*p/(r2*r2*sqrt(r2));}
vec3 thermal_color(float t){float hot=clamp((t-1800.0)/18000.0,0.0,1.0);return mix(vec3(1.0,0.13,0.015),mix(vec3(1.0,0.72,0.23),vec3(0.63,0.80,1.0),hot),smoothstep(1500.0,4500.0,t));}
vec4 plasma(vec3 p,vec3 direction,float ds){
 float radius=length(p.xz);
 float height=0.10+0.035*radius;
 if(!disk_enabled||radius<3.0||radius>12.0||abs(p.y)>height*2.0)return vec4(0);
 float omega=0.70710678/pow(radius,1.5);
 float angle=atan(p.z,p.x)-sim_time*omega;
 vec3 adv=vec3(cos(angle)*radius,p.y*4.0,sin(angle)*radius);
 vec3 domain=adv*0.85+warp(adv*0.26+vec3(0,sim_time*0.004,0))*1.3;
 float density=fbm(domain)*0.65+noise3(domain*3.17+13.2)*0.25+noise3(domain*8.31+29.7)*0.1;
 float opacity=smoothstep(0.22,0.75,density)*exp(-p.y*p.y/(height*height))*smoothstep(3.0,3.4,radius)*(1.0-smoothstep(9.5,12.0,radius));
 float tau=opacity*ds*1.4;
 float alpha=1.0-exp(-tau);
 float temperature=disk_temperature*pow(3.2/radius,0.75)*(0.72+density*0.7);
 vec3 tangent=normalize(vec3(-p.z,0,p.x));
 float beta=min(0.58,sqrt(0.5/max(radius-1.0,0.1)));
 float doppler=sqrt(1.0-beta*beta)/(1.0-beta*dot(tangent,-normalize(direction)));
 float redshift=sqrt(max(0.0,1.0-1.0/length(p)));
 float g=redshift*doppler;
 // Fixed exposure reference: changing plasma temperature changes radiance, not only hue.
 vec3 emission=thermal_color(temperature*g)*clamp(pow(temperature/16000.0,4.0),0.0,8.0)*pow(g,4.0)*0.8;
 return vec4(emission*alpha,alpha);
}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0.0),vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0.0),vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);}
void fragment(){
 vec2 ndc=SCREEN_UV*2.0-1.0;
 vec4 view_point=INV_PROJECTION_MATRIX*vec4(ndc,1.0,1.0);
 vec3 world_direction=normalize((INV_VIEW_MATRIX*vec4(view_point.xyz/view_point.w,0.0)).xyz);
 vec3 camera_point=(INV_VIEW_MATRIX[3].xyz-center_position)/max(rs_scene,1e-12);
 float projection=dot(camera_point,world_direction);
 float discriminant=projection*projection-dot(camera_point,camera_point)+324.0;
 ALBEDO=vec3(0);ALPHA=0.0;
 if(discriminant>0.0&&projection<0.0){
  float enter=max(0.0,-projection-sqrt(discriminant));
  // Preserve foreground opaque meshes using the actual depth buffer (reverse Z).
  float depth=texture(depth_texture,SCREEN_UV).r;
  vec4 scene_view=INV_PROJECTION_MATRIX*vec4(ndc,depth,1.0);
  float scene_distance=length(scene_view.xyz/max(abs(scene_view.w),1e-12));
  if(depth<=0.000001||scene_distance>(enter*rs_scene)){
   vec3 p=camera_point+world_direction*enter,v=world_direction;
   float h2=dot(cross(p,v),cross(p,v));
   vec3 accumulated=vec3(0);float transmittance=1.0;bool captured=false;
   // Sub-pixel step jitter reduces coherent ray-march bands without changing the orbit equation.
   float jitter=0.92+0.16*hash3(vec3(FRAGCOORD.xy,7.31));
   for(int i=0;i<320;i++){
    if(i>=ray_steps)break;
    float radius=length(p);
    if(radius<1.0){captured=true;break;}
    if(radius>18.2&&dot(p,v)>0.0)break;
    float ds=clamp(radius*step_precision,0.012,1.6)*jitter;
    vec3 a=acceleration(p,h2),mid=p+v*ds*0.5;
    vec3 vmid=v+a*ds*0.5;
    vec3 next=p+vmid*ds;
    vec4 gas=plasma((p+next)*0.5,vmid,ds);
    accumulated+=transmittance*gas.rgb;
    transmittance*=1.0-gas.a;
    v+=acceleration(mid,h2)*ds;p=next;
   }
   vec3 outgoing=normalize((VIEW_MATRIX*vec4(normalize(v),0.0)).xyz);
   vec4 projected=PROJECTION_MATRIX*vec4(outgoing,0.0);
   vec2 warped_uv=projected.xy/max(abs(projected.w),1e-6)*0.5+0.5;
   vec3 background=texture(screen_texture,clamp(warped_uv,vec2(0.001),vec2(0.999))).rgb;
   // Thin photon images arise from longer paths and multiple plasma crossings.
   ALBEDO=accumulated+(captured?vec3(0):background)*transmittance;
   if(debug_rays)ALBEDO=captured?vec3(1,0,0):vec3(0,0,1);
   ALPHA=1.0;
  }
 }
}
