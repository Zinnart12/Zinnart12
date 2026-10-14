param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
Push-Location (Join-Path $PSScriptRoot "..")
try {
    & $Godot --headless --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
    & $Godot --headless --script res://tests/PhysicsTests.gd
    if ($LASTEXITCODE -ne 0) { throw "Physics tests failed" }
    & $Godot --headless --script res://tests/SceneTests.gd
    if ($LASTEXITCODE -ne 0) { throw "Scene tests failed" }
    & $Godot --headless --script res://tests/CompactPhysicsTests.gd
    if ($LASTEXITCODE -ne 0) { throw "Compact physics tests failed" }
    & $Godot --headless --script res://tests/CompactSceneTests.gd
    if ($LASTEXITCODE -ne 0) { throw "Compact scene tests failed" }
} finally {
    Pop-Location
}
