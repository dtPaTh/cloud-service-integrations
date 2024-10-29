  [CmdletBinding()]
  Param (
    [Parameter(Position=0,mandatory=$true)]
    [string]$DTDomain ,
    [Parameter(Position=1,mandatory=$true)]
    [string]$DTUser ,
    [Parameter(Position=2,mandatory=$true)]
    [string]$DTToken,
    [Parameter(Position=3,mandatory=$true)]
    [string]$ACR ,
    [Parameter(Position=4,mandatory=$true)]
    [string]$ACRSubscription,
    [Parameter(Position=5,mandatory=$false)]
    [string]$containerRuntime = "podman" #docker or podman
  )

Function Login-Azure {
  [CmdletBinding()]
  Param (
    [string]$subscription 
  )
  az login
  az account set --subscription $subscription 
}

Function Login-ACR {
  [CmdletBinding()]
  Param (
    [string]$registry,
    [string]$subscription,
    [string]$containerRuntime = "podman" #alternative podman
  )

  ($token = az acr login --name $registry --expose-token --output tsv --query accessToken --subscription $subscription) *>$Null 
  $user = "00000000-0000-0000-0000-000000000000"

  if ($containerRuntime -eq "docker") {
    $token | docker login "${registry}.azurecr.io" -u $user --password-stdin 
  }
  else {
    $token | podman login "${registry}.azurecr.io" -u $user --password-stdin 
  }
}

Function Login-Registry {
  [CmdletBinding()]
  Param (
    [string]$registry,
    [string]$user,
    [string]$token,
    [string]$containerRuntime = "podman" #alternative podman
  )

  if ($containerRuntime -eq "docker") {
    $token | docker login "${registry}" -u $user --password-stdin
  }
  else {
    $token | podman login "${registry}" -u $user --password-stdin
  }
}

Function Get-DT-ConnectionInfo {
 [CmdletBinding()]
  Param (
    [string]$apiDomain ,
    [string]$token 
  )

  $res = Invoke-WebRequest -Uri "https://${apiDomain}/api/v1/deployment/installer/agent/connectioninfo" -Method GET -Headers @{ Authorization = "Api-Token ${token}" } -UseBasicParsing | ConvertFrom-Json
  Write-Host $res

}

Function Get-Latest-Version {
  [CmdletBinding()]
  Param (
    [string]$apiDomain,
    [string]$token 
  )

  $res = Invoke-WebRequest -Uri "https://${apiDomain}/api/v1/deployment/installer/agent/unix/paas/latest/metainfo?flavor=multidistro&arch=all&bitness=all" -Method GET -Headers @{ Authorization = "Api-Token ${token}" } -UseBasicParsing | ConvertFrom-Json
  return $res.latestAgentVersion
}


Login-Azure -subscription $ACRSubscription
Login-ACR -registry $ACR -subscription $ACRSubscription -containerRuntime $containerRuntime

Login-Registry -registry $DTDomain -user $DTUser -token $DTToken -containerRuntime $containerRuntime

$artefacts=(
  [pscustomobject]@{srcPath='/linux/oneagent-codemodules';targetPath='/oneagent-codemodules';targetTagPostfix='amd64'},
  [pscustomobject]@{srcPath='/linux/oneagent-codemodules-musl';targetPath='/oneagent-codemodules';targetTagPostfix='alpine-amd64'}
)

$techs = (
  [pscustomobject]@{name='java'; tag='-java'},
  [pscustomobject]@{name='dotnet'; tag='-dotnet'},
  [pscustomobject]@{name='nodejs'; tag='-nodejs'},
  [pscustomobject]@{name='go'; tag='-go'},
  [pscustomobject]@{name='php'; tag='-php'},
  [pscustomobject]@{name='all'; tag=''}
)


$version = Get-Latest-Version -apiDomain $DTDomain -token $DTToken
$versionRollingMinor = $version.substring(0,5)+".x"
#Get-DT-ConnectionInfo -apiDomain $DTDomain -token $DTToken

$targetRegistry = "${ACR}.azurecr.io"

foreach ($tech in $techs) {
  foreach($a in $artefacts) {

    $versionTag = "$($version)$($tech.tag)-$($a.targetTagPostfix)"
    $rollingVersionTag = "$($versionRollingMinor)$($tech.tag)-$($a.targetTagPostfix)"
    $latestVersionTag = "latest$($tech.tag)-$($a.targetTagPostfix)"

    $sourceRepo = "${DTDomain}$($a.srcPath)"
    $targetRepo = "${targetRegistry}$($a.targetPath)"

    $sourceImage = "${sourceRepo}:$($tech.name)-raw"
    
    #pull oneagent codemodule images
    iex "${containerRuntime} pull ${sourceImage}"

    #tag with new naming schema for remote registry
    iex "${containerRuntime} tag ${sourceImage} ${targetRepo}:${versionTag}"
    iex "${containerRuntime} tag ${sourceImage} ${targetRepo}:${rollingVersionTag}"
    iex "${containerRuntime} tag ${sourceImage} ${targetRepo}:${lastestVersionTag}"
    
    #push oneagent codemodule images to remote registry
    iex "${containerRuntime} push ${targetRepo}:${versionTag}"
    iex "${containerRuntime} push ${targetRepo}:${rollingVersionTag}"
    iex "${containerRuntime} push ${targetRepo}:${lastestVersionTag}"

    #build the bootstrated oneagent codemodule image
    iex "${containerRuntime} build --no-cache --build-arg=`"DT_BASEIMG=${sourceImage}`" -f Dockerfile.native -t ${targetRepo}:${versionTag}-bootstrap"
    
    #tag images using latest and rolling version
    iex "${containerRuntime} tag ${targetRepo}:${versionTag}-bootstrap ${targetRepo}:${rollingVersionTag}-bootstrap"
    iex "${containerRuntime} tag ${targetRepo}:${versionTag}-bootstrap ${targetRepo}:${lastestVersionTag}-bootstrap"
 
    #push bootstrapped codemodules images to remote registry
    iex "${containerRuntime} push ${targetRepo}:${versionTag}-bootstrap"
    iex "${containerRuntime} push ${targetRepo}:${rollingVersionTag}-bootstrap"
    iex "${containerRuntime} push ${targetRepo}:${lastestVersionTag}-bootstrap"
    break;
  }
  break;
}