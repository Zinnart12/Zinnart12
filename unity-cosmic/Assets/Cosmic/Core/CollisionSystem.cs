using System;
using System.Collections.Generic;

namespace Cosmic.Core
{
    // Preserves the existing inelastic baseline. Advanced fracture is Phase 3.
    public sealed class CollisionSystem
    {
        public int Resolve(List<CelestialBody> bodies, IReadOnlyDictionary<string,Double3> previous = null)
        {
            int events=0;
            for(int i=0;i<bodies.Count;i++) for(int j=i+1;j<bodies.Count;j++)
            {
                var a=bodies[i]; var b=bodies[j];
                if(a.Kind=="black_hole" || b.Kind=="black_hole") continue;
                double contact=a.Radius+b.Radius;
                var delta=b.Position-a.Position; bool hit=delta.LengthSquared<=contact*contact;
                if(!hit && previous!=null && previous.TryGetValue(a.Id,out var pa) && previous.TryGetValue(b.Id,out var pb))
                {
                    var start=pb-pa; var change=delta-start;
                    double t=change.LengthSquared>0 ? Numeric.Clamp(-Double3.Dot(start,change)/change.LengthSquared,0,1) : 0;
                    hit=(start+change*t).LengthSquared<=contact*contact;
                }
                if(!hit) continue;
                double total=a.Mass+b.Mass, energy=.5*a.Mass*(b.Mass/total)*(a.Velocity-b.Velocity).LengthSquared;
                var survivor=(a.Mass>=b.Mass?a:b).Copy();
                survivor.Position=a.Position*(a.Mass/total)+b.Position*(b.Mass/total);
                survivor.Velocity=a.Velocity*(a.Mass/total)+b.Velocity*(b.Mass/total);
                survivor.Temperature=Math.Min(1e9,(a.Temperature*a.Mass+b.Temperature*b.Mass)/total+energy/(1000*total));
                survivor.Mass=total; survivor.Radius=Math.Pow(a.Radius*a.Radius*a.Radius+b.Radius*b.Radius*b.Radius,1.0/3);
                bodies[i]=survivor; bodies.RemoveAt(j); events++; previous=null; i=-1; break;
            }
            return events;
        }
    }
}
