using System;
using UnityEngine;
using UnityEngine.EventSystems;
using Cosmic.Core;

namespace Cosmic.Runtime
{
    [DefaultExecutionOrder(-200)]
    public sealed class SpaceCameraController : MonoBehaviour
    {
        UniverseManager universe; Camera cameraComponent;
        Double3 target,flyPosition;
        string followId;
        double distance=1000,desiredDistance=1000;
        double preferredMetresToScene=32/Astronomy.AU;
        const double MaximumRenderDistance=64;
        public double ObservationDistance => distance;
        float yaw=25,pitch=35;
        Vector2 clickStart;
        bool dragging,fly;
        public void Initialize(UniverseManager u,Camera c) { universe=u;cameraComponent=c; }
        public void Overview()
        {
            if(universe.Simulation.Bodies.Count==0)return;
            Double3 min=universe.Simulation.Bodies[0].Position,max=min;
            foreach(var b in universe.Simulation.Bodies) {
                min=new Double3(Math.Min(min.X,b.Position.X-b.Radius),Math.Min(min.Y,b.Position.Y-b.Radius),Math.Min(min.Z,b.Position.Z-b.Radius));
                max=new Double3(Math.Max(max.X,b.Position.X+b.Radius),Math.Max(max.Y,b.Position.Y+b.Radius),Math.Max(max.Z,b.Position.Z+b.Radius)); }
            target=(min+max)*.5;followId=null;fly=false;
            double extent=Math.Max((max-min).Length*.5,1);
            preferredMetresToScene=32/Astronomy.AU;
            if(extent*preferredMetresToScene<1)preferredMetresToScene=10/extent;
            double halfAngle=cameraComponent.fieldOfView*Math.PI/360;
            double fit=Math.Min(halfAngle,Math.Atan(Math.Tan(halfAngle)*cameraComponent.aspect));
            desiredDistance=distance=extent/Math.Sin(fit)*1.15;yaw=25;pitch=35;
        }
        public void FocusSelected()
        {
            var b=universe.Selected;if(b==null)return;
            target=b.Position;followId=b.Id;fly=false;
            preferredMetresToScene=Math.Max(32/Astronomy.AU,.75/b.Radius);
            desiredDistance=distance=b.Radius*5;
        }
        public void SetObservationDistance(double metres,bool immediate=false)
        {
            if(!Numeric.Finite(metres) || metres<=0)throw new ArgumentOutOfRangeException(nameof(metres));
            desiredDistance=Numeric.Clamp(metres,MinimumDistance(),1e22);
            if(immediate)distance=desiredDistance;
        }
        public void SetFly(bool enabled)
        {
            if(fly==enabled)return;
            if(enabled) flyPosition=target-ViewDirection()*distance;
            else {target=flyPosition+ViewDirection()*distance;followId=null;}
            fly=enabled;
        }
        public void ToggleMode() => SetFly(!fly);
        Double3 ViewDirection()
        {
            Vector3 f=Quaternion.Euler(pitch,yaw,0)*Vector3.forward;
            return new Double3(f.x,f.y,f.z);
        }
        void Update()
        {
            if(universe==null || universe.LastError!=null)return;
            if(Input.GetKeyDown(KeyCode.Space))universe.Paused=!universe.Paused;
            if(Input.GetKeyDown(KeyCode.F))FocusSelected();
            if(Input.GetKeyDown(KeyCode.R))Overview();
            if(Input.GetKeyDown(KeyCode.C))ToggleMode();
            if(Input.GetKeyDown(KeyCode.F11)) Screen.fullScreen=!Screen.fullScreen;
            bool overUI=EventSystem.current!=null && EventSystem.current.IsPointerOverGameObject();
            if(Input.GetMouseButtonDown(0) && !overUI) {clickStart=Input.mousePosition;dragging=true;}
            if(Input.GetMouseButtonUp(0)) {
                if(dragging && ((Vector2)Input.mousePosition-clickStart).magnitude<5)Pick(Input.mousePosition);
                dragging=false;
            }
            if(dragging && Input.GetMouseButton(0)) {yaw+=Input.GetAxisRaw("Mouse X")*2.5f;pitch=Mathf.Clamp(pitch-Input.GetAxisRaw("Mouse Y")*2.5f,-85,85);}
            if(!overUI)SetObservationDistance(desiredDistance*Math.Exp(-Input.mouseScrollDelta.y*.16));
            distance += (desiredDistance-distance)*(1-Math.Exp(-Time.unscaledDeltaTime*12));
            if(!overUI && (Input.GetKey(KeyCode.W)||Input.GetKey(KeyCode.S)||Input.GetKey(KeyCode.A)||Input.GetKey(KeyCode.D)||Input.GetKey(KeyCode.Q)||Input.GetKey(KeyCode.E)))
            {
                SetFly(true);
                var move=new Vector3((Input.GetKey(KeyCode.D)?1:0)-(Input.GetKey(KeyCode.A)?1:0),
                    (Input.GetKey(KeyCode.E)?1:0)-(Input.GetKey(KeyCode.Q)?1:0),(Input.GetKey(KeyCode.W)?1:0)-(Input.GetKey(KeyCode.S)?1:0));
                move=Quaternion.Euler(pitch,yaw,0)*move.normalized;
                double speed=distance*.4*Time.unscaledDeltaTime*(Input.GetKey(KeyCode.LeftShift)?4:1);
                flyPosition+=new Double3(move.x,move.y,move.z)*speed;
            }
        }
        double MinimumDistance() => followId!=null && universe.Simulation.Find(followId)!=null ? universe.Simulation.Find(followId).Radius*1.08 : 1;
        void LateUpdate()
        {
            if(universe==null || universe.LastError!=null)return;
            var followed=universe.Simulation.Find(followId);
            if(!fly && followed!=null)target=followed.Position;
            Double3 position=fly?flyPosition:target-ViewDirection()*distance;
            // Keep the float rendering coordinates small when zooming out after
            // focusing a planet. The physical camera state stays in metres.
            double extent=Math.Max(distance,(position-target).Length);
            universe.Coordinates.MetresToScene=Math.Min(preferredMetresToScene,MaximumRenderDistance/Math.Max(extent,1));
            universe.Coordinates.Origin=fly?position:target;
            transform.position=universe.ToScene(position);transform.rotation=Quaternion.Euler(pitch,yaw,0);
            float sceneDistance=(float)(distance*universe.Coordinates.MetresToScene);
            cameraComponent.nearClipPlane=Mathf.Clamp(sceneDistance*.001f,.0001f,10);
            cameraComponent.farClipPlane=Mathf.Max(1000,sceneDistance*4);
        }
        void Pick(Vector2 screen)
        {
            float best=18;string id=null;
            Ray ray=cameraComponent.ScreenPointToRay(screen);float closest=float.PositiveInfinity;
            foreach(var b in universe.Simulation.Bodies) {
                var delta=universe.ToScene(b.Position)-ray.origin;float along=Vector3.Dot(delta,ray.direction);
                float radius=universe.DisplayRadius(b),perpendicular=delta.sqrMagnitude-along*along;
                if(perpendicular>radius*radius)continue;
                float half=Mathf.Sqrt(Mathf.Max(0,radius*radius-perpendicular));
                float hit=along-half;if(hit<0)hit=along+half;
                if(hit>=0 && hit<closest) {closest=hit;id=b.Id;}
            }
            if(id!=null) {universe.Select(id);return;}
            // Tiny meshes remain selectable through the screen-space marker fallback.
            foreach(var b in universe.Simulation.Bodies) {
                var p=cameraComponent.WorldToScreenPoint(universe.ToScene(b.Position));if(p.z<=0)continue;
                float d=Vector2.Distance(screen,p);
                if(d<best) {id=b.Id;best=d;}
            }
            if(id!=null)universe.Select(id);
        }
    }
}
