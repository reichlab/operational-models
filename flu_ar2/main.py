import dataclasses
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
from idmodels.sarix import SARIXModel


_STATES = ["US", "01", "02", "04", "05", "06", "08", "09", "10", "11", "12", "13", "15", "16", "17", "18", "19", "20",
           "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38",
           "39", "40", "41", "42", "44", "45", "46", "47", "48", "49", "50", "51", "53", "54", "55", "56", "72"]

_Q_LEVELS = [0.01, 0.025, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75,
             0.80, 0.85, 0.90, 0.95, 0.975, 0.99]

_Q_LABELS = ["0.01", "0.025", "0.05", "0.1", "0.15", "0.2", "0.25", "0.3", "0.35", "0.4", "0.45", "0.5", "0.55", "0.6",
             "0.65", "0.7", "0.75", "0.8", "0.85", "0.9", "0.95", "0.975", "0.99"]


@click.command()
@click.option("--today_date", type=str, required=False, help="Date to use as effective model run date (YYYY-MM-DD)")
@click.option("--short_run", is_flag=True, help="Run with reduced parameters for faster testing")
def main(today_date: str | None = None, short_run: bool = False):
    """Generate flu predictions from AR2 model for nhsn and nssp and plot them."""
    try:
        today_date = datetime.date.fromisoformat(today_date)
    except (TypeError, ValueError):  # if today_date is None or a bad format
        today_date = datetime.date.today()
    reference_date = today_date + relativedelta.relativedelta(weekday=5)

    nhsn_model_config = SARIXModelConfig(
        model_name="nhsn",
        main_source=SourceType.NHSN,
        fit_locations_separately=True,
        p=2,
        P=0,
        d=0,
        D=0,
        season_period=1,
        power_transform=PowerTransform.FOURTH_ROOT,
        theta_pooling=PoolingStrategy.NONE,
        sigma_pooling=PoolingStrategy.NONE,
        x=[],
        num_warmup=2000,
        num_samples=2000,
        num_chains=1)

    nssp_model_config = SARIXModelConfig(
        model_name="nssp",
        main_source=SourceType.NSSP,
        fit_locations_separately=True,
        p=2,
        P=0,
        d=0,
        D=0,
        season_period=1,
        power_transform=PowerTransform.FOURTH_ROOT,
        theta_pooling=PoolingStrategy.NONE,
        sigma_pooling=PoolingStrategy.NONE,
        x=[],
        num_warmup=2000,
        num_samples=2000,
        num_chains=1)

    run_config = RunConfig(
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
        run_config.q_levels = [0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975]
        run_config.q_labels = ["0.025", "0.1", "0.25", "0.5", "0.75", "0.9", "0.975"]
        nhsn_model_config.num_warmup = 100
        nhsn_model_config.num_samples = 100
        nssp_model_config.num_warmup = 100
        nssp_model_config.num_samples = 100

    nhsn_model = SARIXModel(nhsn_model_config)
    nhsn_model.run(run_config)
    # NSSP has no data for Puerto Rico, and Iowa has stopped reporting (all NA since 2026-07-04), which leaves a
    # trailing gap that SARIX can't fit through
    nssp_run_config = dataclasses.replace(run_config, states=[s for s in _STATES if s not in ("19", "72")])
    nssp_model = SARIXModel(nssp_model_config)
    nssp_model.run(nssp_run_config)

    subprocess.run(["Rscript", "1_ar2_concat.R", str(reference_date)])
    subprocess.run(["Rscript", "2_plot.R", str(reference_date)])


if __name__ == "__main__":
    main()
