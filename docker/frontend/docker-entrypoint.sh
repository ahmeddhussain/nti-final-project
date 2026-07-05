#!/bin/sh
set -eu
if [ -n "${BACKEND_HOST:-}" ]; then
  envsubst '${BACKEND_HOST}' < /etc/nginx/conf.d/default.conf > /tmp/default.conf
  mv /tmp/default.conf /etc/nginx/conf.d/default.conf
fi
exec nginx -g 'daemon off;'
