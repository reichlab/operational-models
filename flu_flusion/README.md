# AR2 model for influenza

To test this out locally, run the following with `flu_ar2` as your working directory.  Note that somewhere along the line, incompatible versions of pandas and numpy ended up in a requirements file somewhere.  I have not dug into where or why that happened.  Here we manually override the pandas installation.

```
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python main.py --today_date=2024-01-06 --short_run
```

This should result in a model output file and a pdf with a plot under `flu_flusion/output`. There will also be some other artifacts under `flu_flusion/intermediate-output/output` that we can ignore for now; at some point, we would like to commit those to a different repository.
