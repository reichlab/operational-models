# Ensemble of baseline models with trends for influenza

This should result in a model output directory and a plots directory under `flu_trends_ensemble/output`. Each of these two directories contain additional model subfolders for the component baseline models of the trends ensemble (named for the parameters used to create them) and the trends ensemble itself (UMass-trends_ensemble).

# requirements.txt and renv.lock details

`requirements.txt` and `renv.lock` were generated according to [README.md](../README.md). For `renv.lock`, we installed these specific libraries:

```bash
Rscript -e "renv::install(c('readr', 'fs', 'lubridate'))"
Rscript -e "renv::install('arrow')"
Rscript -e "renv::install('hubverse-org/hubData@*release')"
Rscript -e "renv::install('hubverse-org/hubVis@*release')"
Rscript -e "renv::install('reichlab/trendsEnsemble')"
Rscript -e "renv::install('reichlab/idforecastutils')"  # NB: installs dev versions of above
```
