# AR2 model for influenza

To test this out locally, run the following with `flu_ar2` as your working directory.  Note that somewhere along the line, incompatible versions of pandas and numpy ended up in a requirements file somewhere.  I have not dug into where or why that happened.  Here we manually override the pandas installation.

```
cd <this_repo>
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
pip install --upgrade pandas

cd fl_ar2
python main.py --today_date=2024-01-06
```

This should result in a model output file and a pdf with a plot under `flu_ar2/output`.
