using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Rendering.Universal;

namespace Cosmic.Runtime
{
    public sealed class CosmicBootstrap : MonoBehaviour
    {
        public bool showMenu=true;
        public string initialPreset="solar";
        public GameObject editorPreview;
        public UniverseManager sceneManager;
        public Camera sceneCamera;
        void Awake()
        {
            if(editorPreview!=null)editorPreview.SetActive(false);
            Application.targetFrameRate=60;
            if(EventSystem.current==null) new GameObject("EventSystem",typeof(EventSystem),typeof(StandaloneInputModule));
            var root=sceneManager!=null?sceneManager.gameObject:new GameObject("SimulationManager");
            var universe=sceneManager!=null?sceneManager:root.AddComponent<UniverseManager>();
            var cameraRoot=sceneCamera!=null?sceneCamera.gameObject:new GameObject("Space Camera");
            var camera=sceneCamera!=null?sceneCamera:cameraRoot.AddComponent<Camera>();camera.tag="MainCamera";
            camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;
            camera.fieldOfView=48;camera.allowHDR=true;
            camera.GetUniversalAdditionalCameraData().renderPostProcessing=true;
            if(cameraRoot.GetComponent<AudioListener>()==null)cameraRoot.AddComponent<AudioListener>();
            var controls=cameraRoot.GetComponent<SpaceCameraController>()??cameraRoot.AddComponent<SpaceCameraController>();
            controls.Initialize(universe,camera);
            universe.Initialize(controls,initialPreset);
            (root.GetComponent<SpaceBackground>()??root.AddComponent<SpaceBackground>()).Initialize(camera);
            var ui=new GameObject("Sandbox UI").AddComponent<SandboxUIController>();
            ui.Initialize(universe,controls,showMenu);
            if(universe.LastError==null)Debug.Log("CosmicSandbox startup ready: "+initialPreset);
        }
    }
}
