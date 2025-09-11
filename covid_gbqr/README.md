# Gradient boosting model for covid

To test this out locally, run the following with `covid_gbqr` as your working directory.

```
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python main.py --today_date=2024-01-06 --short_run
```

This should result in a model output file and pdfs with plots under `covid_gbqr/output`.

# requirements.txt and renv.lock details

`requirements.txt` and `renv.lock` were generated according to [README.md](../README.md). For `renv.lock`, we installed these specific libraries:

```bash
Rscript -e "renv::install(c('lubridate', 'readr', 'dplyr'))"
Rscript -e "renv::install('arrow')"
Rscript -e "renv::install('reichlab/zoltr')"
Rscript -e "renv::install('hubverse-org/hubData@*release')"
Rscript -e "renv::install('hubverse-org/hubVis@*release')"
Rscript -e "renv::install('hubverse-org/hubEnsembles@*release')"
Rscript -e "renv::install('Chicago/RSocrata')"  # required by covidData, but CRAN install fails
Rscript -e "renv::install('reichlab/covidData')"
Rscript -e "renv::install('reichlab/idforecastutils')"  # NB: installs dev versions of above
```
