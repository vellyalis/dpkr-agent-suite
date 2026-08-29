[CmdletBinding()]
param(
  [string]$UserHome=$env:USERPROFILE,
  [string]$FrontierLoopSource,
  [string]$NativeUiSource,
  [switch]$SkipCodexCliRegistration
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'scripts\Verify-DpkrAgentSuite.ps1') `
  -SuiteRoot $PSScriptRoot `
  -UserHome $UserHome `
  -FrontierLoopSource $FrontierLoopSource `
  -NativeUiSource $NativeUiSource `
  -SkipCodexCliRegistration:$SkipCodexCliRegistration
exit $LASTEXITCODE
