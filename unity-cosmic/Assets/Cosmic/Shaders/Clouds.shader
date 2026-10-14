Shader "Cosmic/Clouds" {
 Properties {
  _BaseColor("Tint",Color)=(1,1,1,1) _Seed("Seed",Float)=1
  [HideInInspector] _PreviewFlux("Editor Irradiance",Float)=0
  [HideInInspector] _PreviewLightDirection("Editor Light Direction",Vector)=(1,0,0,0)
  [HideInInspector] _PreviewLightColor("Editor Light Color",Color)=(1,.93,.8,1)
 }
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {Tags {"LightMode"="UniversalForward"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "SurfaceCommon.hlsl"
 half4 frag(Varyings i):SV_Target {
  float3 p=normalize(i.local);float a=_SimulationTime*.000025;
  p=float3(p.x*cos(a)-p.z*sin(a),p.y,p.x*sin(a)+p.z*cos(a));
  float coverage=smoothstep(.49,.7,fbm(p*8+warp(p*3)*1.5+_Seed));
  return half4(radiance(normalize(i.normalWS),normalize(GetWorldSpaceViewDir(i.positionWS)),float3(.85,.87,.9),.9),coverage*.74);
 }
 ENDHLSL
 }}
}
