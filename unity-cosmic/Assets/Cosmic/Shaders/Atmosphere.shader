Shader "Cosmic/Atmosphere" {
 Properties { _BaseColor("Tint",Color)=(.15,.42,.85,1) }
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {Tags {"LightMode"="UniversalForward"} Blend One One ZWrite Off Cull Front
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "SurfaceCommon.hlsl"
 half4 frag(Varyings i):SV_Target {
  float3 n=normalize(i.normalWS),v=normalize(GetWorldSpaceViewDir(i.positionWS));
  float rim=pow(1-saturate(abs(dot(n,v))),3.5),day=smoothstep(-.25,.4,dot(n,normalize(_SunDirection.xyz+float3(.00001,0,0))));
  float3 blue=float3(.06,.2,.5),sunset=float3(.6,.12,.025);
  float terminator=1-smoothstep(0,.35,abs(dot(n,normalize(_SunDirection.xyz+float3(.00001,0,0)))));
  return half4(lerp(blue,sunset,terminator*.55)*rim*day*_AtmosphereStrength,0);
 }
 ENDHLSL
 }}
}
