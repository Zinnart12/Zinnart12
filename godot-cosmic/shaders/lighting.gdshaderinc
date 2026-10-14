uniform int stellar_count=0;
uniform vec3 stellar_directions[4];
uniform vec4 stellar_flux[4];
uniform vec3 sunlight_direction=vec3(1,0,0);
uniform bool has_rings=false;
uniform int shadow_quality=1;
uniform vec3 ring_axis=vec3(0,1,0);
vec3 stellar_radiance(vec3 n,vec3 v,vec3 albedo,float roughness,float metallic){
 vec3 out_color=albedo*.012;
 for(int i=0;i<4;i++){
  if(i>=stellar_count)break;
  vec3 l=normalize(stellar_directions[i]),h=normalize(v+l);
  float nl=max(dot(n,l),0.),nv=max(dot(n,v),.001),nh=max(dot(n,h),0.);
  float a=max(roughness*roughness,.035),a2=a*a;
  float denom=nh*nh*(a2-1.)+1.;float d=a2/(3.14159265*denom*denom+.001);
  float k=(roughness+1.)*(roughness+1.)/8.;
  float g=nv/(nv*(1.-k)+k)*nl/(nl*(1.-k)+k);
  vec3 f0=mix(vec3(.04),albedo,metallic),f=f0+(1.-f0)*pow(1.-max(dot(h,v),0.),5.);
  float shadow=1.;
  if(shadow_quality>0&&has_rings&&abs(dot(l,ring_axis))>.001){float t=-dot(n,ring_axis)/dot(l,ring_axis);float radius=length(n+t*l);if(t>0.&&radius>1.35&&radius<2.4&&(radius<1.91||radius>2.02))shadow=.18;if(shadow_quality==2&&t>0.){float edge=max(fwidth(radius),.004);float band=smoothstep(1.35-edge,1.35+edge,radius)*(1.-smoothstep(2.4-edge,2.4+edge,radius));float gap=smoothstep(1.91-edge,1.91+edge,radius)*(1.-smoothstep(2.02-edge,2.02+edge,radius));shadow=1.-band*(1.-gap)*.82;}}
  // SI irradiance remains inverse-square; only display exposure is compressed.
  float energy=stellar_flux[i].a/(1.+stellar_flux[i].a/8.);
  out_color+=stellar_flux[i].rgb*energy*nl*shadow*((1.-f)*albedo+d*g*f/max(4.*nv*nl,.001));
 }return out_color;
}
