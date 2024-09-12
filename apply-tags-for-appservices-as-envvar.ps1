 [CmdletBinding()]
  param (
    [Parameter(Position=0,mandatory=$true)]
    [string]$subscriptionName,
    [Parameter(Position=1)]
    [string]$envKey="OTEL_RESOURCE_ATTRIBUTES",#use DT_TAGS, which are then prefixed with '[Environment] or  OTEL_RESOURCE_ATTRIBUTES
    [Parameter(Position=2)]
    [string]$keyPrefix="[Azure]",   #Prefix so the tags align with the ones automatically applied via Azure Monitor Integration 
    [Parameter(Position=3)]
    [string]$filterAppSvc=""  #use this param to configure a filter limited to apply the setting (e.g. for testing purposes) , leave empty for re-configuring all
  )
Write-Host "Updating AppServices confi adding Azure Tags.. "

az account set -n $subscriptionName
Write-Host "Processing subscripton .. $subscriptionName"

$appServices = az webapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json
Write-Host "Found $($appServices.Length) AppServices!"

foreach ($appService in $appServices) {
    
    $name = $appService.name
    if ([string]::IsNullOrWhitespace($filterAppSvc) -or $name -eq $filterAppSvc) {
        $resourceGroup = $appService.resourceGroup

        # Get tags for the App Service
        $tags = az resource show --resource-group $resourceGroup --name $name --resource-type "Microsoft.Web/sites" --query "tags" -o json | ConvertFrom-Json

        # Convert tags to a single string
        $tagsString = ($tags.PSObject.Properties  | Where-Object { $_.Name -notmatch '^hidden-' } | ForEach-Object { "$keyPrefix$($_.Name)=$($_.Value)" }) -join ','

        # Set the tags as an app setting
        write-host "Updating appsettings in $name"
        
        $ret = az webapp config appsettings set --name $name --resource-group $resourceGroup --settings $envKey=$tagsString
        write-host "Successfully upserted appsettings key $envKey=$tagsString"
    }
    else {
        Write-Host "Skipping '$name'"
    }
}