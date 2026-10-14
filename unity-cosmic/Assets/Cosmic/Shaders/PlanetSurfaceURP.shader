Shader "Cosmic/Planet" {
 Properties {
  _BaseColor("Base Color",Color)=(.2,.5,.8,1) _Temperature("Temperature K",Float)=288 _Seed("Seed",Float)=1
  _SurfaceKind("Surface Kind",Float)=0 _IsMars("Mars",Float)=0 _RedSpot("Great Red Spot",Float)=0
  [HideInInspector] _PreviewFlux("Editor Irradiance",Float)=0
  [HideInInspector] _PreviewLightDirection("Editor Light Direction",Vector)=(1,0,0,0)
  [HideInInspector] _PreviewLightColor("Editor Light Color",Color)=(1,.93,.8,1)
 }
 SubShader { Tags {"RenderPipeline"="UniversalPipeline" "RenderType"="Opaque"}
 Pass { Name "Planet Surface" Tags {"LightMode"="UniversalForward"}
 HLSLPROGRAM
 #pragma target 4.5
 #pragma vertex vert
 #pragma fragment frag
 #include "SurfaceCommon.hlsl"
 half4 frag(Varyings i):SV_Target {
  float3 p=normalize(i.local),q=p*4.1+_Seed;
  float terrain=fbm(q+warp(q*.8)*1.3),detail=noise3(p*(_CosmicDetail<.5?24:(_CosmicDetail<1.5?55:110))+_Seed);
  float3 color=_BaseColor.rgb,thermal=0;float water=0,land=0;
  if(_SurfaceKind<.5 || _SurfaceKind>4.5) {
   land=_SurfaceKind>4.5?0:smoothstep(.48,.54,terrain);water=1-land;
   float3 ocean=lerp(float3(.008,.045,.16),float3(.025,.32,.52),smoothstep(.36,.49,terrain));
   float3 ground=lerp(float3(.075,.28,.055),float3(.42,.31,.14),smoothstep(.59,.72,terrain));
   color=lerp(ocean,ground*(.85+.35*detail),land);
   float ice=smoothstep(.79,.94,abs(p.y)+(terrain-.5)*.13)*saturate((300-_Temperature)/30);
   color=lerp(color,float3(.85,.92,.96),ice);
   float illumination=0;[unroll]for(int j=0;j<4;j++)if(j<_StellarCount)illumination+=max(dot(normalize(i.normalWS),_StellarDirection[j].xyz),0)*_StellarFlux[j].w;
   if(_StellarCount==0 && _PreviewFlux>0)illumination=max(dot(normalize(i.normalWS),normalize(_PreviewLightDirection.xyz)),0)*_PreviewFlux;
   float city=pow(noise3(p*210+_Seed),22)*land*(1-smoothstep(.01,.1,illumination));thermal+=float3(1,.46,.1)*city*.5;
  } else if(_SurfaceKind>1.5 && _SurfaceKind<3.5) {
   float angle=_SimulationTime*(.012+.032*p.y*p.y);
   float3 adv=float3(p.x*cos(angle)-p.z*sin(angle),p.y,p.x*sin(angle)+p.z*cos(angle));
   float bands=noise3(float3(p.y*32+fbm(adv*8+_Seed)*2.7,adv.x*2.1,adv.z*2.1)+_Seed);
   float contrast=_SurfaceKind>2.5?.16:.6;
   color=lerp(_BaseColor.rgb*(1-contrast),_BaseColor.rgb*(.8+terrain*.55),smoothstep(.25,.75,bands));
   if(_RedSpot>.5) {float spot=length(float2(atan2(adv.z,adv.x)-.6,(adv.y+.2)*2.5));color=lerp(color,float3(.64,.19,.09),1-smoothstep(.18,.28,spot));}
  } else {
   color*=.6+terrain*.68+detail*.18;
   float craters=1-smoothstep(.1,.18,noise3(p*28+_Seed));color*=1-.28*craters;
   if(_IsMars>.5)color+=float3(.15,.05,.025)*pow(terrain,4);
  }
  float3 n=normalize(i.normalWS),v=normalize(GetWorldSpaceViewDir(i.positionWS));
  float3 dpdx=ddx(i.positionWS),dpdy=ddy(i.positionWS);
  float3 bump=cross(dpdy,n)*ddx(detail)+cross(n,dpdx)*ddy(detail);
  n=normalize(n+bump*(1-water)*.015/max(length(dpdx)+length(dpdy),.00001));
  if((_SurfaceKind>3.5 && _SurfaceKind<4.5) || _Temperature>1300)thermal+=float3(1,.19,.025)*smoothstep(.5,.68,fbm(p*13+_Seed))*min(pow(_Temperature/1600,4),6);
  return half4(radiance(n,v,color,lerp(.84,.12,water))+thermal,1);
 }
 ENDHLSL
 }}
}
