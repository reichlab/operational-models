# Gradient boosting model for covid

To test this out locally, run the following with `covid_gbqr` as your working directory.

```
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python main.py --today_date=2024-01-06 --short_run
```

This should result in a model output file and pdfs with plots under `covid_gbqr/output`.

# requirements.txt renv and details

`requirements.txt` and `renv.lock` were generated according to [README.md](..%2FREADME.md). For `renv.lock`, we installed these specific libraries:

```bash
Rscript -e "renv::install(c('lubridate', 'readr', 'dplyr'))"
Rscript -e "renv::install('arrow', repos = c('https://apache.r-universe.dev', 'https://cran.r-project.org'))"
Rscript -e "renv::install('git::https://github.com/reichlab/zoltr')"
Rscript -e "renv::install('git::https://github.com/hubverse-org/hubData')"
Rscript -e "renv::install('git::https://github.com/hubverse-org/hubVis')"
Rscript -e "renv::install('git::https://github.com/hubverse-org/hubEnsembles')"
Rscript -e "renv::install('git::https://github.com/reichlab/covidData')"
Rscript -e "renv::install('git::https://github.com/reichlab/idforecastutils')"
```
