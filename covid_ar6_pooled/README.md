# AR6 model for covid

To test this out locally, run the following with `covid_ar6_pooled` as your working directory.

```
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python main.py
```

This should result in a model output file and pdfs with plots under `covid_ar6_pooled/output`.
