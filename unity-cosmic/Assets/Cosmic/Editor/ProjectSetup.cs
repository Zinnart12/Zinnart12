using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Cosmic.Runtime;

namespace Cosmic.Editor
{
    [InitializeOnLoad]
    public static class ProjectSetup
    {
        const string PipelinePath="Assets/Cosmic/Settings/CosmicURP.asset";
        static ProjectSetup()
        {
            EditorApplication.delayCall+=()=> {
                if(!EditorApplication.isPlayingOrWillChangePlaymode && AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath)==null)
                    Prepare();
            };
        }
        [MenuItem("Cosmic/Prepare Phase 1 Project")]
        public static void Prepare()
        {
            if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play Mode before preparing assets.");
            Directory.CreateDirectory("Assets/Cosmic/Settings");Directory.CreateDirectory("Assets/Resources/Materials");
            AssetDatabase.Refresh();
            var pipeline=AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if(pipeline==null) {
                pipeline=UniversalRenderPipelineAsset.Create();
                pipeline.name="Cosmic URP";pipeline.supportsHDR=true;pipeline.msaaSampleCount=2;pipeline.renderScale=1;
                // Persist the renderer referenced by Create(), rather than leaving a transient ScriptableObject.
                var serialized=new SerializedObject(pipeline);
                var renderer=(ScriptableRendererData)serialized.FindProperty("m_RendererDataList").GetArrayElementAtIndex(0).objectReferenceValue;
                renderer.name="Cosmic Universal Renderer";
                AssetDatabase.CreateAsset(renderer,"Assets/Cosmic/Settings/CosmicRenderer.asset");
                AssetDatabase.CreateAsset(pipeline,PipelinePath);
            }
            GraphicsSettings.defaultRenderPipeline=pipeline;QualitySettings.renderPipeline=pipeline;
            foreach(string name in new[]{"Planet","Star","Atmosphere","Clouds","Rings","Starfield","Trail"}) {
                string path="Assets/Resources/Materials/"+name+".mat";
                if(AssetDatabase.LoadAssetAtPath<Material>(path)!=null)continue;
                var shader=Shader.Find("Cosmic/"+name);
                if(shader==null)throw new InvalidOperationException("Shader not imported: "+name);
                AssetDatabase.CreateAsset(new Material(shader){name=name,enableInstancing=name=="Starfield"},path);
            }
            // Runtime-created meshes/UI have no scene renderer for build-time variant discovery.
            var graphics=new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset")[0]);
            var included=graphics.FindProperty("m_AlwaysIncludedShaders");
            foreach(string name in new[]{"Cosmic/Planet","Cosmic/Star","Cosmic/Atmosphere","Cosmic/Clouds","Cosmic/Rings","Cosmic/Starfield","Cosmic/Trail","UI/Default"}) {
                var shader=Shader.Find(name);if(shader==null)throw new InvalidOperationException("Required build shader missing: "+name);
                bool present=false;for(int i=0;i<included.arraySize;i++)if(included.GetArrayElementAtIndex(i).objectReferenceValue==shader)present=true;
                if(!present){int index=included.arraySize;included.InsertArrayElementAtIndex(index);included.GetArrayElementAtIndex(index).objectReferenceValue=shader;}
            }
            var stripping=graphics.FindProperty("m_InstancingStripping");
            if(stripping!=null && stripping.propertyType==SerializedPropertyType.Enum) {
                int keepAll=Array.IndexOf(stripping.enumNames,"KeepAll");if(keepAll>=0)stripping.enumValueIndex=keepAll;
            }
            graphics.ApplyModifiedPropertiesWithoutUndo();
            PlayerSettings.companyName="Cosmic Sandbox";PlayerSettings.productName="COSMIC SANDBOX 3D";
            PlayerSettings.defaultScreenWidth=1920;PlayerSettings.defaultScreenHeight=1080;
            PlayerSettings.fullScreenMode=FullScreenMode.FullScreenWindow;
            PlayerSettings.resizableWindow=true;PlayerSettings.colorSpace=ColorSpace.Linear;
            PlayerSettings.SetScriptingBackend(UnityEditor.Build.NamedBuildTarget.Standalone,ScriptingImplementation.Mono2x);
            PlayerSettings.SetApiCompatibilityLevel(UnityEditor.Build.NamedBuildTarget.Standalone,ApiCompatibilityLevel.NET_Standard);
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64,false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64,new[]{GraphicsDeviceType.Direct3D11,GraphicsDeviceType.Direct3D12});
            // Legacy keyboard/mouse input, no Input System package or Rigidbody gravity dependency.
            var playerSettings=new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
            var handler=playerSettings.FindProperty("activeInputHandler");if(handler!=null){handler.intValue=0;playerSettings.ApplyModifiedPropertiesWithoutUndo();}
            EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene("Assets/Scenes/MainMenu.unity",true),new EditorBuildSettingsScene("Assets/Scenes/Sandbox.unity",true)};
            AssetDatabase.SaveAssets();
            Debug.Log("Cosmic Phase 1 project prepared: Unity 6000.0 / URP 17.0.4 / Windows x64.");
        }
        [MenuItem("Cosmic/Open Sandbox")]
        public static void OpenSandbox()
        {
            if(!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())return;
            EditorSceneManager.OpenScene("Assets/Scenes/Sandbox.unity");
        }
    }
}
