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

ENV GALAXY_VERSION=19.05 \
GALAXY_INSTALL_DIR=/opt/galaxy

RUN apt-get update && apt-get install -y --no-install-recommends \
python \
python-pip \
python-setuptools \
git \
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

RUN bash -c 'pip install --no-cache-dir \
 -r requirements.txt \
 -r <(grep -v mysql lib/galaxy/dependencies/conditional-requirements.txt ) \
--index-url https://wheels.galaxyproject.org/simple \
--extra-index-url https://pypi.python.org/simple'

EXPOSE 8080



