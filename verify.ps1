[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'scripts\Verify-DpkrAgentSuite.ps1') -SuiteRoot $PSScriptRoot
exit $LASTEXITCODE
