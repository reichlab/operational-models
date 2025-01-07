import subprocess
import sys


def run_script(process_args):
    """
    Simple util that calls `subprocess.run()` on `process_args`, exiting with status 1 if the process did not return 0.

    :param process_args: list of `subprocess.run()` args
    """
    completed_process = subprocess.run(process_args)
    if completed_process.returncode != 0:
        print(f"error calling script: {process_args}")
        sys.exit(1)  # 0: Success, 1: General Error
