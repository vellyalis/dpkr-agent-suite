[CmdletBinding()]
param(
  [string]$UserHome=$env:USERPROFILE,
  [string]$FrontierLoopSource,
  [string]$NativeUiSource,
  [switch]$SkipCodexCliRegistration,
  [switch]$ReplaceGlobalAgents,
  [switch]$WhatIf
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'scripts\Install-DpkrAgentSuite.ps1') `
  -SuiteRoot $PSScriptRoot `
  -UserHome $UserHome `
  -FrontierLoopSource $FrontierLoopSource `
  -NativeUiSource $NativeUiSource `
  -SkipCodexCliRegistration:$SkipCodexCliRegistration `
  -ReplaceGlobalAgents:$ReplaceGlobalAgents `
  -WhatIf:$WhatIf
exit $LASTEXITCODE
