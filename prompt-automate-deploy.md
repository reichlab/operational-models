This directory contains code for five forecast models, one per dir: covid_ar6_pooled, covid_gbqr, flu_ar2, flu_flusion, flu_trends_ensemble. These model directories are structured similarly so that we can build a Docker image from any one of them using the same @Dockerfile . This is done by passing a `MODEL_DIR` build variable that names the model being built (it's just the directory name, e.g., "covid_ar6_pooled".) When a change is made to this repo, or to @../idmodels (a dependency of this repo) I have to run a number of commands to deploy the Docker images to AWS. Deployment involves two online resources: Docker Hub and Amazon AWS ECS. (These resources are detailed under "Online resources" below.)

There are multiple steps involved to deploy updated models:

1. compute new image tags
2. build production images
3. push production images
4. update AWS task definitions

(These steps are detailed under "Deployment steps".)

We'd like to automate these steps. For now a bash shell script would be fine. Pay attention to these notes:

Notes:

- Pass any required credentials a environment variables.
- Build order: the script should accept an optional space-delimited list of model dir names to build, defaulting to all five if none passed.
- Failure handling: If one build fails, the script should stop and not continue with the others.
- Dry-run mode: Include support for a `--dry-run` flag to preview what would happen without executing. In dry-run mode, all commands that would be run should be printed, but no command that creates or edits resources should be run. I.e., it's ok to run read-only commands, such as `aws ecs describe-task-definition`, but not `aws ecs register-task-definition`. `docker login` is ok to run.
- `docker login`: let it run and query the user as needed, rather than trying to pass args via env vars.
- AWS region: Always use `us-east-1`.
- Docker Hub auth: The script should call `docker login` before any other `docker` commands.

Go ahead and analyze the problem and outline some solutions. We will then probably iterate back-and-forth.

# Deployment steps

## 1. compute new image tags

We first need to compute tags for each image. We do this by increasing the current version "point" value by one. For example, from the "Docker Hub" section below we see that we have these current image tags in the left column, which would result in the new tags shown in the right column:

| current_image_tag                | new_image_tag                    |
|----------------------------------|----------------------------------|
| reichlab/covid_ar6_pooled:1.5    | reichlab/covid_ar6_pooled:1.6    |
| reichlab/covid_gbqr:1.5          | reichlab/covid_gbqr:1.6          |
| reichlab/flu_ar2:1.2             | reichlab/flu_ar2:1.3             |
| reichlab/flu_flusion:1.2         | reichlab/flu_flusion:1.3         |
| reichlab/flu_trends_ensemble:1.3 | reichlab/flu_trends_ensemble:1.4 |

The safest place to get these names from is Docker Hub. If that's too difficult then they are probably available locally via `docker images`.

## 2. build production images

Images are built locally using `docker build`, passing it the `MODEL_DIR` value for the particular model being built.

Notes:

- You must use the image tags from the "compute new image tags" step.
- Each build can take upwards of 15 minutes.

Here's an example command to build the `covid_ar6_pooled` image. Note that we are building on macOS, and so we first have to disable Rosetta in Docker Desktop (Settings > General > "Use Rosetta for x86/AMD64 emulation on Apple Silicon.") That's because we are building `platform=linux/amd64`.

```bash
# disable Rosetta in Docker Desktop!

docker build --progress=plain \
  --build-arg MODEL_DIR=covid_ar6_pooled \
  --platform=linux/amd64 \
  --tag=reichlab/covid_ar6_pooled:1.6 \
  --file=Dockerfile \
  .

# re-enable Rosetta in Docker Desktop!
```

## 3. push production images

Built images are pushed to Docker Hub via the `docker push` command.

Notes:

- You must use the image tags from the "compute new image tags" step.
- The user may be prompted to log in.

Here's an example command to push the `covid_ar6_pooled` image:

```bash
docker push reichlab/covid_ar6_pooled:1.6
```

## 4. update AWS task definitions

Each task definition must be updated, which results in a new revision. Until now, we have updated them manually using the AWS console's "Create new revision with JSON" command and then editing the `containerDefinitions.image` field to the new tag, leaving all the other fields as-is. Here's the JSON shown for the `covid-ar6-pooled-model` task definition after I've incremented the tag to `"reichlab/covid_ar6_pooled:1.6"`:

```json
{
  "family": "covid-ar6-pooled-model",
  "containerDefinitions": [
    {
      "name": "covid-ar6-pooled-model-container",
      "image": "reichlab/covid_ar6_pooled:1.6",
      "cpu": 0,
      "portMappings": [],
      "essential": true,
      "environment": [],
      "environmentFiles": [
        {
          "value": "arn:aws:s3:::weekly-models/covid_ar6_pooled.env",
          "type": "s3"
        }
      ],
      "mountPoints": [],
      "volumesFrom": [],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/covid-ar6-pooled-model",
          "mode": "non-blocking",
          "awslogs-create-group": "true",
          "max-buffer-size": "25m",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "systemControls": []
    }
  ],
  "executionRoleArn": "arn:aws:iam::312560106906:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "volumes": [],
  "placementConstraints": [],
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "cpu": "1024",
  "memory": "3072",
  "runtimePlatform": {
    "cpuArchitecture": "X86_64",
    "operatingSystemFamily": "LINUX"
  }
}
```

# Online resources

## Docker Hub

Our user account for Docker hub is https://hub.docker.com/repositories/reichlab . Each model dir has a corresponding Docker hub repository with the same name:

| model_dir           | docker_hub_repo_url                                                           |
|---------------------|-------------------------------------------------------------------------------|
| covid_ar6_pooled    | https://hub.docker.com/repository/docker/reichlab/covid_ar6_pooled/general    |
| covid_gbqr          | https://hub.docker.com/repository/docker/reichlab/covid_gbqr/general          |
| flu_ar2             | https://hub.docker.com/repository/docker/reichlab/flu_ar2/general             |
| flu_flusion         | https://hub.docker.com/repository/docker/reichlab/flu_flusion/general         |
| flu_trends_ensemble | https://hub.docker.com/repository/docker/reichlab/flu_trends_ensemble/general |

Tags: We tag models in the format `1.*`. For example, the current latest models are:

- [reichlab/covid_ar6_pooled:1.5](https://hub.docker.com/repository/docker/reichlab/covid_ar6_pooled/tags/1.5/sha256-3e2c286d722e5115b950a94ec4af2080f32c772f40795fae78598f350a1c9c90)
- [reichlab/covid_gbqr:1.5](https://hub.docker.com/repository/docker/reichlab/covid_gbqr/tags/1.5/sha256-4b0492b77baab20e905c273f1a5853628521d5e723a1fb3b742494be721afdb2)
- [reichlab/flu_ar2:1.2](https://hub.docker.com/repository/docker/reichlab/flu_ar2/tags/1.2/sha256-fc450268ba4fdcd6eedc5597fecc2070c492db959a318d85aa211d45da3c073f)
- [reichlab/flu_flusion:1.2](https://hub.docker.com/repository/docker/reichlab/flu_flusion/tags/1.2/sha256-09fe6eaccf70a8f682cf952f2fdd0601c37b1f28a84a1ae594c7e420a15c8eb6)
- [reichlab/flu_trends_ensemble:1.3](https://hub.docker.com/repository/docker/reichlab/flu_trends_ensemble/tags/1.3/sha256-b2117044599d55b703e511a4da268380d0cdfd93d8a66dc74eddbc6354c8ff4d)

We do not use `latest` or similar tags.

## Amazon AWS ECS

### ECS Task Definitions

Each model image has a corresponding AWS ECS Task Definition with the same name as the model dir:

| model_dir           | task_def_url                                                                               |
|---------------------|--------------------------------------------------------------------------------------------|
| covid_ar6_pooled    | https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/covid-ar6-pooled-model    |
| covid_gbqr          | https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/covid-gbqr-model          |
| flu_ar2             | https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/flu-ar2-model             |
| flu_flusion         | https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/flu-flusion-model         |
| flu_trends_ensemble | https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/flu-trends-ensemble-model |

Here are the most recent Task Definition revisions:

- [covid-ar6-pooled-model:6](https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/covid-ar6-pooled-model/6/containers)
- [covid-gbqr-model:6](https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/covid-gbqr-model/6/containers)
- [flu-ar2-model:5](https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/flu-ar2-model/5/containers)
- [flu-flusion-model:4](https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/flu-flusion-model/4/containers)
- [flu-trends-ensemble-model:4](https://us-east-1.console.aws.amazon.com/ecs/v2/task-definitions/flu-trends-ensemble-model/4/containers)

### EventBridge Schedules

We use AWS EventBridge Schedules to automate running each task definition. Each Task Definition has a schedule with the same name:

| task_def               | schedule_url                                                                                                         |
|------------------------|----------------------------------------------------------------------------------------------------------------------|
| covid-ar6-pooled-model | https://us-east-1.console.aws.amazon.com/scheduler/home?region=us-east-1#schedules/default/covid-ar6-pooled-model    |
| covid_gbqr             | https://us-east-1.console.aws.amazon.com/scheduler/home?region=us-east-1#schedules/default/covid-gbqr-model          |
| flu_ar2                | https://us-east-1.console.aws.amazon.com/scheduler/home?region=us-east-1#schedules/default/flu-ar2-model             |
| flu_flusion            | https://us-east-1.console.aws.amazon.com/scheduler/home?region=us-east-1#schedules/default/flu-flusion-model         |
| flu_trends_ensemble    | https://us-east-1.console.aws.amazon.com/scheduler/home?region=us-east-1#schedules/default/flu-trends-ensemble-model |

The schedules all use latest task definition revision, so they do not need updating each time a model is released.

# CLAUDE IGNORE

## output
deploy.sh is ready. Here's a summary of what it does:

Tag computation — calls the Docker Hub public API (/v2/repositories/reichlab/<model>/tags/), finds the highest major.minor tag, and increments the
minor by 1. No Docker Hub credentials needed for this read.

Build — runs docker build with --platform=linux/amd64 and the computed tag. Remember to disable Rosetta in Docker Desktop before running (Settings
> General).

Push — docker push for each image using the new tag.

ECS update — fetches the current task definition via aws ecs describe-task-definition, strips the read-only fields AWS rejects (taskDefinitionArn,
revision, status, requiresAttributes, compatibilities, registeredAt, registeredBy), swaps the image field, and registers a new revision. Prints the
new family:revision on success.

Usage:
    # All five models
    DOCKER_HUB_USERNAME=you DOCKER_HUB_TOKEN=xxx ./deploy.sh
    
    # Subset
    DOCKER_HUB_USERNAME=you DOCKER_HUB_TOKEN=xxx ./deploy.sh flu_ar2 flu_flusion
    
    # Preview without writing anything (except docker login)
    DOCKER_HUB_USERNAME=you DOCKER_HUB_TOKEN=xxx ./deploy.sh --dry-run
    
    AWS credentials are picked up from the environment as normal (AWS_PROFILE, AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, etc.) — nothing special needed.
