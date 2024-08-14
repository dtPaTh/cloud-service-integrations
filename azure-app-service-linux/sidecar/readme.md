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
