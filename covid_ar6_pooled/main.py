import datetime

import click
from dateutil import relativedelta

from util.utils import run_script


@click.command()
@click.option(
    "--today_date",
    type=str,
    required=False,
    help="Date to use as effective model run date (YYYY-MM-DD)",
)
@click.option(
    "--short_run",
    is_flag=True,
    help="Perform a short run."
)
def main(today_date: str | None = None, short_run: bool = False):
    """Generate covid predictions from AR(6) model and plot them."""
    try:
        today_date = datetime.date.fromisoformat(today_date)
    except (TypeError, ValueError):  # if today_date is None or a bad format
        today_date = datetime.date.today()
    reference_date = today_date + relativedelta.relativedelta(weekday=5)
    
    if short_run:
        short_run_flag = ["--short_run"]
    else:
        short_run_flag = []
    
    for script_args in [["python", "0_ar6_pooled.py", "--reference_date", str(reference_date)] + short_run_flag,
                        ["Rscript", "1_plot.R", str(reference_date)]]:
        run_script(script_args)


if __name__ == "__main__":
    main()
