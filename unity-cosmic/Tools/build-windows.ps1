param([Parameter(Mandatory=$true)][string]$Unity)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
New-Item -ItemType Directory -Force (Join-Path $project 'TestResults') | Out-Null
& $Unity -batchmode -nographics -quit -projectPath $project -executeMethod Cosmic.Editor.WindowsBuild.Build -logFile "$project/TestResults/build.log"
if ($LASTEXITCODE -ne 0) { throw 'Build failed. Check build.log, license, and Windows Build Support (Mono).' }
