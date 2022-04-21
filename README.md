# Testbed for cloud service monitoring integrations using Dynatrace
## Azure
## Azure AppService For Linux
Azure AppServices for Linux allows to integrate using startup scripts and script commands. 

**Setting startup script command/file at creation time using Azure CLI**
```
az webapp create -n <my-app> -g <my-resourcegroup> -p <my-appservice-plan> --runtime <runtime-tag> --startup-file <startup-script/command>
```
**Setting script command/file at creation time for an existing appservice**
```
az webapp config set -n <my-app> -g <my-resourcegroup> --startup-file <startup-script/command>
```
### When to use what
Startup scripts require to package the script along with your application. If you don't want to have this dependency, use startup commands.

Scripts/Commands are executed within the containers init scripts, which is implemented differently on each tech-stack. 

| tech stack | possible approaches | available tools | platform-flavor | needs to append entrypoint |
| --- | --- | --- | --- | --- |
| dotnet| script command, script-file | curl and wget| Linux | yes |
| tomcat | only script-file | only wget | Musl-Linux | no |
| java, node.js, ruby, python, ruby | script command, script-file | TBC | TBC | TBC |

#### Available startup scripts
In [/src/azure-app-service-linux](/src/azure-appservice-linux) you will find 2 flavors one using wget the other curl.

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
