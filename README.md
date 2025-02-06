# operational-models

Repository for automating runs of operational disease forecasting models.

# Docker instructions

This project supports containerizing its models via reusable [Dockerfile](Dockerfile) and [run.sh](run.sh) files. This works by passing various environment variables to `docker build` and `docker run` commands as documented below. The basic steps for containerizing a new model are:

- Create a subfolder for your model. This is called the `MODEL_DIR`. An example is `flu_ar2`.
- Add a `README.md` and your executable files (e.g., .R and .py files) to that folder (do not use subfolders).
- Generate `requirements.txt` and `renv.lock` files as documented below.
- Build and run the image as documented below. You will likely want to create a .env file for running the image (see `--env-file` at https://docs.docker.com/reference/cli/docker/container/run/#env ). NB: Do not use double quotes around variable values - see [Handle quotes in --env-file values consistently with Linux/WSL2 "source"ing #3630](https://github.com/docker/cli/issues/3630).

## To build the image

Environment variables: Building the [Dockerfile](Dockerfile) for a particular model uses the following environment variables:

- (required) `MODEL_DIR`: specifies the directory name (not full path) of the model being built. Example: `MODEL_DIR=flu_ar2`.

Example build command:

```bash
cd "path-to-this-repo"
docker build --build-arg MODEL_DIR=flu_ar2 --tag=flu_ar2:1.0 --file=Dockerfile .
```

## To run the image locally

Environment variables: There are two sources of environment variables used by this repo's containerization approach:

1. We use [reichlab/container-utils](https://github.com/reichlab/container-utils) to manage variables for GitHub credentials and Slack integration (messages and uploads). It requires the following variables (please see the repo's [README.md](https://github.com/reichlab/container-utils/blob/main/README.md) for details):
    - `SLACK_API_TOKEN`, `CHANNEL_ID` (required): used by slack.sh
    - `GH_TOKEN`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GIT_CREDENTIALS` (required): used by load-env-vars.sh
    - `DRY_RUN` (optional): when set (to anything), stops git commit actions from happening (default is to do commits).
2. This repo's [run.sh](run.sh) is parameterized to work with this repo's different models, so running the [Dockerfile](Dockerfile) for a particular model uses the following environment variables. These can be passed via [docker run](https://docs.docker.com/reference/cli/docker/container/run/)'s `--env` or `--env-file` args.
    - `MODEL_NAME` (required): Hub name of the model (i.e., the name used in model outputs). Example: `MODEL_NAME=UMass-AR2`
    - `REPO_URL` (required): Full URL of the repository being cloned, excluding ".git". Example: `REPO_URL=https://github.com/reichlab/FluSight-forecast-hub`
    - `REPO_UPSTREAM_URL` (required): Full URL of the repository that `REPO_URL` was forked from, excluding ".git". Example: `REPO_UPSTREAM_URL=https://github.com/cdcepi/FluSight-forecast-hub`
    - `MAIN_PY_ARGS` (optional): Specifies arguments that are passed through to [run.sh](run.sh)'s call to the particular model's `main.py`. Note that these arguments are model-specific. For example, the
      _flu_flusion_ model accepts two args: `MAIN_PY_ARGS=--today_date=2024-11-27 --short_run=True` whereas the
      `flu_ar2` model accepts only the former arg.

Example run command:

```bash
docker run --rm \
  --env-file path_to_env_file/git-and-slack-credentials.env \
  --env MODEL_NAME="UMass-AR2" \
  ... \
  --env DRY_RUN=1 \
  flu_ar2:1.0
```

## To publish the image

Use the following commands to build and push an image. These use the `flu_ar2` model as an example.

> Note: We build for the `amd64` architecture because that's what most Linux-based servers (including AWS) use natively. This is as opposed to Apple Silicon Macs, which have an `arm64` architecture.
> Note: For Macs with Apple silicon chips as of this writing, specifying `--platform=linux/amd64` causes the build to fail unless you disable Rosetta in Docker Desktop. For details, see [Buildx throws Illegal Instruction installing ca-certificates when building for linux/amd64 on M2 #7255](https://github.com/docker/for-mac/issues/7255).

```bash
cd "path-to-this-repo"
docker login -u "reichlab" docker.io
docker build --platform=linux/amd64 --build-arg MODEL_DIR=flu_ar2 --tag=reichlab/flu_ar2:1.0 --file=Dockerfile .
docker push reichlab/flu_ar2:1.0
```

# `requirements.txt` and `renv.lock` details

Each model has different R and Python library requirements. These are captured via Python [requirements.txt](https://pip.pypa.io/en/stable/reference/requirements-file-format/) and [renv](https://rstudio.github.io/renv/articles/renv.html) `renv.lock` files that are stored in each model's subdirectory. Following is how to create these.

## `requirements.txt`

Generating this file is somewhat Python tooling-specific. For example, [pipenv](https://pipenv.pypa.io/en/latest/) uses `pipenv requirements > requirements.txt`.

## `renv.lock`

A `renv.lock` file is generated via the following steps. As noted above, the "install required R libraries via CRAN" step will vary depending on the individual model's needs. Below we show the commands for the `flu_ar2` model, but you will need to change them for yours.

1. start a fresh temporary [rocker/r-ver:4.4.1](https://hub.docker.com/layers/rocker/r-ver/4.4.1/images/sha256-f3ef082e63ca36547fcf0c05a0d74255ddda6ca7bd88f1dae5a44ce117fc3804) container via:
   ```bash
   docker run --rm -it --name temp_container rocker/r-ver:4.4.1 /bin/bash
   ```
2. install the required OS libraries and applications (see "install general OS utilities" and "install OS binaries required by R packages" in the [Dockerfile](Dockerfile))
3. specify the [p3m repository snapshot to a particular date](https://p3m.dev/client/#/repos/cran/setup?distribution=ubuntu-22.04&r_environment=other&snapshot=2025-02-05) (this allows binary packages to be installed for faster builds) (see the [rocker-project guidance for switching the default CRAN mirror](https://rocker-project.org/images/versioned/r-ver.html#switch-the-default-cran-mirror)):
   ```bash
   /rocker_scripts/setup_R.sh https://p3m.dev/cran/__linux__/jammy/2025-02-05
   ```
4. install renv via:
   ```bash
   Rscript -e "install.packages('renv')"
   ```
5. create a project directory and initialize renv via:
   ```bash
   mkdir /proj ; cd /proj
   Rscript -e "renv::init(bare = TRUE)"
   ```
6. install required R libraries. NB: these will vary depending on the model (see each model's `README.md` for the actual list). For example:
   ```bash
   Rscript -e "renv::install(c('lubridate', 'readr', 'remotes'))"
   Rscript -e "renv::install('arrow')"
   Rscript -e "renv::install('reichlab/zoltr')"
   Rscript -e "renv::install('hubverse-org/hubData@*release')"
   Rscript -e "renv::install('hubverse-org/hubVis@*release')"
   ```
7. create `renv.lock` from within the R interpreter (this fails in bash) via:
   ```R
   renv::settings$snapshot.type('all') ; renv::snapshot()
   ```
8. copy the new `/proj/renv.lock` file out from the container
