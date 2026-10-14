using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Cosmic.Core;

namespace Cosmic.Runtime
{
    [DefaultExecutionOrder(-100)]
    public sealed class UniverseManager : MonoBehaviour
    {
        public SimulationEngine Simulation { get; }=new SimulationEngine();
        public TimeController Clock { get; }=new TimeController();
        public FloatingOrigin Coordinates { get; }=new FloatingOrigin();
        public PresetCatalog Catalog { get; private set; }
        public string SelectedId { get; private set; }="earth";
        public CelestialBody Selected => Simulation.Find(SelectedId);
        public bool Paused=true, TrueSize, Trails=true;
        public double SecondsPerSecond=Astronomy.Day;
        public double ActualSpeed { get; private set; }
        public int QualityIndex { get; private set; }=1;
        public event Action Changed;
        readonly Dictionary<string,CelestialBodyView> views=new Dictionary<string,CelestialBodyView>();
        SpaceCameraController controls;
        UniversalRenderPipelineAsset pipeline;
        VolumeProfile profile;
        public string LastError { get; private set; }
        public void Initialize(SpaceCameraController cameraControls,string preset)
        {
            controls=cameraControls;
            try
            {
                Catalog=JsonUtility.FromJson<PresetCatalog>(File.ReadAllText(Path.Combine(Application.streamingAssetsPath,"PresetCatalog.json")));
                if(Catalog==null || Catalog.migration_schema!=1 || Catalog.entries==null) throw new ArgumentException("Invalid migration catalog.");
                foreach(var e in Catalog.entries) e.snapshot.ValidatedBodies();
                ConfigureRendering(); LoadPreset(preset);
            }
            catch(Exception e) { LastError=e.Message;Paused=true;Debug.LogException(e); }
        }
        void ConfigureRendering()
        {
            if(!(GraphicsSettings.currentRenderPipeline is UniversalRenderPipelineAsset asset))
                throw new InvalidOperationException("URP missing. Run Cosmic > Repair URP and Solar System in the Editor.");
            pipeline=Instantiate(asset);QualitySettings.renderPipeline=pipeline;
            RenderSettings.ambientMode=AmbientMode.Flat;RenderSettings.ambientLight=Color.black;RenderSettings.skybox=null;
            var volume=gameObject.AddComponent<Volume>();volume.isGlobal=true;
            profile=ScriptableObject.CreateInstance<VolumeProfile>();volume.sharedProfile=profile;
            var tone=profile.Add<Tonemapping>(true);tone.mode.Override(TonemappingMode.ACES);
            var bloom=profile.Add<Bloom>(true);bloom.intensity.Override(.13f);bloom.threshold.Override(1.2f);bloom.clamp.Override(4);
            SetQuality(1);
        }
        public void LoadPreset(string id)
        {
            var entry=Catalog.entries.FirstOrDefault(e=>e.id==id && e.phase1);
            if(entry==null) throw new ArgumentException("Preset awaits its migration phase: "+id);
            Simulation.Load(entry.snapshot);Clock.Reset();SecondsPerSecond=entry.seconds_per_second;
            SelectedId=Simulation.Find("earth")!=null?"earth":Simulation.Bodies[0].Id;
            SyncViews();controls.Overview();Changed?.Invoke();
        }
        public void Select(string id) { if(Simulation.Find(id)==null)return; SelectedId=id;Changed?.Invoke(); }
        public Vector3 ToScene(Double3 position)
        {
            var relative=Coordinates.Relative(position);
            // This is the only physics-to-render narrowing conversion.
            return new Vector3((float)relative.X,(float)relative.Y,(float)relative.Z);
        }
        public float DisplayRadius(CelestialBody b)
        {
            double physical=b.Radius*Coordinates.MetresToScene;
            if(TrueSize) return (float)physical;
            double exaggerated=Math.Max(physical,b.IsLuminous?.35:.12);
            double nearest=double.PositiveInfinity;
            foreach(var other in Simulation.Bodies) if(other.Id!=b.Id)
                nearest=Math.Min(nearest,(other.Position-b.Position).Length*Coordinates.MetresToScene);
            return (float)Math.Max(physical,Math.Min(exaggerated,nearest*.22));
        }
        public void SetQuality(int index)
        {
            QualityIndex=Mathf.Clamp(index,0,2);
            if(pipeline!=null) { pipeline.renderScale=new[]{.7f,1f,1f}[QualityIndex]; pipeline.msaaSampleCount=new[]{1,2,4}[QualityIndex];pipeline.supportsHDR=true; }
            Shader.SetGlobalFloat("_CosmicDetail",QualityIndex);
            if(profile!=null && profile.TryGet<Bloom>(out var bloom)) bloom.active=QualityIndex>0;
            foreach(var v in views.Values)v.SetQuality(QualityIndex);
        }
        void Update()
        {
            if(LastError!=null)return;
            double actual=0;
            actual=Clock.Tick(Simulation,Time.unscaledDeltaTime,SecondsPerSecond,Paused);
            ActualSpeed=Time.unscaledDeltaTime>0?actual/Time.unscaledDeltaTime:0;
            SyncViews();
        }
        public void Step()
        {
            if(LastError!=null)return;
            Simulation.Advance(Math.Min(SecondsPerSecond,3600),256,6);SyncViews();Changed?.Invoke();
        }
        void SyncViews()
        {
            bool changed=false;
            var present=new HashSet<string>();
            foreach(var b in Simulation.Bodies)
            {
                present.Add(b.Id);
                if(!views.TryGetValue(b.Id,out var view))
                {
                    var prefab=Resources.Load<GameObject>("Prefabs/CelestialBody");
                    if(prefab==null) throw new InvalidOperationException("CelestialBody prefab missing.");
                    var root=Instantiate(prefab,transform);root.name=b.Name;
                    view=root.GetComponent<CelestialBodyView>();view.Initialize(b,QualityIndex);views.Add(b.Id,view);changed=true;
                }
                view.Sync(b,this);
            }
            foreach(var id in views.Keys.Where(id=>!present.Contains(id)).ToArray()) { Destroy(views[id].gameObject);views.Remove(id);changed=true; }
            if(Selected==null) SelectedId=Simulation.Bodies.Count>0?Simulation.Bodies[0].Id:"";
            if(changed)Changed?.Invoke();
        }
        void LateUpdate()
        {
            if(LastError!=null)return;
            // Camera changed the double origin/units earlier in LateUpdate.
            foreach(var b in Simulation.Bodies) if(views.TryGetValue(b.Id,out var view))view.Sync(b,this);
        }
        void OnDestroy()
        {
            if(pipeline!=null) {QualitySettings.renderPipeline=null;Destroy(pipeline);}
            if(profile!=null)Destroy(profile);
        }
    }
}
