FROM rocker/r-ver:4.3.2

# install general OS utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    git

# install OS binaries required by R packages - via rocker-versioned2/scripts/install_tidyverse.sh
RUN apt-get install -y --no-install-recommends \
    libxml2-dev \
    libcairo2-dev \
    libgit2-dev \
    default-libmysqlclient-dev \
    libpq-dev \
    libsasl2-dev \
    libsqlite3-dev \
    libssh2-1-dev \
    libxtst6 \
    libcurl4-openssl-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    unixodbc-dev

# install system libraries required by pyenv
RUN apt install -y --no-install-recommends \
    make \
    build-essential \
    curl \
    git \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libxmlsec1-dev \
    llvm \
    tk-dev \
    wget \
    xz-utils \
    zlib1g-dev

# install pyenv, install python 3.12.7, and set pyenv global. per:
# https://stackoverflow.com/questions/65768775/how-do-i-integrate-pyenv-poetry-and-docker

ENV HOME="/root"
WORKDIR ${HOME}
RUN git clone --depth=1 https://github.com/pyenv/pyenv.git .pyenv
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${PATH}"

ENV PYTHON_VERSION=3.12.7
RUN pyenv install ${PYTHON_VERSION}
RUN pyenv global ${PYTHON_VERSION}

# install the `gh` GitHub CLI binary
RUN apt update && apt install -y curl gpg
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg;
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null;
RUN apt update && apt install -y gh;

WORKDIR /app

ARG MODEL_DIR

# install required Python packages
COPY "${MODEL_DIR}/requirements.txt" ./
RUN pip3 install --upgrade pip
RUN pip3 install -r requirements.txt

# install required R packages using renv
COPY "${MODEL_DIR}/renv.lock" ./
ENV RENV_PATHS_LIBRARY="renv/library"
RUN Rscript -e "install.packages('renv', repos = c(CRAN = 'https://cloud.r-project.org'))"
RUN Rscript -e "renv::restore()"

# clone https://github.com/reichlab/container-utils. ADD is a hack ala https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands
ADD "https://api.github.com/repos/reichlab/container-utils/commits?per_page=1" latest_commit
RUN git clone https://github.com/reichlab/container-utils.git

COPY run.sh "${MODEL_DIR}/*" ./

CMD ["bash", "/app/run.sh"]
