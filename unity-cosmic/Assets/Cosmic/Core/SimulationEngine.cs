using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace Cosmic.Core
{
    public sealed class SimulationEngine
    {
        readonly List<CelestialBody> bodies=new List<CelestialBody>();
        readonly Dictionary<string,Double3> previous=new Dictionary<string,Double3>();
        readonly NBodyGravitySolver gravity=new NBodyGravitySolver();
        readonly CollisionSystem collisions=new CollisionSystem();
        public IReadOnlyList<CelestialBody> Bodies => bodies;
        public double Time { get; private set; }
        public long Steps { get; private set; }
        public string Name { get; private set; }
        public bool Limited { get; private set; }
        public int LastSubsteps { get; private set; }
        public Diagnostics Diagnostics { get; private set; }
        public double BaselineEnergy { get; private set; }
        public double EnergyDrift => BaselineEnergy==0 ? 0 : (Diagnostics.Energy-BaselineEnergy)/Math.Abs(BaselineEnergy);
        public void Load(LegacySnapshot snapshot)
        {
            // Validate completely before changing the currently running universe.
            var incoming=snapshot.ValidatedBodies();
            foreach(var b in incoming) if(b.Kind=="black_hole" || b.Kind=="neutron_star" || b.Kind=="pulsar")
                throw new ArgumentException("Compact-object dynamics are preserved in migration data; runtime integration is Phase 3/5.");
            bodies.Clear(); bodies.AddRange(incoming); Time=snapshot.TimeSeconds; Steps=(long)snapshot.StepCount; Name=snapshot.name;
            ResetBaseline();
        }
        public void ResetBaseline() { Diagnostics=gravity.Measure(bodies); BaselineEnergy=Diagnostics.Energy; Limited=false; }
        public CelestialBody Find(string id) { foreach(var b in bodies) if(b.Id==id) return b; return null; }
        public double Advance(double seconds, int maxSteps=256, double budgetMilliseconds=6)
        {
            if(!Numeric.Finite(seconds) || seconds<=0 || maxSteps<=0) return 0;
            long started=Stopwatch.GetTimestamp(); double completed=0; int count=0;
            if(collisions.Resolve(bodies)>0) ResetBaseline();
            while(completed<seconds && count<maxSteps)
            {
                if(count>0 && budgetMilliseconds>0 && (Stopwatch.GetTimestamp()-started)*1000.0/Stopwatch.Frequency>=budgetMilliseconds) break;
                double dt=Math.Min(seconds-completed,gravity.StableStep(bodies));
                if(!Numeric.Finite(dt) || dt<=0 || Time+dt==Time || completed+dt==completed) break;
                previous.Clear(); foreach(var b in bodies) previous[b.Id]=b.Position;
                gravity.Step(bodies,dt); completed+=dt; Time+=dt; Steps++; count++;
                if(collisions.Resolve(bodies,previous)>0) ResetBaseline();
            }
            LastSubsteps=count; Limited=completed<seconds-Math.Max(1e-8,seconds*1e-12); Diagnostics=gravity.Measure(bodies);
            return completed;
        }
    }
}
