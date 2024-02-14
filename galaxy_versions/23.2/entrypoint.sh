#!/usr/bin/env bash
set -eu

source $GALAXY_VIRTUAL_ENV/bin/activate

cd $GALAXY_INSTALL_DIR

PYTHONPATH=lib GALAXY_CONFIG_FILE=/opt/galaxy/config/galaxy.yml \
$GALAXY_VIRTUAL_ENV/bin/gunicorn \
  'galaxy.webapps.galaxy.fast_factory:factory()' \
  --timeout 300 \
  --pythonpath lib \
  -k galaxy.webapps.galaxy.workers.Worker \
  -b :8080 \
  --workers=$GUNICORN_WORKERS \
  --threads=$GUNICORN_THREADS \
  --config python:galaxy.web_stack.gunicorn_config \
  --preload
