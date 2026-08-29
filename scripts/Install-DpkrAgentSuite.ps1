[CmdletBinding()]
param(
  [string]$SuiteRoot=(Split-Path $PSScriptRoot -Parent),
  [string]$UserHome=$env:USERPROFILE,
  [string]$FrontierLoopSource,
  [string]$NativeUiSource,
  [switch]$SkipCodexCliRegistration,
  [switch]$ReplaceGlobalAgents,
  [switch]$WhatIf
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Full([string]$Path){[IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')}
function CanonicalRepo([string]$Url){
  $v=$Url.Trim().TrimEnd('/')
  if($v.EndsWith('.git',[StringComparison]::OrdinalIgnoreCase)){$v=$v.Substring(0,$v.Length-4)}
  return $v.ToLowerInvariant()
}
function RunGit([string]$Working,[string[]]$Args){
  & git -C $Working @Args
  if($LASTEXITCODE-ne0){throw "git failed in ${Working}: git $($Args -join ' ')"}
}
function ReadJson([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function WriteJson([string]$Path,$Value){
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))|Out-Null
  $json=$Value|ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($Path,$json+"`n",[Text.UTF8Encoding]::new($false))
}
function CodexJson([string[]]$CodexArgs){
  $command=Get-Command codex -ErrorAction SilentlyContinue
  if(-not$command){throw 'Codex CLI is required for Codex plugin registration'}
  $text=(& codex @CodexArgs 2>&1|Out-String).Trim()
  if($LASTEXITCODE-ne0){throw "codex $($CodexArgs -join ' ') failed: $text"}
  try{return $text|ConvertFrom-Json}catch{throw "Codex returned invalid JSON for '$($CodexArgs -join ' ')': $text"}
}
function EnsureCodexMarketplace([string]$MarketplaceRoot){
  $catalog=CodexJson @('plugin','marketplace','list','--json')
  $personal=@($catalog.marketplaces|Where-Object {$_.name-eq'personal'})
  if($personal.Count-eq0){
    [void](CodexJson @('plugin','marketplace','add',$MarketplaceRoot,'--json'))
    $catalog=CodexJson @('plugin','marketplace','list','--json')
    $personal=@($catalog.marketplaces|Where-Object {$_.name-eq'personal'})
  }
  if($personal.Count-ne1){throw "Codex must resolve exactly one personal marketplace; found $($personal.Count)"}
  $root=Full ([string]$personal[0].root)
  if(-not[string]::Equals($root,(Full $MarketplaceRoot),[StringComparison]::OrdinalIgnoreCase)){throw "Codex personal marketplace root mismatch: $root"}
}
function EnsureSource($Component,[string]$Override,[string]$PluginsRoot){
  if($Override){return Full $Override}
  $path=Full (Join-Path $PluginsRoot ([string]$Component.directory))
  if(-not(Test-Path -LiteralPath $path)){
    if($WhatIf){return $path}
    & git clone --branch ([string]$Component.ref) --depth 1 ([string]$Component.repository) $path
    if($LASTEXITCODE-ne0){throw "git clone failed: $($Component.name)"}
    return $path
  }
  if(-not(Test-Path -LiteralPath (Join-Path $path '.git'))){
    # Existing verified local authoring source is allowed, but the suite will not
    # pretend it can update it through Git.
    return $path
  }
  $dirty=& git -C $path status --porcelain
  if($LASTEXITCODE-ne0){throw "cannot inspect Git state: $path"}
  if(@($dirty).Count){throw "refusing to update dirty plugin checkout: $path"}
  $origin=(& git -C $path remote get-url origin 2>$null | Out-String).Trim()
  if(-not$origin){throw "plugin checkout has no origin: $path"}
  if((CanonicalRepo $origin)-ne(CanonicalRepo ([string]$Component.repository))){throw "plugin origin mismatch: $path -> $origin"}
  if(-not$WhatIf){
    RunGit $path @('fetch','--tags','--prune','origin')
    RunGit $path @('checkout','--detach',([string]$Component.ref))
  }
  return $path
}
function AssertManifests($Component,[string]$Source){
  $codex=ReadJson (Join-Path $Source ([string]$Component.codexManifest))
  $tadd=ReadJson (Join-Path $Source ([string]$Component.taddkorroManifest))
  if($codex.name-ne$Component.name-or$codex.version-ne$Component.version){throw "Codex manifest mismatch: $($Component.name)"}
  if($tadd.schemaVersion-ne1-or$tadd.name-ne$Component.name-or$tadd.version-ne$Component.version-or-not$tadd.enabled){throw "Taddkorro manifest mismatch: $($Component.name)"}
  if(@($tadd.skills).Count-ne1-or$tadd.skills[0]-ne'skills'){throw "Taddkorro Skill root mismatch: $($Component.name)"}
}
function MarketplaceEntry($Component,[string]$Source,[string]$MarketplaceRoot){
  $rel='./'+[IO.Path]::GetRelativePath($MarketplaceRoot,$Source).Replace('\','/')
  [ordered]@{
    name=[string]$Component.name
    source=[ordered]@{source='local';path=$rel}
    policy=[ordered]@{installation='INSTALLED_BY_DEFAULT';authentication='ON_INSTALL'}
    category='Developer Tools'
  }
}

$SuiteRoot=Full $SuiteRoot
$UserHome=Full $UserHome
$suite=ReadJson (Join-Path $SuiteRoot 'suite.json')
if($suite.schemaVersion-ne1-or$suite.name-ne'dpkr-agent-suite'){throw 'invalid suite manifest'}
$pluginsRoot=Join-Path $UserHome 'plugins'
$skillsRoot=Join-Path $UserHome ([string]$suite.sharedSkillRoot)
$marketplace=Join-Path $UserHome ([string]$suite.codexMarketplace)
$agentsSource=Join-Path $SuiteRoot ([string]$suite.globalAgents.source)
$agentsTarget=Join-Path $UserHome ([string]$suite.globalAgents.target)

if(-not(Test-Path -LiteralPath $agentsSource -PathType Leaf)){throw 'bundled AGENTS.md missing'}
$sourceOverrides=@{
  'frontier-loop'=$FrontierLoopSource
  'native-ui-governance'=$NativeUiSource
}
$resolved=[ordered]@{}
foreach($component in @($suite.components)){
  $src=EnsureSource $component $sourceOverrides[[string]$component.name] $pluginsRoot
  if(-not$WhatIf-and-not(Test-Path -LiteralPath $src -PathType Container)){throw "component source missing: $src"}
  if(-not$WhatIf){
    AssertManifests $component $src
    & (Join-Path $src ([string]$component.verifier)) -Root $src | Out-Null
    if($LASTEXITCODE-ne0){throw "component verifier failed: $($component.name)"}
  }
  $resolved[[string]$component.name]=$src
}

# Preflight the global instruction owner before any registration/install mutation.
$agentsAction='create'
if(Test-Path -LiteralPath $agentsTarget -PathType Leaf){
  $same=((Get-FileHash -LiteralPath $agentsTarget -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $agentsSource -Algorithm SHA256).Hash)
  if($same){$agentsAction='unchanged'}elseif($ReplaceGlobalAgents){$agentsAction='replace-with-backup'}else{throw "global AGENTS.md differs: $agentsTarget. Re-run with -ReplaceGlobalAgents to adopt the bundled suite file."}
}

if($WhatIf){
  [ordered]@{success=$true;whatIf=$true;version=$suite.version;components=$resolved;globalAgentsAction=$agentsAction;codexRegistration='marketplace';taddkorroRegistration='taddkorro.plugin.json + materialized .agents/skills'}|ConvertTo-Json -Depth 8
  exit 0
}

$marketplaceBackup=$null
$agentsBackup=$null
try{
  [IO.Directory]::CreateDirectory($pluginsRoot)|Out-Null
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($marketplace))|Out-Null
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($agentsTarget))|Out-Null

  if(Test-Path -LiteralPath $marketplace -PathType Leaf){
    $marketplaceBackup="$marketplace.backup-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
    Copy-Item -LiteralPath $marketplace -Destination $marketplaceBackup
    $market=ReadJson $marketplace
  }else{
    $market=[pscustomobject]@{name='personal';interface=[pscustomobject]@{displayName='Personal Plugins'};plugins=@()}
  }
  $plugins=@($market.plugins|Where-Object {$_.name -notin @('frontier-loop','native-ui-governance')})
  foreach($component in @($suite.components)){$plugins += MarketplaceEntry $component $resolved[[string]$component.name] $UserHome}
  $market.plugins=$plugins
  WriteJson $marketplace $market

  if($agentsAction-eq'replace-with-backup'){
    $agentsBackup="$agentsTarget.backup-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
    Copy-Item -LiteralPath $agentsTarget -Destination $agentsBackup
  }
  if($agentsAction-ne'unchanged'){Copy-Item -LiteralPath $agentsSource -Destination $agentsTarget -Force}

  foreach($component in @($suite.components)){
    $src=$resolved[[string]$component.name]
    $cacheRoot=Join-Path $UserHome ('.codex\plugins\cache\personal\'+[string]$component.cacheDirectory)
    $installer=Join-Path $src ([string]$component.installer)
    if($component.name-eq'frontier-loop'){
      & $installer -Source $src -DestinationRoot $cacheRoot -UserSkillRoot $skillsRoot -MarketplaceFiles @($marketplace) | Out-Null
    }else{
      & $installer -Source $src -DestinationRoot $cacheRoot -UserSkillRoot $skillsRoot -MarketplaceFile $marketplace | Out-Null
    }
    if($LASTEXITCODE-ne0){throw "component installation failed: $($component.name)"}
  }

  if(-not$SkipCodexCliRegistration){EnsureCodexMarketplace $UserHome}

  & (Join-Path $SuiteRoot 'scripts\Verify-DpkrAgentSuite.ps1') -SuiteRoot $SuiteRoot -UserHome $UserHome -FrontierLoopSource $resolved['frontier-loop'] -NativeUiSource $resolved['native-ui-governance'] -SkipCodexCliRegistration:$SkipCodexCliRegistration | Out-Null
  if($LASTEXITCODE-ne0){throw 'suite verification failed'}

  [ordered]@{success=$true;version=$suite.version;components=$resolved;globalAgents=$agentsTarget;globalAgentsBackup=$agentsBackup;marketplace=$marketplace;codexPrepared=$true;codexRegistered=(-not$SkipCodexCliRegistration);taddkorroRegistered=$true;skillCount=27}|ConvertTo-Json -Depth 8
  exit 0
}catch{
  if($agentsBackup-and(Test-Path -LiteralPath $agentsBackup)){Copy-Item -LiteralPath $agentsBackup -Destination $agentsTarget -Force}
  if($marketplaceBackup-and(Test-Path -LiteralPath $marketplaceBackup)){Copy-Item -LiteralPath $marketplaceBackup -Destination $marketplace -Force}
  throw
}
