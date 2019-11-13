#!/usr/bin/env bash

source $GALAXY_VIRTUAL_ENV/bin/activate

if [[ $UWSGI_PROCESSES > 1 ]]
    then THUNDERLOCK='--thunder-lock'
    else THUNDERLOCK=''
fi

cd $GALAXY_INSTALL_DIR

$GALAXY_VIRTUAL_ENV/bin/uwsgi \
  --enable-threads \
  --processes $UWSGI_PROCESSES \
  --threads $UWSGI_THREADS \
  --buffer-size 16384 \
  --py-call-osafterfork \
  --logdate \
  $THUNDERLOCK \
  --master \
  --die-on-term \
  --http :8080 \
  --pythonpath lib \
  --virtualenv $GALAXY_VIRTUAL_ENV \
  --module 'galaxy.webapps.galaxy.buildapp:uwsgi_app()' \
  --static-map /static/style=static/style/blue \
  --static-map /static=static \
  --static-map /favicon.ico=static/favicon.ico \
  --yaml config/galaxy.yml
