param(
    [Parameter(Mandatory=$true)][string]$Unity,
    [switch]$SmokeTest,
    [ValidateRange(5,60)][int]$SmokeTimeoutSeconds=45
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$unityExecutable = (Resolve-Path -LiteralPath $Unity).Path
if (Test-Path -LiteralPath (Join-Path $project 'Temp/UnityLockfile')) {
    throw 'Close this project in Unity before the batch build. Temp/UnityLockfile exists.'
}
if ($env:OS -ne 'Windows_NT') {
    throw 'Run this PowerShell entry point on Windows. Linux cloud can invoke Cosmic.Editor.WindowsBuild.Build directly with the installed Windows Mono module.'
}
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($unityExecutable).ProductVersion
if ($version -notmatch '^6000\.6\.5f1(?:\D|$)') {
    throw "Use the Unity 6000.6.5f1 Editor executable. Selected version: $version"
}
$results = Join-Path $project 'TestResults'
New-Item -ItemType Directory -Force -Path $results | Out-Null
$buildLog = Join-Path $results 'build-windows.log'
$buildStartedUtc = [DateTime]::UtcNow
# Select Windows before compilation, so UNITY_STANDALONE_WIN and platform packages
# are compiled for the player that BuildPipeline.BuildPlayer will actually export.
& $unityExecutable -batchmode -nographics -quit -buildTarget Win64 -projectPath $project -executeMethod Cosmic.Editor.WindowsBuild.Build -logFile $buildLog
if ($LASTEXITCODE -ne 0) {
    throw "Unity export failed (exit $LASTEXITCODE). Check $buildLog. No new complete release was published. Verify Editor activation and Windows Build Support (Mono)."
}

$output = Join-Path $project 'CosmicSandboxBuild'
$manifestPath = Join-Path $output 'build-manifest.json'
$archive = Join-Path $project 'Releases/CosmicSandboxBuild.zip'
if (!(Test-Path -LiteralPath $manifestPath) -or !(Test-Path -LiteralPath $archive)) {
    throw 'Unity returned success without the required verified build manifest/archive.'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.unityVersion -ne '6000.6.5f1' -or $manifest.buildTarget -ne 'StandaloneWindows64' -or
    $manifest.backend -ne 'Mono' -or $manifest.graphicsApi -ne 'Direct3D11' -or $manifest.buildErrors -ne 0) {
    throw 'Build manifest does not match the requested Unity / x64 Mono / DirectX 11 configuration.'
}
if ([DateTime]::Parse($manifest.builtUtc, [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() -lt $buildStartedUtc.AddSeconds(-2)) {
    throw 'The output manifest belongs to an older export; the current invocation did not publish a fresh build.'
}
foreach ($entry in $manifest.files) {
    if ($entry.path -match '(^|[\\/])\.\.([\\/]|$)' -or [IO.Path]::IsPathRooted($entry.path)) {
        throw "Unsafe build manifest path: $($entry.path)"
    }
    $file = Join-Path $output $entry.path
    if (!(Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -ne $entry.bytes -or
        (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Build file missing, truncated, or changed: $($entry.path)"
    }
}
Write-Host "Verified Windows build: $output"
Write-Host "Complete distributable: $archive"

if ($SmokeTest) {
    $playerLog = Join-Path $results 'windows-player-smoke.log'
    Remove-Item -LiteralPath $playerLog -ErrorAction SilentlyContinue
    $player = Start-Process -FilePath (Join-Path $output 'CosmicSandbox.exe') -WorkingDirectory $output -PassThru -ArgumentList (
        '-force-d3d11 -screen-fullscreen 0 -screen-width 1920 -screen-height 1080 -logFile "{0}"' -f $playerLog
    )
    $started = $false
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds($SmokeTimeoutSeconds)
        while ([DateTime]::UtcNow -lt $deadline) {
            $player.Refresh()
            if ($player.HasExited) { throw "Windows player exited before startup validation. Check $playerLog" }
            if (Test-Path -LiteralPath $playerLog) {
                $logText = Get-Content -LiteralPath $playerLog -Raw
                if ($logText -match 'Exception:|Shader error in|Failed to create graphics|D3D11: failed|error CS\d+') {
                    throw "Windows player reported a runtime/graphics error. Check $playerLog"
                }
                if ($logText -match 'CosmicSandbox startup ready: solar') { $started=$true; break }
            }
            Start-Sleep -Milliseconds 250
        }
        if (!$started) { throw "No confirmed CosmicSandbox startup within $SmokeTimeoutSeconds seconds. Check $playerLog" }
        Write-Host "Windows launch smoke passed (real DX11 player and solar bootstrap): $playerLog"
        Write-Host 'Check the visible menu, planets, camera and materials before marking visual QA complete.'
    }
    finally {
        $player.Refresh()
        if (!$player.HasExited) { Stop-Process -Id $player.Id }
    }
}
