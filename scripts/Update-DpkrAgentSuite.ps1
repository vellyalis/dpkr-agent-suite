[CmdletBinding()]
param(
  [string]$SuiteRoot=(Split-Path $PSScriptRoot -Parent),
  [string]$UserHome=$env:USERPROFILE,
  [switch]$ReplaceGlobalAgents
)
$ErrorActionPreference='Stop'
$SuiteRoot=[IO.Path]::GetFullPath($SuiteRoot)
if(Test-Path -LiteralPath (Join-Path $SuiteRoot '.git')){
  $dirty=& git -C $SuiteRoot status --porcelain
  if($LASTEXITCODE-ne0){throw 'cannot inspect suite Git state'}
  if(@($dirty).Count){throw 'refusing to update dirty dpkr-agent-suite checkout'}
  & git -C $SuiteRoot pull --ff-only
  if($LASTEXITCODE-ne0){throw 'suite fast-forward update failed'}
}
& (Join-Path $SuiteRoot 'scripts\Install-DpkrAgentSuite.ps1') -SuiteRoot $SuiteRoot -UserHome $UserHome -ReplaceGlobalAgents:$ReplaceGlobalAgents
exit $LASTEXITCODE
