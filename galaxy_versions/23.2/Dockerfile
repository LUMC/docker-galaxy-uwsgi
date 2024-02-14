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

FROM debian:bookworm-slim

MAINTAINER r.h.p.vorderman@lumc.nl

# Build args to make it easier to build a container for a cluster environment.
ARG GALAXY_RELEASE
ARG GALAXY_USER
ARG GALAXY_UID
ARG EXPORT_DIR
ARG GALAXY_VIRTUAL_ENV

# Installation settings
ENV GALAXY_VERSION=${GALAXY_RELEASE:-23.2} \
    GALAXY_UID=${GALAXY_UID:-1450} \
    GALAXY_USER=${GALAXY_USER:-galaxy} \
    EXPORT_DIR=${EXPORT_DIR:-/var/lib/galaxy} \
    GALAXY_INSTALL_DIR=/opt/galaxy \
    GALAXY_HOME=/home/galaxy \
    DEBIAN_FRONTEND=noninteractive

# Galaxy virtualenv in /opt together with galaxy..
ENV GALAXY_VIRTUAL_ENV=${GALAXY_VIRTUAL_ENV:-$GALAXY_INSTALL_DIR/venv}
# Store the conda prefix on the persistent volume
ENV GALAXY_CONFIG_DATA_DIR=$EXPORT_DIR/database
ENV GALAXY_CONFIG_TOOL_DEPENDENCY_DIR=$EXPORT_DIR/tool_dependencies
ENV GALAXY_CONFIG_CONDA_PREFIX=$GALAXY_CONFIG_TOOL_DEPENDENCY_DIR/_conda

# Create the galaxy user.
RUN useradd --home-dir /home/galaxy --create-home \
    --shell /bin/bash --uid ${GALAXY_UID} galaxy \
    && rm -rf /var/log/*

# Make sure all necessary folders are present and owned by the galaxy user. Remove folders from the galaxy install dir
# as this gives errors while cloning. This removes the created venv folder. This makes sure the
# galaxy virtualenv can be set in the build args.
RUN mkdir -p $GALAXY_VIRTUAL_ENV $GALAXY_CONFIG_DATA_DIR $GALAXY_CONFIG_CONDA_PREFIX \
    $GALAXY_CONFIG_TOOL_DEPENDENCY_DIR $GALAXY_INSTALL_DIR $EXPORT_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_CONFIG_DATA_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_CONFIG_TOOL_DEPENDENCY_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_VIRTUAL_ENV \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_CONFIG_CONDA_PREFIX \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_INSTALL_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $EXPORT_DIR \
    && rm -rf $GALAXY_INSTALL_DIR/*

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    bzip2 \
    nano-tiny \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/* \
    /var/log/* /var/lib/apt/extended_states

USER $GALAXY_USER

# Install Conda
# we use conda clean -f flag to also remove the package cache for used packages
# this has no deleterious effect since no packages in the base refer to the pkgs dir
# Make sure all python files are compiled so it does not happen at runtime.
# Some files give syntax errors (notable the ones for python2 while compiling with python3)
# This adds only 100 kb to the container.
RUN curl -s -L https://repo.anaconda.com/miniconda/Miniconda3-py310_23.11.0-2-Linux-x86_64.sh > $GALAXY_HOME/miniconda.sh \
    && bash $GALAXY_HOME/miniconda.sh -u -b -p $GALAXY_CONFIG_CONDA_PREFIX/ \
    && rm $GALAXY_HOME/miniconda.sh \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda config --add channels defaults \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda config --add channels bioconda \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda config --add channels conda-forge \
    && $GALAXY_CONFIG_CONDA_PREFIX/bin/conda clean --all -f -y \
    && ($GALAXY_CONFIG_CONDA_PREFIX/bin/python -m compileall $GALAXY_CONFIG_CONDA_PREFIX || exit 0)

# Clone galaxy to the install dir.
# Remove the git dir as it is unnecessary
# Remove galaxy documentation, as it is not used by galaxy
# Also remove test files, CI files etc.
# Compile the python files in lib, so this does not need to happen at runtime.
# This only adds 7-8 mb to the container and ensures more statelessness outside the
# export dir. If the compileall step does not happen, the .pyc files will be
# generated in between in multiple layers (such as the create_db.sh layer). By
# compiling before hand we keep the changes in each layer to a minimal part
# of the filesystem as opposed to all over the place.
RUN git clone --depth=1 -b release_${GALAXY_VERSION} \
    https://github.com/galaxyproject/galaxy.git $GALAXY_INSTALL_DIR \
    && rm -rf $GALAXY_INSTALL_DIR/.git \
    $GALAXY_INSTALL_DIR/docs $GALAXY_INSTALL_DIR/test/ $GALAXY_INSTALL_DIR/test-data/ \
    $GALAXY_INSTALL_DIR/.ci $GALAXY_INSTALL_DIR/.circleci $GALAXY_INSTALL_DIR/.coveragerc \
    $GALAXY_INSTALL_DIR/.gitignore $GALAXY_INSTALL_DIR/.travis.yml \
    $GALAXY_INSTALL_DIR/Makefile $GALAXY_INSTALL_DIR/pytest.ini \
    $GALAXY_INSTALL_DIR/tox.ini \
    && ($GALAXY_CONFIG_CONDA_PREFIX/bin/python -m compileall $GALAXY_INSTALL_DIR/lib || exit 0)

WORKDIR ${GALAXY_INSTALL_DIR}

# Create default environment with all of galaxy's dependencies.
# Also install nodeenv, npm and yarn in the GALAXY_VIRTUAL_ENV.
# Again we compile all files that can be precompiled. This adds only very little (<200kb)
# if anything to the layer.
RUN $GALAXY_CONFIG_CONDA_PREFIX/bin/python -m venv $GALAXY_VIRTUAL_ENV \
    && bash -c "$GALAXY_VIRTUAL_ENV/bin/pip install --no-cache-dir \
    -r requirements.txt \
    --index-url https://wheels.galaxyproject.org/simple \
    --extra-index-url https://pypi.python.org/simple \
    && source $GALAXY_VIRTUAL_ENV/bin/activate \
    && $GALAXY_VIRTUAL_ENV/bin/nodeenv -n $(cat client/.node_version) -p \
    && $GALAXY_VIRTUAL_ENV/bin/npm install --global yarn" \
    && rm -rf $GALAXY_VIRTUAL_ENV/src $GALAXY_HOME/.npm $GALAXY_HOME/.config && rm -rf $GALAXY_HOME/.cache  \
    && ($GALAXY_VIRTUAL_ENV/bin/python -m compileall $GALAXY_VIRTUAL_ENV || exit 0)

# Install conditional requirements
RUN $GALAXY_CONFIG_CONDA_PREFIX/bin/python -m venv $GALAXY_VIRTUAL_ENV \
    && bash -c "$GALAXY_VIRTUAL_ENV/bin/pip install --no-cache-dir \
    -r <(grep -v mysql lib/galaxy/dependencies/conditional-requirements.txt | grep -v fs | grep -v tensorflow) \
    --index-url https://wheels.galaxyproject.org/simple \
    --extra-index-url https://pypi.python.org/simple " \
    && rm -rf $GALAXY_VIRTUAL_ENV/src $GALAXY_HOME/.config && rm -rf $GALAXY_HOME/.cache  \
    && ($GALAXY_VIRTUAL_ENV/bin/python -m compileall $GALAXY_VIRTUAL_ENV || exit 0)

# Build the galaxy client
RUN bash -c "cd client \
    && source $GALAXY_VIRTUAL_ENV/bin/activate \
    && $GALAXY_VIRTUAL_ENV/bin/yarn install --network-timeout 300000 --check-files \
    && $GALAXY_VIRTUAL_ENV/bin/yarn run build-production-maps " \
    && rm -rf /tmp/* $GALAXY_HOME/.cache client/node_modules*

# Galaxy configuration to create one persistent volume
ENV GALAXY_CONFIG_JOB_WORKING_DIRECTORY=$GALAXY_CONFIG_DATA_DIR/jobs_directory \
    GALAXY_CONFIG_FILE_PATH=$GALAXY_CONFIG_DATA_DIR/files \
    GALAXY_CONFIG_NEW_FILE_PATH=$GALAXY_CONFIG_DATA_DIR/files/tmp \
    GALAXY_CONFIG_TOOL_DATA_PATH=$EXPORT_DIR/tool_data \
    GALAXY_CONFIG_CLUSTER_FILES_DIRECTORY=$GALAXY_CONFIG_DATA_DIR/pbs \
    GALAXY_CONFIG_CITATION_CACHE_DATA_DIR=$GALAXY_CONFIG_DATA_DIR/citations/data \
    GALAXY_CONFIG_CITATION_CACHE_LOCK_DIR=$GALAXY_CONFIG_DATA_DIR/citations/locks \
    GALAXY_CONFIG_TOOL_TEST_DATA_DIRECTORIES=$EXPORT_DIR/tool_test_data \
    GALAXY_CONFIG_MANAGED_CONFIG_DIR=$GALAXY_CONFIG_DATA_DIR/config \
    GALAXY_CONFIG_MUTABLE_CONFIG_DIR=$EXPORT_DIR/mutable_config \
    GALAXY_CONFIG_TEMPLATE_CACHE_PATH=$GALAXY_CONFIG_DATA_DIR/compiled_templates \
    GALAXY_SHED_TOOL_DIR=$EXPORT_DIR/shed_tools \
    GALAXY_CONFIG_DATABASE_CONNECTION="sqlite:///$GALAXY_CONFIG_DATA_DIR/universe.sqlite?isolation_level=IMMEDIATE"

ADD galaxy.yml config/galaxy.yml

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
    $GALAXY_CONFIG_TOOL_TEST_DATA_DIRECTORIES \
    $GALAXY_CONFIG_MUTABLE_CONFIG_DIR \
    $GALAXY_CONFIG_MANAGED_CONFIG_DIR \
    $GALAXY_SHED_TOOL_DIR

# Miscellaneous galaxy settings to make proper use of this container in a
# production setting. These settings are opinionated.
ENV GALAXY_CONFIG_WATCH_TOOLS=True \
    GALAXY_CONFIG_WATCH_TOOL_DATA_DIR=True \
    GALAXY_CONFIG_CONDA_AUTO_INIT=False \
    GALAXY_CONFIG_LOG_LEVEL=INFO

# A sqlite database can only be written to by one thread at a time. So we have one uwsgi process.
# Otherwise there will be errors.
# Of course this can be different for postgres databases but that is for the user to set.
# As a side note: One uwsgi process feels much more responsive when testing.
ENV UWSGI_PROCESSES=1 \
    UWSGI_THREADS=4

# Make sure config files are present
RUN mkdir -p $GALAXY_CONFIG_TOOL_DATA_PATH/shared/ucsc/ \
    && cp tool-data/shared/ucsc/builds.txt.sample $GALAXY_CONFIG_TOOL_DATA_PATH/shared/ucsc/builds.txt \
    && cp tool-data/shared/ucsc/manual_builds.txt.sample $GALAXY_CONFIG_TOOL_DATA_PATH/shared/ucsc/manual_builds.txt \
    && cp static/welcome.html.sample static/welcome.html

ADD ./entrypoint.sh /usr/bin/entrypoint.sh

EXPOSE 8080

CMD ["entrypoint.sh"]
