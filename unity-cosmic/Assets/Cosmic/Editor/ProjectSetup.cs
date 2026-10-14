namespace Cosmic.Editor
{
    // Compatibility entry points; one builder owns project configuration.
    public static class ProjectSetup
    {
        public static void Prepare() => ProjectBuilder.RepairAndBuild();
        public static void OpenSandbox() => ProjectBuilder.OpenSolarSystem();
    }
}
