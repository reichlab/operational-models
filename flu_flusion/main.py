import datetime
import subprocess
from pathlib import Path

import click
from dateutil import relativedelta
from iddata.enums import Disease
from idmodels.config import (
    GBQRModelConfig,
    PoolingStrategy,
    PowerTransform,
    RunConfig,
    SARIXModelConfig,
    SourceType,
)
from idmodels.gbqr import GBQRModel
from idmodels.sarix import SARIXModel


_STATES = ["US", "01", "02", "04", "05", "06", "08", "09", "10", "11", "12", "13", "15", "16", "17", "18", "19", "20",
           "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38",
           "39", "40", "41", "42", "44", "45", "46", "47", "48", "49", "50", "51", "53", "54", "55", "56", "72"]

_Q_LEVELS = [0.01, 0.025, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75,
             0.80, 0.85, 0.90, 0.95, 0.975, 0.99]

_Q_LABELS = ["0.01", "0.025", "0.05", "0.1", "0.15", "0.2", "0.25", "0.3", "0.35", "0.4", "0.45", "0.5", "0.55", "0.6",
             "0.65", "0.7", "0.75", "0.8", "0.85", "0.9", "0.95", "0.975", "0.99"]


@click.command()
@click.option("--today_date", type=str, required=False)
@click.option("--short_run", is_flag=True)
def main(today_date: str | None = None, short_run: bool = False):
    """Generate flu predictions from flusion ensemble (AR6 + GBQR) and plot them."""
    try:
        today_date = datetime.date.fromisoformat(today_date)
    except (TypeError, ValueError):  # if today_date is None or a bad format
        today_date = datetime.date.today()
    reference_date = today_date + relativedelta.relativedelta(weekday=5)

    ar6_model_config = SARIXModelConfig(
        model_name="ar6_pooled",
        sources=[SourceType.NHSN],
        fit_locations_separately=False,
        p=6,
        P=0,
        d=0,
        D=0,
        season_period=1,
        power_transform=PowerTransform.FOURTH_ROOT,
        theta_pooling=PoolingStrategy.SHARED,
        sigma_pooling=PoolingStrategy.NONE,
        x=[],
        num_warmup=2000,
        num_samples=2000,
        num_chains=1)

    gbqr_model_config = GBQRModelConfig(
        model_name="gbqr",
        incl_level_feats=True,
        num_bags=100,
        bag_frac_samples=0.7,
        reporting_adj=False,
        save_feat_importance=False,
        sources=[SourceType.FLUSURVNET, SourceType.NHSN, SourceType.ILINET],
        fit_locations_separately=False,
        power_transform=PowerTransform.FOURTH_ROOT)

    ar6_run_config = RunConfig(
        disease=Disease.FLU,
        ref_date=reference_date,
        output_root=Path("intermediate-output/model-output"),
        artifact_store_root=None,
        max_horizon=4,
        states=_STATES,
        hsas=[],
        q_levels=_Q_LEVELS,
        q_labels=_Q_LABELS)

    gbqr_run_config = RunConfig(
        disease=Disease.FLU,
        ref_date=reference_date,
        output_root=Path("intermediate-output/model-output"),
        artifact_store_root=None,
        max_horizon=4,
        states=_STATES,
        hsas=[],
        q_levels=_Q_LEVELS,
        q_labels=_Q_LABELS)

    if short_run:
        for rc in (ar6_run_config, gbqr_run_config):
            rc.q_levels = [0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975]
            rc.q_labels = ["0.025", "0.1", "0.25", "0.5", "0.75", "0.9", "0.975"]
        ar6_model_config.num_warmup = 100
        ar6_model_config.num_samples = 100
        gbqr_model_config.num_bags = 10

    SARIXModel(ar6_model_config).run(ar6_run_config)
    GBQRModel(gbqr_model_config).run(gbqr_run_config)

    subprocess.run(["Rscript", "2_flusion_ensemble.R", str(reference_date)])
    subprocess.run(["Rscript", "3_plot.R", str(reference_date)])


if __name__ == "__main__":
    main()
