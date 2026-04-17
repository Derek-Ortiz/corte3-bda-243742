#!/usr/bin/env bash
set -e

psql \
  -d "clinica_vet" \
  -v vet_pwd="$APP_VET_PASSWORD" \
  -v recep_pwd="$APP_RECEP_PASSWORD" \
  -v admin_pwd="$APP_ADMIN_PASSWORD" \
  -f /docker-entrypoint-initdb.d/04_roles_y_permisos.sql.tmpl
