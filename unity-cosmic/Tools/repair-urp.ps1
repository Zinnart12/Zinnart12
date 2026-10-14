param([switch]$ClearShaderCache)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (Test-Path (Join-Path $project 'Temp/UnityLockfile')) {
    throw 'Close Unity Editor before repairing packages/cache. Assets are preserved.'
}
$manifestPath = Join-Path $project 'Packages/manifest.json'
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$backup = Join-Path $project ('TestResults/PackageRepair/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $backup | Out-Null
Copy-Item $manifestPath (Join-Path $backup 'manifest.json')
$lockPath = Join-Path $project 'Packages/packages-lock.json'
if (Test-Path $lockPath) { Copy-Item $lockPath (Join-Path $backup 'packages-lock.json') }
$versions = @{
    'com.unity.render-pipelines.universal' = '17.6.0'
    'com.unity.render-pipelines.core' = '17.6.0'
    'com.unity.shadergraph' = '17.6.0'
    'com.unity.ugui' = '2.6.0'
    'com.unity.test-framework' = '1.8.0'
    'com.unity.modules.screencapture' = '1.0.0'
}
foreach ($name in $versions.Keys) {
    $manifest.dependencies | Add-Member -NotePropertyName $name -NotePropertyValue $versions[$name] -Force
}
$json = ($manifest | ConvertTo-Json -Depth 100) + "`n"
[System.IO.File]::WriteAllText($manifestPath, $json, [System.Text.UTF8Encoding]::new($false))
if ($ClearShaderCache) {
    foreach ($relative in @('Library/ShaderCache','Library/ScriptAssemblies','Library/Bee')) {
        $cachePath = Join-Path $project $relative
        if (Test-Path $cachePath) { Remove-Item -Recurse -Force $cachePath }
    }
    $packageCache = Join-Path $project 'Library/PackageCache'
    if (Test-Path $packageCache) {
        Get-ChildItem $packageCache -Directory |
            Where-Object { $_.Name -match '^com\.unity\.(render-pipelines\.(universal|core)|shadergraph|ugui|test-framework)@' } |
            Remove-Item -Recurse -Force
    }
}
Write-Output 'URP/Core/ShaderGraph pinned to 17.6.0; other package declarations preserved.'
Write-Output 'Open with Unity 6000.6.5f1, resolve the first C# error if any, then Cosmic > Repair URP and Solar System.'
