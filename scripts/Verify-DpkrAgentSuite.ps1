[CmdletBinding()]
param(
  [string]$SuiteRoot=(Split-Path $PSScriptRoot -Parent),
  [string]$UserHome=$env:USERPROFILE,
  [string]$FrontierLoopSource,
  [string]$NativeUiSource
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Full([string]$Path){[IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')}
function ReadJson([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function Excluded([string]$Rel){
  $p=$Rel.Replace('\','/').ToLowerInvariant()
  return $p-eq'.git' -or
    $p.StartsWith('.git/') -or
    $p.StartsWith('evaluation/results/') -or
    $p.Contains('/__pycache__/') -or
    $p.EndsWith('.pyc') -or
    $p.Contains('/.frontier-loop-') -or
    $p.Contains('install-backup') -or
    $p.Contains('/temp/')
}
function Inventory([string]$Base){
  $r=Full $Base
  @(Get-ChildItem -LiteralPath $r -Recurse -File -Force|Sort-Object FullName|ForEach-Object{
    $rel=[IO.Path]::GetRelativePath($r,$_.FullName).Replace('\','/')
    if(-not(Excluded $rel)){[ordered]@{path=$rel;length=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}}
  })
}
function SameTree([string]$A,[string]$B){(ConvertTo-Json -InputObject @(Inventory $A)-Compress)-eq(ConvertTo-Json -InputObject @(Inventory $B)-Compress)}

$SuiteRoot=Full $SuiteRoot;$UserHome=Full $UserHome
$suite=ReadJson (Join-Path $SuiteRoot 'suite.json')
if($suite.schemaVersion-ne1-or$suite.name-ne'dpkr-agent-suite'){throw 'invalid suite manifest'}
$agentsSource=Join-Path $SuiteRoot ([string]$suite.globalAgents.source)
$agentsTarget=Join-Path $UserHome ([string]$suite.globalAgents.target)
if(-not(Test-Path -LiteralPath $agentsTarget -PathType Leaf)){throw 'global AGENTS.md missing'}
if((Get-FileHash $agentsSource -Algorithm SHA256).Hash-ne(Get-FileHash $agentsTarget -Algorithm SHA256).Hash){throw 'global AGENTS.md does not match suite payload'}

$sources=@{
  'frontier-loop'=if($FrontierLoopSource){Full $FrontierLoopSource}else{Full (Join-Path $UserHome 'plugins\frontier-loop')}
  'native-ui-governance'=if($NativeUiSource){Full $NativeUiSource}else{Full (Join-Path $UserHome 'plugins\native-ui-governance')}
}
$marketplace=Join-Path $UserHome ([string]$suite.codexMarketplace)
$market=ReadJson $marketplace
$skillsRoot=Join-Path $UserHome ([string]$suite.sharedSkillRoot)
$allSkills=@()

foreach($component in @($suite.components)){
  $name=[string]$component.name;$src=$sources[$name]
  if(-not(Test-Path -LiteralPath $src -PathType Container)){throw "component source missing: $name"}
  $codex=ReadJson (Join-Path $src ([string]$component.codexManifest))
  $tadd=ReadJson (Join-Path $src ([string]$component.taddkorroManifest))
  if($codex.name-ne$name-or$codex.version-ne$component.version){throw "Codex registration mismatch: $name"}
  if($tadd.schemaVersion-ne1-or$tadd.name-ne$name-or$tadd.version-ne$component.version-or-not$tadd.enabled-or@($tadd.skills).Count-ne1-or$tadd.skills[0]-ne'skills'){throw "Taddkorro registration mismatch: $name"}
  & (Join-Path $src ([string]$component.verifier)) -Root $src | Out-Null
  if($LASTEXITCODE-ne0){throw "component verifier failed: $name"}

  $entries=@($market.plugins|Where-Object name -eq $name)
  if($entries.Count-ne1-or$entries[0].source.source-ne'local'-or$entries[0].policy.installation-ne'INSTALLED_BY_DEFAULT'){throw "Codex marketplace registration mismatch: $name"}
  $marketSource=Full (Join-Path ([IO.Path]::GetDirectoryName($marketplace)) ([string]$entries[0].source.path))
  if(-not[string]::Equals($marketSource,$src,[StringComparison]::OrdinalIgnoreCase)){throw "Codex marketplace source is not canonical: $name"}

  $cache=Join-Path $UserHome ('.codex\plugins\cache\personal\'+[string]$component.cacheDirectory+'\'+[string]$component.version)
  if(-not(Test-Path -LiteralPath $cache -PathType Container)){throw "versioned cache missing: $name"}
  if(-not(SameTree $src $cache)){throw "source/cache drift: $name"}
  foreach($skill in @(Get-ChildItem -LiteralPath (Join-Path $src 'skills') -Directory|Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')})){
    $installed=Join-Path $skillsRoot $skill.Name
    if(-not(Test-Path -LiteralPath $installed -PathType Container)){throw "materialized Skill missing: $($skill.Name)"}
    $item=Get-Item -LiteralPath $installed -Force
    if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "materialized Skill is a reparse point: $($skill.Name)"}
    $cacheSkill=Join-Path $cache ('skills\'+$skill.Name)
    if(-not(SameTree $installed $cacheSkill)){throw "installed Skill drift: $($skill.Name)"}
    $allSkills += $skill.Name
  }
}
if(@($allSkills|Sort-Object -Unique).Count-ne27){throw "expected 27 unique suite Skills, got $(@($allSkills|Sort-Object -Unique).Count)"}

$frontierVersion=[string](@($suite.components|Where-Object {$_.name-eq'frontier-loop'})[0].version)
$nativeUiVersion=[string](@($suite.components|Where-Object {$_.name-eq'native-ui-governance'})[0].version)
[ordered]@{success=$true;version=$suite.version;codexRegistered=$true;taddkorroRegistered=$true;globalAgentsMatched=$true;skillCount=27;frontierLoopVersion=$frontierVersion;nativeUiVersion=$nativeUiVersion}|ConvertTo-Json -Compress
exit 0
