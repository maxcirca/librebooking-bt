#!/bin/sh
# Idempotently initialize the LibreBooking MariaDB schema on container start.
# Detects an empty database (no tables) and applies:
#   1. database_schema/create-schema.sql
#   2. database_schema/upgrades/<version>/{schema,data}.sql in version order
#   3. database_schema/create-data.sql
# Does nothing if any tables already exist, so safe to invoke on every boot.
set -u

: "${LB_DATABASE_HOSTSPEC:?LB_DATABASE_HOSTSPEC not set}"
: "${LB_DATABASE_USER:?LB_DATABASE_USER not set}"
: "${LB_DATABASE_PASSWORD:?LB_DATABASE_PASSWORD not set}"
: "${LB_DATABASE_NAME:?LB_DATABASE_NAME not set}"

SCHEMA_DIR="${SCHEMA_DIR:-/var/www/html/database_schema}"
DB_HOST="${LB_DATABASE_HOSTSPEC%:*}"
DB_PORT="${LB_DATABASE_HOSTSPEC#*:}"
if [ "${DB_HOST}" = "${LB_DATABASE_HOSTSPEC}" ]; then
    DB_PORT=3306
fi

MYSQL="mysql -h ${DB_HOST} -P ${DB_PORT} -u ${LB_DATABASE_USER} -p${LB_DATABASE_PASSWORD} ${LB_DATABASE_NAME}"

echo "[db-init] Checking schema state at ${DB_HOST}:${DB_PORT}/${LB_DATABASE_NAME}..."
TABLE_COUNT=$(${MYSQL} -N -B -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${LB_DATABASE_NAME}';" 2>&1)
case "${TABLE_COUNT}" in
    ''|*[!0-9]*)
        echo "[db-init] Could not query the database — skipping init. Output was:"
        echo "${TABLE_COUNT}"
        exit 0
        ;;
esac

if [ "${TABLE_COUNT}" -gt 0 ]; then
    echo "[db-init] Database already has ${TABLE_COUNT} tables — skipping init."
    exit 0
fi

echo "[db-init] Database is empty. Applying base schema..."
${MYSQL} --abort-source-on-error < "${SCHEMA_DIR}/create-schema.sql" || {
    echo "[db-init] FAILED applying create-schema.sql"; exit 1; }

for v in $(find "${SCHEMA_DIR}/upgrades/" -mindepth 1 -maxdepth 1 -type d \
            -printf '%f\n' | sort -V); do
    for f in schema.sql data.sql; do
        if [ -f "${SCHEMA_DIR}/upgrades/${v}/${f}" ]; then
            echo "[db-init] Applying upgrades/${v}/${f}"
            ${MYSQL} --abort-source-on-error \
                < "${SCHEMA_DIR}/upgrades/${v}/${f}" || {
                echo "[db-init] FAILED applying upgrades/${v}/${f}"; exit 1; }
        fi
    done
done

echo "[db-init] Loading initial data..."
${MYSQL} --abort-source-on-error < "${SCHEMA_DIR}/create-data.sql" || {
    echo "[db-init] FAILED applying create-data.sql"; exit 1; }

echo "[db-init] Schema initialization complete."
