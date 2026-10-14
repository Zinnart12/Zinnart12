#ifndef COSMIC_NOISE_INCLUDED
#define COSMIC_NOISE_INCLUDED
float hash3(float3 p) {p=frac(p*.1031);p+=dot(p,p.yzx+33.33);return frac((p.x+p.y)*p.z);}
float noise3(float3 p) {
 float3 i=floor(p),f=frac(p);f=f*f*(3-2*f);
 return lerp(lerp(lerp(hash3(i),hash3(i+float3(1,0,0)),f.x),lerp(hash3(i+float3(0,1,0)),hash3(i+float3(1,1,0)),f.x),f.y),
  lerp(lerp(hash3(i+float3(0,0,1)),hash3(i+float3(1,0,1)),f.x),lerp(hash3(i+float3(0,1,1)),hash3(i+1),f.x),f.y),f.z);
}
float fbm(float3 p) {float a=.52,n=0;[unroll]for(int i=0;i<5;i++){n+=a*noise3(p);p=p*2.03+float3(7.1,3.6,9.3);a*=.48;}return n;}
float3 warp(float3 p) {return float3(fbm(p),fbm(p+5.7),fbm(p+11.3));}
#endif
