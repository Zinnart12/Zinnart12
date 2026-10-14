param([Parameter(Mandatory=$true)][string]$Unity)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
New-Item -ItemType Directory -Force (Join-Path $project 'TestResults') | Out-Null
& $Unity -batchmode -nographics -quit -projectPath $project -executeMethod Cosmic.Editor.ProjectSetup.Prepare -logFile "$project/TestResults/import.log"
if ($LASTEXITCODE -ne 0) { throw 'Unity import/setup failed. Check import.log and the Unity Hub license.' }
# No -nographics: tests include framebuffer assertions and native URP shader compilation.
& $Unity -batchmode -projectPath $project -runTests -testPlatform PlayMode -testResults "$project/TestResults/playmode.xml" -logFile "$project/TestResults/playmode.log"
if ($LASTEXITCODE -ne 0) { throw 'Unity PlayMode tests failed. Check playmode.xml and playmode.log.' }
