import click


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
@click.command()
def main(today_date: str | None = None, short_run: bool = False):
    """
    A no-op model for testing Docker image build and deploy. Generates no output .csv or .pdf files and so will cause
    the container to fail when it runs.
    """
    click.echo(f"temp main(). {today_date=}, {short_run=}")


if __name__ == "__main__":
    main()
