[CmdletBinding()]
param(
  [switch]$ReplaceGlobalAgents
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'scripts\Update-DpkrAgentSuite.ps1') `
  -SuiteRoot $PSScriptRoot `
  -ReplaceGlobalAgents:$ReplaceGlobalAgents
exit $LASTEXITCODE
