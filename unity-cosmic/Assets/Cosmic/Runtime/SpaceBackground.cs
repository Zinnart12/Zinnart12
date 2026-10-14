using UnityEngine;
using UnityEngine.Rendering;

namespace Cosmic.Runtime
{
    public sealed class SpaceBackground : MonoBehaviour
    {
        public struct StarInstance { public Matrix4x4 objectToWorld; }
        readonly StarInstance[][] batches=new StarInstance[4][];
        readonly Vector3[] directions=new Vector3[4096];
        Camera cameraComponent;Mesh quad;Material material;
        public void Initialize(Camera camera)
        {
            cameraComponent=camera;var rng=new System.Random(2031417);
            for(int i=0;i<directions.Length;i++) {double y=rng.NextDouble()*2-1,a=rng.NextDouble()*System.Math.PI*2;
                float xz=(float)System.Math.Sqrt(1-y*y);directions[i]=new Vector3(xz*(float)System.Math.Cos(a),(float)y,xz*(float)System.Math.Sin(a)); }
            for(int b=0;b<4;b++)batches[b]=new StarInstance[1024];
            quad=new Mesh {name="Instanced Background Quad",vertices=new[]{new Vector3(-1,-1),new Vector3(-1,1),new Vector3(1,1),new Vector3(1,-1)},
                uv=new[]{Vector2.zero,Vector2.up,Vector2.one,Vector2.right},triangles=new[]{0,1,2,0,2,3}};quad.RecalculateBounds();
            var template=Resources.Load<Material>("Materials/Starfield");
            if(template==null)throw new System.InvalidOperationException("Starfield material missing.");
            material=new Material(template){enableInstancing=true};
        }
        void LateUpdate()
        {
            if(cameraComponent==null || material==null)return;
            float radius=cameraComponent.farClipPlane*.8f;
            var rotation=cameraComponent.transform.rotation;
            for(int b=0;b<4;b++) {
                for(int i=0;i<1024;i++)batches[b][i].objectToWorld=Matrix4x4.TRS(cameraComponent.transform.position+directions[b*1024+i]*radius,rotation,Vector3.one*(radius*.0007f));
                var parameters=new RenderParams(material){worldBounds=new Bounds(cameraComponent.transform.position,Vector3.one*radius*2.1f),shadowCastingMode=ShadowCastingMode.Off,receiveShadows=false};
                // The API's default instance limit is 511 when inverse matrices are present.
                Graphics.RenderMeshInstanced(parameters,quad,0,batches[b],511,0);
                Graphics.RenderMeshInstanced(parameters,quad,0,batches[b],511,511);
                Graphics.RenderMeshInstanced(parameters,quad,0,batches[b],2,1022);
            }
        }
        void OnDestroy() {if(material!=null)Destroy(material);if(quad!=null)Destroy(quad);}
    }
}
