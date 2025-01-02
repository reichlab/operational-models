# Gradient boosting model for covid

To test this out locally, run the following with `covid_gbqr` as your working directory.

```
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python main.py --today_date=2024-01-06 --short_run
```

This should result in a model output file and pdfs with plots under `covid_gbqr/output`.
