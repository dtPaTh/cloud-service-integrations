# Testbed for cloud service monitoring integrations using Dynatrace
## Azure
## Customize Azure AppService For Linux environment
Azure AppService for Linux allows to customize it's container runtime environment using a [startup script or script command](https://docs.microsoft.com/en-us/azure/app-service/configure-language-python#customize-startup-command), which can be configured in multiple ways:

### Setting startup script command/file at creation time using Azure CLI
```
az webapp create -n <my-app> -g <my-resourcegroup> -p <my-appservice-plan> --runtime <runtime-tag> --startup-file <startup-script/command>
```
### Setting script command/file at creation time for an existing appservice
```
az webapp config set -n <my-app> -g <my-resourcegroup> --startup-file <startup-script/command>
```
### Setting script command/file using ARM template 

Use the [appCommandLine](https://docs.microsoft.com/en-us/azure/templates/microsoft.web/sites/config-web?pivots=deployment-language-arm-template#siteconfig-1) property of your ARM template to set the startup script/command.
```
{
  "acrUseManagedIdentityCreds": false,
  "acrUserManagedIdentityId": null,
  "alwaysOn": false,
  "apiDefinition": null,
  "apiManagementConfig": null,
  "appCommandLine": "<startup-script/command>",
  "appSettings": null,
  "autoHealEnabled": false,
  "autoHealRules": null,
  "autoSwapSlotName": null,
...
```
### Setting startup script command/file in the Azure portal
![Azure Portal]()

### Script or command?
Startup scripts require to package the script along with your application. If you don't want to have this dependency, use startup commands.

The script/command is executed within the containers init script, which is implemented differently on each technology stack. 

For more details on startup commands see Azure AppService for Linux documentation on [What are the expected values for the Startup File section when I configure the runtime stack?](https://docs.microsoft.com/en-us/troubleshoot/azure/app-service/faqs-app-service-linux#what-are-the-expected-values-for-the-startup-file-section-when-i-configure-the-runtime-stack-)

## Integrate Dynatrace on AppServices for Linux

Bash script template to integrate Dynatrace
```bash
"curl -o /tmp/installer.sh -s \"$DT_ENDPOINT/api/v1/deployment/installer/agent/unix/paas-sh/latest?Api-Token=$DT_API_TOKEN&arch=$DT_ARCH&include=$DT_INCLUDE\" && sh /tmp/installer.sh /home && LD_PRELOAD='/home/dynatrace/oneagent/agent/lib64/liboneagentproc.so' $START_APP"
```

Set/replace the following the following parameters of the script
|Parameter|Description|
|---|---|
|DT_ENDPOINT|Your Dynatrace API server endpoint. Using either your environments [cluster-endpoint](https://www.dynatrace.com/support/help/get-started/monitoring-environment/environment-id) or alternatively an [ActiveGate address](https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-activegate)|
|DT_API_TOKEN| API Token to access the Dynatrace REST API. [Create an API Token](https://www.dynatrace.com/support/help/dynatrace-api/basics/dynatrace-api-authentication) with **"PaaS integration - InstallerDownload"** permission.|
|DT_ARCH|Configure required architecture. **x86** for standard, glibc based linux images or **musl** for alpine based images. **Note**: Most built-in images are using standard linux base images, with exception for tomcat. You may need to review the dockerfile of the used runtime stack if it is using an alpine based image.  |
|DT_INCLUDE| Configure required code-modules, depending on used technology stack. **all** includes all available technologies, but increases download package size. Alternatively choose an identifier appropriate of your application stack such as e.g. **java**, **dotnet**, **nodejs**, **php**. For more details see [API documentation](https://www.dynatrace.com/support/help/dynatrace-api/environment-api/deployment/oneagent/download-oneagent-latest) |
|START_APP| The actual command to start your application. [What are the expected values for the Startup File section when I configure the runtime stack?](https://docs.microsoft.com/en-us/troubleshoot/azure/app-service/faqs-app-service-linux#what-are-the-expected-values-for-the-startup-file-section-when-i-configure-the-runtime-stack-)|


### Examples
### Integrate into a node.js application using Azure CLI within a bash shell.

```bash
RESOURCE_GROUP="my-appservice-test"
APPSVC="my-linux-webapp"
DT_API_URL="https://XXXXXX.live.dynatrace.com"
DT_API_TOKEN="XXXXXX"
DT_ARCH="x86"
DT_INCLUDE="nodejs"
START_APP="pm2 start index.js --no-daemon"
STARTUP="curl -o /tmp/installer.sh -s \"$DT_API_URL/api/v1/deployment/installer/agent/unix/paas-sh/latest?Api-Token=$DT_API_TOKEN&arch=DT_ARCH&include=$DT_INCLUDE\" && sh /tmp/installer.sh /home && LD_PRELOAD='/home/dynatrace/oneagent/agent/lib64/liboneagentproc.so' $START_APP"

az webapp config set --resource-group $RESOURCE_GROUP --name $APPSVC --startup-file "$STARTUP"
```

```powershell
#powershell (not working as needs proper escaping for ampersand)

$RESOURCE_GROUP="AppServices-Europe"
$LOCATION="westeurope"

$NAME="dt-webapp-linux"

$DT_API_URL="https://aea76191.live.dynatrace.com"
$AZURE_SERVICE_PLAN_NAME="dt-webapp-linux"
$APPSVC=$NAME
$START_APP="pm2 start index.js --no-daemon"
$DT_API_TOKEN="spjxsLTOR_mNuSixzRuTH"
$STARTUP="curl -o /tmp/installer.sh -s `"$DT_API_URL/api/v1/deployment/installer/agent/unix/paas-sh/latest?Api-Token=$DT_API_TOKEN`&arch=x86`" && sh /tmp/installer.sh /home && LD_PRELOAD='/home/dynatrace/oneagent/agent/lib64/liboneagentproc.so' $START_APP"

$STARTUP='curl -o /tmp/installer.sh -s "$DT_API_URL/api/v1/deployment/installer/agent/unix/paas-sh/latest?Api-Token=$DT_API_TOKEN`&arch=x86"'

az webapp config set --resource-group $RESOURCE_GROUP --name $APPSVC --startup-file "$STARTUP"
```

#### Available startup scripts
In [/src/azure-appservice-linux](/src/azure-appservice-linux) you will find 2 flavors one using wget the other curl.

The scripts are parameterized using environment variables:
| env-var | required | description |
| --- | --- | ---|
| DT_API_URL | yes | Dynatrace API endpoint |
| DT_API_TOKEN | yes | Dynatrace API token to with permission "PaaS integration - Installer download" |
| DT_LINUX_FLAVOR | no | Some containers may use alpine based images (e.g. tomcat) which need to set DT_LINUX_FLAVOR to 'musl' |

**Example how to set startup script**
```
az webapp config set -n <my-app> -g <my-resourcegroup> --startup-file "home/startup-wget.sh"
```
