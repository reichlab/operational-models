# Flusion model for influenza

# To run locally without Docker

To test this out locally, run the following with `flu_flusion` as your working directory.

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python main.py --today_date=2024-01-06 --short_run
```

This should result in a model output file and a pdf with a plot under `flu_flusion/output`. There will also be some other artifacts under `flu_flusion/intermediate-output/output` that we can ignore for now; at some point, we would like to commit those to a different repository.

# requirements.txt and renv.lock details

`requirements.txt` and `renv.lock` were generated according to [README.md](../README.md). For `renv.lock`, we installed these specific libraries:

```bash
Rscript -e "renv::install(c('dplyr'))"
Rscript -e "renv::install('arrow')"
Rscript -e "renv::install('reichlab/zoltr')"
Rscript -e "renv::install('hubverse-org/hubData@*release')"
Rscript -e "renv::install('hubverse-org/hubVis@*release')"
Rscript -e "renv::install('hubverse-org/hubEnsembles@*release')"
Rscript -e "renv::install('reichlab/covidData')"
Rscript -e "renv::install('reichlab/idforecastutils')"  # NB: installs dev versions of above
```
