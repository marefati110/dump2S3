#! /bin/sh

set -u # `-e` omitted intentionally, but i can't remember why exactly :'(
set -o pipefail

source ./env.sh

s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}"

if [ $# -eq 1 ]; then
  timestamp="$1"
  # try .dump.gz first, then .dump
  key_base="${POSTGRES_DATABASE}_${timestamp}.dump"
  if aws $aws_args s3 ls "${s3_uri_base}/${key_base}.gz" >/dev/null 2>&1; then
    key_suffix="${key_base}.gz"
  else
    key_suffix="${key_base}"
  fi
else
  echo "Finding latest backup..."
  # List both .dump.gz and .dump and pick the latest
  key_suffix=$(aws $aws_args s3 ls "${s3_uri_base}/${POSTGRES_DATABASE}" \
      | awk '{ print $4 }' \
      | grep -E "\\.dump(\\.gz)?$" \
      | sort \
      | tail -n 1)
fi

echo "Fetching backup from S3..."
aws $aws_args s3 cp "${s3_uri_base}/${key_suffix}" db.fetch

# Decompress if needed
if echo "$key_suffix" | grep -qE "\\.gz$"; then
  echo "Decompressing gzip archive..."
  gunzip -c db.fetch > db.dump
  rm -f db.fetch
else
  mv db.fetch db.dump
fi

conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE"

echo "Restoring from backup..."
pg_restore $conn_opts --clean --if-exists db.dump
rm db.dump

echo "Restore complete."
