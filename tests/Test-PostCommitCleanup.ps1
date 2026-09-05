[CmdletBinding()]
param([string]$SuiteRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$plugins=Split-Path ([IO.Path]::GetFullPath($SuiteRoot)) -Parent
$temp=Join-Path ([IO.Path]::GetTempPath()) ('suite-cleanup-test-'+[guid]::NewGuid().ToString('N'))
$passed=@()
try{
  foreach($component in @(@{name='frontier-loop';installer='Install-FrontierLoop.ps1';count=23},@{name='native-ui-governance';installer='Install-NativeUiGovernance.ps1';count=4})){
    $source=Join-Path $plugins $component.name
    $case=Join-Path $temp $component.name
    $cache=Join-Path $case 'cache';$skills=Join-Path $case 'skills'
    $install=Join-Path $source ('scripts/'+$component.installer)
    $version=[string]((Get-Content -LiteralPath (Join-Path $source '.codex-plugin/plugin.json') -Raw|ConvertFrom-Json).version)
    $first=(& $install -Source $source -DestinationRoot $cache -UserSkillRoot $skills|Out-String|ConvertFrom-Json)
    if(-not$first.success){throw 'Fixture install failed'}
    $old=Join-Path $cache $version
    foreach($dir in @(Get-ChildItem -LiteralPath $skills -Directory)){
      [IO.File]::WriteAllText((Join-Path $dir.FullName 'prior-version.marker'),'old')
      [IO.File]::WriteAllText((Join-Path $old ('skills/'+$dir.Name+'/prior-version.marker')),'old')
    }
    $objectDir=Join-Path $old '.git/objects/aa'
    [IO.Directory]::CreateDirectory($objectDir)|Out-Null
    $object=Join-Path $objectDir 'read-only-fixture'
    [IO.File]::WriteAllText($object,'disposable test object')
    [IO.File]::SetAttributes($object,[IO.FileAttributes]::ReadOnly)
    $result=(& $install -Source $source -DestinationRoot $cache -UserSkillRoot $skills|Out-String|ConvertFrom-Json)
    if(-not$result.success-or@($result.cleanupWarnings).Count-ne1){throw "Cleanup failure was not reported without rollback: $($component.name)"}
    $active=@(Get-ChildItem -LiteralPath $skills -Directory|Where-Object {-not$_.Name.StartsWith('.')})
    if($active.Count-ne$component.count){throw "Verified active skills were lost: $($component.name)"}
    foreach($dir in $active){
      $actual=(Get-FileHash -LiteralPath (Join-Path $dir.FullName 'SKILL.md')).Hash
      $expected=(Get-FileHash -LiteralPath (Join-Path $source ('skills/'+$dir.Name+'/SKILL.md'))).Hash
      if($actual-ne$expected-or(Test-Path -LiteralPath (Join-Path $dir.FullName 'prior-version.marker'))){throw 'Active skill is not the new version'}
    }
    $passed += $component.name+'-verified-install-survives-cleanup-failure'
  }
  [ordered]@{success=$true;count=$passed.Count;tests=$passed}|ConvertTo-Json -Compress
}finally{
  if(Test-Path -LiteralPath $temp){
    # Only this disposable fixture's attributes are reset for test cleanup.
    Get-ChildItem -LiteralPath $temp -Recurse -File -Force|ForEach-Object {if($_.Attributes-band[IO.FileAttributes]::ReadOnly){[IO.File]::SetAttributes($_.FullName,($_.Attributes-band(-bnot[IO.FileAttributes]::ReadOnly)))}}
    [IO.Directory]::Delete($temp,$true)
  }
}
