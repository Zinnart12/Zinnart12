using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Cosmic.Runtime
{
    public static class PlanetGenerator
    {
        static readonly Dictionary<int,Mesh> spheres=new Dictionary<int,Mesh>();
        static Mesh rings;
        public static Mesh Sphere(int quality)
        {
            int segments=new[]{24,48,96}[Mathf.Clamp(quality,0,2)];
            if(spheres.TryGetValue(segments,out var cached))return cached;
            int latitude=segments/2;var vertices=new Vector3[(latitude+1)*(segments+1)];var uv=new Vector2[vertices.Length];
            for(int y=0;y<=latitude;y++)for(int x=0;x<=segments;x++) {
                float v=(float)y/latitude,u=(float)x/segments,a=u*Mathf.PI*2,b=v*Mathf.PI;
                int i=y*(segments+1)+x;vertices[i]=new Vector3(Mathf.Sin(b)*Mathf.Cos(a),Mathf.Cos(b),Mathf.Sin(b)*Mathf.Sin(a));uv[i]=new Vector2(u,v); }
            var triangles=new List<int>();
            for(int y=0;y<latitude;y++)for(int x=0;x<segments;x++) {
                int i=y*(segments+1)+x,j=i+segments+1;
                // Winding outward, with duplicated longitude vertices for UV continuity.
                triangles.Add(i);triangles.Add(i+1);triangles.Add(j);
                triangles.Add(i+1);triangles.Add(j+1);triangles.Add(j);
            }
            var mesh=new Mesh {name="Procedural Planet LOD "+segments,indexFormat=IndexFormat.UInt32};
            mesh.vertices=vertices;mesh.normals=vertices;mesh.uv=uv;mesh.triangles=triangles.ToArray();mesh.RecalculateBounds();
            spheres[segments]=mesh;return mesh;
        }
        public static Mesh Rings()
        {
            if(rings!=null)return rings;
            var v=new Vector3[514];var uv=new Vector2[514];var t=new int[256*6];
            for(int i=0;i<=256;i++) {float a=i*Mathf.PI*2/256;var d=new Vector3(Mathf.Cos(a),0,Mathf.Sin(a));
                v[i*2]=d*1.25f;v[i*2+1]=d*2.3f;uv[i*2]=new Vector2(0,(float)i/256);uv[i*2+1]=new Vector2(1,(float)i/256);
                if(i==256)continue;int k=i*6,n=i*2;t[k]=n;t[k+1]=n+2;t[k+2]=n+1;t[k+3]=n+1;t[k+4]=n+2;t[k+5]=n+3; }
            rings=new Mesh{name="Saturn Grain Rings",vertices=v,uv=uv,triangles=t};rings.RecalculateNormals();rings.RecalculateBounds();return rings;
        }
    }
}
