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

# install system libraries required by pyenv. per https://medium.com/@aashari/easy-to-follow-guide-of-how-to-install-pyenv-on-ubuntu-a3730af8d7f0
RUN apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

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

# install R packages from CRAN. NB: we install arrow explicitly so that it will get the latest version. o/w we see an
# error like: namespace ‘arrow’ 14.0.2.1 is being loaded, but >= 17.0.0 is required
RUN Rscript -e "install.packages(c('lubridate', 'readr', 'remotes'))"
RUN Rscript -e "install.packages('arrow', repos = c('https://apache.r-universe.dev', 'https://cran.r-project.org'))"

# install R packages from reichlab
RUN Rscript -e "remotes::install_github('reichlab/zoltr')"
RUN Rscript -e "remotes::install_github('hubverse-org/hubData')"
RUN Rscript -e "remotes::install_github('hubverse-org/hubVis')"

# install required Python packages
RUN pip3 install --upgrade pip
RUN pip3 install 'click==8.1.7' 'numpy==2.1.3' 'pandas==2.2.3' 'python-dateutil==2.9.0.post0' 'idmodels @ git+https://github.com/reichlab/idmodels@b08602e37f1a4d5d8aed9caac5b28188583b23a5'

WORKDIR /app

# clone https://github.com/reichlab/container-utils. ADD is a hack ala https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands
ADD "https://api.github.com/repos/reichlab/container-utils/commits?per_page=1" latest_commit
RUN git clone https://github.com/reichlab/container-utils.git

# the ADD is a hack ala https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands
ADD "https://api.github.com/repos/elray1/sarix/commits?per_page=1" latest_commit
RUN pip3 install git+https://github.com/elray1/sarix.git

COPY flu_ar2/main.py flu_ar2/plot.R flu_ar2/run.sh ./

CMD ["bash", "/app/run.sh"]
