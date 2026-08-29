[CmdletBinding()]
param(
  [string]$UserHome=$env:USERPROFILE,
  [switch]$ReplaceGlobalAgents
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'scripts\Update-DpkrAgentSuite.ps1') `
  -SuiteRoot $PSScriptRoot `
  -UserHome $UserHome `
  -ReplaceGlobalAgents:$ReplaceGlobalAgents
exit $LASTEXITCODE
