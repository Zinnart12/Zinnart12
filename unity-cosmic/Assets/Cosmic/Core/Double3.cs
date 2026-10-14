using System;

namespace Cosmic.Core
{
    // Engine-independent SI coordinates. Never integrate Unity Vector3 values.
    [Serializable]
    public struct Double3
    {
        public double X, Y, Z;
        public Double3(double x, double y, double z) { X = x; Y = y; Z = z; }
        public static Double3 Zero => new Double3();
        public double LengthSquared => X * X + Y * Y + Z * Z;
        public double Length => Math.Sqrt(LengthSquared);
        public bool IsFinite => Numeric.Finite(X) && Numeric.Finite(Y) && Numeric.Finite(Z);
        public Double3 Normalized => Length > 0 ? this / Length : Zero;
        public static double Dot(Double3 a, Double3 b) => a.X * b.X + a.Y * b.Y + a.Z * b.Z;
        public static Double3 Cross(Double3 a, Double3 b) => new Double3(a.Y*b.Z-a.Z*b.Y, a.Z*b.X-a.X*b.Z, a.X*b.Y-a.Y*b.X);
        public static Double3 operator +(Double3 a, Double3 b) => new Double3(a.X+b.X, a.Y+b.Y, a.Z+b.Z);
        public static Double3 operator -(Double3 a, Double3 b) => new Double3(a.X-b.X, a.Y-b.Y, a.Z-b.Z);
        public static Double3 operator -(Double3 a) => a * -1;
        public static Double3 operator *(Double3 a, double b) => new Double3(a.X*b, a.Y*b, a.Z*b);
        public static Double3 operator /(Double3 a, double b) => a * (1 / b);
        public double[] ToArray() => new[] { X, Y, Z };
        public static Double3 FromArray(double[] a)
        {
            if (a == null || a.Length != 3) throw new ArgumentException("Expected three SI components.");
            return new Double3(a[0], a[1], a[2]);
        }
    }

    public static class Numeric
    {
        public static bool Finite(double x) => !double.IsNaN(x) && !double.IsInfinity(x);
        public static double Clamp(double x, double min, double max) => Math.Max(min, Math.Min(max, x));
    }

    public static class Astronomy
    {
        public const double G = 6.67430e-11, AU = 149597870700, Day = 86400,
            Year = 31557600, SolarMass = 1.98847e30, EarthMass = 5.9722e24,
            C = 299792458, Sigma = 5.670374419e-8;
        public static double SchwarzschildRadius(double mass) => 2 * G * mass / (C * C);
    }
}
