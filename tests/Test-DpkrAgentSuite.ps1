[CmdletBinding()]
param(
  [string]$SuiteRoot=(Split-Path $PSScriptRoot -Parent),
  [string]$FrontierLoopSource,
  [string]$NativeUiSource
)
$ErrorActionPreference='Stop'
$SuiteRoot=[IO.Path]::GetFullPath($SuiteRoot)
$siblingRoot=Split-Path $SuiteRoot -Parent
if(-not$FrontierLoopSource){$FrontierLoopSource=Join-Path $siblingRoot 'frontier-loop'}
if(-not$NativeUiSource){$NativeUiSource=Join-Path $siblingRoot 'native-ui-governance'}
$root=Join-Path ([IO.Path]::GetTempPath()) ('dpkr-suite-test-'+[guid]::NewGuid().ToString('N'))
$tests=@()
try{
  New-Item -ItemType Directory -Force -Path $root|Out-Null
  & (Join-Path $SuiteRoot 'scripts\Install-DpkrAgentSuite.ps1') -SuiteRoot $SuiteRoot -UserHome $root -FrontierLoopSource $FrontierLoopSource -NativeUiSource $NativeUiSource | Out-Null
  if($LASTEXITCODE-ne0){throw 'clean-install failed'};$tests+='clean-install'
  & (Join-Path $SuiteRoot 'scripts\Verify-DpkrAgentSuite.ps1') -SuiteRoot $SuiteRoot -UserHome $root -FrontierLoopSource $FrontierLoopSource -NativeUiSource $NativeUiSource | Out-Null
  if($LASTEXITCODE-ne0){throw 'verify failed'};$tests+='verify-both-runtimes'
  $dirs=@(Get-ChildItem -LiteralPath (Join-Path $root '.agents\skills') -Directory)
  if($dirs.Count-ne27-or@($dirs|Where-Object {($_.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0}).Count){throw 'materialized Skill topology failed'};$tests+='27-materialized-skills'
  $market=Get-Content -LiteralPath (Join-Path $root '.agents\plugins\marketplace.json') -Raw|ConvertFrom-Json
  if(@($market.plugins|Where-Object {$_.name -in @('frontier-loop','native-ui-governance')}).Count-ne2){throw 'marketplace registration failed'};$tests+='codex-marketplace'

  # Idempotence.
  & (Join-Path $SuiteRoot 'scripts\Install-DpkrAgentSuite.ps1') -SuiteRoot $SuiteRoot -UserHome $root -FrontierLoopSource $FrontierLoopSource -NativeUiSource $NativeUiSource | Out-Null
  if($LASTEXITCODE-ne0){throw 'idempotent install failed'};$tests+='idempotent'

  # Existing foreign AGENTS must fail closed without explicit replacement.
  $other=Join-Path ([IO.Path]::GetTempPath()) ('dpkr-suite-agents-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path (Join-Path $other '.codex')|Out-Null
  Set-Content -LiteralPath (Join-Path $other '.codex\AGENTS.md') -Value '# foreign instructions' -Encoding utf8NoBOM
  $failed=$false
  try{& (Join-Path $SuiteRoot 'scripts\Install-DpkrAgentSuite.ps1') -SuiteRoot $SuiteRoot -UserHome $other -FrontierLoopSource $FrontierLoopSource -NativeUiSource $NativeUiSource | Out-Null}catch{$failed=$true}
  if(-not$failed){throw 'foreign AGENTS was not rejected'};$tests+='foreign-agents-fail-closed'
  & (Join-Path $SuiteRoot 'scripts\Install-DpkrAgentSuite.ps1') -SuiteRoot $SuiteRoot -UserHome $other -FrontierLoopSource $FrontierLoopSource -NativeUiSource $NativeUiSource -ReplaceGlobalAgents | Out-Null
  if($LASTEXITCODE-ne0-or-not(Get-ChildItem -LiteralPath (Join-Path $other '.codex') -Filter 'AGENTS.md.backup-*' -File)){throw 'AGENTS replacement backup failed'};$tests+='explicit-agents-replace-with-backup'
  Remove-Item -LiteralPath $other -Recurse -Force

  [ordered]@{success=$true;tests=$tests;count=$tests.Count}|ConvertTo-Json -Compress
  exit 0
}finally{
  if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
