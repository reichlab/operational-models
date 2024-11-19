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
        max_horizon=4,
        q_levels = [0.01, 0.025, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30,
                    0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70,
                    0.75, 0.80, 0.85, 0.90, 0.95, 0.975, 0.99],
        q_labels = ['0.01', '0.025', '0.05', '0.1', '0.15', '0.2',
                    '0.25', '0.3', '0.35', '0.4', '0.45', '0.5',
                    '0.55', '0.6', '0.65', '0.7', '0.75', '0.8',
                    '0.85', '0.9', '0.95', '0.975', '0.99'],
        num_warmup = 2000,
        num_samples = 2000,
        num_chains = 1
    )
    
    model = SARIXModel(model_config)
    model.run(run_config)
    
    subprocess.run(["Rscript", "plot.R", str(reference_date)])


if __name__ == "__main__":
    main()
