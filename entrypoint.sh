#!/usr/bin/env bash
set -eu

cd $GALAXY_INSTALL_DIR

$GALAXY_VIRTUALENV/bin/uwsgi \
  --logdate \
  --thunder-lock \
  --master \
  --logto $GALAXY_LOGS_DIR/uwsgi_log \
  --http :8080 --pythonpath lib \
  --module galaxy.webapps.galaxy.buildapp:uwsgi_app() \
  -b 16384