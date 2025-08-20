ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}-alpine

# Install script
COPY src/install.sh /install.sh
RUN sh /install.sh && rm /install.sh

# Environment variables
ENV POSTGRES_HOST ''
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER ''
ENV POSTGRES_PASSWORD ''
ENV PGDUMP_EXTRA_OPTS ''

ENV S3_ACCESS_KEY_ID ''
ENV S3_SECRET_ACCESS_KEY ''
ENV S3_BUCKET ''
ENV S3_REGION 'us-west-1'
ENV S3_PATH 'backup'
ENV S3_ENDPOINT ''
ENV S3_S3V4 'no'

ENV SCHEDULE ''
ENV BACKUP_KEEP_DAYS ''
ENV GZIP_ENABLED 'yes'
ENV RUN_BACKUP_ON_START 'false'
ENV WEBHOOK_URL ''


# Copy runtime scripts
COPY src/run.sh /run.sh
COPY src/env.sh /env.sh
COPY src/backup.sh /backup.sh

# Default command
CMD ["sh", "/run.sh"]
