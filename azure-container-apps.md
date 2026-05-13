# Integrate Dynatrace OneAgent into Azure Container Apps 

The following instructions describe how to integrate Dynatrace OneAgent code-modules to your Azure Container Apps using an initContainer approach. 
The initContainer copies the Dynatrace OneAgent artefacts into a (ephemeral) shared volume, from where the OneAgent is configured and activated via environment variables. 

While you can configure the Dynatrace initContainer within the Azure Portal, the following step-by-step guide shows how to do it using Powershell and the azure-cli: 

## Prerequisites
1. API Token to access the Dynatrace REST API for fetching the necessary tenant configuration
   
   [Create an API Token](https://www.dynatrace.com/support/help/dynatrace-api/basics/dynatrace-api-authentication) with **"InstallerDownload"** permissions. The token created is later referenced as ```<API-TOKEN>```
     
2. API endpoint url, later referened as ```<ADDRESS>```
   1. Using your environments [cluster-endpoint](https://www.dynatrace.com/support/help/get-started/monitoring-environment/environment-id)
   2. or alternatively an [ActiveGate](https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-activegate) address.

3. Dynatrace connection parameters
   
   To configure the OneAgent Code-Modules to connect to Dynatrace, you need to retrieve the agent connection parameters via the Dynatrace API:  

   API Endpoint ```<ADDRESS>/api/v1/deployment/installer/agent/connectioninfo?Api-Token=<API-TOKEN>```

   You can e.g. use **curl** to retrieve the information as a Json payloud:
    ```
    {
        "tenantUUID" : "XXXXXXXX",
        "tenantToken" : "XXXXXXXXXX",
        "communicationEndpoints" :  [ "https://XXXXXXX:9999/communication", "https://YYYYYYY/communication"],
        "formattedCommunicationEndpoints" : "https://XXXXXXX:9999/communication;https://YYYYYYY/communication"
    }
    ```
    
## Retrieve your containerapps manifest
``` Powershell
$ResourceGroup = "<Your ContainerApp's resourcegroup name>"
$AppName = "<Your ContainerApp's name>"

az containerapp show --name $appName --resource-group $resourceGroup --output yaml > containerapp.yaml
```

## Modify the containerapp.yaml file

### Add an ephemeral volume that will hold the Oneagent artefacts
``` Yaml
...
  template:
    ...
    volumes:
    - name: oneagent
        storageType: EmptyDir
...
```

### Add an init-container to copy the Oneagent artefacts

The init-container uses Dynatrace OneAgent images from e.g.[public.ecr.aws/dynatrace/dynatrace-codemodules](https://gallery.ecr.aws/dynatrace/dynatrace-codemodules) or [Docker Hub](https://hub.docker.com/r/dynatrace/dynatrace-codemodules). 

**Available image tags:**
* Immutable tags containing all code-modules of a specific release e.g.: 1.327.51.20251205-162230, 1.327.43.20251117-175735
* Mutable (or rolling tags) with major.minor version scheme e.g.: 1.327
* Technology specific images with immutable and mutable tags e.g.: 1.327.51.20251205-162230-java, 1.327-java, 1.327-dotnet

``` Yaml
...
  template:
  ...
    initContainers:
    - args:
      - --source=/opt/dynatrace/oneagent
      - --target=/home/dynatrace/oneagent
    image: docker.io/dynatrace/dynatrace-codemodules:1.315.68.20250627-182234
    imageType: ContainerImage
    name: initoneagent
    resources:
        cpu: 0.25
        ephemeralStorage: 1Gi
        memory: 0.5Gi
    volumeMounts:
    - mountPath: /home/
        volumeName: oneagent
...
```
**Note:** To reduce the startup time, you should specify an additional argument to only copy technology specific OneAgent artefacts e.g. for .Net: ```--technology=dotnet```. 
For more details and additional options see [https://github.com/Dynatrace/dynatrace-bootstrapper](https://github.com/Dynatrace/dynatrace-bootstrapper)

### Add the volume mount and necessary configuration for OneAgent to your main container
**Please note** for simplicity the tenant details are provided as plain text environment variables. It is highly recommended to configure them as secrets!

``` yaml
...
  template:
  ...
    containers:
    - env:
      - name: DT_TENANT
        value: <Your Dynatrace Tenant Id>
      - name: DT_TENANTTOKEN
        value: <Your Dynatrace Tenant Token>
      - name: DT_CONNECTION_POINT
        value: <Your Dynatrace Connection Point>
      - name: LD_PRELOAD
        value: /home/dynatrace/oneagent/agent/lib64/liboneagentproc.so
      - name: DT_AGENTACTIVE
        value: 'true'
      - name: DT_LOGSTREAM
        value: stdout
      - name: DT_LOGLEVELCON
        value: INFO
      image: mcr.microsoft.com/dotnet/samples:aspnetapp
      imageType: ContainerImage
      name: myaspnetapp
      volumeMounts:
      - mountPath: /home/
        volumeName: oneagent
      resources:
        cpu: 0.25
        ephemeralStorage: 1Gi
        memory: 0.5Gi
...
```

## Update the containerapp with the enhanced containerapp.yaml
``` Powershell
az containerapp update --name $appName --resource-group $resourceGroup --yaml containerapp.yaml```
```` 
