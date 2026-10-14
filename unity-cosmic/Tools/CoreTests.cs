using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text.Json;
using Cosmic.Core;

public static class CoreChecks
{
    static int passed;
    static readonly JsonSerializerOptions json = new JsonSerializerOptions { IncludeFields = true };
    public static void Require(bool ok, string message) { if(!ok) throw new Exception(message); }
    static void Check(string title, Action test) { test(); passed++; Console.WriteLine("PASS " + title); }
    static CelestialBody Body(string id, double mass, double radius=1) => new CelestialBody {
        Id=id, Name=id, Kind="planet", Surface="rocky", Composition="Rock", Color="808080",
        Mass=mass, Radius=radius, Temperature=288, Strength=1e8, MagneticAxis=30, DiskEnabled=true
    };
    static List<CelestialBody> Pair(double eccentricity=0)
    {
        var a=Body("sun",Astronomy.SolarMass,695700000);a.Kind="star";a.Temperature=5772;
        var b=Body("earth",Astronomy.EarthMass,6371000);
        double total=a.Mass+b.Mass,r=Astronomy.AU*(1-eccentricity);
        double v=Math.Sqrt(Astronomy.G*total*(1+eccentricity)/r);
        a.Position=new Double3(-r*b.Mass/total,0,0);b.Position=new Double3(r*a.Mass/total,0,0);
        a.Velocity=new Double3(0,0,-v*b.Mass/total);b.Velocity=new Double3(0,0,v*a.Mass/total);
        return new List<CelestialBody>{a,b};
    }
    static LegacySnapshot Snapshot(IEnumerable<CelestialBody> bodies) => new LegacySnapshot {
        schema_version=1,name="Test", bodies=bodies.Select(b=>new LegacyBody { id=b.Id,name=b.Name,kind=b.Kind,surface=b.Surface,
            composition=b.Composition,color=b.Color,mass=b.Mass,radius=b.Radius,temperature=b.Temperature,
            position=b.Position.ToArray(),velocity=b.Velocity.ToArray(),strength=b.Strength,magnetic_axis=b.MagneticAxis }).ToArray()
    };
    static void Integrate(List<CelestialBody> pair,double seconds)
    {
        var g=new NBodyGravitySolver();double done=0;
        while(done<seconds) { double dt=Math.Min(seconds-done,g.StableStep(pair));g.Step(pair,dt);done+=dt; }
    }
    static double Relative(double actual,double expected) => Math.Abs(actual-expected)/Math.Max(1,Math.Abs(expected));
    public static void Run(string root)
    {
        Check("SI constants and Earth gravity",()=>Require(Relative(Body("earth",Astronomy.EarthMass,6371000).SurfaceGravity,9.820302293385645)<1e-12,"GM/R²"));
        Check("Schwarzschild radius is physical, not visual",()=>Require(Relative(Astronomy.SchwarzschildRadius(Astronomy.SolarMass),2953.3393820668784)<1e-12,"Rs"));
        Check("Pair force preserves action/reaction",()=> {
            var pair=Pair();var output=new Double3[2];new NBodyGravitySolver().Accelerations(pair,output);
            Require((output[0]*pair[0].Mass+output[1]*pair[1].Mass).Length/(output[1].Length*pair[1].Mass)<1e-14,"Unequal forces");
        });
        Check("Circular orbit returns after one period",()=> {
            var pair=Pair();var initial=pair[1].Position-pair[0].Position;
            double period=2*Math.PI*Math.Sqrt(Math.Pow(Astronomy.AU,3)/(Astronomy.G*(pair[0].Mass+pair[1].Mass)));
            Integrate(pair,period);Require(((pair[1].Position-pair[0].Position)-initial).Length/Astronomy.AU<1e-5,"Orbit drift");
        });
        Check("Five eccentric years retain energy and momentum",()=> {
            var pair=Pair(.6);var g=new NBodyGravitySolver();var initial=g.Measure(pair);double done=0,max=0;
            while(done<5*Astronomy.Year) { double dt=Math.Min(5*Astronomy.Year-done,g.StableStep(pair));g.Step(pair,dt);done+=dt;
                max=Math.Max(max,Relative(g.Measure(pair).Energy,initial.Energy)); }
            var d=g.Measure(pair);Console.WriteLine("  eccentric energy drift max = "+max.ToString("G10"));
            Require(max<1e-4 && d.Momentum.Length/(pair[1].Mass*pair[1].Velocity.Length)<1e-11,"Conservation");
        });
        Check("Parabolic escape is not a closed animation",()=> {
            var pair=Pair();pair[1].Velocity*=Math.Sqrt(2);Integrate(pair,Astronomy.Year);
            Require((pair[1].Position-pair[0].Position).Length>2*Astronomy.AU,"Failed escape");
        });
        Check("Hyperbolic escape keeps positive orbital energy",()=> {
            var pair=Pair();pair[1].Velocity*=1.6;var g=new NBodyGravitySolver();double before=g.Measure(pair).Energy;
            Integrate(pair,Astronomy.Year);Require(before>0 && g.Measure(pair).Energy>0 && (pair[1].Position-pair[0].Position).Length>3*Astronomy.AU,"Failed hyperbola");
        });
        Check("Deleting Sun removes gravity and retains velocity",()=> {
            var pair=Pair();pair.RemoveAt(0);var p=pair[0].Position;var v=pair[0].Velocity;
            Integrate(pair,Astronomy.Day*30);Require((pair[0].Position-p-v*(Astronomy.Day*30)).Length<.1 && (pair[0].Velocity-v).Length==0,"Sun removed still orbits");
        });
        Check("Same-mass compact replacement gives same Newton acceleration",()=> {
            var pair=Pair();var g=new NBodyGravitySolver();var a=new Double3[2];var b=new Double3[2];g.Accelerations(pair,a);
            pair[0].Kind="black_hole";pair[0].Radius=Astronomy.SchwarzschildRadius(pair[0].Mass);g.Accelerations(pair,b);
            Require((a[1]-b[1]).Length==0,"Artificial infall after replacement");
        });
        Check("Adaptive substeps shrink for close encounters",()=> {
            var pair=Pair();var g=new NBodyGravitySolver();double distant=g.StableStep(pair);
            pair[1].Position=pair[0].Position+new Double3(1e8,0,0);Require(g.StableStep(pair)<distant*.01,"Unstable step");
        });
        Check("Swept collision conserves mass, momentum and volume",()=> {
            var a=Body("a",1e8,2);var b=Body("b",2e8,3);a.Position=new Double3(-10,0,0);b.Position=new Double3(10,0,0);
            a.Velocity=new Double3(10,0,0);b.Velocity=new Double3(-2,0,0);
            var old=new Dictionary<string,Double3>{{"a",a.Position},{"b",b.Position}};
            a.Position=new Double3(10,0,0);b.Position=new Double3(-10,0,0);var list=new List<CelestialBody>{a,b};
            Require(new CollisionSystem().Resolve(list,old)==1 && list.Count==1,"Missed contact");
            Require(Relative(list[0].Mass,3e8)<1e-14 && Relative(list[0].Velocity.X*list[0].Mass,6e8)<1e-14 &&
                Relative(Math.Pow(list[0].Radius,3),35)<1e-14 && list[0].Temperature>288,"Bad remnant");
        });
        Check("Floating origin retains one metre at 1000 AU",()=> {
            var f=new FloatingOrigin { Origin=new Double3(1000*Astronomy.AU,0,0),MetresToScene=1 };
            Require(f.Relative(f.Origin+new Double3(1,0,0)).X==1,"Lost metre before float conversion");
        });
        Check("Frame budget advances only integrated time",()=> {
            var engine=new SimulationEngine();engine.Load(Snapshot(Pair()));double actual=engine.Advance(Astronomy.Year,2,0);
            Require(engine.Steps==2 && engine.Time==actual && actual<=7200 && engine.Limited,"Skipped unintegrated time");
        });
        Check("Equal simulated intervals agree across frame partitions",()=> {
            var a=new SimulationEngine();var b=new SimulationEngine();a.Load(Snapshot(Pair()));b.Load(Snapshot(Pair()));
            for(int i=0;i<60;i++)a.Advance(600,10000,0);for(int i=0;i<30;i++)b.Advance(1200,10000,0);
            Require(a.Time==b.Time && (a.Bodies[1].Position-b.Bodies[1].Position).Length/Astronomy.AU<1e-8,"FPS dependent time/trajectory");
        });
        Check("Accumulator produces identical trajectories at 30 and 60 FPS",()=> {
            var a=new SimulationEngine();var b=new SimulationEngine();a.Load(Snapshot(Pair()));b.Load(Snapshot(Pair()));
            var ca=new TimeController();var cb=new TimeController();
            for(int i=0;i<60;i++)ca.Tick(a,1.0/60,Astronomy.Day,false,1000,0);
            for(int i=0;i<30;i++)cb.Tick(b,1.0/30,Astronomy.Day,false,1000,0);
            Require(a.Steps==b.Steps && a.Time==b.Time && (a.Bodies[1].Position-b.Bodies[1].Position).Length==0,"FPS changes integration boundaries");
        });
        Check("Budget backlog is retained and pause cancels pending time",()=> {
            var engine=new SimulationEngine();engine.Load(Snapshot(Pair()));var clock=new TimeController();
            double done=clock.Tick(engine,1,Astronomy.Day,false,2,0);
            Require(clock.BudgetLimited && Relative(done+clock.PendingSeconds,Astronomy.Day)<1e-14,"Dropped budget debt");
            double drain=clock.Tick(engine,0,Astronomy.Day,false,1000,0);
            Require(Relative(engine.Time,Astronomy.Day)<1e-14 && drain>0,"Cannot catch up");
            clock.Tick(engine,1,Astronomy.Day,false,1,0);double before=engine.Time;clock.Tick(engine,1,Astronomy.Day,true,1000,0);
            Require(clock.PendingSeconds==0 && engine.Time==before,"Pause advances queued time");
        });
        Check("Invalid load does not mutate the live universe",()=> {
            var engine=new SimulationEngine();engine.Load(Snapshot(Pair()));var bad=Snapshot(Pair());bad.bodies[0].mass=double.NaN;
            try { engine.Load(bad);throw new Exception("Accepted NaN"); } catch(ArgumentException) { }
            Require(engine.Bodies.Count==2 && engine.Bodies[0].Mass==Astronomy.SolarMass,"Partial mutation");
        });
        var catalog=JsonSerializer.Deserialize<PresetCatalog>(File.ReadAllText(Path.Combine(root,"Assets/StreamingAssets/GodotPresets.json")),json);
        Check("All nine Godot presets retained, including compact metadata",()=> {
            Require(catalog.migration_schema==1 && catalog.entries.Length==9,"Missing presets");
            foreach(var e in catalog.entries)e.snapshot.ValidatedBodies();
            Require(catalog.entries.Single(e=>e.id=="solar").snapshot.bodies.Length==10,"Missing planet/Moon");
            Require(catalog.entries.Single(e=>e.id=="neutronhole").snapshot.bodies.Any(b=>b.kind=="pulsar" && Relative(b.mass,1.4*Astronomy.SolarMass)<1e-15 && b.radius==12000),"Lost neutron data");
        });
        using var golden=JsonDocument.Parse(File.ReadAllText(Path.Combine(root,"Assets/StreamingAssets/GodotGoldenSteps.json")));
        Check("Godot JSON migration retains every original double bit",()=> {
            var names=new Dictionary<string,string>{{"mass","Mass"},{"radius","Radius"},{"temperature","Temperature"},{"rotation_period","RotationPeriod"},
                {"axial_tilt","AxialTilt"},{"atmosphere","Atmosphere"},{"seed","Seed"},{"strength","Strength"},{"spin","Spin"},{"accreted_mass","AccretedMass"},
                {"magnetic_axis","MagneticAxis"},{"position","Position"},{"velocity","Velocity"}};
            foreach(var c in golden.RootElement.GetProperty("cases").EnumerateArray()) {
                string id=c.GetProperty("id").GetString();var preset=catalog.entries.Single(e=>e.id==id);
                foreach(var record in c.GetProperty("initial_bits").EnumerateArray()) {
                    var body=preset.snapshot.ValidatedBodies().Single(b=>b.Id==record.GetProperty("id").GetString());
                    foreach(var field in record.GetProperty("fields").EnumerateObject()) {
                        object value=typeof(CelestialBody).GetField(names[field.Name]).GetValue(body);
                        if(value is double number)Require(Convert.ToHexString(BitConverter.GetBytes(number)).ToLowerInvariant()==field.Value.GetString(),"Lost double bits: "+id+"/"+body.Id+"/"+field.Name);
                        else {
                            var vector=((Double3)value).ToArray();int index=0;
                            foreach(var expected in field.Value.EnumerateArray())Require(Convert.ToHexString(BitConverter.GetBytes(vector[index++])).ToLowerInvariant()==expected.GetString(),"Lost vector bits");
                        }
                    }
                }
            }
        });
        foreach(var c in golden.RootElement.GetProperty("cases").EnumerateArray())
        {
            string id=c.GetProperty("id").GetString();
            Check("Original Godot Newton oracle: "+id,()=> {
                var bodies=catalog.entries.Single(e=>e.id==id).snapshot.ValidatedBodies();
                new NBodyGravitySolver().Step(bodies,c.GetProperty("dt").GetDouble());
                var expected=JsonSerializer.Deserialize<LegacyBody[]>(c.GetProperty("bodies").GetRawText(),json);
                for(int i=0;i<bodies.Count;i++) {
                    var ep=Double3.FromArray(expected[i].position);var ev=Double3.FromArray(expected[i].velocity);
                    Require((bodies[i].Position-ep).Length/Math.Max(1,ep.Length)<1e-14 &&
                        (bodies[i].Velocity-ev).Length/Math.Max(1,ev.Length)<1e-14,"Port changed Newton result: "+bodies[i].Id);
                }
            });
        }
        Check("Solar System evolves all bodies with real mutual gravity",()=> {
            var engine=new SimulationEngine();engine.Load(catalog.entries.Single(e=>e.id=="solar").snapshot);
            double actual=engine.Advance(Astronomy.Day*10,100000,0);
            Require(actual==Astronomy.Day*10 && engine.Bodies.Count==10 && Math.Abs(engine.EnergyDrift)<1e-3,"Solar dynamics");
        });
        Console.WriteLine("TOTAL "+passed+" core checks passed");
    }
    public static int Main(string[] args)
    {
        try { Run(args.Length>0?args[0]:Directory.GetCurrentDirectory());return 0; }
        catch(Exception e) { Console.Error.WriteLine(e);return 1; }
    }
}
