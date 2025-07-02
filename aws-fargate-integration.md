# Integrate Dynatrace OneAgent into AWS Fargate 

The following instructions describe how to integrate Dynatrace OneAgent code-modules to your AWS Fargate using an initContaienr approach. 
The initContainer copies the Dynatrace OneAgent artefacts into a shared volume, from where the OneAgent is configured and activated via environment variables. 


## 1. Create an EFS Volume (Shared Storage)
``` Bash
aws efs create-file-system --creation-token dynatrace-fs --performance-mode generalPurpose
```
Save the FileSystemId returned (e.g., fs-0123456789abcdef0).


## 2. Create Mount Target for EFS
You must create one in the same VPC and subnet as your ECS tasks:

``` Bash

aws efs create-mount-target \
  --file-system-id fs-0123456789abcdef0 \
  --subnet-id <your-subnet-id> \
  --security-groups <sg-with-nfs-access>
```

Get the Task Definition 
``` bash
aws ecs describe-task-definition \
  --task-definition aspnet-with-dynatrace \
  --query "taskDefinition" \
  --output json > fargatetask.json
```

## 3. Add the oneagent init container to containerDefinitions: 
``` json
{
      "name": "initoneagent",
      "image": "docker.io/dynatrace/dynatrace-codemodules:1.315.68.20250627-182234",
      "entryPoint": ["/copy"],
      "command": [
        "--source=/opt/dynatrace/oneagent",
        "--target=/mnt/efs/oneagent",
        "--technology=dotnet"
      ],
      "essential": false,
      "mountPoints": [
        {
          "containerPath": "/mnt/efs",
          "sourceVolume": "oneagentvolume"
        }
      ]
    },
```

## 4. Add the shared mount and necessary dependency and environment variables to your main container: 
```json 
 "dependsOn": [
        {
          "containerName": "initoneagent",
          "condition": "COMPLETE"
        }
      ],
   "mountPoints": [
        {
          "containerPath": "/mnt/efs",
          "sourceVolume": "oneagentvolume"
        }
      ],
      "environment": [
        { "name": "DT_TENANT", "value": "<Your Tenant>" },
        { "name": "DT_TENANTTOKEN", "value": "<Your Token>" },
        { "name": "DT_CONNECTION_POINT", "value": "<Your Connection Point>" },
        { "name": "LD_PRELOAD", "value": "/mnt/efs/oneagent/agent/lib64/liboneagentproc.so" },
        { "name": "DT_AGENTACTIVE", "value": "true" },
        { "name": "DT_LOGSTREAM", "value": "stdout" },
        { "name": "DT_LOGLEVELCON", "value": "INFO" }
      ]
```

Your task definiton then may look like this for asp.net sample application:
```json
{
  "family": "aspnet-with-dynatrace",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::<your-account>:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "initoneagent",
      "image": "public.ecr.aws/dynatrace/dynatrace-codemodules:1.315.68.20250627-182234",
      "entryPoint": ["/copy"],
      "command": [
        "--source=/opt/dynatrace/oneagent",
        "--target=/mnt/efs/oneagent",
        "--technology=dotnet"
      ],
      "essential": false,
      "mountPoints": [
        {
          "containerPath": "/mnt/efs",
          "sourceVolume": "oneagentvolume"
        }
      ]
    },
    {
      "name": "myaspnetapp",
      "image": "mcr.microsoft.com/dotnet/samples:aspnetapp",
      "essential": true,
      "dependsOn": [
        {
          "containerName": "initoneagent",
          "condition": "COMPLETE"
        }
      ],
      "mountPoints": [
        {
          "containerPath": "/mnt/efs",
          "sourceVolume": "oneagentvolume"
        }
      ],
      "environment": [
        { "name": "DT_TENANT", "value": "<Your Tenant>" },
        { "name": "DT_TENANTTOKEN", "value": "<Your Token>" },
        { "name": "DT_CONNECTION_POINT", "value": "<Your Connection Point>" },
        { "name": "LD_PRELOAD", "value": "/mnt/efs/oneagent/agent/lib64/liboneagentproc.so" },
        { "name": "DT_AGENTACTIVE", "value": "true" },
        { "name": "DT_LOGSTREAM", "value": "stdout" },
        { "name": "DT_LOGLEVELCON", "value": "INFO" }
      ]
    }
  ],
  "volumes": [
    {
      "name": "oneagentvolume",
      "efsVolumeConfiguration": {
        "fileSystemId": "fs-0123456789abcdef0",
        "rootDirectory": "/",
        "transitEncryption": "ENABLED"
      }
    }
  ]
}
```

## 5. Register the updated task definition to create a new revision
```bash
aws ecs register-task-definition \
  --cli-input-json file://fargatetask.json
```
## 6.  Update your ECS service to use the new revision
If you're using a service (not run-task), update it to use the latest revision:

``` bash
aws ecs update-service \
  --cluster <your-cluster-name> \
  --service <your-service-name> \
  --task-definition <task-definition-name>:<revision>
```
Or to always point to the latest revision:

``` bash
aws ecs update-service \
  --cluster <your-cluster-name> \
  --service <your-service-name> \
  --task-definition <task-definition-name>
```
AWS will automatically use the latest revision.
