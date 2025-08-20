#!/bin/sh

set -eu
set -o pipefail

# Webhook notification helpers (optional)
FAILED=1
STEP="init"

send_webhook() {
  # send_webhook <status> <message> <file>
  [ -z "${WEBHOOK_URL:-}" ] && return 0
  status="$1"
  message="$2"
  file_name="$3"
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  body='{"status":"'"$status"'","message":"'"$message"'","file":"'"$file_name"'","database":"'"${POSTGRES_DATABASE:-}"'","host":"'"${POSTGRES_HOST:-}"'","timestamp":"'"$ts"'"}'
  if command -v curl >/dev/null 2>&1; then
    curl -sS -X POST -H "Content-Type: application/json" -d "$body" "${WEBHOOK_URL}" >/dev/null 2>&1 || true
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- --header="Content-Type: application/json" --post-data="$body" "${WEBHOOK_URL}" >/dev/null 2>&1 || true
  else
    echo "Webhook skipped: no curl/wget available" >&2
  fi
}

on_exit() {
  code=$?
  if [ "${FAILED}" -ne 0 ]; then
    # figure out best-guess file name
    fn=""
    if [ -n "${s3_uri:-}" ]; then
      fn=$(basename "$s3_uri") || true
    elif [ -n "${local_file:-}" ]; then
      fn=$(basename "$local_file") || true
    fi
    send_webhook "error" "Backup failed at step: ${STEP}" "$fn"
  fi
  exit $code
}

trap on_exit EXIT INT TERM

source ./env.sh

# Required environment variables for private S3 storage
# Example:
#   S3_ENDPOINT="https://s3.myprivatehost.com"
#   AWS_ACCESS_KEY_ID="myaccesskey"
#   AWS_SECRET_ACCESS_KEY="mysecretkey"
#   S3_BUCKET="mybucket"
#   S3_PREFIX="backups"
#   POSTGRES_DATABASE="mydb"
#   POSTGRES_USER="postgres"
#   POSTGRES_PASSWORD="mypassword"
#   POSTGRES_HOST="localhost"
#   POSTGRES_PORT="5432"
#   BACKUP_KEEP_DAYS=7 # optional

AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"

STEP="dump"
echo "Creating backup of $POSTGRES_DATABASE database..."
pg_dump -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DATABASE" \
        ${PGDUMP_EXTRA_OPTS:-} \
        > db.dump
echo "Backup created"

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")

local_file="db.dump"
# s3_uri will be set after determining compression/filenames
# Gzip compression (default: enabled)
case "${GZIP_ENABLED:-yes}" in
  [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1)
  STEP="compress"
    echo "Compressing backup with gzip..."
    rm -f db.dump.gz
    gzip -9 -c db.dump > db.dump.gz
    rm -f db.dump
    local_file="db.dump.gz"
    # Determine final filename for compressed upload
    if [ -n "${GZIP_FILENAME:-}" ]; then
      s3_filename="$GZIP_FILENAME"
      case "$s3_filename" in
        *.gz) : ;;
        *) s3_filename="${s3_filename}.gz" ;;
      esac
    else
      s3_filename="${POSTGRES_DATABASE}_${timestamp}.dump.gz"
    fi
    s3_uri="s3://${S3_BUCKET}/${S3_PREFIX}/${s3_filename}"
    echo "Backup compressed"
    ;;
  *)
    local_file="db.dump"
    # Determine final filename for uncompressed upload
    if [ -n "${DUMP_FILENAME:-}" ]; then
      s3_filename="$DUMP_FILENAME"
      case "$s3_filename" in
        *.dump|*.dump.gz) : ;; # allow explicit .dump.gz though uncommon here
        *) s3_filename="${s3_filename}.dump" ;;
      esac
    else
      s3_filename="${POSTGRES_DATABASE}_${timestamp}.dump"
    fi
    s3_uri="s3://${S3_BUCKET}/${S3_PREFIX}/${s3_filename}"
    ;;
esac

echo "Uploading backup to private S3 storage..."
STEP="upload"
aws $AWS_ARGS s3 cp "$local_file" "$s3_uri"
rm "$local_file"

echo "Backup complete."
FAILED=0
send_webhook "success" "Backup completed" "$(basename "$s3_uri")"
