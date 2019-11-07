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

FROM debian:buster

MAINTAINER r.h.p.vorderman@lumc.nl

ARG GALAXY_RELEASE
ENV GALAXY_VERSION=${GALAXY_RELEASE:-19.05} \
GALAXY_INSTALL_DIR=/opt/galaxy \
GALAXY_UID=1450 \
GALAXY_USER=galaxy \
GALAXY_HOME=/home/galaxy \
GALAXY_LOGS_DIR=/home/galaxy/logs \
GALAXY_VIRTUAL_ENV=/galaxy_venv \
GALAXY_CONDA_PREFIX=/conda


RUN apt-get update && apt-get install -y --no-install-recommends \
git \
curl \
ca-certificates \
&& \
git clone --depth=1 -b release_${GALAXY_VERSION} \
--separate-git-dir=/tmp/galaxy.git \
https://github.com/galaxyproject/galaxy.git $GALAXY_INSTALL_DIR \
&& rm $GALAXY_INSTALL_DIR/.git %% rm -rf /tmp/galaxy.git \
&& \
apt-get purge -y git && \
apt-get autoremove -y && \
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR ${GALAXY_INSTALL_DIR}

RUN useradd --home-dir /home/galaxy --create-home \
--shell /bin/bash --uid ${GALAXY_UID} galaxy && \
chown $GALAXY_USER:$GALAXY_USER $GALAXY_INSTALL_DIR

RUN mkdir -p $GALAXY_VIRTUAL_ENV $GALAXY_LOGS_DIR $GALAXY_CONDA_PREFIX \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_VIRTUAL_ENV \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_LOGS_DIR \
    && chown $GALAXY_USER:$GALAXY_USER $GALAXY_VIRTUAL_ENV

USER $GALAXY_USER

RUN curl -s -L https://repo.continuum.io/miniconda/Miniconda2-4.7.10-Linux-x86_64.sh > $GALAXY_HOME/miniconda.sh \
    && bash $GALAXY_HOME/miniconda.sh -b -p $GALAXY_CONDA_PREFIX/ \
    && $GALAXY_CONDA_PREFIX/bin/conda config --add channels defaults \
    && $GALAXY_CONDA_PREFIX/bin/conda config --add channels bioconda \
    && $GALAXY_CONDA_PREFIX/bin/conda config --add channels conda-forge \
    && $GALAXY_CONDA_PREFIX/bin/conda install virtualenv \
    && $GALAXY_CONDA_PREFIX/bin/conda clean --packages -t -i \
    && $GALAXY_CONDA_PREFIX/bin/virtualenv $GALAXY_VIRTUAL_ENV

RUN bash -c "$GALAXY_VIRTUAL_ENV/bin/pip install --no-cache-dir \
 -r requirements.txt \
 -r <(grep -v mysql lib/galaxy/dependencies/conditional-requirements.txt ) \
--index-url https://wheels.galaxyproject.org/simple \
--extra-index-url https://pypi.python.org/simple"


EXPOSE 8080
