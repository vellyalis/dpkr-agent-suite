[CmdletBinding()]
param(
  [switch]$ReplaceGlobalAgents,
  [switch]$WhatIf
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'scripts\Install-DpkrAgentSuite.ps1') `
  -SuiteRoot $PSScriptRoot `
  -ReplaceGlobalAgents:$ReplaceGlobalAgents `
  -WhatIf:$WhatIf
exit $LASTEXITCODE
