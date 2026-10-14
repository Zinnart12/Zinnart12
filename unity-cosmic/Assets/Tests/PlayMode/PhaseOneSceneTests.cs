using System.Collections;
using System.IO;
using System.Linq;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using Cosmic.Core;
using Cosmic.Runtime;

namespace Cosmic.Tests
{
    public sealed class PhaseOneSceneTests
    {
        [UnityTest]
        public IEnumerator SolarSystemHasRealBodiesAndCompiledSurfaceShaders()
        {
            yield return SceneManager.LoadSceneAsync("Sandbox");yield return null;
            var u=Object.FindFirstObjectByType<UniverseManager>();Assert.NotNull(u);Assert.IsNull(u.LastError);
            u.Paused=true;Assert.AreEqual(10,u.Simulation.Bodies.Count);
            Assert.NotNull(u.Simulation.Find("sun"));Assert.NotNull(u.Simulation.Find("neptune"));Assert.NotNull(u.Simulation.Find("moon"));
            Assert.AreEqual(10,Object.FindObjectsByType<CelestialBodyView>(FindObjectsSortMode.None).Length);
            foreach(string name in new[]{"Planet","Star","Atmosphere","Clouds","Rings","Starfield","Trail"}) {
                var material=Resources.Load<Material>("Materials/"+name);Assert.NotNull(material);Assert.IsTrue(material.shader.isSupported,name);
            }
            LogAssert.NoUnexpectedReceived();
        }
        [UnityTest]
        public IEnumerator CameraFocusDoesNotChangeSIStateAndStepsMovePlanets()
        {
            yield return SceneManager.LoadSceneAsync("Sandbox");yield return null;
            var u=Object.FindFirstObjectByType<UniverseManager>();u.Paused=true;
            var c=Object.FindFirstObjectByType<SpaceCameraController>();u.Select("earth");
            var p=u.Selected.Position;var v=u.Selected.Velocity;c.FocusSelected();yield return null;
            Assert.AreEqual(p.X,u.Selected.Position.X);Assert.AreEqual(v.Z,u.Selected.Velocity.Z);
            Assert.Greater(u.Coordinates.MetresToScene,32/Astronomy.AU);
            var surface=Object.FindObjectsByType<CelestialBodyView>(FindObjectsSortMode.None).Single(x=>x.name=="Earth");
            var screen=Camera.main.WorldToViewportPoint(surface.transform.position);Assert.Greater(screen.z,0);
            Assert.That(screen.x,Is.InRange(.4f,.6f));Assert.That(screen.y,Is.InRange(.4f,.6f));
            u.Step();Assert.Greater((u.Selected.Position-p).Length,0);Assert.Greater(u.Simulation.Time,0);
            LogAssert.NoUnexpectedReceived();
        }
        [UnityTest]
        public IEnumerator LegacyJsonParserRetainsDoubleBits()
        {
            yield return SceneManager.LoadSceneAsync("Sandbox");yield return null;
            var u=Object.FindFirstObjectByType<UniverseManager>();u.Paused=true;
            var p=new Double3(1000*Astronomy.AU+1,2,-3);
            string json="{\"schema_version\":1,\"name\":\"Precision\",\"time\":0,\"steps\":0,\"bodies\":[{\"id\":\"a\",\"name\":\"a\",\"kind\":\"planet\",\"surface\":\"rocky\",\"mass\":1000000,\"radius\":1,\"temperature\":288,\"color\":\"808080\",\"composition\":\"Rock\",\"position\":[149597870700001,2,-3],\"velocity\":[0,0,0]}]}";
            var snapshot=JsonUtility.FromJson<LegacySnapshot>(json);var b=snapshot.ValidatedBodies()[0];
            Assert.AreEqual(System.BitConverter.DoubleToInt64Bits(p.X),System.BitConverter.DoubleToInt64Bits(b.Position.X));
            LogAssert.NoUnexpectedReceived();
        }
        [UnityTest]
        public IEnumerator EarthAndMoonAndBinaryPresetsHaveDistinctDynamics()
        {
            yield return SceneManager.LoadSceneAsync("Sandbox");yield return null;
            var u=Object.FindFirstObjectByType<UniverseManager>();u.Paused=true;
            u.LoadPreset("earthmoon");Assert.AreEqual(2,u.Simulation.Bodies.Count);Assert.NotNull(u.Simulation.Find("moon"));
            u.LoadPreset("binary");Assert.AreEqual(2,u.Simulation.Bodies.Count);Assert.IsTrue(u.Simulation.Bodies.All(b=>b.IsLuminous));
            yield return null;LogAssert.NoUnexpectedReceived();
        }
        [UnityTest]
        public IEnumerator HDRSceneHasVisibleSunAndDetailedPlanetPixels()
        {
            yield return SceneManager.LoadSceneAsync("Sandbox");yield return null;
            var u=Object.FindFirstObjectByType<UniverseManager>();u.Paused=true;u.Trails=false;
            foreach(var canvas in Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None))canvas.enabled=false;
            var c=Object.FindFirstObjectByType<SpaceCameraController>();
            foreach(string id in new[]{"sun","earth","jupiter"}) {
                u.Select(id);c.FocusSelected();yield return null;yield return new WaitForEndOfFrame();
                var capture=ScreenCapture.CaptureScreenshotAsTexture();
                var pixels=capture.GetPixels();float max=0,min=1;int bright=0;
                // Center of the actual focused mesh, excluding UI/labels and outer background.
                for(int y=capture.height*45/100;y<capture.height*55/100;y++)for(int x=capture.width*45/100;x<capture.width*55/100;x++) {
                    float light=pixels[y*capture.width+x].grayscale;max=Mathf.Max(max,light);min=Mathf.Min(min,light);if(light>.03f)bright++;
                }
                Assert.Greater(bright,100,id+" mesh is black");Assert.Greater(max-min,.015f,id+" lacks texture detail");
                Directory.CreateDirectory("TestResults/Captures");File.WriteAllBytes("TestResults/Captures/"+id+".png",capture.EncodeToPNG());Object.Destroy(capture);
            }
            LogAssert.NoUnexpectedReceived();
        }
    }
}
