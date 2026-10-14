using System;

namespace Cosmic.Core
{
    [Serializable]
    public sealed class CelestialBody
    {
        public string Id, Name, Kind, Surface, Composition, Color;
        public double Mass, Radius, Temperature, RotationPeriod, AxialTilt, Atmosphere,
            Seed, Strength, Spin, AccretedMass, MagneticAxis;
        public Double3 Position, Velocity;
        public bool DiskEnabled;
        public int FragmentationDepth;

        public bool IsLuminous => Kind == "star" || Kind == "white_dwarf" || Kind == "neutron_star" || Kind == "pulsar";
        public double Density => Mass / (4 * Math.PI * Radius * Radius * Radius / 3);
        public double SurfaceGravity => Astronomy.G * Mass / (Radius * Radius);
        public double EscapeVelocity => Math.Sqrt(2 * Astronomy.G * Mass / Radius);
        public double Luminosity => IsLuminous ? 4 * Math.PI * Radius * Radius * Astronomy.Sigma * Math.Pow(Temperature, 4) : 0;
        public CelestialBody Copy() => (CelestialBody)MemberwiseClone();
        public void Validate()
        {
            if (string.IsNullOrEmpty(Id) || Id.Length > 100 || string.IsNullOrEmpty(Name) || Name.Length > 100)
                throw new ArgumentException("Missing or oversized body ID/name.");
            if (!Allowed(Kind, "star", "planet", "moon", "asteroid", "comet", "black_hole", "neutron_star", "pulsar", "white_dwarf", "debris") ||
                !Allowed(Surface, "earth", "rocky", "gas", "ice", "lava", "ocean"))
                throw new ArgumentException("Unknown body kind/surface.");
            Check(Mass, 1e-6, 1e41, "mass"); Check(Radius, .001, 1e18, "radius");
            Check(Temperature, 0, 1e9, "temperature"); Check(Atmosphere, 0, 1000, "atmosphere");
            Check(RotationPeriod, -1e41, 1e41, "rotation period"); Check(AxialTilt, -1e41, 1e41, "axial tilt");
            Check(Seed, -1e41, 1e41, "seed"); Check(Strength, 0, 1e35, "strength");
            Check(Spin, -.998, .998, "spin"); Check(AccretedMass, 0, 1e41, "accreted mass");
            Check(MagneticAxis, 0, 180, "magnetic axis");
            if (!Position.IsFinite || Math.Abs(Position.X)>1e22 || Math.Abs(Position.Y)>1e22 || Math.Abs(Position.Z)>1e22 ||
                !Velocity.IsFinite || Math.Abs(Velocity.X)>1e9 || Math.Abs(Velocity.Y)>1e9 || Math.Abs(Velocity.Z)>1e9)
                throw new ArgumentException("Invalid SI position/velocity.");
            if (Composition == null || Composition.Length > 500 || Color == null || (Color.Length != 6 && Color.Length != 8))
                throw new ArgumentException("Invalid composition/color.");
            foreach (char c in Color) if (!Uri.IsHexDigit(c)) throw new ArgumentException("Invalid color.");
            if (FragmentationDepth < 0 || FragmentationDepth > 10) throw new ArgumentException("Invalid fragment generation.");
            if (Kind == "black_hole" && Math.Abs(Radius / Astronomy.SchwarzschildRadius(Mass) - 1) > 1e-8)
                throw new ArgumentException("Black hole radius must match 2GM/c².");
        }
        internal static void Check(double value, double min, double max, string name)
        {
            if (!Numeric.Finite(value) || value < min || value > max) throw new ArgumentException("Invalid " + name);
        }
        static bool Allowed(string value, params string[] options) => Array.IndexOf(options, value) >= 0;
    }
}
