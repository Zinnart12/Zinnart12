using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Cosmic.Editor
{
    public static class WindowsBuild
    {
        public static void Build()
        {
            ProjectSetup.Prepare();
            if(!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Standalone,BuildTarget.StandaloneWindows64))
                throw new InvalidOperationException("Install Windows Build Support (Mono) for Unity 6000.6.5f1 in Unity Hub.");
            Directory.CreateDirectory("Builds/Windows");
            var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes=new[]{"Assets/Scenes/MainMenu.unity","Assets/Scenes/SolarSystem.unity"},
                locationPathName="Builds/Windows/CosmicSandbox.exe",target=BuildTarget.StandaloneWindows64,options=BuildOptions.None
            });
            if(report.summary.result!=BuildResult.Succeeded)throw new Exception("Windows build failed: "+report.summary.result);
            Debug.Log("Windows x64 build complete: "+report.summary.totalSize+" bytes");
        }
    }
}
