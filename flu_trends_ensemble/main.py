import datetime
import subprocess

import click
from dateutil import relativedelta


@click.command()
@click.option(
    "--today_date",
    type=str,
    required=False,
    help="Date to use as effective model run date (YYYY-MM-DD)",
)
@click.option(
    "--use_versioned_data",
    is_flag=True,
    help="Fit and plot with the target data snapshot released on the Wednesday before the reference date (for "
         "retrospective runs) instead of the latest target data on the hub's GitHub repo",
)
def main(today_date: str | None = None, use_versioned_data: bool = False):
    """
    Simple wrapper around main.R that provides a `run.sh` entry point. Also, parses and passes `today_date` and
    `use_versioned_data`.
    """
    try:
        today_date = datetime.date.fromisoformat(today_date)
    except (TypeError, ValueError):  # if today_date is None or a bad format
        today_date = datetime.date.today()
    reference_date = today_date + relativedelta.relativedelta(weekday=5)

    subprocess.run(["Rscript", "main.R", str(reference_date), str(use_versioned_data)])


if __name__ == "__main__":
    main()
