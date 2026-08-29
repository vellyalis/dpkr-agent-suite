[CmdletBinding()]
param(
  [string]$UserHome=$env:USERPROFILE,
  [string]$FrontierLoopSource,
  [string]$NativeUiSource
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'scripts\Verify-DpkrAgentSuite.ps1') `
  -SuiteRoot $PSScriptRoot `
  -UserHome $UserHome `
  -FrontierLoopSource $FrontierLoopSource `
  -NativeUiSource $NativeUiSource
exit $LASTEXITCODE
