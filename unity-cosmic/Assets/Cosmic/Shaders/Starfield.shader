Shader "Cosmic/Starfield" {
 Properties { _BaseColor("Tint",Color)=(.4,.48,.65,1) }
 SubShader {Tags {"RenderPipeline"="UniversalPipeline" "RenderType"="Opaque"}
 Pass {Tags {"LightMode"="UniversalForward"} Cull Off
 HLSLPROGRAM
 #pragma target 4.5
 #pragma vertex vertexStars
 #pragma fragment fragmentStars
 #pragma multi_compile_instancing
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 struct A {float4 positionOS:POSITION;float2 uv:TEXCOORD0;UNITY_VERTEX_INPUT_INSTANCE_ID};
 struct V {float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;};
 V vertexStars(A i) {UNITY_SETUP_INSTANCE_ID(i);V o;o.positionCS=TransformObjectToHClip(i.positionOS.xyz);o.uv=i.uv;return o;}
 half4 fragmentStars(V i):SV_Target {float r=length(i.uv-.5);clip(.48-r);return half4(float3(.4,.48,.65)*pow(saturate(1-r*2),2),1);}
 ENDHLSL
 }}
}
