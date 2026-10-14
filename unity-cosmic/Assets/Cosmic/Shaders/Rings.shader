Shader "Cosmic/Rings" {
 Properties {
  _BaseColor("Tint",Color)=(.7,.6,.4,1) _Seed("Seed",Float)=1 _SunDirection("Sun Direction",Vector)=(1,0,0,0)
  [HideInInspector] _PreviewFlux("Editor Irradiance",Float)=0
  [HideInInspector] _PreviewLightDirection("Editor Light Direction",Vector)=(1,0,0,0)
  [HideInInspector] _PreviewLightColor("Editor Light Color",Color)=(1,.93,.8,1)
 }
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {Tags {"LightMode"="UniversalForward"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "SurfaceCommon.hlsl"
 half4 frag(Varyings i):SV_Target {
  float r=length(i.local.xz),grain=noise3(float3(r*83,i.local.x*45,i.local.z*45)+_Seed);
  float density=fbm(float3(r*40,2,3))*.8+.15;
  float gap=1-smoothstep(.035,.06,abs(r-1.9));float alpha=density*(1-gap)*smoothstep(1.25,1.35,r)*(1-smoothstep(2.15,2.3,r));
  float3 directionOS=normalize(mul((float3x3)unity_WorldToObject,_SunDirection.xyz+float3(.00001,0,0)));
  float along=dot(i.local,directionOS);float shadow=along<0 && length(i.local-directionOS*along)<1 ? .05:1;
  float3 n=normalize(i.normalWS);if(dot(n,_SunDirection.xyz)<0)n=-n;
  return half4(radiance(n,normalize(GetWorldSpaceViewDir(i.positionWS)),_BaseColor.rgb*(.65+.45*grain),.9)*shadow,alpha*.85);
 }
 ENDHLSL
 }}
}
