#
# A wrapper script to run the baseline model, messaging slack with progress and results.
#
# Environment variables (see https://github.com/reichlab/container-utils/blob/main/README.md for details):
# - `SLACK_API_TOKEN`, `CHANNEL_ID` (required): used by slack.sh
# - `GH_TOKEN`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GIT_CREDENTIALS` (required): used by load-env-vars.sh
# - `DRY_RUN` (optional): when set (to anything), stops git commit actions from happening (default is to do commits)
#

#
# load environment variables and then slack functions
#

APP_DIR=$(pwd)

echo "sourcing: load-env-vars.sh"
source "${APP_DIR}/container-utils/scripts/load-env-vars.sh"

echo "sourcing: slack.sh"
source "${APP_DIR}/container-utils/scripts/slack.sh"

#
# start
#

slack_message "starting. id='$(id -u -n)', HOME='${HOME}', PWD='${PWD}', DRY_RUN='${DRY_RUN+x}'"

#
# build the model
#

OUT_FILE=/tmp/run-baseline-out.txt

python3 "${APP_DIR}/main.py" >${OUT_FILE} 2>&1
PYTHON_RESULT=$?

if [ ${PYTHON_RESULT} -ne 0 ]; then
  # python had errors
  slack_message "python failed"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

#
# python had no errors. find PDF and CSV files, add new CSV file to new branch, and then upload the PDF to slack.
# example output files (under /app):
#   ./output/model-output/UMass-AR2/2024-01-06-UMass-AR2.csv
#   ./output/plots/2024-01-06-UMass-AR2.pdf

slack_message "python OK; collecting PDF and CSV files"

CSV_FILES=$(find "${APP_DIR}/output" -type f -name "*.csv")
NUM_CSV_FILES=$(echo "${CSV_FILES}" | wc -l)
if [ "${NUM_CSV_FILES}" -ne 1 ]; then
  slack_message "CSV_FILES error: not exactly 1 CSV file. CSV_FILES='${CSV_FILES}', NUM_CSV_FILES=${NUM_CSV_FILES}"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

PDF_FILES=$(find "${APP_DIR}/output" -type f -name "*.pdf")
NUM_PDF_FILES=$(echo "${PDF_FILES}" | wc -l)
if [ "${NUM_PDF_FILES}" -ne 1 ]; then
  slack_message "PDF_FILES error: not exactly 1 PDF file. PDF_FILES='${PDF_FILES}', NUM_PDF_FILES=${NUM_PDF_FILES}"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

# found exactly one CSV and one PDF file
CSV_FILE=${CSV_FILES}
PDF_FILE=${PDF_FILES}
slack_message "found: CSV_FILE='${CSV_FILE}', PDF_FILE='${PDF_FILE}'"

if [ -n "${DRY_RUN+x}" ]; then # yes DRY_RUN
  slack_message "DRY_RUN set, exiting"
  exit 0 # success
fi

# create and push a branch with the new CSV file, first cloniing the repo and deleting any previous branch. the repo is
# the reichlab fork of the upstream cdcepi/FluSight-forecast-hub repo . the branch name is the csv file's basename minus
# the extension, e.g., '2024-01-06-UMass-AR2'

# clone the repo
HUB_DIR="${APP_DIR}/FluSight-forecast-hub"
git clone https://github.com/reichlab/FluSight-forecast-hub.git "${HUB_DIR}"
cd ${HUB_DIR}

# delete old branch
CSV_FILE_BASENAME=$(basename "${CSV_FILE%.*}") # Parameter Expansion per: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_02
BRANCH_NAME=${CSV_FILE_BASENAME}

slack_message "deleting old branch if present. BRANCH_NAME='${BRANCH_NAME}'"
git branch --delete --force "${BRANCH_NAME}" # delete local branch
git push origin --delete "${BRANCH_NAME}"    # delete remote branch

# create new branch, add the .csv file, and push
slack_message "creating branch and pushing"
git checkout -b "${BRANCH_NAME}"
cp "${CSV_FILE}" "${HUB_DIR}/model-output/UMass-AR2"
git add model-output/UMass-AR2/\*
git commit -m "flu_ar2 build"
git push -u origin "${BRANCH_NAME}"
PUSH_RESULT=$?

if [ ${PUSH_RESULT} -ne 0 ]; then
  slack_message "push failed"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

# the "compare" url should show a "Create pull request" button:
slack_message "push OK. branch comparison: https://github.com/reichlab/FluSight-forecast-hub/compare/main...${GIT_USER_NAME}:FluSight-forecast-hub:${BRANCH_NAME}?expand=1"

# upload PDF
slack_upload "${PDF_FILE}"

#
# done
#

slack_message "done"
exit 0 # success
