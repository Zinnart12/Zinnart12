using System;
using System.Collections.Generic;

namespace Cosmic.Core
{
    // Direct port of GravitySolver.gd: symmetric pair forces and velocity Verlet.
    public sealed class NBodyGravitySolver
    {
        Double3[] first = Array.Empty<Double3>(), second = Array.Empty<Double3>();
        public const double MaximumStep = 3600;
        public void Accelerations(IReadOnlyList<CelestialBody> bodies, Double3[] output)
        {
            if (output.Length < bodies.Count) throw new ArgumentException("Acceleration buffer too small.");
            Array.Clear(output, 0, bodies.Count);
            for (int i=0; i<bodies.Count; i++) for (int j=i+1; j<bodies.Count; j++)
            {
                var a=bodies[i]; var b=bodies[j]; var delta=b.Position-a.Position;
                double floor=.1*(a.Radius+b.Radius);
                double d2=Math.Max(delta.LengthSquared, floor*floor);
                double factor=Astronomy.G/(d2*Math.Sqrt(d2));
                output[i] += delta*(factor*b.Mass);
                output[j] -= delta*(factor*a.Mass);
            }
        }
        public void Step(IReadOnlyList<CelestialBody> bodies, double dt)
        {
            if (!Numeric.Finite(dt) || dt<=0) throw new ArgumentOutOfRangeException(nameof(dt));
            if (first.Length < bodies.Count) { first=new Double3[bodies.Count]; second=new Double3[bodies.Count]; }
            Accelerations(bodies, first);
            for (int i=0; i<bodies.Count; i++) bodies[i].Position += bodies[i].Velocity*dt + first[i]*(.5*dt*dt);
            Accelerations(bodies, second);
            for (int i=0; i<bodies.Count; i++) bodies[i].Velocity += (first[i]+second[i])*(.5*dt);
        }
        public double StableStep(IReadOnlyList<CelestialBody> bodies)
        {
            double result=MaximumStep;
            for(int i=0;i<bodies.Count;i++) for(int j=i+1;j<bodies.Count;j++)
            {
                double d2=(bodies[j].Position-bodies[i].Position).LengthSquared;
                if(d2<=0) continue;
                double r=Math.Sqrt(d2), v=(bodies[j].Velocity-bodies[i].Velocity).Length;
                result=Math.Min(result,.01*Math.Sqrt(r*d2/(Astronomy.G*(bodies[i].Mass+bodies[j].Mass))));
                if(v>0) result=Math.Min(result,.15*r/v);
            }
            return result;
        }
        public Diagnostics Measure(IReadOnlyList<CelestialBody> bodies)
        {
            var d=new Diagnostics();
            for(int i=0;i<bodies.Count;i++)
            {
                var b=bodies[i]; d.Kinetic+=.5*b.Mass*b.Velocity.LengthSquared;
                d.Momentum+=b.Velocity*b.Mass; d.TotalMass+=b.Mass;
                for(int j=i+1;j<bodies.Count;j++)
                    d.Potential-=Astronomy.G*b.Mass*bodies[j].Mass/Math.Max((bodies[j].Position-b.Position).Length,.1*(b.Radius+bodies[j].Radius));
            }
            return d;
        }
    }
    public struct Diagnostics
    {
        public double Kinetic, Potential, TotalMass;
        public Double3 Momentum;
        public double Energy => Kinetic+Potential;
    }
}
