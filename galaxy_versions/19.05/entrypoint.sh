#!/usr/bin/env bash

source $GALAXY_VIRTUAL_ENV/bin/activate

cd $GALAXY_INSTALL_DIR

$GALAXY_VIRTUAL_ENV/bin/uwsgi \
  --enable-threads \
  --processes $UWSGI_PROCESSES \
  --threads $UWSGI_THREADS \
  --offload-threads 1 \
  --buffer-size 16384 \
  --py-call-osafterfork \
  --logdate \
  --thunderlock \
  --master \
  --die-on-term \
  --http :8080 \
  --socket :8000 \
  --pythonpath lib \
  --virtualenv $GALAXY_VIRTUAL_ENV \
  --module 'galaxy.webapps.galaxy.buildapp:uwsgi_app()' \
  --static-map /static/style=static/style/blue \
  --static-map /static=static \
  --static-map /favicon.ico=static/favicon.ico \
  --yaml config/galaxy.yml
