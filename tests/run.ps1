# Runs the headless test suite.
#
#   tests\run.ps1                 run everything
#   tests\run.ps1 --only=rhythm   run the tests whose path or name contains "rhythm"
#
# Set $env:GODOT to the editor binary if `godot` isn't on your PATH.

$projectDir = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT) { $env:GODOT } else { 'godot' }

if (-not (Get-Command $godot -ErrorAction SilentlyContinue)) {
	Write-Error "Could not find Godot at '$godot'. Set `$env:GODOT to the editor binary."
	exit 2
}

# Registers new class_name scripts and imports new assets. Its own exit
# status is not meaningful; the test run below is what decides the result.
& $godot --headless --path $projectDir --import *> $null

$userArgs = @()
if ($args.Count -gt 0) {
	$userArgs = @('--') + $args
}

# Godot is a GUI-subsystem program on Windows, so PowerShell would not wait
# for it or see its exit code unless its output is piped.
& $godot --headless --path $projectDir res://tests/test_runner.tscn @userArgs | Out-Host
exit $LASTEXITCODE
