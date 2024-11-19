# AR2 model for influenza

To test this out locally, run the following with `flu_ar2` as your working directory.  Note that somewhere along the line, incompatible versions of pandas and numpy ended up in a requirements file somewhere.  I have not dug into where or why that happened.  Here we manually override the pandas installation.

```
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
pip install --upgrade pandas

python main.py --today_date=2024-01-06
```

This should result in a model output file and a pdf with a plot under `flu_ar2/output`.

# Docker commands

## To build the image

```bash
cd "path-to-this-repo"
docker build --tag=flu_ar2:1.0 --file=flu_ar2/Dockerfile .
```

## To run the image locally

```bash
docker run --rm \
  --mount type=volume,src=data_volume,target=/data \
  --env-file /path-to-env-dir/.env \
  flu_ar2:1.0
```

## To publish the image

> Note: We build for the `amd64` architecture because that's what most Linux-based servers (including AWS) use natively. This is as opposed to Apple Silicon Macs, which have an `arm64` architecture.

```bash
cd "path-to-this-repo"
docker login -u "reichlab" docker.io
docker build --platform=linux/amd64 --tag=reichlab/flu_ar2:1.0 --file=flu_ar2/Dockerfile .
docker push reichlab/flu_ar2:1.0
```
