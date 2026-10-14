using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Cosmic.Core;

namespace Cosmic.Runtime
{
    public sealed class SandboxUIController : MonoBehaviour
    {
        UniverseManager universe;SpaceCameraController controls;Canvas canvas;Font font;
        Text inspector,status;RectTransform list;GameObject menu;
        readonly Dictionary<string,GameObject> markers=new Dictionary<string,GameObject>();
        readonly List<Rect> occupied=new List<Rect>();
        bool labels=true;float refreshTime;
        public void Initialize(UniverseManager u,SpaceCameraController c,bool showMenu)
        {
            universe=u;controls=c;font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            canvas=gameObject.AddComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;
            var scaler=gameObject.AddComponent<CanvasScaler>();scaler.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution=new Vector2(1920,1080);scaler.matchWidthOrHeight=.5f;gameObject.AddComponent<GraphicRaycaster>();
            var header=Panel("Header",transform,new Vector2(0,1),new Vector2(1,1),new Vector2(0,-70),Vector2.zero);
            Label(header,"COSMIC SANDBOX 3D",new Vector2(28,-18),new Vector2(640,40),26);
            Label(header,"GRAVITY • ORBITS • WORLDS",new Vector2(1250,-20),new Vector2(620,36),17);
            var left=Panel("Objects",transform,new Vector2(0,0),new Vector2(0,1),new Vector2(18,105),new Vector2(302,-86));
            Label(left,"UNIVERSE",new Vector2(18,-16),new Vector2(250,34),19);
            Button(left,"Solar System",new Vector2(16,-58),new Vector2(268,42),()=>Load("solar"));
            Button(left,"Earth & Moon",new Vector2(16,-106),new Vector2(268,42),()=>Load("earthmoon"));
            Button(left,"Binary Stars",new Vector2(16,-154),new Vector2(268,42),()=>Load("binary"));
            var scroll=Panel("Object Scroll",left,new Vector2(0,0),new Vector2(1,1),new Vector2(12,12),new Vector2(-12,-218));
            scroll.gameObject.AddComponent<RectMask2D>();
            var sr=scroll.gameObject.AddComponent<ScrollRect>();sr.horizontal=false;sr.movementType=ScrollRect.MovementType.Clamped;
            list=Rect("Body List",scroll);list.anchorMin=new Vector2(0,1);list.anchorMax=new Vector2(1,1);list.pivot=new Vector2(.5f,1);list.sizeDelta=new Vector2(0,0);sr.content=list;sr.viewport=scroll;
            var right=Panel("Inspector",transform,new Vector2(1,0),new Vector2(1,1),new Vector2(-332,105),new Vector2(-18,-86));
            Label(right,"OBJECT INSPECTOR",new Vector2(18,-16),new Vector2(280,36),19);
            inspector=Label(right,"",new Vector2(18,-65),new Vector2(280,500),17);inspector.lineSpacing=1.2f;
            Button(right,"FOCUS [F]",new Vector2(18,-585),new Vector2(278,44),controls.FocusSelected);
            Button(right,"OVERVIEW [R]",new Vector2(18,-637),new Vector2(278,44),controls.Overview);
            var bottom=Panel("Time Toolbar",transform,new Vector2(0,0),new Vector2(1,0),Vector2.zero,new Vector2(0,88));
            Button(bottom,"PAUSE / PLAY",new Vector2(20,-17),new Vector2(180,48),()=>universe.Paused=!universe.Paused);
            Button(bottom,"STEP",new Vector2(212,-17),new Vector2(100,48),universe.Step);
            Button(bottom,"SLOW",new Vector2(324,-17),new Vector2(100,48),()=>universe.SecondsPerSecond=Math.Max(.001,universe.SecondsPerSecond*.1));
            Button(bottom,"FAST",new Vector2(436,-17),new Vector2(100,48),()=>universe.SecondsPerSecond=Math.Min(Astronomy.Year,universe.SecondsPerSecond*10));
            Button(bottom,"TRUE SIZE",new Vector2(560,-17),new Vector2(150,48),()=>universe.TrueSize=!universe.TrueSize);
            Button(bottom,"TRAILS",new Vector2(722,-17),new Vector2(110,48),()=>universe.Trails=!universe.Trails);
            Button(bottom,"LABELS",new Vector2(844,-17),new Vector2(110,48),()=>labels=!labels);
            Button(bottom,"FLY / ORBIT [C]",new Vector2(966,-17),new Vector2(190,48),controls.ToggleMode);
            Button(bottom,"QUALITY",new Vector2(1168,-17),new Vector2(140,48),()=>universe.SetQuality((universe.QualityIndex+1)%3));
            status=Label(bottom,"",new Vector2(1330,-10),new Vector2(570,68),15);
            BuildMenu();menu.SetActive(showMenu);universe.Paused=showMenu;
            universe.Changed+=Rebuild;Rebuild();
        }
        void Load(string id) {if(universe.LastError!=null)return;universe.LoadPreset(id);menu.SetActive(false);universe.Paused=false;}
        void BuildMenu()
        {
            var overlay=Panel("Main Menu",transform,Vector2.zero,Vector2.one,Vector2.zero,Vector2.zero);menu=overlay.gameObject;
            overlay.GetComponent<Image>().color=new Color(.025f,.04f,.065f,.98f);
            var box=Rect("Menu Content",overlay);box.anchorMin=box.anchorMax=new Vector2(.5f,.5f);box.sizeDelta=new Vector2(700,620);box.pivot=new Vector2(.5f,.5f);
            Label(box,"COSMIC\nSANDBOX 3D",new Vector2(40,-30),new Vector2(640,140),48);
            Label(box,"Explore a universe governed by gravity.",new Vector2(42,-198),new Vector2(620,38),20);
            Button(box,"ENTER SOLAR SYSTEM",new Vector2(40,-264),new Vector2(620,58),()=>Load("solar"));
            Button(box,"EARTH & MOON",new Vector2(40,-334),new Vector2(620,58),()=>Load("earthmoon"));
            Button(box,"BINARY STARS",new Vector2(40,-404),new Vector2(620,58),()=>Load("binary"));
            Button(box,"QUIT",new Vector2(40,-474),new Vector2(620,48),Application.Quit);
            Label(box,"Drag: orbit  •  Wheel: zoom  •  WASD/QE: fly  •  F11: fullscreen",new Vector2(40,-546),new Vector2(640,60),16);
        }
        void Rebuild()
        {
            if(list==null)return;
            foreach(Transform child in list)Destroy(child.gameObject);
            foreach(var m in markers.Values)Destroy(m);markers.Clear();
            int i=0;
            foreach(var body in universe.Simulation.Bodies) {
                string id=body.Id;
                Button(list,body.Name,new Vector2(2,-i*43),new Vector2(262,38),()=>universe.Select(id));i++;
                var marker=Button(transform,"",Vector2.zero,new Vector2(120,26),()=>universe.Select(id));
                marker.GetComponent<Image>().color=Color.clear;marker.GetComponentInChildren<Text>().fontSize=14;
                markers.Add(id,marker.gameObject);
            }
            list.sizeDelta=new Vector2(0,i*43);
            if(menu!=null)menu.transform.SetAsLastSibling();
        }
        void Update()
        {
            if(Input.GetKeyDown(KeyCode.Escape)) {menu.SetActive(!menu.activeSelf);universe.Paused=menu.activeSelf;}
            refreshTime+=Time.unscaledDeltaTime;if(refreshTime<.15f)return;refreshTime=0;
            var b=universe.Selected;
            if(b!=null) inspector.text=b.Name+"\n"+b.Kind.ToUpperInvariant()+"\n\nMass  "+b.Mass.ToString("E4")+" kg\nRadius  "+(b.Radius/1000).ToString("N1")+" km\nDensity  "+b.Density.ToString("N1")+" kg/m³\nTemperature  "+b.Temperature.ToString("N1")+" K\nSpeed  "+(b.Velocity.Length/1000).ToString("N2")+" km/s\nGravity  "+b.SurfaceGravity.ToString("N3")+" m/s²\nEscape  "+(b.EscapeVelocity/1000).ToString("N2")+" km/s\nRotation  "+(b.RotationPeriod/3600).ToString("N2")+" h\nAtmosphere  "+b.Atmosphere.ToString("G3")+"\n\n"+b.Composition;
            status.text=universe.LastError!=null?universe.LastError:(universe.Paused?"PAUSED":"RUNNING")+"  "+universe.SecondsPerSecond.ToString("G4")+" s/s\n"+
                (universe.Simulation.Time/Astronomy.Day).ToString("N3")+" days  |  ΔE "+universe.Simulation.EnergyDrift.ToString("E2")+"\n"+
                new[]{"Performance","Balanced","Ultra"}[universe.QualityIndex]+(universe.Clock.BudgetLimited?" • solver backlog":"")+" • "+universe.Simulation.Bodies.Count+" bodies";
        }
        void LateUpdate()
        {
            occupied.Clear();var camera=Camera.main;if(camera==null)return;
            // Selected first, then hide overlaps and labels behind side panels.
            DrawMarker(universe.Selected,camera);
            foreach(var b in universe.Simulation.Bodies)if(b.Id!=universe.SelectedId)DrawMarker(b,camera);
        }
        void DrawMarker(CelestialBody b,Camera camera)
        {
            if(b==null || !markers.TryGetValue(b.Id,out var marker))return;
            var p=camera.WorldToScreenPoint(universe.ToScene(b.Position));
            float scale=canvas.scaleFactor;
            var rect=new Rect(p.x,p.y-26*scale,120*scale,26*scale);
            bool visible=labels && !menu.activeSelf && p.z>0 && p.x>325*scale && p.x+rect.width<Screen.width-335*scale && p.y>110*scale && p.y+rect.height<Screen.height-85*scale;
            float meshPixels=universe.DisplayRadius(b)*Screen.height/(2*Mathf.Tan(camera.fieldOfView*Mathf.Deg2Rad*.5f)*Mathf.Max(p.z,.0001f));
            if(meshPixels>14)visible=false;
            foreach(var other in occupied)if(rect.Overlaps(other))visible=false;
            marker.SetActive(visible);if(!visible)return;occupied.Add(rect);
            marker.transform.position=new Vector3(p.x,p.y,0);
            marker.GetComponentInChildren<Text>().text=(b.Id==universe.SelectedId?"◉ ":"• ")+b.Name;
        }
        RectTransform Panel(string name,Transform parent,Vector2 min,Vector2 max,Vector2 offsetMin,Vector2 offsetMax)
        {
            var r=Rect(name,parent);r.anchorMin=min;r.anchorMax=max;r.offsetMin=offsetMin;r.offsetMax=offsetMax;
            r.gameObject.AddComponent<Image>().color=new Color(.055f,.075f,.105f,.94f);return r;
        }
        static RectTransform Rect(string name,Transform parent)
        {
            var g=new GameObject(name,typeof(RectTransform));var r=(RectTransform)g.transform;r.SetParent(parent,false);return r;
        }
        Text Label(Transform parent,string value,Vector2 position,Vector2 size,int fontSize)
        {
            var r=Rect("Label",parent);r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=position;r.sizeDelta=size;
            var t=r.gameObject.AddComponent<Text>();t.font=font;t.text=value;t.fontSize=fontSize;t.color=new Color(.83f,.91f,.97f);t.raycastTarget=false;t.verticalOverflow=VerticalWrapMode.Truncate;return t;
        }
        RectTransform Button(Transform parent,string value,Vector2 position,Vector2 size,Action action)
        {
            var r=Rect(value+" Button",parent);r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=position;r.sizeDelta=size;
            r.gameObject.AddComponent<Image>().color=new Color(.09f,.16f,.22f);
            var button=r.gameObject.AddComponent<Button>();button.onClick.AddListener(()=>action());
            var t=Label(r,value,new Vector2(8,-2),size-new Vector2(16,4),16);t.alignment=TextAnchor.MiddleLeft;
            return r;
        }
        void OnDestroy() {if(universe!=null)universe.Changed-=Rebuild;}
    }
}
