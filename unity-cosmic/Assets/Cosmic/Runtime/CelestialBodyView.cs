using System;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using Cosmic.Core;

namespace Cosmic.Runtime
{
    public sealed class CelestialBodyView : MonoBehaviour
    {
        readonly List<Renderer> surfaces=new List<Renderer>();
        readonly List<Material> ownedMaterials=new List<Material>();
        readonly Queue<Double3> trailPoints=new Queue<Double3>();
        MaterialPropertyBlock properties;
        LineRenderer trail;
        LODGroup lod;
        Transform spin;
        long trailStep=-1;
        public void Initialize(CelestialBody body,int quality)
        {
            properties=new MaterialPropertyBlock();
            spin=new GameObject("Axial Rotation").transform;spin.SetParent(transform,false);
            lod=spin.gameObject.AddComponent<LODGroup>();
            Material surface=Material(body.IsLuminous?"Star":"Planet");
            var levels=new LOD[3];
            for(int i=0;i<3;i++) {
                var mesh=MeshObject("Surface LOD "+i,PlanetGenerator.Sphere(2-i),surface,spin,1);
                surfaces.Add(mesh);levels[i]=new LOD(new[]{.35f,.07f,.001f}[i],new Renderer[]{mesh}); }
            lod.SetLODs(levels);lod.RecalculateBounds();
            if(!body.IsLuminous && body.Atmosphere>0) {
                surfaces.Add(MeshObject("Atmosphere",PlanetGenerator.Sphere(1),Material("Atmosphere"),spin,1.04f));
                if(body.Id=="earth" || body.Id=="venus")surfaces.Add(MeshObject("Cloud Layer",PlanetGenerator.Sphere(1),Material("Clouds"),spin,1.013f)); }
            if(body.Id=="saturn")surfaces.Add(MeshObject("Grain Rings",PlanetGenerator.Rings(),Material("Rings"),spin,1));
            var line=new GameObject("Integrated Orbit Trail");line.transform.SetParent(transform.parent,false);
            trail=line.AddComponent<LineRenderer>();trail.sharedMaterial=Material("Trail");trail.useWorldSpace=true;
            trail.widthMultiplier=.015f;trail.startColor=trail.endColor=new Color(.3f,.55f,.8f,.45f);
            SetQuality(quality);
        }
        Material Material(string name)
        {
            var template=Resources.Load<Material>("Materials/"+name);
            if(template==null)throw new InvalidOperationException("Material missing: "+name+". Prepare the project in the Editor.");
            var material=new Material(template);ownedMaterials.Add(material);return material;
        }
        static MeshRenderer MeshObject(string name,Mesh mesh,Material material,Transform parent,float scale)
        {
            var root=new GameObject(name,typeof(MeshFilter),typeof(MeshRenderer));root.transform.SetParent(parent,false);
            root.transform.localScale=Vector3.one*scale;root.GetComponent<MeshFilter>().sharedMesh=mesh;
            var renderer=root.GetComponent<MeshRenderer>();renderer.sharedMaterial=material;return renderer;
        }
        public void SetQuality(int quality)
        {
            if(lod==null)return;
            lod.ForceLOD(quality==0?2:-1);
        }
        public void Sync(CelestialBody body,UniverseManager universe)
        {
            transform.position=universe.ToScene(body.Position);transform.localScale=Vector3.one*universe.DisplayRadius(body);
            double rotation=body.RotationPeriod!=0 ? (universe.Simulation.Time/body.RotationPeriod%1)*360 : 0;
            spin.localRotation=Quaternion.Euler(0,0,(float)body.AxialTilt)*Quaternion.Euler(0,(float)rotation,0);
            ColorUtility.TryParseHtmlString("#"+body.Color,out var color);
            properties.Clear();properties.SetColor("_BaseColor",color.linear);properties.SetFloat("_Seed",(float)body.Seed);
            properties.SetFloat("_Temperature",(float)body.Temperature);
            properties.SetFloat("_SimulationTime",(float)(universe.Simulation.Time%1e6));
            properties.SetFloat("_SurfaceKind",Array.IndexOf(new[]{"earth","rocky","gas","ice","lava","ocean"},body.Surface));
            properties.SetFloat("_IsMars",body.Id=="mars"?1:0);properties.SetFloat("_RedSpot",body.Id=="jupiter"?1:0);
            properties.SetFloat("_AtmosphereStrength",(float)Math.Min(1,Math.Log(1+body.Atmosphere)));
            var sources=universe.Simulation.Bodies.Where(b=>b.Id!=body.Id && b.IsLuminous).Select(b=>new { Body=b,Flux=Flux(b,body) }).OrderByDescending(b=>b.Flux).Take(4).ToArray();
            var directions=new Vector4[4];var colors=new Vector4[4];int count=sources.Length;
            for(int i=0;i<count;i++) {
                var delta=(sources[i].Body.Position-body.Position).Normalized;
                directions[i]=new Vector4((float)delta.X,(float)delta.Y,(float)delta.Z,0);
                var c=TemperatureColor(sources[i].Body.Temperature);colors[i]=new Vector4(c.r,c.g,c.b,(float)(sources[i].Flux/1361)); }
            if(count==0 && universe.Simulation.Name=="Earth & Moon") {
                directions[0]=new Vector4(-1,0,0,0);colors[0]=new Vector4(1,.93f,.8f,1);count=1; }
            properties.SetInt("_StellarCount",count);properties.SetVectorArray("_StellarDirection",directions);properties.SetVectorArray("_StellarFlux",colors);
            properties.SetColor("_TemperatureColor",TemperatureColor(body.Temperature));
            properties.SetVector("_SunDirection",directions[0]);
            foreach(var renderer in surfaces)renderer.SetPropertyBlock(properties);
            if(universe.Simulation.Steps!=trailStep) {
                trailStep=universe.Simulation.Steps;trailPoints.Enqueue(body.Position);while(trailPoints.Count>256)trailPoints.Dequeue(); }
            trail.enabled=universe.Trails;
            if(trail.enabled) {
                var points=trailPoints.Select(universe.ToScene).ToArray();trail.positionCount=points.Length;trail.SetPositions(points);
                trail.widthMultiplier=Mathf.Clamp(Vector3.Distance(Camera.main.transform.position,transform.position)*.00015f,.002f,.12f); }
        }
        static double Flux(CelestialBody source,CelestialBody receiver) => source.Luminosity/(4*Math.PI*Math.Max((source.Position-receiver.Position).LengthSquared,source.Radius*source.Radius));
        public static Color TemperatureColor(double temperature)
        {
            double t=Numeric.Clamp(temperature,1000,40000)/100;
            double r=t<=66?255:329.698727446*Math.Pow(t-60,-.1332047592);
            double g=t<=66?99.4708025861*Math.Log(t)-161.1195681661:288.1221695283*Math.Pow(t-60,-.0755148492);
            double b=t>=66?255:t<=19?0:138.5177312231*Math.Log(t-10)-305.0447927307;
            return new Color((float)Numeric.Clamp(r/255,0,1),(float)Numeric.Clamp(g/255,0,1),(float)Numeric.Clamp(b/255,0,1)).linear;
        }
        void OnDestroy()
        {
            if(trail!=null)Destroy(trail.gameObject);
            foreach(var material in ownedMaterials)if(material!=null)Destroy(material);
        }
    }
}
