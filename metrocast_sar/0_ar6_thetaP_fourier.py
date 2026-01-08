import click
import datetime
from pathlib import Path
from types import SimpleNamespace

from idmodels.sarix import SARIXFourierModel

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
    """Generate Metrocast flu predictions from an AR(6) model with Fourier seasonality."""
    reference_date = datetime.date.fromisoformat(reference_date)
    
    model_config = SimpleNamespace(
        model_class = "sarix",
        model_name = "SAR",
        
        # data sources and adjustments for reporting issues
        sources = ["nssp"],
        
        # fit locations separately or jointly
        fit_locations_separately = False,
        
        # SARI model parameters
        p = 6,
        P = 0,
        d = 0,
        D = 0,
        season_period = 1,
        
        # power transform applied to surveillance signals
        power_transform = "4rt",
        
        # sharing of information about parameters
        theta_pooling="shared",
        sigma_pooling="none",
        fourier_pooling="shared",
        
        # Fourier seasonality parameters
        fourier_K = 2, # A number of Fourier harmonic pairs for annual seasonality
        
        # covariates
        x = []
    )
    
    run_config = SimpleNamespace(
        disease="flu",
        ref_date=reference_date,
        output_root=Path("intermediate-output/model-output"),
        artifact_store_root=None,
        max_horizon=4,
        states=["08", "13", "18", "23", "24", "25", "27", "45", "48", "49", "51"],
        hsas=["688", "711", "754", "760", "795", "796", #colorado
            "275", #indiana
            "143", "154", "157", "190", "193", #georgia
            "825", "826", "829", "830", "893", "894", #georgia
            "22", "32", "68", "74", "101", "112", #massachusetts
            "16", "48", #maryland
            "869", "875", "941" #maryland
            "9", "17", #maine
            "286", "289", "540", "588", "941", #minnesota
            "160", "182", "184", "212", "244", "246", #south-carolina
            "408", "410", "413", "415", "425", "453", #texas
            "703", "708", "744", #utah
            "14"], # virginia
        q_levels = [0.025, 0.05, 0.10, 0.25, 0.50, 0.75, 0.9, 0.95, 0.975],
        q_labels = ["0.025", "0.05", "0.1", "0.25", "0.5", "0.75", "0.9", "0.95", "0.975"],
        num_warmup = 2000,
        num_samples = 2000,
        num_chains = 1
    )
    if short_run:
        run_config.q_levels = [0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975]
        run_config.q_labels = ['0.025', '0.1', '0.25', '0.5', '0.75', '0.9', '0.975']
        run_config.num_warmup = 100
        run_config.num_samples = 100
    
    model = SARIXFourierModel(model_config)
    model.run(run_config)


if __name__ == "__main__":
    main()
