# Copyright (c) 2019 Leiden University Medical Center
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

FROM debian:buster-slim

MAINTAINER r.h.p.vorderman@lumc.nl

ARG GALAXY_RELEASE

# Installation settings
ENV GALAXY_VERSION=${GALAXY_RELEASE:-19.05} \
    GALAXY_INSTALL_DIR=/opt/galaxy \
    GALAXY_UID=1450 \
    GALAXY_USER=galaxy \
    GALAXY_HOME=/home/galaxy \
    GALAXY_VIRTUAL_ENV=/galaxy_venv \
    DEBIAN_FRONTEND=noninteractive \
    EXPORT_DIR=/galaxy_data

# Store the conda prefix on the persistent volume
ENV GALAXY_CONFIG_DATA_DIR=$EXPORT_DIR/database
ENV GALAXY_CONFIG_TOOL_DEPENDENCY_DIR=$GALAXY_CONFIG_DATA_DIR/dependencies
ENV GALAXY_CONFIG_CONDA_PREFIX=$GALAXY_CONFIG_TOOL_DEPENDENCY_DIR/_conda

# Create the galaxy user.
RUN useradd --home-dir /home/galaxy --create-home \
--shell /bin/bash --uid ${GALAXY_UID} galaxy

# Make sure all necessary folders are present and owned by the galaxy user.
RUN mkdir -p $GALAXY_VIRTUAL_ENV $GALAXY_CONFIG_DATA_DIR $GALAXY_CONFIG_CONDA_PREFIX \
    $GALAXY_CONFIG_TOOL_DEPENDENCY_DIR $GALAXY_INSTALL_DIR $EXPORT_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_CONFIG_DATA_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_CONFIG_TOOL_DEPENDENCY_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_VIRTUAL_ENV \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_CONFIG_CONDA_PREFIX \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_INSTALL_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $EXPORT_DIR

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    bzip2 \
    gridengine-client \
    gridengine-drmaa1.0 \
    slurm-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/*

USER $GALAXY_USER

# Clone galaxy to the install dir.
RUN git clone --depth=1 -b release_${GALAXY_VERSION} \
--separate-git-dir=/tmp/galaxy.git \
https://github.com/galaxyproject/galaxy.git $GALAXY_INSTALL_DIR \
&& rm $GALAXY_INSTALL_DIR/.git %% rm -rf /tmp/galaxy.git

WORKDIR ${GALAXY_INSTALL_DIR}

# Install Conda and create a virtualenv
RUN curl -s -L https://repo.continuum.io/miniconda/Miniconda2-4.7.10-Linux-x86_64.sh > $GALAXY_HOME/miniconda.sh \
    && bash $GALAXY_HOME/miniconda.sh -u -b -p $GALAXY_CONFIG_CONDA_PREFIX/ \
    && rm $GALAXY_HOME/miniconda.sh \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda config --add channels defaults \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda config --add channels bioconda \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda config --add channels conda-forge \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda install virtualenv \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda clean --packages -t -i \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/virtualenv $GALAXY_VIRTUAL_ENV \
    && rm -rf $GALAXY_HOME/.cache/pip

# Populate default environment with all of galaxy's dependencies
RUN bash -c "$GALAXY_VIRTUAL_ENV/bin/pip install --no-cache-dir \
    -r requirements.txt \
    -r <(grep -v mysql lib/galaxy/dependencies/conditional-requirements.txt ) \
    --index-url https://wheels.galaxyproject.org/simple \
    --extra-index-url https://pypi.python.org/simple" \
    && rm -rf $GALAXY_VIRTUAL_ENV/src

# Build the galaxy client
RUN bash -c "source $GALAXY_VIRTUAL_ENV/bin/activate \
    && $GALAXY_VIRTUAL_ENV/bin/nodeenv -n $(cat client/.node_version) -p \
    && $GALAXY_VIRTUAL_ENV/bin/npm install --global yarn \
    && cd client \
    && $GALAXY_VIRTUAL_ENV/bin/yarn install --network-timeout 300000 --check-files \
    && $GALAXY_VIRTUAL_ENV/bin/yarn run build-production-maps " \
    && rm -rf /tmp/* $GALAXY_HOME/.cache/* $GALAXY_HOME/.npm client/node_modules*


# Galaxy configuration to create one persistent volume
ENV GALAXY_CONFIG_JOB_WORKING_DIRECTORY=$GALAXY_CONFIG_DATA_DIR/jobs_directory \
    GALAXY_CONFIG_FILE_PATH=$EXPORT_DIR/files \
    GALAXY_CONFIG_NEW_FILE_PATH=$EXPORT_DIR/tmp_files \
    GALAXY_CONFIG_TOOL_DATA_PATH=$EXPORT_DIR/tool-data \
    GALAXY_CONFIG_CLUSTER_FILES_DIRECTORY=$EXPORT_DIR/pbs \
    GALAXY_CONFIG_CITATION_CACHE_DATA_DIR=$EXPORT_DIR/citations/data \
    GALAXY_CONFIG_CITATION_CACHE_LOCK_DIR=$EXPORT_DIR/citations/locks \
    GALAXY_CONFIG_TOOL_TEST_DATA_DIRECTORIES=$EXPORT_DIR/test-data

# Make sure directories are present.
RUN mkdir -p \
    $GALAXY_CONFIG_DATA_DIR \
    $GALAXY_CONFIG_TOOL_DEPENDENCY_DIR \
    $GALAXY_CONFIG_CONDA_PREFIX \
    $GALAXY_CONFIG_FILE_PATH \
    $GALAXY_CONFIG_JOB_WORKING_DIRECTORY \
    $GALAXY_CONFIG_TOOL_DATA_PATH \
    $GALAXY_CONFIG_CLUSTER_FILES_DIRECTORY \
    $GALAXY_CONFIG_CITATION_CACHE_DATA_DIR \
    $GALAXY_CONFIG_CITATION_CACHE_LOCK_DIR \
    $GALAXY_CONFIG_TOOL_TEST_DATA_DIRECTORIES

# Miscellaneous galaxy settings to make proper use of this container
ENV GALAXY_CONFIG_WATCH_TOOLS=True \
    GALAXY_CONFIG_WATCH_TOOL_DATA_DIR=True \
    GALAXY_CONFIG_CONDA_AUTO_INIT=False \
    GALAXY_CONFIG_CONDA_EXEC=$GALAXY_CONFIG_CONDA_PREFIX/bin/conda

ENV UWSGI_PROCESSES=2 \
    UWSGI_THREADS=4

# Create the database. This only adds 3 mb to the container while drastically reducing start time.
RUN bash create_db.sh

# Make sure config files are present
RUN cp config/migrated_tools_conf.xml.sample config/migrated_tools_conf.xml \
    && cp config/shed_tool_conf.xml.sample config/shed_tool_conf.xml \
    && cp config/shed_tool_data_table_conf.xml.sample config/shed_tool_data_table_conf.xml \
    && cp config/shed_data_manager_conf.xml.sample config/shed_data_manager_conf.xml \
    && cp tool-data/shared/ucsc/builds.txt.sample tool-data/shared/ucsc/builds.txt \
    && cp tool-data/shared/ucsc/manual_builds.txt.sample tool-data/shared/ucsc/manual_builds.txt \
    && cp static/welcome.html.sample static/welcome.html

ADD galaxy.yml config/galaxy.yml

ADD ./entrypoint.sh /usr/bin/entrypoint.sh

EXPOSE 8080

CMD ["entrypoint.sh"]
