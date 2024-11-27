# AR2 model for influenza

To test this out locally, run the following with `flu_ar2` as your working directory.  Note that somewhere along the line, incompatible versions of pandas and numpy ended up in a requirements file somewhere.  I have not dug into where or why that happened.  Here we manually override the pandas installation.

```
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python main.py --today_date=2024-01-06
```

This should result in a model output file and a pdf with a plot under `flu_ar2/output`.

# renv details

The `renv.lock` file was generated via these steps:

- start a fresh temporary [rocker/r-ver:4.3.2](https://hub.docker.com/layers/rocker/r-ver/4.3.2/images/sha256-8b25859fbf21a7075bbc2285ebfe06bb8a14dd83e4576df11ff46f14a8620636?context=explore) container via `docker run --rm -it --name temp_container rocker/r-ver:4.3.2 /bin/bash`
- install the required OS libraries and applications (see "install general OS utilities" and "install OS binaries required by R packages" in the Dockerfile)
- install renv via `Rscript -e "install.packages('renv', repos = c(CRAN = 'https://cloud.r-project.org'))"`
- create a project directory via `mkdir proj ; cd proj`
- initialize renv via `Rscript -e "renv::init(bare = TRUE)"`
- install required R libraries via CRAN:
```bash
Rscript -e "renv::install(c('lubridate', 'readr', 'remotes'))"
Rscript -e "renv::install('arrow', repos = c('https://apache.r-universe.dev', 'https://cran.r-project.org'))"
Rscript -e "renv::install('reichlab/zoltr')"
Rscript -e "renv::install('hubverse-org/hubData')"
Rscript -e "renv::install('hubverse-org/hubVis')"
```
- create `renv.lock` from within the R interpreter (fails in bash) via `renv::settings$snapshot.type('all') ; renv::snapshot()`
- copying the new `/proj/renv.lock` file out from the container

# Docker commands

## To build the image

```bash
cd "path-to-this-repo"
docker build --tag=flu_ar2:1.0 --file=flu_ar2/Dockerfile .
```

## To run the image locally

```bash
docker run --rm flu_ar2:1.0
```

## To publish the image

> Note: We build for the `amd64` architecture because that's what most Linux-based servers (including AWS) use natively. This is as opposed to Apple Silicon Macs, which have an `arm64` architecture.

```bash
cd "path-to-this-repo"
docker login -u "reichlab" docker.io
docker build --platform=linux/amd64 --tag=reichlab/flu_ar2:1.0 --file=flu_ar2/Dockerfile .
docker push reichlab/flu_ar2:1.0
```
