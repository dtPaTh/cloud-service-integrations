# Building a Dynatrace OneAgent image for side-car integrations
Dynatrace provides a built-in image registry for each tenant, which contains pre-configured OneAgent images. 

These images can be used to integrate images into applicaiton images using e.g. the docker file command "COPY". 

If you want a runtime integration using an initcontainer or side-car pattern, you want to copy the OneAgent artefacts during container/pod startup into a mounted volume, from where the main container can integrate the Oneagent. 

## Option 1 (recommended)
Create a OneAgent Image, including a native binary without OS depenencies, that copies the necessary artefacts. 

Dockerfile: ```Dockerfile.native```

### Testing the copy binary
Create a volume to be mounted where artefacts are copied to
```podman volume create testvol```

Build the image with sample artefacts 
```podman build -f .\Dockerfile.test.native -t copy-artefacts```

Run the container
```podman run --mount type=volume,source=testvol,target=/home my-artefacts```

Build the test container that checks if the artefacts are copied
```podman build -f .\Dockerfile.test.copy -t copytest```

Run the container that lists the copied artefacts
 ```podman run --mount type=volume,source=myhome,target=/home copytest```

## Option 2 
Using a shell script to copy the necessary artefacts. 

This approach comes with the caveat of larger image size due to the required OS layer to execute the shell script and additional maintanance effort for keeping the image up-to-date for security reasons. 

Dockerfile: ```Dockerfile.boostrapped```

## A sample scenario 
The repostory comes with a powershell script (clone_latest_oa_images.ps1) which creates images containing the OneAgent artefacts which copy the artefacts into /home/dynatrace folder when the container is started and pushes the images into an Azure Container registry. **Note** The tagging scheme used by the script uses *rolling tags* as the version tag only contains the major and minor agent version. 

Included is as well a sample docker-compose file, that demonstrates the use of the image with a runtime integration as a side-car.

### How to run clone_latest_oa_images.ps1

``` ./clone_latest_oa_images.ps1 -DTDomain <YOUR-TENANT-ID>.live.dynatrace.com -DTUser <YOUR-TENANT-ID> -DTToken <YOUR-DT-API-TOKEN> -ACR <NAME-OF-AZURE-CONTAINER-REGISTRY> -ACRSubscription XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX -containerRuntime docker ```

The script will 
- login to Azure via azure-cli
- pulls latest oneagent code-modules from your Dynatrace tenant registry
- creates a new (bootstrapped) images, that copies the /opt/dynatrace/ folder into /home/dynatrace/ (using *Option 1* as described above)
- applies a new tagging schema

  ```
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-alpine-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-alpine-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-dotnet-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-dotnet-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-dotnet-alpine-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-dotnet-alpine-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-nodejs-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-nodejs-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-nodejs-alpine-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-nodejs-alpine-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-java-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-java-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-java-alpine-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-java-alpine-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-php-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-php-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-php-alpine-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-php-alpine-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-go-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-go-amd64-bootstrapped
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-go-alpine-amd64
  <TARGET-REPOSITORY>/oneagent-codemodules:<VERSION>-go-alpine-amd64-bootstrapped
  ```
  ... with 3 version variants: 
  * origin version when using immutible images (e.g. 1.301.48.20241007-103336)
  * rolling version tag with major.minor.x (e.g. 1.301.x)
  * and "latest" to reference the latest available version
* then pushes the images to the target (azure container) registry


