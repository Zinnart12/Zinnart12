#ifndef COSMIC_SURFACE_INCLUDED
#define COSMIC_SURFACE_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Noise.hlsl"
float _CosmicDetail;
CBUFFER_START(UnityPerMaterial)
float4 _BaseColor, _TemperatureColor;
float _Temperature, _Seed, _SimulationTime, _SurfaceKind, _IsMars, _RedSpot, _AtmosphereStrength;
int _StellarCount;
float4 _StellarDirection[4], _StellarFlux[4], _SunDirection;
float4 _PreviewLightDirection, _PreviewLightColor;
float _PreviewFlux;
CBUFFER_END
struct Attributes {float4 positionOS:POSITION;float3 normalOS:NORMAL;float2 uv:TEXCOORD0;};
struct Varyings {float4 positionCS:SV_POSITION;float3 local:TEXCOORD0;float3 normalWS:TEXCOORD1;float3 positionWS:TEXCOORD2;float2 uv:TEXCOORD3;};
Varyings vert(Attributes i) {
 Varyings o;o.positionCS=TransformObjectToHClip(i.positionOS.xyz);o.local=i.positionOS.xyz;
 o.normalWS=TransformObjectToWorldNormal(i.normalOS);o.positionWS=TransformObjectToWorld(i.positionOS.xyz);o.uv=i.uv;return o;
}
float3 radiance(float3 n,float3 v,float3 albedo,float roughness) {
 float3 result=albedo*.012;float nv=max(dot(n,v),.001);
 [unroll]for(int j=0;j<4;j++) {
  int count=_StellarCount>0?_StellarCount:(_PreviewFlux>0?1:0);
  if(j>=count)break;
  float3 l=normalize(_StellarCount>0?_StellarDirection[j].xyz:_PreviewLightDirection.xyz),h=normalize(l+v);
  float nl=max(dot(n,l),0),nh=max(dot(n,h),0),vh=max(dot(v,h),0);
  float alpha=roughness*roughness,a2=alpha*alpha;
  float denom=nh*nh*(a2-1)+1;
  float distribution=a2/(PI*denom*denom+.0001),k=(roughness+1)*(roughness+1)/8;
  float geometry=(nv/(nv*(1-k)+k))*(nl/(nl*(1-k)+k));
  float3 fresnel=.04+.96*pow(1-vh,5);
  float3 specular=fresnel*distribution*geometry/(4*nv*nl+.0001);
  float flux=max(_StellarCount>0?_StellarFlux[j].w:_PreviewFlux,0);float exposure=flux/(1+.65*flux);
  float3 sourceColor=_StellarCount>0?_StellarFlux[j].rgb:_PreviewLightColor.rgb;
  result+=((1-fresnel)*albedo+specular)*nl*sourceColor*exposure;
 }
 return result;
}
#endif
