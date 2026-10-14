# License-independent script/parser/report checks. This does not run Unity tests.
# All script syntax and APIs are compatible with Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testScript = Join-Path $PSScriptRoot 'test-unity.ps1'
$testAst = $null
foreach ($name in @('test-unity.ps1', 'build-windows.ps1', 'repair-urp.ps1', 'check-powershell.ps1')) {
    $path = Join-Path $PSScriptRoot $name
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0) { throw "PowerShell parser errors in ${name}: $($parseErrors.Message -join '; ')" }
    if ($name -eq 'test-unity.ps1') { $testAst = $ast }
    Write-Host "PASS PowerShell script parser: $name"
}

# Import only the validation function and expected-name arrays from our own script;
# never evaluate its Unity process invocation while testing report guards.
$function = $testAst.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-NativeTestReport' }, $true)
if ($null -eq $function) { throw 'Native NUnit report guard is missing.' }
. ([scriptblock]::Create($function.Extent.Text))
foreach ($name in @('$editTests', '$playTests')) {
    $assignment = $testAst.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq $name }, $true)
    if ($null -eq $assignment) { throw "Expected native test names are missing: $name" }
    . ([scriptblock]::Create($assignment.Extent.Text))
}
if ($editTests.Count -ne 3 -or $playTests.Count -ne 6) { throw 'Expected current 3 EditMode and 6 PlayMode report requirements.' }

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cosmic-report-guards-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
$fixture = Join-Path $fixtureRoot 'fixture.xml'
function Write-ReportFixture {
    param([string[]]$Names, [string]$CaseResult = 'Passed', [string]$RunResult = 'Passed', [int]$Total = -1)
    if ($Total -lt 0) { $Total = $Names.Count }
    $cases = @($Names | ForEach-Object { '<test-case fullname="' + $_ + '" result="' + $CaseResult + '" />' })
    $xml = '<test-run total="' + $Total + '" result="' + $RunResult + '">' + ($cases -join '') + '</test-run>'
    [System.IO.File]::WriteAllText($fixture, $xml)
}
function Assert-ReportRejected {
    param([string]$Label)
    $rejected = $false
    try { Assert-NativeTestReport -Path $fixture -Platform 'fixture' -ExpectedTests $editTests }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Report guard accepted invalid fixture: $Label" }
    Write-Host "PASS report-parser rejection fixture: $Label"
}
try {
    Write-ReportFixture -Names $editTests
    Assert-NativeTestReport -Path $fixture -Platform 'EditMode fixture (not native execution)' -ExpectedTests $editTests
    Write-ReportFixture -Names $playTests
    Assert-NativeTestReport -Path $fixture -Platform 'PlayMode fixture (not native execution)' -ExpectedTests $playTests
    Write-ReportFixture -Names @() -Total 0
    Assert-ReportRejected 'zero tests'
    Write-ReportFixture -Names $editTests -CaseResult 'Skipped'
    Assert-ReportRejected 'skipped required tests'
    Write-ReportFixture -Names $editTests -CaseResult 'Inconclusive'
    Assert-ReportRejected 'inconclusive tests'
    Write-ReportFixture -Names $editTests -CaseResult 'Failed' -RunResult 'Failed'
    Assert-ReportRejected 'failed tests'
    Write-ReportFixture -Names @($editTests[0], $editTests[1], 'Cosmic.Tests.Unrelated')
    Assert-ReportRejected 'missing required test despite correct total'
    Write-ReportFixture -Names @($editTests[0], $editTests[0], $editTests[1], $editTests[2])
    Assert-ReportRejected 'duplicate expected test'
    [System.IO.File]::WriteAllText($fixture, '<test-run')
    Assert-ReportRejected 'malformed XML'
    Remove-Item -LiteralPath $fixture -Force
    Assert-ReportRejected 'missing report'

    # Exercise stale-file removal end to end with an explicit exit-zero command stub.
    # This stub produces no Unity output and cannot simulate a successful native test.
    $probeProject = Join-Path $fixtureRoot 'stale-probe'
    $probeTools = Join-Path $probeProject 'Tools'
    $probeResults = Join-Path $probeProject 'TestResults'
    New-Item -ItemType Directory -Path $probeTools, $probeResults | Out-Null
    Copy-Item -LiteralPath $testScript -Destination (Join-Path $probeTools 'test-unity.ps1')
    Write-ReportFixture -Names $editTests
    $stale = Join-Path $probeResults 'editmode.xml'
    Copy-Item -LiteralPath $fixture -Destination $stale
    if ($env:OS -eq 'Windows_NT') {
        $probe = Join-Path $fixtureRoot 'exit-zero-test-stub.cmd'
        [System.IO.File]::WriteAllText($probe, "@echo off`r`nexit /b 0`r`n")
    } else {
        $probe = Join-Path $fixtureRoot 'exit-zero-test-stub.sh'
        [System.IO.File]::WriteAllText($probe, "#!/bin/sh`nexit 0`n")
        & chmod 755 $probe
        if ($LASTEXITCODE -ne 0) { throw 'Cannot execute the report-guard command stub.' }
    }
    $rejected = $false
    try { & (Join-Path $probeTools 'test-unity.ps1') -Unity $probe }
    catch {
        if ($_.Exception.Message -notmatch 'did not produce a fresh NUnit XML report') { throw }
        $rejected = $true
    }
    if (-not $rejected -or (Test-Path -LiteralPath $stale)) { throw 'Stale report was accepted after exit-zero command produced no result.' }
    Write-Host 'PASS report-parser rejection fixture: stale XML plus exit-zero command'

    $playInvocation = @($testAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.Extent.Text -match '-testPlatform PlayMode' }, $true))
    if ($playInvocation.Count -ne 1 -or $playInvocation[0].Extent.Text -match '-batchmode|-nographics') {
        throw 'Framebuffer PlayMode tests require a visible, graphics-enabled Editor invocation.'
    }
    Write-Host 'PASS PlayMode invocation keeps rendering and WaitForEndOfFrame enabled.'
    Write-Host 'NOTE: fixture checks are not native Unity import, test execution, or a Windows build.'
}
finally { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
