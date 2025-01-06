import click
import datetime
from pathlib import Path
from types import SimpleNamespace

from idmodels.gbqr import GBQRModel

@click.command()
@click.option(
    "--reference_date",
    type=str,
    required=True,
    help="Reference date for model run (YYYY-MM-DD)",
)
@click.option(
    "--short_run",
    is_flag=True,
    help="Perform a short run."
)
def main(reference_date: str, short_run: bool):
    """Generate flu predictions from gbqr model."""
    reference_date = datetime.date.fromisoformat(reference_date)
    
    model_config = SimpleNamespace(
        model_class = "gbqr",
        model_name = "gbqr",
        
        incl_level_feats = True,

        # bagging setup
        num_bags = 100,
        bag_frac_samples = 0.7,

        # adjustments to reporting
        reporting_adj = False,

        # data sources and adjustments for reporting issues
        sources = ["flusurvnet", "nhsn", "ilinet"],

        # fit locations separately or jointly
        fit_locations_separately = False,

        # power transform applied to surveillance signals
        power_transform = "4rt"
    )
    
    run_config = SimpleNamespace(
        ref_date=reference_date,
        output_root=Path("intermediate-output/model-output"),
        artifact_store_root=None,
        save_feat_importance=False,
        max_horizon=4,
        locations=["US", "01", "02", "04", "05", "06", "08", "09", "10", "11",
                   "12", "13", "15", "16", "17", "18", "19", "20", "21", "22",
                   "23", "24", "25", "26", "27", "28", "29", "30", "31", "32",
                   "33", "34", "35", "36", "37", "38", "39", "40", "41", "42",
                   "44", "45", "46", "47", "48", "49", "50", "51", "53", "54",
                   "55", "56", "72"],
        q_levels = [0.01, 0.025, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30,
                    0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70,
                    0.75, 0.80, 0.85, 0.90, 0.95, 0.975, 0.99],
        q_labels = ['0.01', '0.025', '0.05', '0.1', '0.15', '0.2',
                    '0.25', '0.3', '0.35', '0.4', '0.45', '0.5',
                    '0.55', '0.6', '0.65', '0.7', '0.75', '0.8',
                    '0.85', '0.9', '0.95', '0.975', '0.99']
    )
    if short_run:
        run_config.q_levels = [0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975]
        run_config.q_labels = ['0.025', '0.1', '0.25', '0.5', '0.75', '0.9', '0.975']
        model_config.num_bags = 10
    
    model = GBQRModel(model_config)
    model.run(run_config)


if __name__ == "__main__":
    main()
