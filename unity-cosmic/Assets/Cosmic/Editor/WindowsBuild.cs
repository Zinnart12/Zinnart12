using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using Cosmic.Runtime;

namespace Cosmic.Editor
{
    public static class WindowsBuild
    {
        public const string OutputDirectory="CosmicSandboxBuild";
        const string ExecutableName="CosmicSandbox.exe";
        const string ManifestName="build-manifest.json";

        [Serializable] sealed class FileRecord {public string path;public long bytes;public string sha256;}
        [Serializable] sealed class Manifest
        {
            public string product="Cosmic Sandbox 3D",unityVersion,buildTarget="StandaloneWindows64",backend="Mono",graphicsApi="Direct3D11",builtUtc;
            public string[] scenes;
            public FileRecord[] files;
            public int buildErrors,buildWarnings;
            public bool launchTested;
        }

        /// <summary>Build a real Windows player; publish only after Unity and artifact validation succeed.</summary>
        public static void Build()
        {
            if(EditorApplication.isCompiling || EditorApplication.isPlayingOrWillChangePlaymode)
                throw new InvalidOperationException("Stop Play Mode and wait for script compilation before building.");
            if(Application.unityVersion!="6000.6.5f1")
                throw new InvalidOperationException("Build with Unity 6000.6.5f1; current Editor is "+Application.unityVersion+".");
            ProjectSetup.Prepare();
            if(!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Standalone,BuildTarget.StandaloneWindows64))
                throw new InvalidOperationException("Install Windows Build Support (Mono) for Unity 6000.6.5f1 in Unity Hub.");
            ValidateConfiguration();ValidateScenes();ValidateShaderErrors();
            string project=Path.GetFullPath(Path.Combine(Application.dataPath,".."));
            string run=Path.Combine(project,"TestResults","WindowsBuild-"+Guid.NewGuid().ToString("N"));
            string staging=Path.Combine(run,OutputDirectory);
            Directory.CreateDirectory(staging);
            var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes=new[]{ProjectBuilder.MenuPath,ProjectBuilder.SolarPath},
                locationPathName=Path.Combine(staging,ExecutableName),target=BuildTarget.StandaloneWindows64,
                subtarget=(int)StandaloneBuildSubtarget.Player,options=BuildOptions.None
            });
            if(report==null || report.summary.result!=BuildResult.Succeeded || report.summary.totalErrors!=0)
                throw new InvalidOperationException("Windows build failed; output was not published. Check build.log and Unity BuildReport.");
            ValidateOutput(staging);WriteManifest(staging,report);
            // Archive every file, including native plugins/Mono runtime, before publishing.
            string stagedZip=Path.Combine(run,"CosmicSandboxBuild.zip");
            ZipFile.CreateFromDirectory(staging,stagedZip,System.IO.Compression.CompressionLevel.Optimal,true);
            ValidateArchive(stagedZip,staging);
            string output=Path.Combine(project,OutputDirectory);
            string release=Path.Combine(project,"Releases","CosmicSandboxBuild.zip");
            Directory.CreateDirectory(Path.GetDirectoryName(release));
            string previousOutput=Path.Combine(run,"PreviousCosmicSandboxBuild");
            string previousArchive=Path.Combine(run,"PreviousCosmicSandboxBuild.zip");
            bool directoryPublished=false,archivePublished=false;
            try {
                if(Directory.Exists(output))Directory.Move(output,previousOutput);
                if(File.Exists(release))File.Move(release,previousArchive);
                Directory.Move(staging,output);directoryPublished=true;
                File.Move(stagedZip,release);archivePublished=true;
            }
            catch {
                if(directoryPublished)Directory.Move(output,staging);
                if(archivePublished)File.Move(release,stagedZip);
                if(Directory.Exists(previousOutput))Directory.Move(previousOutput,output);
                if(File.Exists(previousArchive))File.Move(previousArchive,release);
                throw;
            }
            Debug.Log("Windows x64 Mono / DX11 build succeeded and all required files verified: "+output+
                " ("+report.summary.totalSize+" bytes). Package: "+release+". Launch/visual test is still required on Windows.");
        }

        static void ValidateConfiguration()
        {
            ProjectBuilder.ValidateBuildScenes();
            if(PlayerSettings.GetScriptingBackend(NamedBuildTarget.Standalone)!=ScriptingImplementation.Mono2x)
                throw new InvalidOperationException("Windows build requires the Mono scripting backend.");
            var apis=PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64);
            if(PlayerSettings.GetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64) || apis.Length!=1 || apis[0]!=GraphicsDeviceType.Direct3D11)
                throw new InvalidOperationException("Windows graphics APIs must contain Direct3D11 only.");
            if(GraphicsSettings.defaultRenderPipeline==null || PlayerSettings.colorSpace!=ColorSpace.Linear)
                throw new InvalidOperationException("URP and Linear color space must be assigned before export.");
            foreach(string guid in AssetDatabase.FindAssets("t:AssemblyDefinitionAsset",new[]{"Assets/Cosmic"})) {
                string path=AssetDatabase.GUIDToAssetPath(guid);
                if(path.Contains("/Editor/"))continue;
                foreach(string source in Directory.GetFiles(Path.GetDirectoryName(path),"*.cs",SearchOption.AllDirectories))
                    if(File.ReadAllText(source).Contains("using UnityEditor"))
                        throw new InvalidOperationException("Runtime assembly imports UnityEditor: "+source);
            }
        }

        static void ValidateScenes()
        {
            foreach(string path in new[]{ProjectBuilder.MenuPath,ProjectBuilder.SolarPath}) {
                var scene=SceneManager.GetSceneByPath(path);
                bool opened=!scene.IsValid() || !scene.isLoaded;
                if(opened)scene=EditorSceneManager.OpenScene(path,OpenSceneMode.Additive);
                try {
                    var roots=scene.GetRootGameObjects();
                    var transforms=roots.SelectMany(g=>g.GetComponentsInChildren<Transform>(true)).ToArray();
                    foreach(var transform in transforms) {
                        var gameObject=transform.gameObject;
                        if(GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(gameObject)>0)
                            throw new InvalidOperationException("Missing script in "+path+": "+gameObject.name);
                        foreach(var renderer in gameObject.GetComponents<Renderer>())
                            if(renderer.sharedMaterials.Any(m=>m==null || m.shader==null))
                                throw new InvalidOperationException("Missing renderer material in "+path+": "+gameObject.name);
                    }
                    var bootstrap=roots.SelectMany(g=>g.GetComponentsInChildren<CosmicBootstrap>(true)).SingleOrDefault();
                    if(bootstrap==null || string.IsNullOrEmpty(bootstrap.initialPreset))
                        throw new InvalidOperationException("Scene does not have one configured CosmicBootstrap: "+path);
                    if(path==ProjectBuilder.MenuPath && !bootstrap.showMenu)
                        throw new InvalidOperationException("MainMenu must show the main menu on startup.");
                    if(path==ProjectBuilder.SolarPath && (bootstrap.sceneManager==null || bootstrap.sceneCamera==null))
                        throw new InvalidOperationException("SolarSystem has missing SimulationManager/camera references.");
                }
                finally {if(opened)EditorSceneManager.CloseScene(scene,true);}
            }
        }

        static void ValidateShaderErrors()
        {
            var failed=new List<string>();
            foreach(string guid in AssetDatabase.FindAssets("t:Shader",new[]{"Assets"})) {
                string path=AssetDatabase.GUIDToAssetPath(guid);
                var shader=AssetDatabase.LoadAssetAtPath<Shader>(path);
                if(shader==null || ShaderUtil.ShaderHasError(shader))failed.Add(path);
            }
            if(failed.Count>0)throw new InvalidOperationException("Shaders have import/compilation errors: "+string.Join(", ",failed));
        }

        public static void ValidateOutput(string directory)
        {
            foreach(string name in new[]{ExecutableName,"UnityPlayer.dll","UnityCrashHandler64.exe","MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll"})
                ValidatePeX64(Path.Combine(directory,name));
            string data=Path.Combine(directory,"CosmicSandbox_Data");
            foreach(string name in new[]{"globalgamemanagers","boot.config","Managed/Cosmic.Core.dll","Managed/Cosmic.Runtime.dll","StreamingAssets/PresetCatalog.json"}) {
                string file=Path.Combine(data,name);
                if(!File.Exists(file) || new FileInfo(file).Length==0)
                    throw new InvalidDataException("Windows output is incomplete: "+file);
            }
            if(Directory.GetFiles(data,"*",SearchOption.AllDirectories).Length<8)
                throw new InvalidDataException("Windows player data is incomplete: "+data);
        }

        public static void ValidatePeX64(string path)
        {
            if(!File.Exists(path))throw new InvalidDataException("Required Windows player file is missing: "+path);
            using(var stream=File.OpenRead(path))using(var reader=new BinaryReader(stream)) {
                if(stream.Length<256 || reader.ReadUInt16()!=0x5a4d)throw new InvalidDataException("Not a Windows PE binary: "+path);
                stream.Position=0x3c;uint offset=reader.ReadUInt32();
                if(offset<64 || offset>stream.Length-26)throw new InvalidDataException("Invalid PE header: "+path);
                stream.Position=offset;
                if(reader.ReadUInt32()!=0x00004550 || reader.ReadUInt16()!=0x8664)
                    throw new InvalidDataException("Not an x64 Windows PE binary: "+path);
                stream.Position=offset+24;
                if(reader.ReadUInt16()!=0x20b)throw new InvalidDataException("Expected PE32+ Windows binary: "+path);
            }
        }

        static void WriteManifest(string directory,BuildReport report)
        {
            var manifest=new Manifest {
                unityVersion=Application.unityVersion,builtUtc=DateTime.UtcNow.ToString("O"),
                scenes=new[]{ProjectBuilder.MenuPath,ProjectBuilder.SolarPath},buildErrors=(int)report.summary.totalErrors,
                buildWarnings=(int)report.summary.totalWarnings,launchTested=false,
                files=Directory.GetFiles(directory,"*",SearchOption.AllDirectories).OrderBy(p=>p,StringComparer.Ordinal).Select(p=>new FileRecord {
                    path=p.Substring(directory.Length+1).Replace('\\','/'),bytes=new FileInfo(p).Length,sha256=Hash(p)
                }).ToArray()
            };
            File.WriteAllText(Path.Combine(directory,ManifestName),JsonUtility.ToJson(manifest,true));
        }

        static string Hash(string path)
        {
            using(var hash=SHA256.Create())using(var file=File.OpenRead(path))
                return BitConverter.ToString(hash.ComputeHash(file)).Replace("-","").ToLowerInvariant();
        }

        static void ValidateArchive(string archivePath,string directory)
        {
            using(var archive=ZipFile.OpenRead(archivePath)) {
                var files=Directory.GetFiles(directory,"*",SearchOption.AllDirectories);
                if(archive.Entries.Count(entry=>!entry.FullName.EndsWith("/",StringComparison.Ordinal))!=files.Length)
                    throw new InvalidDataException("Build archive file count mismatch.");
                foreach(string file in files) {
                    string name=OutputDirectory+"/"+file.Substring(directory.Length+1).Replace('\\','/');
                    var entry=archive.GetEntry(name);
                    if(entry==null || entry.Length!=new FileInfo(file).Length)throw new InvalidDataException("Build archive entry missing/incomplete: "+name);
                }
            }
        }
    }
}
