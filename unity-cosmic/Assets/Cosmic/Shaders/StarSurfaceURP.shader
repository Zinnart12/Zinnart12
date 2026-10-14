Shader "Cosmic/Star" {
 Properties { _TemperatureColor("Temperature Color",Color)=(1,.93,.77,1) _Temperature("Temperature K",Float)=5772 _Seed("Seed",Float)=1 }
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "RenderType"="Opaque"}
 Pass {Tags {"LightMode"="UniversalForward"}
 HLSLPROGRAM
 #pragma target 4.5
 #pragma vertex vert
 #pragma fragment frag
 #include "SurfaceCommon.hlsl"
 half4 frag(Varyings i):SV_Target {
  float3 p=normalize(i.local);float coarse=fbm(p*13+_Seed+float3(_SimulationTime*.002,0,0));
  float cell=noise3(p*(_CosmicDetail<.5?35:(_CosmicDetail<1.5?67:103))+_Seed+warp(p*9)*.6+float3(_SimulationTime*.03,0,0));
  float spots=smoothstep(.65,.77,coarse),emission=(.32+1.3*pow(cell,2.2))*(1-spots*.7);
  float limb=.45+.55*pow(abs(dot(normalize(i.normalWS),normalize(GetWorldSpaceViewDir(i.positionWS)))),.4);
  return half4(_TemperatureColor.rgb*emission*limb*.7*clamp(pow(_Temperature/5772,.35),.4,2.5),1);
 }
 ENDHLSL
 }}
}
