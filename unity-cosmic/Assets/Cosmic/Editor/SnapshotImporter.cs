using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using Cosmic.Core;

namespace Cosmic.Editor
{
    public static class SnapshotImporter
    {
        [MenuItem("Cosmic/Import Validated Snapshot JSON")]
        public static void Import()
        {
            string source=EditorUtility.OpenFilePanel("Validated simulation snapshot JSON","","json");
            if(string.IsNullOrEmpty(source))return;
            if(new FileInfo(source).Length>2000000)throw new ArgumentException("Snapshot JSON exceeds 2 MB.");
            string text=File.ReadAllText(source);var snapshot=JsonUtility.FromJson<LegacySnapshot>(text);
            snapshot.ValidatedBodies();
            // Archives the snapshot without changing a running scene or the source JSON.
            Directory.CreateDirectory("Assets/StreamingAssets/ImportedSaves");
            File.Copy(source,"Assets/StreamingAssets/ImportedSaves/"+Path.GetFileName(source),true);AssetDatabase.Refresh();
            Debug.Log("Imported "+snapshot.bodies.Length+" bodies at simulation time "+snapshot.time+" s. Runtime Save/Load is Phase 2.");
        }
    }
}
