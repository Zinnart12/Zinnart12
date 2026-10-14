using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Rendering.Universal;

namespace Cosmic.Runtime
{
    public sealed class CosmicBootstrap : MonoBehaviour
    {
        public bool showMenu=true;
        public string initialPreset="solar";
        void Awake()
        {
            Application.targetFrameRate=60;
            if(EventSystem.current==null) new GameObject("EventSystem",typeof(EventSystem),typeof(StandaloneInputModule));
            var root=new GameObject("Universe");
            var universe=root.AddComponent<UniverseManager>();
            var cameraRoot=new GameObject("Space Camera");
            var camera=cameraRoot.AddComponent<Camera>();camera.tag="MainCamera";
            camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;
            camera.fieldOfView=48;camera.allowHDR=true;
            camera.GetUniversalAdditionalCameraData().renderPostProcessing=true;
            cameraRoot.AddComponent<AudioListener>();
            var controls=cameraRoot.AddComponent<SpaceCameraController>();
            controls.Initialize(universe,camera);
            universe.Initialize(controls,initialPreset);
            root.AddComponent<SpaceBackground>().Initialize(camera);
            var ui=new GameObject("Sandbox UI").AddComponent<SandboxUIController>();
            ui.Initialize(universe,controls,showMenu);
        }
    }
}
