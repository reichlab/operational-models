import datetime
import subprocess
from pathlib import Path

import click
from dateutil import relativedelta
from iddata.enums import Disease
from idmodels.config import (
    PoolingStrategy,
    PowerTransform,
    RunConfig,
    SampleIdScheme,
    SARIXFourierModelConfig,
    SourceType,
)
from idmodels.sarix import SARIXFourierModel

# last target end date to forecast
SEASON_END_DATE = datetime.date(2027, 6, 12)


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
    """Generate flu metrocast predictions from AR(6) Fourier model and plot them."""
    try:
        today_date = datetime.date.fromisoformat(today_date)
    except (TypeError, ValueError):  # if today_date is None or a bad format
        today_date = datetime.date.today()
    reference_date = today_date + relativedelta.relativedelta(weekday=5)
    # forecast through the end of the season. idmodels counts horizons from the last observed week (the week before
    # reference_date), so reaching hub horizon h takes h + 1 model horizons
    max_horizon = (SEASON_END_DATE - reference_date).days // 7 + 1
    if max_horizon < 1:
        raise ValueError(f"reference_date {reference_date} is after the end of the season ({SEASON_END_DATE})")

    model_config = SARIXFourierModelConfig(
        model_name = "SAR",

        # data sources and adjustments for reporting issues
        main_source = SourceType.NSSP,

        # fit locations separately or jointly
        fit_locations_separately = False,

        # SARI model parameters
        p = 6,
        P = 0,
        d = 0,
        D = 0,
        season_period = 1,

        # power transform applied to surveillance signals
        power_transform = PowerTransform.FOURTH_ROOT,

        # sharing of information about parameters
        theta_pooling = PoolingStrategy.SHARED,
        sigma_pooling = PoolingStrategy.NONE,
        fourier_pooling = PoolingStrategy.SHARED,

        # Fourier seasonality parameters
        fourier_K = 2, # A number of Fourier harmonic pairs for annual seasonality

        # covariates
        x = [],

        # MCMC settings; num_samples * num_chains must be at least num_sample_forecasts
        num_warmup = 2000,
        num_samples = 2000,
        num_chains = 1
    )

    run_config = RunConfig(
        disease=Disease.FLU,
        ref_date=reference_date,
        output_root=Path("intermediate-output/model-output"),
        artifact_store_root=None,
        max_horizon=max_horizon,
        states=["08", "13", "18", "23", "24", "25", "27", "36", "37", "41", "45", "48", "49", "51"],
        hsas=["688", "711", "754", "760", "795", "796", #colorado
            "275", #indiana
            "143", "154", "157", "190", "193", #georgia
            "825", "826", "829", "830", "893", "894", #georgia
            "22", "32", "68", "74", "101", "112", #massachusetts
            "16", "48", #maryland
            "869", "875", #maryland
            "9", "17", #maine
            "286", "289", "540", "588", "941", #minnesota
            "689", "705", "719", "782", "973", #oregon
            "160", "182", "184", "212", "244", "246", #south-carolina
            "408", "410", "413", "415", "425", "453", #texas
            "405", "406", "427", "434", "437", "441", "452", "462", #texas
            "464", "495", "505", "510", "520", "532", "538", #texas
            "14"], # virginia
        # samples only: the hub doesn't take quantiles
        q_levels = [],
        q_labels = [],
        # the hub requires exactly 100 samples per location. Draws are numbered 1-100 here, and
        # 0_sar_format_metrocast.R prefixes them with each hub location name to make them unique across locations
        num_sample_forecasts = 100,
        sample_id_scheme = SampleIdScheme.DRAW_NUMBER,
        # skip locations without data for the latest week (e.g. a state reporting late), which SARIX can't fit
        drop_incomplete_locations = True
    )
    if short_run:
        model_config.num_warmup = 100
        model_config.num_samples = 100

    model = SARIXFourierModel(model_config)
    model.run(run_config)

    subprocess.run(["Rscript", "0_sar_format_metrocast.R", str(reference_date)])
    subprocess.run(["Rscript", "1_plot.R", str(reference_date)])


if __name__ == "__main__":
    main()
