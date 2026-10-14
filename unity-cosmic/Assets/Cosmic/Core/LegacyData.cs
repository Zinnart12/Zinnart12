using System;
using System.Collections.Generic;

namespace Cosmic.Core
{
    // Field names match snapshot schema 1, including compact-object metadata.
    [Serializable]
    public sealed class LegacyBody
    {
        public string id, name, kind, surface, composition, color;
        public double mass, radius, temperature, rotation_period, axial_tilt, atmosphere, seed,
            strength = 1e8, spin, accreted_mass, magnetic_axis = 30;
        public double[] position, velocity;
        public bool disk_enabled = true;
        public int fragmentation_depth;
        public string mass_bits,radius_bits,temperature_bits,rotation_period_bits,axial_tilt_bits,atmosphere_bits,
            seed_bits,strength_bits,spin_bits,accreted_mass_bits,magnetic_axis_bits;
        public string[] position_bits,velocity_bits;
        public CelestialBody ToBody()
        {
            var b = new CelestialBody { Id=id, Name=name, Kind=kind, Surface=surface, Composition=composition, Color=color,
                Mass=DoubleEncoding.Read(mass,mass_bits), Radius=DoubleEncoding.Read(radius,radius_bits),
                Temperature=DoubleEncoding.Read(temperature,temperature_bits), RotationPeriod=DoubleEncoding.Read(rotation_period,rotation_period_bits),
                AxialTilt=DoubleEncoding.Read(axial_tilt,axial_tilt_bits), Atmosphere=DoubleEncoding.Read(atmosphere,atmosphere_bits),
                Seed=DoubleEncoding.Read(seed,seed_bits), Strength=DoubleEncoding.Read(strength,strength_bits),
                Spin=DoubleEncoding.Read(spin,spin_bits), AccretedMass=DoubleEncoding.Read(accreted_mass,accreted_mass_bits),
                MagneticAxis=DoubleEncoding.Read(magnetic_axis,magnetic_axis_bits), DiskEnabled=disk_enabled, FragmentationDepth=fragmentation_depth,
                Position=DoubleEncoding.Read(position,position_bits), Velocity=DoubleEncoding.Read(velocity,velocity_bits) };
            b.Validate(); return b;
        }
    }
    [Serializable]
    public sealed class LegacySnapshot
    {
        public int schema_version;
        public string name;
        public double time, steps;
        public string time_bits,steps_bits;
        public double TimeSeconds => DoubleEncoding.Read(time,time_bits);
        public double StepCount => DoubleEncoding.Read(steps,steps_bits);
        public LegacyBody[] bodies;
        public List<CelestialBody> ValidatedBodies()
        {
            if (schema_version != 1 || bodies == null || bodies.Length > 128 || name == null || name.Length > 100)
                throw new ArgumentException("Invalid snapshot schema/body count/name.");
            CelestialBody.Check(TimeSeconds, 0, 1e15, "simulation time");
            CelestialBody.Check(StepCount, 0, 9e15, "step counter");
            if (StepCount != Math.Floor(StepCount)) throw new ArgumentException("Step counter must be an integer.");
            var ids = new HashSet<string>(); var result = new List<CelestialBody>();
            foreach (var record in bodies)
            {
                if (record == null) throw new ArgumentException("Null body.");
                var b = record.ToBody();
                if (!ids.Add(b.Id)) throw new ArgumentException("Duplicate body ID: " + b.Id);
                result.Add(b);
            }
            return result;
        }
    }
    [Serializable]
    public sealed class PresetEntry
    {
        public string id, title;
        public double seconds_per_second;
        public bool phase1;
        public LegacySnapshot snapshot;
    }
    [Serializable]
    public sealed class PresetCatalog { public int migration_schema; public PresetEntry[] entries; }
}
