using System.Linq;
using NUnit.Framework;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Cosmic.Editor;
using Cosmic.Runtime;

namespace Cosmic.Tests
{
    public sealed class ProjectRepairTests
    {
        [Test]
        public void EveryQualityUsesTheSameValidURPAsset()
        {
            ProjectBuilder.RepairAndBuild();int previous=QualitySettings.GetQualityLevel();
            try {
                var asset=AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(ProjectBuilder.PipelinePath);
                Assert.NotNull(asset);Assert.AreSame(asset,GraphicsSettings.defaultRenderPipeline);
                for(int i=0;i<QualitySettings.names.Length;i++){QualitySettings.SetQualityLevel(i,false);Assert.AreSame(asset,QualitySettings.renderPipeline);}
                Assert.IsTrue(asset.supportsCameraDepthTexture);Assert.IsTrue(asset.supportsCameraOpaqueTexture);
                CollectionAssert.AreEqual(new[]{GraphicsDeviceType.Direct3D11},PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64));
                ProjectBuilder.ValidateBuildScenes();
            }
            finally {QualitySettings.SetQualityLevel(previous,false);}
        }
        [Test]
        public void OfficialLitInspectorCanBeInstantiatedAndPBRPropertiesArePreserved()
        {
            MaterialRepair.VerifyLitInspector();var material=new Material(Shader.Find("Standard"));
            const string path="Assets/Cosmic/TemporaryMaterialRepairTest.mat";
            try {
                material.SetColor("_Color",new Color(.2f,.3f,.4f,.8f));material.SetFloat("_Metallic",.65f);material.SetFloat("_Glossiness",.73f);
                AssetDatabase.CreateAsset(material,path);MaterialRepair.ConvertBuiltInMaterials();
                Assert.AreEqual("Universal Render Pipeline/Lit",material.shader.name);
                Assert.AreEqual(.65f,material.GetFloat("_Metallic"));Assert.AreEqual(.73f,material.GetFloat("_Smoothness"));
                Assert.AreEqual(new Color(.2f,.3f,.4f,.8f),material.GetColor("_BaseColor"));
                var inspector=(MaterialEditor)UnityEditor.Editor.CreateEditor(material);
                try {Assert.NotNull(inspector.customShaderGUI);Assert.AreEqual("LitShader",inspector.customShaderGUI.GetType().Name);}
                finally {Object.DestroyImmediate(inspector);}
            }
            finally {AssetDatabase.DeleteAsset(path);if(material!=null)Object.DestroyImmediate(material);}
        }
        [Test]
        public void SolarSceneContainsAllBodiesRingsAndWiredCameraBeforePlay()
        {
            var previous=EditorSceneManager.GetSceneManagerSetup();
            try {
                EditorSceneManager.OpenScene(ProjectBuilder.SolarPath);
                var bootstrap=Object.FindAnyObjectByType<CosmicBootstrap>();Assert.NotNull(bootstrap);
                Assert.NotNull(bootstrap.sceneManager);Assert.NotNull(bootstrap.sceneCamera);Assert.NotNull(bootstrap.editorPreview);
                var names=bootstrap.editorPreview.transform.Cast<Transform>().Select(t=>t.name).ToArray();
                CollectionAssert.AreEquivalent(new[]{"Sun","Mercury","Venus","Earth","Mars","Jupiter","Saturn","Uranus","Neptune","Moon"},names);
                Assert.NotNull(bootstrap.editorPreview.transform.Find("Saturn/Axial Rotation/Grain Rings"));
                Assert.NotNull(bootstrap.sceneCamera.GetComponent<SpaceCameraController>());
                Assert.NotNull(bootstrap.sceneManager.GetComponent<SpaceBackground>());
                MaterialRepair.ValidateAllMaterials();
            }
            finally {EditorSceneManager.RestoreSceneManagerSetup(previous);}
        }
    }
}
