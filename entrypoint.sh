#!/usr/bin/env bash

source $GALAXY_VIRTUAL_ENV/bin/activate

set -eu

cd $GALAXY_INSTALL_DIR

$GALAXY_VIRTUAL_ENV/bin/uwsgi \
  --enable-threads \
  --processes $UWSGI_PROCESSES \
  --threads $UWSGI_THREADS \
  --buffer-size 16384 \
  --logdate \
  --thunder-lock \
  --master \
  --http :8080 \
  --pythonpath lib \
  --virtualenv $GALAXY_VIRTUAL_ENV \
  --module 'galaxy.webapps.galaxy.buildapp:uwsgi_app()' \
  --die-on-term \
  --yaml config/galaxy.yml