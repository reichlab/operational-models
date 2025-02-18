#
# A wrapper script to run the a model, messaging slack with progress and results.
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
# check for additional required environment variables
#

if [ -z ${MODEL_NAME+x} ] || [ -z ${REPO_URL+x} ] || [ -z ${REPO_UPSTREAM_URL+x} ]; then
  slack_message "one or more additional required environment variables were unset: MODEL_NAME='${MODEL_NAME}', REPO_URL='${REPO_URL}', REPO_UPSTREAM_URL='${REPO_UPSTREAM_URL}'"
  exit 1 # fail
else
  slack_message "found all additional required environment variables"
fi

#
# start
#

slack_message "${MODEL_NAME}: entered. id=$(id -u -n), HOME=${HOME}, PWD=${PWD}, DRY_RUN='${DRY_RUN+x}', GIT_USER_NAME=${GIT_USER_NAME}, MODEL_NAME=${MODEL_NAME}, REPO_URL=${REPO_URL}, REPO_UPSTREAM_URL=${REPO_UPSTREAM_URL}"

#
# build the model
#

slack_message "${MODEL_NAME}: calling main.py"

OUT_FILE=/tmp/run-out.txt
python3 "${APP_DIR}"/main.py ${MAIN_PY_ARGS} >${OUT_FILE} 2>&1  # NB: important to not double-quote MAIN_PY_ARGS
PYTHON_RESULT=$?

if [ ${PYTHON_RESULT} -ne 0 ]; then
  # python had errors
  slack_message "${MODEL_NAME}: python failed"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

#
# python had no errors. find CSV/PARQUET (1) and PDF (1+) files, add new CSV/PARQUET file to new branch, and then upload
# the PDFs to slack. example output files (under /app):
#   ./output/model-output/UMass-AR2/2024-01-06-UMass-AR2.csv
#   ./output/plots/2024-01-06-UMass-AR2.pdf

slack_message "${MODEL_NAME}: python OK; collecting PDF and CSV/PARQUET files"

MODEL_OUTPUT_FILES=($(find "${APP_DIR}/output/model-output/${MODEL_NAME}" -type f \( -name "*.csv" -o -name "*.parquet" \) )) # creates an array from find output
NUM_MODEL_OUTPUT_FILES=${#MODEL_OUTPUT_FILES[@]}
if [ "${NUM_MODEL_OUTPUT_FILES}" -ne 1 ]; then
  slack_message "${MODEL_NAME}: MODEL_OUTPUT_FILES error: not exactly 1 CSV/PARQUET file. NUM_MODEL_OUTPUT_FILES=${NUM_MODEL_OUTPUT_FILES}"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

PDF_FILES=($(find "${APP_DIR}/output" -type f -name "*.pdf")) # parens: find output -> array
NUM_PDF_FILES=${#PDF_FILES[@]}
if [ "${NUM_PDF_FILES}" -eq 0 ]; then
  slack_message "${MODEL_NAME}: PDF_FILES error: no PDF files"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

# found 1 CSV/PARQUET and 1+ PDF file
MODEL_OUTPUT_FILE=${MODEL_OUTPUT_FILES[0]}
slack_message "${MODEL_NAME}: found: MODEL_OUTPUT_FILE=${MODEL_OUTPUT_FILE}, PDF_FILES=$(IFS=,; echo "${PDF_FILES[*]}")"  # array -> comma-sep string

if [ -n "${DRY_RUN+x}" ]; then # yes DRY_RUN
  slack_message "${MODEL_NAME}: DRY_RUN set, exiting"
  slack_upload ${OUT_FILE}
  exit 0 # success
fi

# create and push a branch with the new CSV file, first cloniing the repo and deleting any previous branch. the repo is
# the reichlab fork of the upstream cdcepi/FluSight-forecast-hub repo . the branch name is the csv file's basename minus
# the extension, e.g., '2024-01-06-UMass-AR2'

# clone the repo
HUB_DIR="${APP_DIR}/hub-repo"  # hard-coded repo name
slack_message "${MODEL_NAME}: cloning ${REPO_URL} -> ${HUB_DIR}"
git clone "${REPO_URL}" "${HUB_DIR}"
cd ${HUB_DIR}

# sync fork w/upstream and then push to the fork
slack_message "${MODEL_NAME}: updating fork from upstream"
git remote add upstream "${REPO_UPSTREAM_URL}"
git fetch upstream # pull down the latest source from original repo
git checkout main
git merge upstream/main # update fork from original repo to keep up with their changes
git push origin main    # sync with fork

# delete old branch
MODEL_OUTPUT_FILE_BASENAME=$(basename "${MODEL_OUTPUT_FILE%.*}") # Parameter Expansion per: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_02
BRANCH_NAME=${MODEL_OUTPUT_FILE_BASENAME}               # e.g., "2024-11-30-UMass-AR2"

slack_message "${MODEL_NAME}: deleting old branch if present. BRANCH_NAME='${BRANCH_NAME}'"
git branch --delete --force "${BRANCH_NAME}" # delete local branch
git push origin --delete "${BRANCH_NAME}"    # delete remote branch

# create new branch, add the .csv file, and push
slack_message "${MODEL_NAME}: creating branch and pushing"
git checkout -b "${BRANCH_NAME}"
cp "${MODEL_OUTPUT_FILE}" "${HUB_DIR}/model-output/${MODEL_NAME}"
git add model-output/"${MODEL_NAME}"/\*
git commit -m "${BRANCH_NAME}"
git push -u origin "${BRANCH_NAME}"
PUSH_RESULT=$?

if [ ${PUSH_RESULT} -ne 0 ]; then
  slack_message "${MODEL_NAME}: push failed"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

# this url shows an "Open a pull request" form with a "Create pull request" button. ex:
# https://github.com/reichlab/FluSight-forecast-hub/pull/new/2024-12-21-UMass-AR2 , which redirects to:
# https://github.com/cdcepi/FluSight-forecast-hub/compare/main...reichlab:FluSight-forecast-hub:2024-12-21-UMass-AR2?expand=1
BRANCH_COMPARE_URL="${REPO_URL}/pull/new/${BRANCH_NAME}"
slack_message "${MODEL_NAME}: push OK. branch comparison: ${BRANCH_COMPARE_URL}"

# upload PDF(s)
for PDF_FILE in "${PDF_FILES[@]}"; do
  slack_upload "${PDF_FILE}"
done

#
# done
#

slack_message "${MODEL_NAME}: done"
exit 0 # success
