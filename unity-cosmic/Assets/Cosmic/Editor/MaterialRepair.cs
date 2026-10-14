using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Cosmic.Editor
{
    public static class MaterialRepair
    {
        public static readonly string[] CosmicNames={"Planet","Star","Atmosphere","Clouds","Rings","Starfield","Trail"};
        public static void EnsureGameMaterials()
        {
            Directory.CreateDirectory("Assets/Resources/Materials");AssetDatabase.Refresh();
            foreach(string name in CosmicNames) {
                var shader=Shader.Find("Cosmic/"+name);
                if(shader==null || ShaderUtil.ShaderHasError(shader))throw new InvalidOperationException("Custom HLSL import failed: Cosmic/"+name);
                string path="Assets/Resources/Materials/"+name+".mat";
                var material=AssetDatabase.LoadAssetAtPath<Material>(path);
                if(material==null) {material=new Material(shader){name=name};AssetDatabase.CreateAsset(material,path);}
                else if(material.shader!=shader)material.shader=shader;
                material.enableInstancing=name=="Starfield";EditorUtility.SetDirty(material);
            }
        }
        public static Type VerifyLitInspector()
        {
            var type=Type.GetType("UnityEditor.Rendering.Universal.ShaderGUI.LitShader, Unity.RenderPipelines.Universal.Editor",false)
                ??AppDomain.CurrentDomain.GetAssemblies().Select(a=>a.GetType("UnityEditor.Rendering.Universal.ShaderGUI.LitShader",false)).FirstOrDefault(t=>t!=null);
            if(type==null || type.IsAbstract || !typeof(ShaderGUI).IsAssignableFrom(type))
                throw new InvalidOperationException("URP LitShader inspector is unavailable. Fix the first C# package error; match URP/Core/ShaderGraph 17.6.0 and remove duplicate URP source/DLLs from Assets. Tools/repair-urp.ps1 re-resolves packages with Unity closed.");
            return type;
        }
        public static int ConvertBuiltInMaterials()
        {
            var inspector=(ShaderGUI)Activator.CreateInstance(VerifyLitInspector(),true);
            var lit=Shader.Find("Universal Render Pipeline/Lit");
            if(lit==null)throw new InvalidOperationException("Official URP Lit shader is missing.");
            int changed=0;
            foreach(string guid in AssetDatabase.FindAssets("t:Material",new[]{"Assets"})) {
                string path=AssetDatabase.GUIDToAssetPath(guid);
                foreach(var material in AssetDatabase.LoadAllAssetsAtPath(path).OfType<Material>()) {
                    string name=material.shader!=null?material.shader.name:"";
                    if(name!="Standard" && name!="Standard (Specular setup)" && !name.StartsWith("Legacy Shaders/",StringComparison.Ordinal))continue;
                    if(path.EndsWith(".mat",StringComparison.OrdinalIgnoreCase)) {
                        string backup=Path.Combine("TestResults/MaterialBackups",path);
                        Directory.CreateDirectory(Path.GetDirectoryName(backup));if(!File.Exists(backup))File.Copy(path,backup);
                    }
                    bool specular=name=="Standard (Specular setup)";
                    var baseColor=material.HasProperty("_Color")?material.GetColor("_Color"):Color.white;
                    var baseMap=material.HasProperty("_MainTex")?material.GetTexture("_MainTex"):null;
                    var scale=material.HasProperty("_MainTex")?material.GetTextureScale("_MainTex"):Vector2.one;
                    var offset=material.HasProperty("_MainTex")?material.GetTextureOffset("_MainTex"):Vector2.zero;
                    float legacyMode=name.Contains("Transparent/Cutout")?1:name.Contains("Transparent")?2:0;
                    float metallic=Value(material,"_Metallic",0),smooth=Value(material,"_Glossiness",.5f),cutoff=Value(material,"_Cutoff",.5f),mode=Value(material,"_Mode",legacyMode);
                    var normal=material.HasProperty("_BumpMap")?material.GetTexture("_BumpMap"):null;
                    var metalMap=material.HasProperty("_MetallicGlossMap")?material.GetTexture("_MetallicGlossMap"):null;
                    var specMap=material.HasProperty("_SpecGlossMap")?material.GetTexture("_SpecGlossMap"):null;
                    var specColor=material.HasProperty("_SpecColor")?material.GetColor("_SpecColor"):new Color(.2f,.2f,.2f);
                    var emission=material.HasProperty("_EmissionColor")?material.GetColor("_EmissionColor"):Color.black;
                    var emissionMap=material.HasProperty("_EmissionMap")?material.GetTexture("_EmissionMap"):null;
                    var occlusion=material.HasProperty("_OcclusionMap")?material.GetTexture("_OcclusionMap"):null;
                    float bumpScale=Value(material,"_BumpScale",1),occlusionStrength=Value(material,"_OcclusionStrength",1);
                    material.shader=lit;material.shaderKeywords=Array.Empty<string>();
                    material.SetColor("_BaseColor",baseColor);material.SetTexture("_BaseMap",baseMap);material.SetTextureScale("_BaseMap",scale);material.SetTextureOffset("_BaseMap",offset);
                    material.SetFloat("_Metallic",metallic);material.SetFloat("_Smoothness",smooth);material.SetFloat("_Cutoff",cutoff);
                    material.SetFloat("_WorkflowMode",specular?0:1);material.SetColor("_SpecColor",specColor);material.SetTexture("_SpecGlossMap",specMap);
                    material.SetTexture("_BumpMap",normal);material.SetFloat("_BumpScale",bumpScale);material.SetTexture("_MetallicGlossMap",metalMap);
                    material.SetTexture("_OcclusionMap",occlusion);material.SetFloat("_OcclusionStrength",occlusionStrength);
                    material.SetColor("_EmissionColor",emission);material.SetTexture("_EmissionMap",emissionMap);
                    Keyword(material,"_NORMALMAP",normal!=null);Keyword(material,"_METALLICSPECGLOSSMAP",specular?specMap!=null:metalMap!=null);
                    Keyword(material,"_SPECULAR_SETUP",specular);Keyword(material,"_OCCLUSIONMAP",occlusion!=null);Keyword(material,"_EMISSION",emission.maxColorComponent>0 || emissionMap!=null);
                    bool transparent=mode>=2,cutout=mode==1;
                    material.SetFloat("_Surface",transparent?1:0);material.SetFloat("_AlphaClip",cutout?1:0);material.SetFloat("_Blend",0);
                    material.SetFloat("_BlendModePreserveSpecular",mode==3?1:0);
                    material.SetFloat("_SrcBlend",transparent?(float)BlendMode.SrcAlpha:(float)BlendMode.One);
                    material.SetFloat("_DstBlend",transparent?(float)BlendMode.OneMinusSrcAlpha:(float)BlendMode.Zero);material.SetFloat("_ZWrite",transparent?0:1);
                    Keyword(material,"_SURFACE_TYPE_TRANSPARENT",transparent);Keyword(material,"_ALPHATEST_ON",cutout);
                    material.renderQueue=transparent?(int)RenderQueue.Transparent:cutout?(int)RenderQueue.AlphaTest:(int)RenderQueue.Geometry;
                    material.SetOverrideTag("RenderType",transparent?"Transparent":cutout?"TransparentCutout":"Opaque");
                    // Let the installed URP inspector synchronize blend/pass/keyword state.
                    inspector.ValidateMaterial(material);
                    EditorUtility.SetDirty(material);changed++;
                }
            }
            return changed;
        }
        public static void ValidateAllMaterials()
        {
            foreach(string guid in AssetDatabase.FindAssets("t:Material",new[]{"Assets"})) {
                string path=AssetDatabase.GUIDToAssetPath(guid);
                foreach(var material in AssetDatabase.LoadAllAssetsAtPath(path).OfType<Material>()) {
                    if(material.shader==null || material.shader.name=="Hidden/InternalErrorShader" || ShaderUtil.ShaderHasError(material.shader))
                        throw new InvalidOperationException("Broken material/shader needs its source repaired: "+path+" / "+material.name);
                    string pipeline=material.GetTag("RenderPipeline",false,"");
                    if(pipeline!="UniversalPipeline" && !material.shader.name.StartsWith("UI/",StringComparison.Ordinal) && !material.shader.name.StartsWith("Hidden/",StringComparison.Ordinal))
                        throw new InvalidOperationException("Shader is not URP compatible: "+path+" / "+material.shader.name);
                }
            }
        }
        static float Value(Material m,string key,float fallback)=>m.HasProperty(key)?m.GetFloat(key):fallback;
        static void Keyword(Material m,string key,bool enabled) {if(enabled)m.EnableKeyword(key);else m.DisableKeyword(key);}
    }
}
