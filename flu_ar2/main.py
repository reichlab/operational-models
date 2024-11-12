import click
import datetime
from dateutil import relativedelta
from pathlib import Path
import subprocess
from types import SimpleNamespace

from idmodels.sarix import SARIXModel

@click.command()
@click.option(
    "--today_date",
    type=str,
    required=False,
    help="Date to use as effective model run date (YYYY-MM-DD)",
)
def main(today_date: str | None = None):
    """Get clade counts and save to S3 bucket."""
    try:
        today_date = datetime.date.fromisoformat(today_date)
    except (TypeError, ValueError):  # if today_date is None or a bad format
        today_date = datetime.date.today()
    reference_date = today_date + relativedelta.relativedelta(weekday=5)
    
    model_config = SimpleNamespace(
        model_class = "sarix",
        model_name = "AR2",
        
        # data sources and adjustments for reporting issues
        sources = ["nhsn"],

        # fit locations separately or jointly
        fit_locations_separately = True,

        # SARI model parameters
        p = 2,
        P = 0,
        d = 0,
        D = 0,
        season_period = 1,

        # power transform applied to surveillance signals
        power_transform = "4rt",

        # sharing of information about parameters
        theta_pooling="none",
        sigma_pooling="none",
        
        # covariates
        x = []
    )
    
    run_config = SimpleNamespace(
        ref_date=reference_date,
        output_root=Path("output/model-output"),
        artifact_store_root=None,
        max_horizon=5,
        q_levels = [0.025, 0.50, 0.975],
        q_labels = ["0.025", "0.5", "0.975"],
        num_warmup = 2000,
        num_samples = 2000,
        num_chains = 1
    )
    
    model = SARIXModel(model_config)
    model.run(run_config)
    
    subprocess.run(["Rscript", "plot.R", str(reference_date)])


if __name__ == "__main__":
    main()
