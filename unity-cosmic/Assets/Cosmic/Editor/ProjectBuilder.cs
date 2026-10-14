using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.PackageManager;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Cosmic.Editor
{
    [InitializeOnLoad]
    public static class ProjectBuilder
    {
        public const string PipelinePath="Assets/Cosmic/Settings/PC_RPAsset.asset";
        public const string SolarPath="Assets/Scenes/SolarSystem.unity";
        public const string MenuPath="Assets/Scenes/MainMenu.unity";
        static bool busy;
        static ProjectBuilder()
        {
            EditorApplication.delayCall+=()=> {
                if(EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling || busy)return;
                if(!SessionState.GetBool("Cosmic66Prepared",false)) {
                    RepairAndBuild();SessionState.SetBool("Cosmic66Prepared",true);
                    var scene=EditorSceneManager.GetActiveScene();
                    if(string.IsNullOrEmpty(scene.path) && scene.GetRootGameObjects().All(g=>g.name=="Main Camera" || g.name=="Directional Light"))
                        EditorSceneManager.OpenScene(SolarPath);
                }
            };
        }
        [MenuItem("Cosmic/Repair URP and Solar System")]
        public static void RepairAndBuild()
        {
            if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play Mode before repairing project assets.");
            if(busy)return;busy=true;
            try {
                ValidatePackageVersions();AssignPipelineToEveryQuality();
                MaterialRepair.EnsureGameMaterials();int converted=MaterialRepair.ConvertBuiltInMaterials();
                ConfigurePlayerAndShaders();SolarSystemBuilder.CreateIfMissing();
                EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(MenuPath,true),new EditorBuildSettingsScene(SolarPath,true)};
                MaterialRepair.ValidateAllMaterials();ValidateBuildScenes();AssetDatabase.SaveAssets();
                Debug.Log("Cosmic Unity 6000.6.5f1 / URP 17.6.0 / DirectX 11 repaired; "+converted+" built-in materials converted. Open SolarSystem and press Play.");
            }
            finally {busy=false;}
        }
        public static void ValidatePackageVersions()
        {
            if(!Application.unityVersion.StartsWith("6000.6.",StringComparison.Ordinal))
                throw new InvalidOperationException("Open this project in Unity 6000.6.5f1. Current Editor: "+Application.unityVersion);
            foreach(string name in new[]{"com.unity.render-pipelines.universal","com.unity.render-pipelines.core","com.unity.shadergraph"}) {
                var info=UnityEditor.PackageManager.PackageInfo.GetAllRegisteredPackages().FirstOrDefault(p=>p.name==name);
                if(info==null || info.version!="17.6.0")throw new InvalidOperationException("Package mismatch: "+name+" must be 17.6.0. Use Tools/repair-urp.ps1 after closing Unity.");
            }
        }
        public static void AssignPipelineToEveryQuality()
        {
            var asset=AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if(asset==null)throw new InvalidOperationException("Missing serialized URP asset: "+PipelinePath);
            asset.supportsHDR=true;asset.supportsCameraDepthTexture=true;asset.supportsCameraOpaqueTexture=true;
            asset.gpuResidentDrawerMode=GPUResidentDrawerMode.Disabled;
            GraphicsSettings.defaultRenderPipeline=asset;
            int selected=QualitySettings.GetQualityLevel();
            for(int i=0;i<QualitySettings.names.Length;i++) {QualitySettings.SetQualityLevel(i,false);QualitySettings.renderPipeline=asset;}
            QualitySettings.SetQualityLevel(selected,false);EditorUtility.SetDirty(asset);
            var serialized=new SerializedObject(asset);var renderers=serialized.FindProperty("m_RendererDataList");
            if(renderers==null || renderers.arraySize==0 || renderers.GetArrayElementAtIndex(0).objectReferenceValue==null)
                throw new InvalidOperationException("URP renderer data failed to load.");
        }
        static void ConfigurePlayerAndShaders()
        {
            PlayerSettings.companyName="Cosmic Sandbox";PlayerSettings.productName="COSMIC SANDBOX 3D";
            PlayerSettings.defaultScreenWidth=1920;PlayerSettings.defaultScreenHeight=1080;PlayerSettings.resizableWindow=true;
            PlayerSettings.fullScreenMode=FullScreenMode.FullScreenWindow;PlayerSettings.colorSpace=ColorSpace.Linear;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Standalone,ScriptingImplementation.Mono2x);
            PlayerSettings.SetApiCompatibilityLevel(NamedBuildTarget.Standalone,ApiCompatibilityLevel.NET_Standard);
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64,false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64,new[]{GraphicsDeviceType.Direct3D11});
            var graphics=new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset")[0]);
            var included=graphics.FindProperty("m_AlwaysIncludedShaders");
            foreach(string name in MaterialRepair.CosmicNames.Select(n=>"Cosmic/"+n).Concat(new[]{"UI/Default"})) {
                var shader=Shader.Find(name);if(shader==null)throw new InvalidOperationException("Required shader missing: "+name);
                bool present=false;for(int i=0;i<included.arraySize;i++)if(included.GetArrayElementAtIndex(i).objectReferenceValue==shader)present=true;
                if(!present) {int i=included.arraySize;included.InsertArrayElementAtIndex(i);included.GetArrayElementAtIndex(i).objectReferenceValue=shader;}
            }
            graphics.ApplyModifiedPropertiesWithoutUndo();
            var settings=new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
            var input=settings.FindProperty("activeInputHandler");if(input!=null){input.intValue=0;settings.ApplyModifiedPropertiesWithoutUndo();}
        }
        public static void ValidateBuildScenes()
        {
            if(!File.Exists(MenuPath) || !File.Exists(SolarPath))throw new InvalidOperationException("Build scenes are missing.");
            var enabled=EditorBuildSettings.scenes.Where(s=>s.enabled).Select(s=>s.path).ToArray();
            if(enabled.Length!=2 || enabled[0]!=MenuPath || enabled[1]!=SolarPath)throw new InvalidOperationException("MainMenu/SolarSystem build order is invalid.");
        }
        [MenuItem("Cosmic/Open Solar System")]
        public static void OpenSolarSystem()
        {
            if(!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())return;
            RepairAndBuild();EditorSceneManager.OpenScene(SolarPath);
        }
        [MenuItem("Cosmic/Build Windows x64")]
        public static void BuildWindows() => WindowsBuild.Build();
    }
}
