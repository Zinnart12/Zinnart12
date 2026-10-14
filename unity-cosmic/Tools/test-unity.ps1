param([Parameter(Mandatory=$true)][string]$Unity)
$ErrorActionPreference = 'Stop'

function Assert-NativeTestReport {
    param([string]$Path, [string]$Platform, [string[]]$ExpectedTests)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Platform did not produce a fresh NUnit XML report: $Path"
    }
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    $report = New-Object System.Xml.XmlDocument
    $report.XmlResolver = $null
    try { $report.Load($reader) } finally { $reader.Dispose() }
    $run = $report.SelectSingleNode('/test-run')
    if ($null -eq $run) { throw "$Platform result is not a NUnit test-run report: $Path" }
    $total = 0
    if (-not [int]::TryParse($run.GetAttribute('total'), [ref]$total) -or $total -lt $ExpectedTests.Count) {
        throw "$Platform ran zero or too few tests; expected at least $($ExpectedTests.Count): $Path"
    }
    if ($run.GetAttribute('result') -ne 'Passed') {
        throw "$Platform NUnit run did not pass: $Path"
    }
    $cases = @($report.SelectNodes('//test-case'))
    if ($cases.Count -eq 0) { throw "$Platform report has no executed test cases: $Path" }
    foreach ($case in $cases) {
        if ($case.GetAttribute('result') -ne 'Passed') {
            throw "$Platform test was failed, skipped, or inconclusive: $($case.GetAttribute('fullname')); see $Path"
        }
    }
    foreach ($name in $ExpectedTests) {
        $matches = @($cases | Where-Object { $_.GetAttribute('fullname') -eq $name })
        if ($matches.Count -ne 1 -or $matches[0].GetAttribute('result') -ne 'Passed') {
            throw "$Platform required test did not execute and pass exactly once: $name; see $Path"
        }
    }
    Write-Host "PASS $Platform native NUnit report: $($ExpectedTests.Count) required named tests executed and passed."
}

$editTests = @(
    'Cosmic.Tests.ProjectRepairTests.EveryQualityUsesTheSameValidURPAsset',
    'Cosmic.Tests.ProjectRepairTests.OfficialLitInspectorCanBeInstantiatedAndPBRPropertiesArePreserved',
    'Cosmic.Tests.ProjectRepairTests.SolarSceneContainsAllBodiesRingsAndWiredCameraBeforePlay'
)
$playTests = @(
    'Cosmic.Tests.PhaseOneSceneTests.SolarSystemHasRealBodiesAndCompiledSurfaceShaders',
    'Cosmic.Tests.PhaseOneSceneTests.CameraFocusDoesNotChangeSIStateAndStepsMovePlanets',
    'Cosmic.Tests.PhaseOneSceneTests.CameraKeepsEarthResolvableWhenZoomingToOuterSystemDistances',
    'Cosmic.Tests.PhaseOneSceneTests.LegacyJsonParserRetainsDoubleBits',
    'Cosmic.Tests.PhaseOneSceneTests.EarthAndMoonAndBinaryPresetsHaveDistinctDynamics',
    'Cosmic.Tests.PhaseOneSceneTests.HDRSceneHasVisibleSunAndDetailedPlanetPixels'
)
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
New-Item -ItemType Directory -Force (Join-Path $project 'TestResults') | Out-Null
& $Unity -batchmode -nographics -quit -projectPath $project -executeMethod Cosmic.Editor.ProjectSetup.Prepare -logFile "$project/TestResults/import.log"
if ($LASTEXITCODE -ne 0) { throw 'Unity import/setup failed. Check import.log and the Unity Hub license.' }
$editReport = Join-Path $project 'TestResults/editmode.xml'
if (Test-Path -LiteralPath $editReport) { Remove-Item -LiteralPath $editReport -Force }
& $Unity -batchmode -nographics -projectPath $project -runTests -testPlatform EditMode -testResults "$project/TestResults/editmode.xml" -logFile "$project/TestResults/editmode.log"
if ($LASTEXITCODE -ne 0) { throw 'Native Editor/material/scene repair tests failed. Check editmode.xml and editmode.log.' }
Assert-NativeTestReport -Path $editReport -Platform 'EditMode' -ExpectedTests $editTests
$playReport = Join-Path $project 'TestResults/playmode.xml'
if (Test-Path -LiteralPath $playReport) { Remove-Item -LiteralPath $playReport -Force }
# Launch a visible, graphics-enabled Editor and keep its Game View visible.
# No -batchmode: Test Framework rejects WaitForEndOfFrame in Editor batchmode.
# No -nographics: HDR tests read actual framebuffer pixels and compile native URP shaders.
& $Unity -projectPath $project -runTests -testPlatform PlayMode -testResults "$project/TestResults/playmode.xml" -logFile "$project/TestResults/playmode.log"
if ($LASTEXITCODE -ne 0) { throw 'Unity PlayMode tests failed. Check playmode.xml and playmode.log.' }
Assert-NativeTestReport -Path $playReport -Platform 'PlayMode' -ExpectedTests $playTests
