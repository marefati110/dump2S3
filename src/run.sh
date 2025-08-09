#! /bin/sh

set -eu

if [ "$S3_S3V4" = "yes" ]; then
  aws configure set default.s3.signature_version s3v4
fi

# Normalize optional RUN_BACKUP_ON_START to yes/no
case "${RUN_BACKUP_ON_START:-}" in
  [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1)
    RUN_ON_START="yes"
    ;;
  *)
    RUN_ON_START="no"
    ;;
esac

if [ -z "${SCHEDULE:-}" ]; then
  # No schedule provided: run one backup and exit
  sh backup.sh
else
  # Schedule provided: optionally run an immediate backup, then start scheduler
  if [ "$RUN_ON_START" = "yes" ]; then
    echo "RUN_BACKUP_ON_START enabled: running initial backup before scheduler..."
    sh backup.sh
  fi
  exec go-cron "$SCHEDULE" /bin/sh backup.sh
fi
