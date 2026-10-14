Shader "Cosmic/Trail" {
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
 Pass {Tags {"LightMode"="UniversalForward"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 HLSLPROGRAM
 #pragma vertex vertexLine
 #pragma fragment fragmentLine
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A {float4 positionOS:POSITION;float4 color:COLOR;};struct V {float4 positionCS:SV_POSITION;float4 color:COLOR;};
 V vertexLine(A i) {V o;o.positionCS=TransformObjectToHClip(i.positionOS.xyz);o.color=i.color;return o;}
 half4 fragmentLine(V i):SV_Target {return i.color;}
 ENDHLSL
 }}
}
