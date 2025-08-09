#!/bin/sh

set -eu
set -o pipefail

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

echo "Creating backup of $POSTGRES_DATABASE database..."
pg_dump -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DATABASE" \
        ${PGDUMP_EXTRA_OPTS:-} \
        > db.dump

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}/${POSTGRES_DATABASE}_${timestamp}.dump"

local_file="db.dump"
s3_uri="$s3_uri_base"

echo "Uploading backup to private S3 storage..."
aws $AWS_ARGS s3 cp "$local_file" "$s3_uri"
rm "$local_file"

echo "Backup complete."

if [ -n "${BACKUP_KEEP_DAYS:-}" ]; then
  sec=$((86400 * BACKUP_KEEP_DAYS))
  date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET..."
  aws $AWS_ARGS s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}" \
    --query "${backups_query}" \
    --output text \
    | xargs -n1 -t -I 'KEY' aws $AWS_ARGS s3 rm s3://"${S3_BUCKET}"/'KEY'
  echo "Removal complete."
fi
