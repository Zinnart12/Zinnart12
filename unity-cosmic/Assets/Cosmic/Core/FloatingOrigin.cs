namespace Cosmic.Core
{
    public sealed class FloatingOrigin
    {
        public Double3 Origin;
        public double MetresToScene=32/Astronomy.AU;
        public Double3 Relative(Double3 si) => (si-Origin)*MetresToScene;
        public Double3 Absolute(Double3 scene) => Origin+scene/MetresToScene;
    }
}
