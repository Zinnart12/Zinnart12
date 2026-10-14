using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using Cosmic.Core;
using Cosmic.Runtime;

namespace Cosmic.Editor
{
    public static class SolarSystemBuilder
    {
        public static void CreateIfMissing()
        {
            Directory.CreateDirectory("Assets/Scenes");
            if(!File.Exists(ProjectBuilder.SolarPath))CreateSolarScene();
            if(!File.Exists(ProjectBuilder.MenuPath)) {
                var previous=EditorSceneManager.GetSceneManagerSetup();
                try {var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
                    new GameObject("Cosmic Bootstrap").AddComponent<CosmicBootstrap>().showMenu=true;
                    EditorSceneManager.SaveScene(scene,ProjectBuilder.MenuPath);}
                finally {EditorSceneManager.RestoreSceneManagerSetup(previous);}
            }
        }
        [MenuItem("Cosmic/Rebuild Solar System Scene")]
        public static void Rebuild()
        {
            if(!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())return;
            CreateSolarScene();EditorSceneManager.OpenScene(ProjectBuilder.SolarPath);
        }
        static void CreateSolarScene()
        {
            var previous=EditorSceneManager.GetSceneManagerSetup();
            try {
                var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
                var bootstrap=new GameObject("Cosmic Bootstrap").AddComponent<CosmicBootstrap>();bootstrap.showMenu=false;
                var manager=new GameObject("SimulationManager").AddComponent<UniverseManager>();bootstrap.sceneManager=manager;
                var cameraRoot=new GameObject("Space Camera",typeof(Camera),typeof(AudioListener),typeof(SpaceCameraController));
                var camera=cameraRoot.GetComponent<Camera>();camera.tag="MainCamera";camera.fieldOfView=48;camera.allowHDR=true;
                camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;camera.nearClipPlane=.1f;camera.farClipPlane=8000;
                camera.GetUniversalAdditionalCameraData().renderPostProcessing=true;bootstrap.sceneCamera=camera;
                manager.gameObject.AddComponent<SpaceBackground>();
                var preview=new GameObject("Editor Preview - initial SI state");preview.transform.SetParent(manager.transform,false);bootstrap.editorPreview=preview;
                BuildPreview(preview.transform);
                camera.transform.position=new Vector3(0,540,-1550);camera.transform.LookAt(Vector3.zero);
                EditorSceneManager.SaveScene(scene,ProjectBuilder.SolarPath);
            }
            finally {EditorSceneManager.RestoreSceneManagerSetup(previous);}
        }
        public static void BuildPreview(Transform parent)
        {
            var catalog=JsonUtility.FromJson<PresetCatalog>(File.ReadAllText(Path.Combine(Application.streamingAssetsPath,"PresetCatalog.json")));
            var bodies=catalog.entries.Single(e=>e.id=="solar").snapshot.ValidatedBodies();var sun=bodies.Single(b=>b.Id=="sun");
            const double scale=32/Astronomy.AU;
            Directory.CreateDirectory("Assets/Cosmic/Meshes");Directory.CreateDirectory("Assets/Resources/Materials/Preview");AssetDatabase.Refresh();
            foreach(var b in bodies) {
                var root=new GameObject(b.Name);root.transform.SetParent(parent,false);
                root.transform.localPosition=new Vector3((float)(b.Position.X*scale),(float)(b.Position.Y*scale),(float)(b.Position.Z*scale));
                double radius=Math.Max(b.Radius*scale,b.IsLuminous?.35:.12);
                double nearest=bodies.Where(other=>other.Id!=b.Id).Min(other=>(other.Position-b.Position).Length*scale);
                radius=Math.Max(b.Radius*scale,Math.Min(radius,nearest*.22));root.transform.localScale=Vector3.one*(float)radius;
                var rotation=new GameObject("Axial Rotation");rotation.transform.SetParent(root.transform,false);rotation.transform.localRotation=Quaternion.Euler(0,0,(float)b.AxialTilt);
                var material=PreviewMaterial(b,sun,b.IsLuminous?"Star":"Planet");var lod=rotation.AddComponent<LODGroup>();var levels=new LOD[3];
                for(int i=0;i<3;i++) {
                    var mesh=PersistMesh("PlanetLOD"+(2-i),PlanetGenerator.Sphere(2-i));
                    var renderer=MeshObject("Surface LOD "+i,rotation.transform,mesh,material,1);
                    levels[i]=new LOD(new[]{.35f,.07f,.001f}[i],new Renderer[]{renderer});
                }
                lod.SetLODs(levels);lod.RecalculateBounds();
                if(b.Atmosphere>0 && !b.IsLuminous) {
                    MeshObject("Atmosphere",rotation.transform,PersistMesh("PlanetLOD1",PlanetGenerator.Sphere(1)),PreviewMaterial(b,sun,"Atmosphere"),1.04f);
                    if(b.Id=="earth" || b.Id=="venus")MeshObject("Cloud Layer",rotation.transform,PersistMesh("PlanetLOD1",PlanetGenerator.Sphere(1)),PreviewMaterial(b,sun,"Clouds"),1.013f);
                }
                if(b.Id=="saturn")MeshObject("Grain Rings",rotation.transform,PersistMesh("SaturnRings",PlanetGenerator.Rings()),PreviewMaterial(b,sun,"Rings"),1);
            }
        }
        static Mesh PersistMesh(string name,Mesh generated)
        {
            string path="Assets/Cosmic/Meshes/"+name+".asset";var mesh=AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if(mesh==null){mesh=UnityEngine.Object.Instantiate(generated);mesh.name=name;AssetDatabase.CreateAsset(mesh,path);}return mesh;
        }
        static Material PreviewMaterial(CelestialBody body,CelestialBody sun,string kind)
        {
            string path="Assets/Resources/Materials/Preview/"+body.Id+"-"+kind+".mat";
            var material=AssetDatabase.LoadAssetAtPath<Material>(path);var source=Resources.Load<Material>("Materials/"+kind);
            if(source==null)throw new InvalidOperationException("Missing procedural material: "+kind);
            if(material==null){material=new Material(source){name=body.Name+" "+kind};AssetDatabase.CreateAsset(material,path);}
            else material.shader=source.shader;
            ColorUtility.TryParseHtmlString("#"+body.Color,out var color);
            Set(material,"_BaseColor",color.linear);Set(material,"_TemperatureColor",CelestialBodyView.TemperatureColor(body.Temperature));
            Set(material,"_Temperature",(float)body.Temperature);Set(material,"_Seed",(float)body.Seed);
            Set(material,"_SurfaceKind",Array.IndexOf(new[]{"earth","rocky","gas","ice","lava","ocean"},body.Surface));
            Set(material,"_IsMars",body.Id=="mars"?1:0);Set(material,"_RedSpot",body.Id=="jupiter"?1:0);
            Set(material,"_AtmosphereStrength",(float)Math.Min(1,Math.Log(1+body.Atmosphere)));
            var d=(sun.Position-body.Position).Normalized;var direction=new Vector4((float)d.X,(float)d.Y,(float)d.Z,0);
            Set(material,"_SunDirection",direction);Set(material,"_PreviewLightDirection",direction);
            Set(material,"_PreviewLightColor",CelestialBodyView.TemperatureColor(sun.Temperature));
            Set(material,"_PreviewFlux",body==sun?0:(float)(sun.Luminosity/(4*Math.PI*(sun.Position-body.Position).LengthSquared)/1361));
            EditorUtility.SetDirty(material);return material;
        }
        static void Set(Material m,string key,float value){if(m.HasProperty(key))m.SetFloat(key,value);}
        static void Set(Material m,string key,Vector4 value){if(m.HasProperty(key))m.SetVector(key,value);}
        static MeshRenderer MeshObject(string name,Transform parent,Mesh mesh,Material material,float scale)
        {
            var g=new GameObject(name,typeof(MeshFilter),typeof(MeshRenderer));g.transform.SetParent(parent,false);g.transform.localScale=Vector3.one*scale;
            g.GetComponent<MeshFilter>().sharedMesh=mesh;var renderer=g.GetComponent<MeshRenderer>();renderer.sharedMaterial=material;return renderer;
        }
    }
}
